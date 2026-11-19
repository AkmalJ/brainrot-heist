--[[
	Thieves.luau — locks, stealing and Ash Goblins for MAGMA MAYHEM.

	ServerScriptService ModuleScript. Owns the game's tension:
	  * Base LOCK: ToggleLock raises a forcefield dome for a duration
	    (Base Lock upgrade stretches it), then a cooldown, then open
	    again. Locked bases cannot be stolen from — by players or
	    goblins.
	  * Player stealing: every occupied pedestal wears a STEAL prompt
	    for everyone but its owner. Hold it, and the brainrot is
	    yours — if you can carry it home.
	  * Ash Goblins: NPC thieves that stalk a random unlocked base,
	    grab a placed brainrot and flee to the shore. Every player
	    carries a Magma Mallet: whack a loaded goblin and it drops
	    the loot as a loose item and stands stunned.
	  * Rival NPC bases: stocked pedestals anyone may grab from —
	    but the base's guard goblin chases the thief and knocks the
	    loot loose if it catches them before they bank it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))
local Upgrades = require(ReplicatedStorage:WaitForChild("Upgrades"))

local Thieves = {}
local G = nil -- the Game context, set by Init

local goblins = {} -- array of goblin records
local nextGoblinAt = 0
local rushEndsAt = 0
local lastWhackAt = {} -- [player] = os.clock of last mallet swing

local GOBLIN_HOMES = {
	Vector3.new(0, 1, -186), Vector3.new(-172, 1, 55), Vector3.new(172, 1, 55),
}

local function playerRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--====================================================================--
-- The Magma Mallet: every player's anti-goblin tool.
--====================================================================--

local function BuildMallet()
	local tool = Instance.new("Tool")
	tool.Name = "Magma Mallet"
	tool.ToolTip = "Whack Ash Goblins to make them drop stolen brainrots!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 2.6, 0.45)
	handle.Color = Color3.fromRGB(96, 66, 44)
	handle.Material = Enum.Material.Wood
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "MalletHead"
	head.Size = Vector3.new(1.5, 1.1, 1.1)
	head.Color = Color3.fromRGB(255, 120, 45)
	head.Material = Enum.Material.Neon
	head.CanCollide = false
	head.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
	head.CFrame = handle.CFrame * CFrame.new(0, 1.6, 0)
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if player then
			Thieves.WhackGoblins(player)
		end
	end)
	return tool
end

local function GiveMallet(player)
	local function hasMallet(container)
		return container and container:FindFirstChild("Magma Mallet")
	end
	if hasMallet(player:FindFirstChild("Backpack"))
		or hasMallet(player:FindFirstChild("StarterGear"))
		or hasMallet(player.Character) then
		return
	end
	local mallet = BuildMallet()
	mallet.Parent = player:WaitForChild("Backpack")
end

-- A swing lands on every goblin in reach: loaded ones drop their
-- loot as a loose item (and the swinger earns a "stole back"), all
-- of them stand stunned while the stars clear.
function Thieves.WhackGoblins(player)
	local now = os.clock()
	if now - (lastWhackAt[player] or 0) < 0.45 then
		return
	end
	lastWhackAt[player] = now
	local root = playerRoot(player)
	if not root then
		return
	end
	for _, goblin in ipairs(goblins) do
		local gpos = goblin.model:GetPivot().Position
		if (gpos - root.Position).Magnitude < 8.5 then
			if goblin.loot then
				local loot = goblin.loot
				goblin.loot = nil
				loot.model:Destroy()
				G.Modules.Economy.AddLooseItem(loot.defName, loot.mutationName,
					Vector3.new(gpos.X, math.max(gpos.Y, 1), gpos.Z))
				local st = G.State[player]
				if st then
					st.stats.stoleBack += 1
				end
				G.Toast(player, "WHACK!", "The goblin dropped the brainrot — grab it!", "success")
				goblin.mode = "stunned"
				goblin.stunEnds = now + 3
			elseif goblin.mode ~= "stunned" then
				goblin.mode = "stunned"
				goblin.stunEnds = now + 2
			end
		end
	end
end

--====================================================================--
-- Base lock: open -> locked (duration) -> cooldown -> open.
--====================================================================--

local function RefreshLockDome(st)
	if st.plot and st.plot.lockDome then
		st.plot.lockDome.Transparency = (st.lockState == "locked") and 0.72 or 1
	end
end

local function OnToggleLock(player)
	local st = G.State[player]
	if not st then
		return
	end
	if st.lockState ~= "open" then
		G.Toast(player, "Lock unavailable", "Your forcefield is " .. st.lockState .. ".", "warn")
		return
	end
	local duration = Upgrades.LockDuration(st.upgrades["Base Lock"])
	st.lockState = "locked"
	st.lockEndsAt = os.time() + duration
	RefreshLockDome(st)
	G.Toast(player, "Base LOCKED", "Forcefield up for " .. duration .. " seconds.", "success")
	G.PushHud(player)
end

--====================================================================--
-- Stealing from player bases (STEAL prompts on occupied pedestals)
--====================================================================--

local function TryStealFromBase(thief, owner, index)
	local thiefState = G.State[thief]
	local ownerState = G.State[owner]
	if not thiefState or not ownerState or thief == owner then
		return
	end
	if thiefState.carried then
		G.Toast(thief, "Hands full!", "Bank your current brainrot first.", "warn")
		return
	end
	if ownerState.lockState == "locked" then
		G.Toast(thief, "Forcefield up!", string.upper(owner.DisplayName) .. "'s base is locked.", "warn")
		return
	end
	local entry = ownerState.pedestals[index]
	if not entry then
		return
	end
	-- No yields between the peek and the removal: this is atomic.
	if G.Modules.Economy.GiveCarried(thief, entry.defName, entry.mutationName, "steal") then
		G.Modules.Economy.RemoveFromPedestal(owner, index)
		local def = Brainrots.ByName[entry.defName]
		G.Toast(thief, "STOLEN!", "You grabbed " .. def.name .. " — get it home!", "success")
		G.Toast(owner, "ROBBED!", string.upper(thief.DisplayName) .. " stole your " .. def.name .. "!", "danger")
	end
end

local function SyncStealPrompts()
	for owner, st in pairs(G.State) do
		if st.plot then
			for index = 1, #st.plot.pedestalParts do
				local part = st.plot.pedestalParts[index]
				local prompt = part:FindFirstChild("StealPrompt")
				if st.pedestals[index] then
					if not prompt then
						prompt = Instance.new("ProximityPrompt")
						prompt.Name = "StealPrompt"
						prompt.ActionText = "STEAL"
						prompt.HoldDuration = 1.5
						prompt.MaxActivationDistance = 12
						prompt.RequiresLineOfSight = false
						prompt.Parent = part
						local idx = index
						prompt.Triggered:Connect(function(triggerer)
							if triggerer ~= owner then
								TryStealFromBase(triggerer, owner, idx)
							end
						end)
					end
					local entry = st.pedestals[index]
					local def = Brainrots.ByName[entry.defName]
					local mutation = entry.mutationName and Brainrots.MutationByName[entry.mutationName]
					prompt.ObjectText = Brainrots.DisplayName(def, mutation)
				elseif prompt then
					prompt:Destroy()
				end
			end
		end
	end
end

--====================================================================--
-- Ash Goblins
--====================================================================--

local function BuildGoblinModel()
	local model = Instance.new("Model")
	model.Name = "AshGoblin"
	local function part(name, size, cf, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.Parent = model
		return p
	end
	local body = part("Body", Vector3.new(1.5, 1.7, 1.1), CFrame.new(0, 1.15, 0), Color3.fromRGB(105, 125, 80))
	part("Head", Vector3.new(1.25, 1.15, 1.15), CFrame.new(0, 2.6, 0), Color3.fromRGB(120, 140, 90))
	for _, s in ipairs({ -1, 1 }) do
		part("Ear", Vector3.new(0.75, 0.22, 0.22), CFrame.new(s * 0.95, 2.85, 0), Color3.fromRGB(120, 140, 90))
		part("Eye", Vector3.new(0.18, 0.18, 0.1), CFrame.new(s * 0.3, 2.7, -0.6),
			Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
	end
	part("Sack", Vector3.new(1.1, 1.3, 0.7), CFrame.new(0, 1.5, 0.85), Color3.fromRGB(130, 100, 65))
	model.PrimaryPart = body
	return model
end

local function MoveGoblinToward(goblin, targetPos, dt)
	local pivot = goblin.model:GetPivot()
	local pos = pivot.Position
	local flat = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	local dist = flat.Magnitude
	if dist > 0.05 then
		local step = math.min(dist, goblin.speed * dt)
		local dir = flat / dist
		local newPos = pos + dir * step
		newPos = Vector3.new(newPos.X, pos.Y + (targetPos.Y - pos.Y) * math.min(1, dt * 3), newPos.Z)
		goblin.model:PivotTo(CFrame.lookAt(newPos, Vector3.new(newPos.X + dir.X, newPos.Y, newPos.Z + dir.Z)))
	else
		-- Arrived horizontally; settle the height too.
		goblin.model:PivotTo(CFrame.new(pos.X, targetPos.Y, pos.Z) * (pivot - pivot.Position))
	end
	return dist
end

local function DestroyGoblin(goblin)
	if goblin.loot and goblin.loot.model then
		goblin.loot.model:Destroy()
	end
	if goblin.model then
		goblin.model:Destroy()
	end
	for i, g in ipairs(goblins) do
		if g == goblin then
			table.remove(goblins, i)
			break
		end
	end
end

local function SpawnGoblin()
	-- Eligible victims: someone home, something placed, no forcefield.
	local victims = {}
	for player, st in pairs(G.State) do
		if st.lockState ~= "locked" then
			local occupied = {}
			for index in pairs(st.pedestals) do
				table.insert(occupied, index)
			end
			if #occupied > 0 then
				table.insert(victims, { player = player, st = st, occupied = occupied })
			end
		end
	end
	if #victims == 0 then
		return false
	end
	local victim = victims[math.random(1, #victims)]
	local index = victim.occupied[math.random(1, #victim.occupied)]
	local home = GOBLIN_HOMES[math.random(1, #GOBLIN_HOMES)]
	local model = BuildGoblinModel()
	model:PivotTo(CFrame.new(home))
	model.Parent = G.ActorsFolder
	table.insert(goblins, {
		model = model, mode = "seek", speed = 13.5,
		targetPlayer = victim.player, targetIndex = index,
		loot = nil, homePos = home, stunEnds = 0, bornAt = os.clock(),
	})
	return true
end

local function GoblinGrab(goblin)
	local owner = goblin.targetPlayer
	local st = G.State[owner]
	if not st or st.lockState == "locked" then
		goblin.mode = "flee" -- forcefield beat him to it
		return
	end
	local entry = G.Modules.Economy.RemoveFromPedestal(owner, goblin.targetIndex)
	if not entry then
		goblin.mode = "flee"
		return
	end
	local def = Brainrots.ByName[entry.defName]
	local lootModel = Brainrots.BuildBrainrotModel(def, entry.mutationName)
	lootModel:ScaleTo(0.55)
	lootModel.Parent = G.ActorsFolder
	goblin.loot = { defName = entry.defName, mutationName = entry.mutationName, model = lootModel }
	goblin.mode = "flee"
	G.Toast(owner, "GOBLIN THEFT!", "An Ash Goblin grabbed your " .. def.name
		.. "! Whack it with your Magma Mallet!", "danger")
end

local function StepGoblin(goblin, dt, now)
	if goblin.mode == "stunned" then
		if now >= goblin.stunEnds then
			goblin.mode = "flee"
		end
		return
	end
	if goblin.mode == "seek" then
		local st = G.State[goblin.targetPlayer]
		if not st or not st.pedestals[goblin.targetIndex] then
			goblin.mode = "flee"
			return
		end
		local target = st.plot.pedestalCFrames[goblin.targetIndex].Position + Vector3.new(0, 0.5, 0)
		if MoveGoblinToward(goblin, target, dt) < 4.2 then
			GoblinGrab(goblin)
		end
	elseif goblin.mode == "flee" then
		if MoveGoblinToward(goblin, goblin.homePos + Vector3.new(0, 0.5, 0), dt) < 4 then
			if goblin.loot then
				local owner = goblin.targetPlayer
				if G.State[owner] then
					G.Toast(owner, "Gone!", "The goblin escaped with your "
						.. goblin.loot.defName .. ". It is gone for good.", "danger")
				end
			end
			DestroyGoblin(goblin)
		end
	elseif goblin.mode == "hunt" then
		-- A rival base's guard: chase the thief until they bank the
		-- loot, the chase times out, or the guard lands a knock-loose.
		local target = goblin.guardTarget
		local tst = target and G.State[target]
		if not tst or not tst.carried or now - goblin.bornAt > 30 then
			DestroyGoblin(goblin)
			return
		end
		local root = playerRoot(target)
		if not root then
			DestroyGoblin(goblin)
			return
		end
		if MoveGoblinToward(goblin, root.Position - Vector3.new(0, 2, 0), dt) < 3.2 then
			G.Modules.Economy.DropCarried(target, root.Position + Vector3.new(3, 1, 0))
			G.Toast(target, "CAUGHT!", "The guard knocked your stolen brainrot loose!", "danger")
			DestroyGoblin(goblin)
		end
	end
	-- Carried loot rides above the goblin's head.
	if goblin.loot and goblin.loot.model then
		local head = goblin.model:GetPivot() * CFrame.new(0, 3.6, 0)
		goblin.loot.model:PivotTo(head)
	end
end

-- Eruption's Goblin Rush event calls this: a wave window opens.
function Thieves.TriggerGoblinRush(duration)
	rushEndsAt = os.clock() + duration
	nextGoblinAt = 0
end

--====================================================================--
-- Rival NPC bases: stocked shelves and their guards
--====================================================================--

local function StockRivalSlot(rival, slotIndex)
	local def, mutation = Brainrots.RollSpawn({ zoneLuck = rival.zone == "Ashen Beach" and 1 or (rival.zone == "Obsidian Fields" and 1.5 or 2.5) })
	local mutationName = mutation and mutation.name or nil
	local model = Brainrots.BuildBrainrotModel(def, mutationName)
	model:PivotTo(rival.pedestalCFrames[slotIndex])
	model.Parent = G.ActorsFolder
	rival.slots[slotIndex] = { defName = def.name, mutationName = mutationName, model = model }
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "GRAB"
	prompt.ObjectText = Brainrots.DisplayName(def, mutation)
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = rival.pedestalParts[slotIndex]
	prompt.Triggered:Connect(function(player)
		Thieves.TryStealFromRival(player, rival, slotIndex)
	end)
	rival.slots[slotIndex].prompt = prompt
end

function Thieves.TryStealFromRival(player, rival, slotIndex)
	local st = G.State[player]
	if not st then
		return
	end
	local slot = rival.slots[slotIndex]
	if not slot then
		return
	end
	if st.carried then
		G.Toast(player, "Hands full!", "Bank your current brainrot first.", "warn")
		return
	end
	if not st.zonesUnlocked[rival.zone] then
		G.Toast(player, "Zone locked!", "Rekindle to unlock the " .. rival.zone .. ".", "warn")
		return
	end
	if G.Modules.Economy.GiveCarried(player, slot.defName, slot.mutationName, "rival") then
		if slot.prompt then
			slot.prompt:Destroy()
		end
		slot.model:Destroy()
		rival.slots[slotIndex] = nil
		st.stats.rivalSteals += 1
		G.Toast(player, "GRABBED!", "Get it home — " .. rival.name .. "'s guard is coming!", "success")
		-- The guard wakes.
		local model = BuildGoblinModel()
		model:PivotTo(CFrame.new(rival.guardPost))
		model.Parent = G.ActorsFolder
		table.insert(goblins, {
			model = model, mode = "hunt", speed = 15,
			guardTarget = player, loot = nil,
			homePos = rival.guardPost, stunEnds = 0, bornAt = os.clock(),
		})
		-- And the shelf restocks itself a minute later.
		task.delay(60, function()
			if not rival.slots[slotIndex] then
				StockRivalSlot(rival, slotIndex)
			end
		end)
	end
end

--====================================================================--
-- Wiring + loops
--====================================================================--

function Thieves.Init(game)
	G = game
	nextGoblinAt = os.clock() + 40

	G.Remotes.ToggleLock.OnServerEvent:Connect(OnToggleLock)

	for _, player in ipairs(Players:GetPlayers()) do
		GiveMallet(player)
	end
	Players.PlayerAdded:Connect(GiveMallet)

	for _, rival in ipairs(G.RivalBases) do
		for k = 1, 4 do
			StockRivalSlot(rival, k)
		end
	end

	-- Lock state machine + steal-prompt upkeep.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.time()
			for _, st in pairs(G.State) do
				if st.lockState == "locked" and now >= st.lockEndsAt then
					local cooldown = Upgrades.LockCooldown(st.upgrades["Base Lock"])
					st.lockState = "cooldown"
					st.lockEndsAt = now + cooldown
					RefreshLockDome(st)
					G.PushHud(st.player)
				elseif st.lockState == "cooldown" and now >= st.lockEndsAt then
					st.lockState = "open"
					st.lockEndsAt = 0
					RefreshLockDome(st)
					G.PushHud(st.player)
				end
			end
			SyncStealPrompts()
		end
	end)

	-- Goblin spawner: a thief every 45–75 s, a wave during a rush.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			if now >= nextGoblinAt then
				if SpawnGoblin() then
					if now < rushEndsAt then
						nextGoblinAt = now + 6
					else
						nextGoblinAt = now + math.random(45, 75)
					end
				else
					nextGoblinAt = now + 12
				end
			end
		end
	end)

	-- Goblin movement.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			for i = #goblins, 1, -1 do
				local goblin = goblins[i]
				if goblin.model and goblin.model.Parent then
					StepGoblin(goblin, dt, now)
				else
					table.remove(goblins, i)
				end
			end
		end
	end)
end

return Thieves
