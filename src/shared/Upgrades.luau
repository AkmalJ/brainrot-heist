--[[
	Upgrades.luau — the shop + Rekindle data for MAGMA MAYHEM.

	Paste target: a ModuleScript named "Upgrades" in ReplicatedStorage.
	Pure data and small pure functions: Progression executes purchases
	against this table, and Economy / Conveyor / Thieves / Progression
	read the derived effects from here, so a balance tweak is one edit.

	Contents:
	  * 4 upgrade tracks x 6 tiers: Speed Boots, Carry Harness,
	    Base Lock, Luck Charm — each tier a cost and a plain-number
	    effect the owning system interprets.
	  * The REKINDLE (rebirth) ladder: 8 steps of cash cost, gem bonus,
	    x2 income per step, +2 pedestals per step, and the two zone
	    unlocks (step 1 -> Obsidian Fields, step 3 -> Crater Rim).
]]

local Upgrades = {}

--====================================================================--
-- Upgrade tracks. Tier 0 = not bought. A player may buy tier n+1 only.
--   effect meaning per track:
--     Speed Boots   -> WalkSpeed multiplier bonus, in percent
--     Carry Harness -> carry speed-penalty reduction, in percent
--     Base Lock     -> (durationBonus seconds, cooldownCut seconds)
--     Luck Charm    -> luck percent: wild catch +luck/2 flat percent,
--                      mutation re-roll odds x (1 + luck/100)
--====================================================================--

Upgrades.Tracks = {
	["Speed Boots"] = {
		blurb = "Run like the floor is lava. Because it is.",
		tiers = {
			{ cost = 500, effect = 6, label = "Sneakers of Regret" },
			{ cost = 2000, effect = 13, label = "Asbestos Trainers" },
			{ cost = 8000, effect = 21, label = "Lava-Proof Runners" },
			{ cost = 30000, effect = 30, label = "Obsidian Cleats" },
			{ cost = 120000, effect = 40, label = "Magma Skates" },
			{ cost = 500000, effect = 52, label = "Boots of the Caldera" },
		},
	},
	["Carry Harness"] = {
		blurb = "Heavy brainrots feel lighter. Your spine sends thanks.",
		tiers = {
			{ cost = 750, effect = 15, label = "Rope and Optimism" },
			{ cost = 3000, effect = 30, label = "Leather Harness" },
			{ cost = 12000, effect = 45, label = "Steel-Frame Pack" },
			{ cost = 45000, effect = 60, label = "Padded Titan Rig" },
			{ cost = 180000, effect = 75, label = "Exo-Harness Mk.IV" },
			{ cost = 750000, effect = 90, label = "Anti-Gravity Sling" },
		},
	},
	["Base Lock"] = {
		blurb = "A longer, faster-cycling forcefield for your base.",
		tiers = {
			{ cost = 1000, effect = 10, label = "Padlock of Justice" },
			{ cost = 4000, effect = 20, label = "Obsidian Deadbolt" },
			{ cost = 16000, effect = 32, label = "Lava Moat Permit" },
			{ cost = 60000, effect = 45, label = "Magma Forcefield" },
			{ cost = 240000, effect = 60, label = "Crater Vault Seal" },
			{ cost = 1000000, effect = 78, label = "The Volcano Itself Guards You" },
		},
	},
	["Luck Charm"] = {
		blurb = "The volcano starts playing favourites. Yours.",
		tiers = {
			{ cost = 1500, effect = 5, label = "Warm Pebble" },
			{ cost = 6000, effect = 10, label = "Four-Leaf Cinder" },
			{ cost = 24000, effect = 16, label = "Lucky Lava Tooth" },
			{ cost = 90000, effect = 22, label = "Gambling Geyser Idol" },
			{ cost = 360000, effect = 30, label = "Fortune's Furnace" },
			{ cost = 1500000, effect = 40, label = "The Volcano's Own Dice" },
		},
	},
}

-- Track names in shop order.
Upgrades.TrackOrder = { "Speed Boots", "Carry Harness", "Base Lock", "Luck Charm" }

function Upgrades.MaxTier(trackName)
	local track = Upgrades.Tracks[trackName]
	return track and #track.tiers or 0
end

-- The tier row a purchase would grant, or nil if maxed / unknown.
function Upgrades.NextTier(trackName, currentTier)
	local track = Upgrades.Tracks[trackName]
	if not track then
		return nil
	end
	return track.tiers[currentTier + 1]
end

-- The effect value of an owned tier (0 when nothing is bought).
function Upgrades.EffectAt(trackName, tier)
	local track = Upgrades.Tracks[trackName]
	if not track or tier <= 0 then
		return 0
	end
	local row = track.tiers[tier]
	return row and row.effect or 0
end

--====================================================================--
-- Derived effects — the numbers the game systems actually consume.
--====================================================================--

-- WalkSpeed multiplier from Speed Boots: 1 + percent.
function Upgrades.SpeedMult(bootsTier)
	return 1 + Upgrades.EffectAt("Speed Boots", bootsTier) / 100
end

-- Fraction of a carry penalty that remains after the harness:
-- 1 = full penalty, 0.1 = the Anti-Gravity Sling shrugs it off.
function Upgrades.CarryPenaltyLeft(harnessTier)
	return 1 - Upgrades.EffectAt("Carry Harness", harnessTier) / 100
end

-- Base Lock timings (seconds): base 60 s locked / 90 s cooldown,
-- upgraded by the track's effect (duration +, cooldown -).
function Upgrades.LockDuration(lockTier)
	return 60 + Upgrades.EffectAt("Base Lock", lockTier)
end

function Upgrades.LockCooldown(lockTier)
	return math.max(30, 90 - math.floor(Upgrades.EffectAt("Base Lock", lockTier) * 0.7))
end

-- Luck Charm percent owned (0 when un-bought).
function Upgrades.LuckPercent(luckTier)
	return Upgrades.EffectAt("Luck Charm", luckTier)
end

--====================================================================--
-- REKINDLE — the rebirth ladder. Rekindle step n (your (n)th rebirth):
-- pay the step's cash cost, cash resets to the starting amount, placed
-- brainrots are cleared, and you keep upgrades, gems and discoveries.
-- Income multiplier is x2 per step and pedestals grow +2 per step;
-- both are formulas, the table carries cost / gems / zone unlocks.
--====================================================================--

Upgrades.BasePedestals = 6

Upgrades.RekindleSteps = {
	{ cost = 100000, gems = 10, unlockZone = "Obsidian Fields" },
	{ cost = 500000, gems = 20 },
	{ cost = 2500000, gems = 35, unlockZone = "Crater Rim" },
	{ cost = 12000000, gems = 55 },
	{ cost = 60000000, gems = 80 },
	{ cost = 300000000, gems = 120 },
	{ cost = 1500000000, gems = 175 },
	{ cost = 8000000000, gems = 250 },
}

function Upgrades.MaxRekindle()
	return #Upgrades.RekindleSteps
end

-- The step a player with `rebirths` rebirths would buy next, or nil.
function Upgrades.NextRekindleStep(rebirths)
	return Upgrades.RekindleSteps[rebirths + 1]
end

-- Permanent income multiplier after `rebirths` Rekindles: x2 each.
function Upgrades.RekindleMult(rebirths)
	return 2 ^ rebirths
end

-- Pedestal slots after `rebirths` Rekindles: 6 base, +2 per step.
function Upgrades.PedestalsFor(rebirths)
	return Upgrades.BasePedestals + 2 * rebirths
end

-- Zones a player with `rebirths` Rekindles may enter, start zone first.
function Upgrades.UnlockedZones(rebirths)
	local zones = { "Ashen Beach" }
	for i = 1, math.min(rebirths, #Upgrades.RekindleSteps) do
		local step = Upgrades.RekindleSteps[i]
		if step.unlockZone then
			table.insert(zones, step.unlockZone)
		end
	end
	return zones
end

return Upgrades
