--[[
	Progression.luau — upgrades, REKINDLE and Chief Magma's contracts
	for MAGMA MAYHEM.

	ServerScriptService ModuleScript. Owns:
	  * Upgrade purchases (the BuyUpgrade remote + the shop pads):
	    four tracks, six tiers each, data in Upgrades.luau.
	  * Movement maths: Game.ApplyMovement lives here because it is
	    upgrades (Speed Boots) x carry effects (Carry Harness) and
	    every other module calls it after changing either input.
	  * REKINDLE (the DoRekindle remote): pay the ladder step, cash
	    and pedestals reset, income multiplier x2, +2 pedestals, and
	    the zone unlocks at steps 1 and 3.
	  * The 15 Chief Magma contracts (the ClaimQuest remote): every
	    quest's progress is DERIVED from the State stats, so no event
	    wiring can ever miss a count — Economy, Conveyor, Thieves and
	    Eruption just keep the stats honest.
	  * Index milestones and the GetIndexState RemoteFunction.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))
local Upgrades = require(ReplicatedStorage:WaitForChild("Upgrades"))

local Progression = {}
local G = nil -- the Game context, set by Init

--====================================================================--
-- Chief Magma's contracts: 15 steps. `kind` names the State stat the
-- progress is read from; `goal` is its target (for BestRarity, the
-- rarity order: 4 = Epic, 7 = Secret).
--====================================================================--

local QUESTS = {
	{ title = "Warm-Up Lap", kind = "BuyCount", goal = 3, rewardCash = 500, rewardGems = 0,
		blurb = "Buy 3 brainrots from the parade" },
	{ title = "First Catch", kind = "CatchWild", goal = 1, rewardCash = 750, rewardGems = 2,
		blurb = "Catch a wild brainrot in a lava pool" },
	{ title = "Pocket Change", kind = "EarnTotal", goal = 5000, rewardCash = 1500, rewardGems = 0,
		blurb = "Earn $5K of income, all-time" },
	{ title = "Full House", kind = "MaxPlaced", goal = 6, rewardCash = 3000, rewardGems = 0,
		blurb = "Have 6 brainrots banked at once" },
	{ title = "Shiny Hunter", kind = "MutatedPlaced", goal = 1, rewardCash = 5000, rewardGems = 3,
		blurb = "Bank a mutated brainrot" },
	{ title = "Big Earner", kind = "EarnTotal", goal = 50000, rewardCash = 10000, rewardGems = 0,
		blurb = "Earn $50K of income, all-time" },
	{ title = "Goblin Menace", kind = "StoleBack", goal = 1, rewardCash = 8000, rewardGems = 3,
		blurb = "Whack a goblin that is carrying loot" },
	{ title = "Rare Air", kind = "BestRarity", goal = 4, rewardCash = 25000, rewardGems = 0,
		blurb = "Bank an Epic or rarer brainrot" },
	{ title = "Storm Chaser", kind = "SurviveEruption", goal = 1, rewardCash = 15000, rewardGems = 5,
		blurb = "Survive an eruption" },
	{ title = "Rival Raid", kind = "RivalSteal", goal = 2, rewardCash = 40000, rewardGems = 0,
		blurb = "Steal 2 brainrots from rival bases" },
	{ title = "High Roller", kind = "EarnTotal", goal = 1000000, rewardCash = 100000, rewardGems = 5,
		blurb = "Earn $1M of income, all-time" },
	{ title = "Rekindle the Flame", kind = "Rekindles", goal = 1, rewardCash = 150000, rewardGems = 0,
		blurb = "Rekindle at the volcano once" },
	{ title = "Mutation Lab", kind = "MutatedPlaced", goal = 5, rewardCash = 250000, rewardGems = 10,
		blurb = "Bank 5 mutated brainrots, all-time" },
	{ title = "Island Tycoon", kind = "EarnTotal", goal = 25000000, rewardCash = 1000000, rewardGems = 10,
		blurb = "Earn $25M of income, all-time" },
	{ title = "Legend of the Caldera", kind = "BestRarity", goal = 7, rewardCash = 5000000, rewardGems = 25,
		blurb = "Bank a SECRET brainrot" },
}

Progression.Quests = QUESTS

local function GetProgress(st, quest)
	if quest.kind == "BuyCount" then
		return st.stats.bought
	elseif quest.kind == "CatchWild" then
		return st.stats.wildCaught
	elseif quest.kind == "EarnTotal" then
		return math.floor(st.lifetimeEarned)
	elseif quest.kind == "MaxPlaced" then
		return st.stats.maxPlaced
	elseif quest.kind == "MutatedPlaced" then
		return st.stats.mutatedPlaced
	elseif quest.kind == "StoleBack" then
		return st.stats.stoleBack
	elseif quest.kind == "BestRarity" then
		return st.stats.bestRarityOrder
	elseif quest.kind == "SurviveEruption" then
		return st.stats.eruptionsSurvived
	elseif quest.kind == "RivalSteal" then
		return st.stats.rivalSteals
	elseif quest.kind == "Rekindles" then
		return st.stats.rekindles
	end
	return 0
end

-- The HUD's quest triple: (index, progress capped at goal, goal).
-- Past the last contract: (16, 0, 0) — the client shows "complete".
function Progression.GetQuestHud(player)
	local st = G.State[player]
	if not st then
		return 1, 0, 0
	end
	local quest = QUESTS[st.questIndex]
	if not quest then
		return st.questIndex, 0, 0
	end
	local reward = "+" .. Brainrots.FormatMoney(quest.rewardCash)
		.. (quest.rewardGems > 0 and (" and +" .. quest.rewardGems .. " gems") or "")
	return st.questIndex, math.min(GetProgress(st, quest), quest.goal), quest.goal,
		quest.title, quest.blurb, reward
end

local function OnClaimQuest(player)
	local st = G.State[player]
	if not st then
		return
	end
	local quest = QUESTS[st.questIndex]
	if not quest then
		G.Toast(player, "All contracts complete!", "Chief Magma bows to you, Legend of the Caldera.", "success")
		return
	end
	if GetProgress(st, quest) < quest.goal then
		G.Toast(player, "Not yet", quest.title .. ": " .. GetProgress(st, quest)
			.. " / " .. quest.goal .. " — " .. quest.blurb .. ".", "warn")
		return
	end
	st.questIndex += 1
	G.AddCash(player, quest.rewardCash, false)
	if quest.rewardGems > 0 then
		G.AddGems(player, quest.rewardGems)
	end
	G.Toast(player, "Contract complete: " .. quest.title,
		"+" .. Brainrots.FormatMoney(quest.rewardCash)
			.. (quest.rewardGems > 0 and (" and +" .. quest.rewardGems .. " gems") or "")
			.. "! Next: " .. (QUESTS[st.questIndex] and QUESTS[st.questIndex].title or "none — you legend"), "success")
	G.PushHud(player)
end

--====================================================================--
-- Index milestones (data in Brainrots; awarded on discovery, which
-- Economy reports through GiveCarried -> here).
--====================================================================--

function Progression.CheckIndexMilestones(player)
	local st = G.State[player]
	if not st then
		return
	end
	local discovered = 0
	for _ in pairs(st.discovered) do
		discovered += 1
	end
	for _, milestone in ipairs(Brainrots.IndexMilestones) do
		if discovered >= milestone.count and not st.indexMilestonesClaimed[milestone.count] then
			st.indexMilestonesClaimed[milestone.count] = true
			G.AddGems(player, milestone.gems)
			G.Toast(player, "Index milestone: " .. milestone.title,
				discovered .. " / " .. #Brainrots.Characters .. " discovered. +"
					.. milestone.gems .. " gems.", "success")
		end
	end
end

--====================================================================--
-- Movement: WalkSpeed = 16 x Speed Boots x carry effect (softened
-- by the Carry Harness). Called whenever any input changes.
--====================================================================--

local CARRY_FACTORS = { none = 1, slow = 0.8, heavy = 0.6, speed = 1.15, jump = 1 }

local function ApplyMovement(player)
	local st = G.State[player]
	if not st then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local factor = 1
	local jumpPower = 50
	if st.carried then
		local def = Brainrots.ByName[st.carried.defName]
		local base = CARRY_FACTORS[def.carryEffect] or 1
		if base < 1 then
			factor = 1 - (1 - base) * Upgrades.CarryPenaltyLeft(st.upgrades["Carry Harness"])
		else
			factor = base
		end
		if def.carryEffect == "jump" then
			jumpPower = 70
		end
	end
	humanoid.WalkSpeed = 16 * Upgrades.SpeedMult(st.upgrades["Speed Boots"]) * factor
	humanoid.JumpPower = jumpPower
end

--====================================================================--
-- Upgrade purchases (remote + shop pads share this validation)
--====================================================================--

function Progression.BuyUpgrade(player, trackName, tier)
	local st = G.State[player]
	if not st or typeof(trackName) ~= "string" or typeof(tier) ~= "number" then
		return
	end
	tier = math.floor(tier)
	local track = Upgrades.Tracks[trackName]
	if not track then
		return
	end
	if tier ~= (st.upgrades[trackName] or 0) + 1 then
		return -- tiers are bought in order, no skipping, no re-buys
	end
	local row = track.tiers[tier]
	if not row then
		return
	end
	if st.cash < row.cost then
		G.Toast(player, "Not enough cash", trackName .. " tier " .. tier .. " costs "
			.. Brainrots.FormatMoney(row.cost) .. ".", "warn")
		return
	end
	G.AddCash(player, -row.cost, false)
	st.upgrades[trackName] = tier
	if trackName == "Speed Boots" then
		ApplyMovement(player)
	end
	G.Toast(player, trackName .. " tier " .. tier .. "!", row.label .. " — equipped.", "success")
	G.PushHud(player)
end

--====================================================================--
-- REKINDLE: the volcano takes your cash and your collection, and
-- gives you back a multiplier, more pedestals and new lands.
--====================================================================--

local function OnDoRekindle(player)
	local st = G.State[player]
	if not st then
		return
	end
	local step = Upgrades.NextRekindleStep(st.rebirth)
	if not step then
		G.Toast(player, "Fully Rekindled", "Eight Rekindles. The volcano has nothing left to teach you.", "info")
		return
	end
	if st.cash < step.cost then
		G.Toast(player, "The volcano hungers", "Rekindle " .. (st.rebirth + 1) .. " needs "
			.. Brainrots.FormatMoney(step.cost) .. " in hand.", "warn")
		return
	end
	G.Modules.Economy.ClearPedestals(player)
	st.cash = Brainrots.StartingCash
	st.rebirth += 1
	st.multiplier = Upgrades.RekindleMult(st.rebirth)
	st.pedestalsMax = math.min(Upgrades.PedestalsFor(st.rebirth), #st.plot.pedestalParts)
	st.stats.rekindles += 1
	if step.gems > 0 then
		G.AddGems(player, step.gems)
	end
	local zoneNote = ""
	if step.unlockZone then
		st.zonesUnlocked[step.unlockZone] = true
		zoneNote = " NEW ZONE: " .. step.unlockZone .. "!"
	end
	G.Toast(player, "REKINDLE " .. st.rebirth .. "!",
		"Income x" .. st.multiplier .. " forever, " .. st.pedestalsMax .. " pedestals, +"
			.. step.gems .. " gems." .. zoneNote, "success")
	G.PushHud(player)
end

--====================================================================--
-- Wiring
--====================================================================--

function Progression.Init(game)
	G = game
	G.ApplyMovement = ApplyMovement

	G.Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, trackName, tier)
		Progression.BuyUpgrade(player, trackName, tier)
	end)
	G.Remotes.DoRekindle.OnServerEvent:Connect(OnDoRekindle)
	G.Remotes.ClaimQuest.OnServerEvent:Connect(OnClaimQuest)

	G.Remotes.GetIndexState.OnServerInvoke = function(player)
		local st = G.State[player]
		if not st then
			return { ownedCounts = {}, discovered = {} }
		end
		return { ownedCounts = st.ownedCounts, discovered = st.discovered }
	end

	-- Shop pads: stepping up and using the pad buys the next tier of
	-- its track (the HUD shop fires the same path by remote).
	for trackName, pad in pairs(G.ShopPads) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyUpgradePrompt"
		prompt.ActionText = "Buy Next Tier"
		prompt.ObjectText = trackName
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			local st = G.State[player]
			if st then
				Progression.BuyUpgrade(player, trackName, (st.upgrades[trackName] or 0) + 1)
			end
		end)
	end
end

return Progression
