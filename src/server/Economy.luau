--[[
	Economy.luau — money, pedestals and carrying for MAGMA MAYHEM.

	ServerScriptService ModuleScript. Owns:
	  * Pedestals: placing a carried brainrot, selling it back, the
	    mutation re-roll, and clearing a base for a Rekindle.
	  * Income: every placed brainrot accrues cash at its rate x
	    mutation x rebirth multiplier x event multiplier, once a
	    second, until the owner collects it (CollectCash remote or
	    stepping on the base's collect pad).
	  * Carrying: the one-brainrot-over-the-head rule — buying from
	    the parade, wild catches and steals all funnel through
	    GiveCarried, and stepping onto your own plot banks the load.
	  * Loose items: brainrots dropped in the world (eruptions,
	    whacked goblins) that anyone empty-handed can pick up.
	  * HudUpdate: the contract table, pushed on change + every second.

	It never decides prices or odds: Brainrots / Upgrades own the data.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))
local Upgrades = require(ReplicatedStorage:WaitForChild("Upgrades"))

local Economy = {}
local G = nil -- the Game context, set by Init

--====================================================================--
-- Small state readers
--====================================================================--

local function placedCount(st)
	local n = 0
	for _ in pairs(st.pedestals) do
		n += 1
	end
	return n
end

local function firstFreePedestal(st)
	for i = 1, st.pedestalsMax do
		if not st.pedestals[i] then
			return i
		end
	end
	return nil
end

local function recountOwned(st)
	local counts = {}
	for _, entry in pairs(st.pedestals) do
		counts[entry.defName] = (counts[entry.defName] or 0) + 1
	end
	if st.carried then
		counts[st.carried.defName] = (counts[st.carried.defName] or 0) + 1
	end
	st.ownedCounts = counts
end

local function totalAccrued(st)
	local sum = 0
	for _, entry in pairs(st.pedestals) do
		sum += entry.accrued
	end
	return sum
end

local function playerRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--====================================================================--
-- HUD contract
--====================================================================--

function Economy.GetIncomePerSec(player)
	local st = G.State[player]
	if not st then
		return 0
	end
	local sum = 0
	for _, entry in pairs(st.pedestals) do
		local def = Brainrots.ByName[entry.defName]
		local mutation = entry.mutationName and Brainrots.MutationByName[entry.mutationName]
		sum += Brainrots.EffectiveRate(def, mutation)
	end
	return math.floor(sum * st.multiplier * G.EventState.incomeMult)
end

function Economy.PushHud(player)
	local st = G.State[player]
	if not st then
		return
	end
	local questIndex, questProgress, questGoal = st.questIndex, 0, 0
	local questName, questText, questReward = nil, nil, nil
	local progression = G.Modules.Progression
	if progression and progression.GetQuestHud then
		questIndex, questProgress, questGoal, questName, questText, questReward =
			progression.GetQuestHud(player)
	end
	local nextStep = Upgrades.NextRekindleStep(st.rebirth)
	G.Remotes.HudUpdate:FireClient(player, {
		cash = math.floor(st.cash),
		gems = st.gems,
		incomePerSec = Economy.GetIncomePerSec(player),
		multiplier = st.multiplier,
		rebirth = st.rebirth,
		pedestalsUsed = placedCount(st),
		pedestalsMax = st.pedestalsMax,
		lockState = st.lockState,
		lockEndsAt = st.lockEndsAt,
		eventName = G.EventState.name,
		eventEndsAt = G.EventState.endsAt,
		eruptionPhase = G.EruptionState.phase,
		eruptionAt = G.EruptionState.at,
		questIndex = questIndex,
		questProgress = questProgress,
		questGoal = questGoal,
		questName = questName,
		questText = questText,
		questReward = questReward,
		rekindleCost = nextStep and nextStep.cost or nil,
		nextMultiplier = Upgrades.RekindleMult(st.rebirth + 1),
		ownedCounts = st.ownedCounts,
		carriedName = st.carried and Brainrots.DisplayName(
			Brainrots.ByName[st.carried.defName],
			st.carried.mutationName and Brainrots.MutationByName[st.carried.mutationName]) or nil,
		zonesUnlocked = st.zonesUnlocked,
	})
end

function Economy.PushHudAll()
	for _, player in ipairs(Players:GetPlayers()) do
		Economy.PushHud(player)
	end
end

--====================================================================--
-- Carrying: one brainrot over the head, placed by walking it home.
--====================================================================--

-- Give a player a carried brainrot. The single funnel for parade
-- buys, wild catches, rival steals and loose pickups. Returns false
-- (with a toast) when their hands are already full.
function Economy.GiveCarried(player, defName, mutationName, source)
	local st = G.State[player]
	if not st then
		return false
	end
	if st.carried then
		G.Toast(player, "Hands full!", "Bank the " .. st.carried.defName .. " at your base first.", "warn")
		return false
	end
	local def = Brainrots.ByName[defName]
	local model = Brainrots.BuildBrainrotModel(def, mutationName)
	model.Parent = G.ActorsFolder
	st.carried = { defName = defName, mutationName = mutationName, model = model, source = source }
	if not st.discovered[defName] then
		st.discovered[defName] = true
		local progression = G.Modules.Progression
		if progression and progression.CheckIndexMilestones then
			progression.CheckIndexMilestones(player)
		end
	end
	recountOwned(st)
	if G.ApplyMovement then
		G.ApplyMovement(player)
	end
	Economy.PushHud(player)
	return true
end

-- Drop the carried brainrot into the world as a loose item.
function Economy.DropCarried(player, position)
	local st = G.State[player]
	if not st or not st.carried then
		return
	end
	local carried = st.carried
	st.carried = nil
	carried.model:Destroy()
	Economy.AddLooseItem(carried.defName, carried.mutationName, position)
	recountOwned(st)
	if G.ApplyMovement then
		G.ApplyMovement(player)
	end
	Economy.PushHud(player)
end

function Economy.AddLooseItem(defName, mutationName, position)
	local def = Brainrots.ByName[defName]
	local model = Brainrots.BuildBrainrotModel(def, mutationName)
	model:PivotTo(CFrame.new(position))
	model.Parent = G.ActorsFolder
	table.insert(G.LooseItems, {
		defName = defName, mutationName = mutationName, model = model,
		position = position, bornAt = os.clock(),
	})
end

-- Bank the carried brainrot on the first free pedestal. Called by
-- the placement loop when the carrier steps onto their own plot.
local function PlaceCarried(player)
	local st = G.State[player]
	if not st or not st.carried then
		return
	end
	local index = firstFreePedestal(st)
	if not index then
		G.Toast(player, "No free pedestal!", "Sell something or Rekindle for more slots.", "warn")
		return
	end
	local carried = st.carried
	st.carried = nil
	carried.model:Destroy()

	local def = Brainrots.ByName[carried.defName]
	local mutation = carried.mutationName and Brainrots.MutationByName[carried.mutationName]
	local model = Brainrots.BuildBrainrotModel(def, carried.mutationName)
	model:PivotTo(st.plot.pedestalCFrames[index])
	model.Parent = G.ActorsFolder

	-- The sell-back prompt lives on the pedestal part itself.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell " .. Brainrots.FormatMoney(math.floor(def.price * 0.5))
	prompt.ObjectText = Brainrots.DisplayName(def, mutation)
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = st.plot.pedestalParts[index]
	prompt.Triggered:Connect(function(triggerer)
		if triggerer == player then
			Economy.SellPedestal(player, index)
		end
	end)

	st.pedestals[index] = {
		defName = carried.defName, mutationName = carried.mutationName,
		accrued = 0, model = model, prompt = prompt,
	}
	st.stats.placedTotal += 1
	st.stats.maxPlaced = math.max(st.stats.maxPlaced, placedCount(st))
	if carried.mutationName then
		st.stats.mutatedPlaced += 1
	end
	st.stats.bestRarityOrder = math.max(st.stats.bestRarityOrder, Brainrots.Rarities[def.rarity].order)
	recountOwned(st)
	if G.ApplyMovement then
		G.ApplyMovement(player)
	end
	G.Toast(player, "Banked!", Brainrots.DisplayName(def, mutation) .. " now earns "
		.. Brainrots.FormatMoney(Brainrots.EffectiveRate(def, mutation) * st.multiplier) .. "/s.", "success")
	Economy.PushHud(player)
end

--====================================================================--
-- Pedestal removal (sell / goblin grab / Rekindle clear)
--====================================================================--

function Economy.RemoveFromPedestal(player, index)
	local st = G.State[player]
	if not st then
		return nil
	end
	local entry = st.pedestals[index]
	if not entry then
		return nil
	end
	st.pedestals[index] = nil
	if entry.model then
		entry.model:Destroy()
	end
	if entry.prompt then
		entry.prompt:Destroy()
	end
	recountOwned(st)
	Economy.PushHud(player)
	return entry
end

function Economy.SellPedestal(player, index)
	local st = G.State[player]
	if not st or not st.pedestals[index] then
		return
	end
	local entry = st.pedestals[index]
	local def = Brainrots.ByName[entry.defName]
	local value = math.floor(def.price * 0.5)
	Economy.RemoveFromPedestal(player, index)
	G.AddCash(player, value, false)
	G.Toast(player, "Sold!", def.name .. " went for " .. Brainrots.FormatMoney(value) .. ".", "info")
	Economy.PushHud(player)
end

function Economy.ClearPedestals(player)
	local st = G.State[player]
	if not st then
		return
	end
	local indices = {}
	for index in pairs(st.pedestals) do
		table.insert(indices, index)
	end
	for _, index in ipairs(indices) do
		Economy.RemoveFromPedestal(player, index)
	end
end

--====================================================================--
-- Buying off the parade (the BuyBrainrot remote lands here)
--====================================================================--

function Economy.BuyParadeBrainrot(player, paradeId)
	local st = G.State[player]
	if not st then
		return
	end
	local conveyor = G.Modules.Conveyor
	local actor = conveyor and conveyor.GetParadeActor(paradeId)
	if not actor then
		return -- already marched off or someone else bought it
	end
	if st.carried then
		G.Toast(player, "Hands full!", "Bank your current brainrot first.", "warn")
		return
	end
	if not firstFreePedestal(st) then
		G.Toast(player, "No free pedestal!", "Sell something or Rekindle for more slots.", "warn")
		return
	end
	local def = Brainrots.ByName[actor.defName]
	if st.cash < def.price then
		G.Toast(player, "Not enough cash", "That " .. def.name .. " costs "
			.. Brainrots.FormatMoney(def.price) .. ".", "warn")
		return
	end
	conveyor.RemoveParadeActor(paradeId)
	if Economy.GiveCarried(player, actor.defName, actor.mutationName, "parade") then
		G.AddCash(player, -def.price, false)
		st.stats.bought += 1
		G.Toast(player, "Bought!", "Carry the " .. def.name .. " home to your base!", "success")
	end
	Economy.PushHud(player)
end

--====================================================================--
-- Collecting: sweep every pedestal's accrued cash at once.
--====================================================================--

function Economy.CollectAll(player)
	local st = G.State[player]
	if not st then
		return
	end
	local sum = math.floor(totalAccrued(st))
	if sum < 1 then
		return
	end
	for _, entry in pairs(st.pedestals) do
		entry.accrued = 0
	end
	-- countsAsEarned = false: the accrual tick already added every
	-- dollar to lifetimeEarned as it was earned.
	G.AddCash(player, sum, false)
	G.Toast(player, "+" .. Brainrots.FormatMoney(sum), "Collected from your pedestals.", "success")
	Economy.PushHud(player)
end

--====================================================================--
-- Mutation re-roll (RerollMutation remote): 5 gems, fresh odds,
-- luck counts. The pedestal model is rebuilt so the new look shows.
--====================================================================--

local function OnRerollMutation(player, pedestalIndex)
	local st = G.State[player]
	if not st or typeof(pedestalIndex) ~= "number" then
		return
	end
	local index = math.floor(pedestalIndex)
	local entry = st.pedestals[index]
	if not entry then
		return
	end
	if st.gems < Brainrots.RerollGemCost then
		G.Toast(player, "Not enough gems", "A re-roll costs " .. Brainrots.RerollGemCost .. " gems.", "warn")
		return
	end
	G.AddGems(player, -Brainrots.RerollGemCost)
	local luckMult = 1 + Upgrades.LuckPercent(st.upgrades["Luck Charm"]) / 100
	local mutation = Brainrots.RollMutation(luckMult)
	entry.mutationName = mutation and mutation.name or nil
	entry.model:Destroy()
	local def = Brainrots.ByName[entry.defName]
	local model = Brainrots.BuildBrainrotModel(def, entry.mutationName)
	model:PivotTo(st.plot.pedestalCFrames[index])
	model.Parent = G.ActorsFolder
	entry.model = model
	if entry.prompt then
		entry.prompt.ObjectText = Brainrots.DisplayName(def, mutation)
	end
	if mutation then
		G.Toast(player, "RE-ROLL: " .. mutation.prefix .. "!", def.name .. " now earns x" .. mutation.mult .. ".", "success")
	else
		G.Toast(player, "Re-roll: plain", "The volcano giveth, and the volcano taketh away.", "info")
	end
	Economy.PushHud(player)
end

--====================================================================--
-- Cleanup + loops + wiring
--====================================================================--

function Economy.PlayerLeft(player)
	local st = G.State[player]
	if not st then
		return
	end
	Economy.ClearPedestals(player)
	if st.carried then
		st.carried.model:Destroy()
		st.carried = nil
	end
end

function Economy.Init(game)
	G = game
	G.PushHud = Economy.PushHud

	G.Remotes.BuyBrainrot.OnServerEvent:Connect(function(player, paradeId)
		if typeof(paradeId) == "string" then
			Economy.BuyParadeBrainrot(player, paradeId)
		end
	end)
	G.Remotes.CollectCash.OnServerEvent:Connect(function(player)
		Economy.CollectAll(player)
	end)
	G.Remotes.RerollMutation.OnServerEvent:Connect(OnRerollMutation)

	-- Carried models ride above the carrier's head, slowly spinning.
	local spin = 0
	RunService.Heartbeat:Connect(function(dt)
		spin += dt * 1.1
		for player, st in pairs(G.State) do
			if st.carried and st.carried.model then
				local root = playerRoot(player)
				if root then
					st.carried.model:PivotTo(root.CFrame * CFrame.new(0, 3.55, 1.0) * CFrame.Angles(0, spin, 0))
				end
			end
		end
	end)

	-- Income tick: accrue a second of earnings on every pedestal,
	-- watch the collect pads, then push the HUD (contract: on change
	-- + every second — this loop is the every-second part).
	task.spawn(function()
		while true do
			task.wait(1)
			for player, st in pairs(G.State) do
				local mult = st.multiplier * G.EventState.incomeMult
				for _, entry in pairs(st.pedestals) do
					local def = Brainrots.ByName[entry.defName]
					local mutation = entry.mutationName and Brainrots.MutationByName[entry.mutationName]
					local gain = Brainrots.EffectiveRate(def, mutation) * mult
					entry.accrued += gain
					st.lifetimeEarned += gain
				end
				local root = playerRoot(player)
				if root and st.plot then
					local padPos = st.plot.collectPad.Position
					local flat = Vector3.new(root.Position.X - padPos.X, 0, root.Position.Z - padPos.Z)
					if flat.Magnitude < 4.5 and math.abs(root.Position.Y - padPos.Y) < 5 then
						Economy.CollectAll(player)
					end
				end
				Economy.PushHud(player)
			end
		end
	end)

	-- Placement + pickup loop: bank a carried brainrot when its
	-- carrier reaches home; let the empty-handed pick up loose items.
	task.spawn(function()
		while true do
			task.wait(0.3)
			for player, st in pairs(G.State) do
				local root = playerRoot(player)
				if root then
					if st.carried and st.plot then
						local c = st.plot.centerTop
						local flat = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z)
						if flat.Magnitude < 17 and math.abs(root.Position.Y - c.Y) < 7 then
							PlaceCarried(player)
						end
					elseif not st.carried then
						for i = #G.LooseItems, 1, -1 do
							local item = G.LooseItems[i]
							if (root.Position - item.position).Magnitude < 5.5 then
								table.remove(G.LooseItems, i)
								item.model:Destroy()
								Economy.GiveCarried(player, item.defName, item.mutationName, "loose")
								break
							end
						end
					end
				end
			end
			-- Loose items cool back into the volcano after 150 s.
			for i = #G.LooseItems, 1, -1 do
				local item = G.LooseItems[i]
				if os.clock() - item.bornAt > 150 then
					table.remove(G.LooseItems, i)
					item.model:Destroy()
				end
			end
		end
	end)
end

return Economy
