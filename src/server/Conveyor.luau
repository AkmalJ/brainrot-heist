--[[
	Conveyor.luau — the parade ring and the wild pools, MAGMA MAYHEM.

	ServerScriptService ModuleScript. Owns:
	  * The parade: brainrots spawn at the south gate, march the
	    obsidian ring once with name / rarity / $/s labels, and despawn
	    at the end of the loop. Buying (the BuyBrainrot remote, or the
	    prompt on each marcher) is validated by Economy; this module
	    only keeps the registry Economy validates against.
	  * Wild spawns: brainrots that idle in the three lava pools.
	    Walking up to one rolls a catch (chance by rarity, better in
	    richer zones); a miss makes it hop away inside its pool.

	Movement is CFrame steps on server loops — no physics, no
	Humanoids — exactly like the lane walkers of Brainrot Heist.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))
local Upgrades = require(ReplicatedStorage:WaitForChild("Upgrades"))

local Conveyor = {}
local G = nil -- the Game context, set by Init

local PARADE_CAP = 14 -- marchers on the ring at once
local PARADE_SPAWN_EVERY = 2.2 -- seconds between gate spawns
local WILD_PER_POOL = 2 -- wild spawns idling in each pool

local paradeActors = {} -- [paradeId] = actor
local paradeCount = 0
local nextParadeNumber = 0
local wildActors = {} -- array of wild records

local function playerRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--====================================================================--
-- The parade
--====================================================================--

local function SpawnParadeBrainrot()
	nextParadeNumber += 1
	local id = "P" .. nextParadeNumber
	local def, mutation = Brainrots.RollSpawn({ oddsMult = G.EventState.mutationOddsMult })
	local mutationName = mutation and mutation.name or nil
	local model = Brainrots.BuildBrainrotModel(def, mutationName)
	model:SetAttribute("ParadeId", id)
	model.Parent = G.ActorsFolder

	local actor = {
		id = id, defName = def.name, mutationName = mutationName,
		model = model, angle = math.pi / 2, traveled = 0,
		speed = def.speed, phase = math.random() * math.pi * 2,
	}
	paradeActors[id] = actor
	paradeCount += 1

	-- The buy prompt rides on the marcher; the remote path (client
	-- buttons) lands in the same Economy validation.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Brainrots.FormatMoney(def.price)
	prompt.ObjectText = Brainrots.DisplayName(def, mutation)
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		G.Modules.Economy.BuyParadeBrainrot(player, id)
	end)
	return actor
end

function Conveyor.GetParadeActor(paradeId)
	return paradeActors[paradeId]
end

function Conveyor.RemoveParadeActor(paradeId)
	local actor = paradeActors[paradeId]
	if not actor then
		return
	end
	paradeActors[paradeId] = nil
	paradeCount -= 1
	if actor.model then
		actor.model:Destroy()
	end
end

local function paradePosition(angle)
	local p = G.Parade
	return Vector3.new(
		p.center.X + math.cos(angle) * p.radius,
		p.y,
		p.center.Z + math.sin(angle) * p.radius)
end

--====================================================================--
-- Wild spawns in the lava pools
--====================================================================--

local function SpawnWildBrainrot(pool)
	local def, mutation = Brainrots.RollSpawn({
		oddsMult = G.EventState.mutationOddsMult, zoneLuck = pool.zoneLuck,
	})
	local mutationName = mutation and mutation.name or nil
	local model = Brainrots.BuildBrainrotModel(def, mutationName)
	local a = math.random() * math.pi * 2
	local r = pool.radius * 0.45 * math.random()
	local home = pool.position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	model:PivotTo(CFrame.new(home))
	model.Parent = G.ActorsFolder
	table.insert(wildActors, {
		defName = def.name, mutationName = mutationName, model = model,
		pool = pool, home = home, cooldowns = {}, phase = math.random() * math.pi * 2,
	})
end

local function RemoveWildActor(index)
	local wild = wildActors[index]
	if wild and wild.model then
		wild.model:Destroy()
	end
	table.remove(wildActors, index)
end

local function TryCatchWild(player, wild)
	local st = G.State[player]
	if not st or st.carried then
		return
	end
	if not st.zonesUnlocked[wild.pool.zone] then
		-- Locked zone: one polite warning per 10 seconds.
		if os.clock() - st.lastZoneToastAt > 10 then
			st.lastZoneToastAt = os.clock()
			G.Toast(player, "Zone locked!", "Rekindle to unlock the " .. wild.pool.zone .. ".", "warn")
		end
		return
	end
	local def = Brainrots.ByName[wild.defName]
	local luck = Upgrades.LuckPercent(st.upgrades["Luck Charm"])
	local chance = Brainrots.CatchChance[def.rarity] + luck / 200
	if math.random() < chance then
		if G.Modules.Economy.GiveCarried(player, wild.defName, wild.mutationName, "wild") then
			st.stats.wildCaught += 1
			local gems = Brainrots.CatchGems[def.rarity]
			if gems > 0 then
				G.AddGems(player, gems)
				G.Toast(player, "Wild catch!", def.name .. " caught, +" .. gems .. " gems.", "success")
			else
				G.Toast(player, "Wild catch!", "You caught a " .. def.name .. "! Carry it home.", "success")
			end
			for i, w in ipairs(wildActors) do
				if w == wild then
					RemoveWildActor(i)
					break
				end
			end
		end
	else
		-- Missed: it hops to a new spot in the pool and needs a moment
		-- before this player may try again.
		wild.cooldowns[player] = os.clock() + 1.2
		local a = math.random() * math.pi * 2
		local r = wild.pool.radius * 0.45 * math.random()
		wild.home = wild.pool.position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
end

--====================================================================--
-- Loops + wiring
--====================================================================--

function Conveyor.Init(game)
	G = game

	-- Gate spawner: keep the ring stocked.
	task.spawn(function()
		while true do
			task.wait(PARADE_SPAWN_EVERY)
			if paradeCount < PARADE_CAP then
				SpawnParadeBrainrot()
			end
		end
	end)

	-- March step: advance every parade actor along the ring; a full
	-- loop (2 pi of travel) despawns it at the gate.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			local t = now
			for id, actor in pairs(paradeActors) do
				local step = (actor.speed / G.Parade.radius) * dt
				actor.angle += step
				actor.traveled += step
				if actor.traveled >= math.pi * 2 then
					Conveyor.RemoveParadeActor(id)
				else
					local bob = (0.5 + 0.5 * math.sin(t * 6 + actor.phase)) * 0.18
					local pos = paradePosition(actor.angle) + Vector3.new(0, bob, 0)
					local ahead = paradePosition(actor.angle + 0.06)
					actor.model:PivotTo(CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)))
				end
			end
			-- Wild spawns idle-bob in their pools.
			for _, wild in ipairs(wildActors) do
				local bob = (0.5 + 0.5 * math.sin(t * 2.4 + wild.phase)) * 0.3
				wild.model:PivotTo(CFrame.new(wild.home + Vector3.new(0, bob, 0))
					* CFrame.Angles(0, t * 0.4 + wild.phase, 0))
			end
		end
	end)

	-- Pool keeper + catch checks.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, pool in ipairs(G.Pools) do
				local inPool = 0
				for _, wild in ipairs(wildActors) do
					if wild.pool == pool then
						inPool += 1
					end
				end
				if inPool < WILD_PER_POOL and math.random() < 0.3 then
					SpawnWildBrainrot(pool)
				end
			end
			for i = #wildActors, 1, -1 do
				local wild = wildActors[i]
				for player, st in pairs(G.State) do
					if not st.carried then
						local root = playerRoot(player)
						if root and (root.Position - wild.home).Magnitude < 7
							and (wild.cooldowns[player] or 0) <= os.clock() then
							TryCatchWild(player, wild)
							break -- one attempt per wild per tick
						end
					end
				end
			end
		end
	end)
end

return Conveyor
