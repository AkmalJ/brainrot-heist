--[[
	Brainrots.luau — the shared catalogue for BRAINROT HEIST.

	Paste target: a ModuleScript named "Brainrots" in ReplicatedStorage.
	Both the server (Main.server.luau) and the client HUD (Client.client.luau)
	require this one module, so the roster, the prices and the maths live in
	exactly one place.

	Contents:
	  * 12 original brainrot characters across 7 rarity tiers.
	  * Tier colours (pads, nameplates, light beams) and spawn weights.
	  * Mutations: Gold x2, Diamond x3, Rainbow x5 income, rolled per spawn.
	  * The rebirth price curve and income multiplier.
	  * Money formatting shared by the HUD, the signs and the boards.
]]

local Brainrots = {}

-- Cash every player starts a session (and every rebirth) with: enough for a
-- first Noodle Newt and a reason to dash home with it.
Brainrots.StartingCash = 100

--====================================================================--
-- Rarity tiers
--====================================================================--

-- order drives beam height and bragging rights; color dresses pads and
-- nameplates; beam is the light-pillar colour for Rare and above.
Brainrots.Tiers = {
	Common = { order = 1, color = Color3.fromRGB(141, 199, 84), beam = Color3.fromRGB(170, 235, 120) },
	Uncommon = { order = 2, color = Color3.fromRGB(64, 178, 224), beam = Color3.fromRGB(110, 210, 255) },
	Rare = { order = 3, color = Color3.fromRGB(66, 103, 255), beam = Color3.fromRGB(96, 140, 255) },
	Epic = { order = 4, color = Color3.fromRGB(168, 85, 247), beam = Color3.fromRGB(196, 130, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(245, 158, 11), beam = Color3.fromRGB(255, 196, 64) },
	Mythic = { order = 6, color = Color3.fromRGB(236, 72, 153), beam = Color3.fromRGB(255, 110, 199) },
	["Brainrot God"] = { order = 7, color = Color3.fromRGB(250, 204, 21), beam = Color3.fromRGB(255, 240, 150) },
}

-- How the lane's spawns spread across tiers (weights, summing to 100).
Brainrots.TierWeights = {
	{ tier = "Common", weight = 32 },
	{ tier = "Uncommon", weight = 25 },
	{ tier = "Rare", weight = 18 },
	{ tier = "Epic", weight = 11 },
	{ tier = "Legendary", weight = 7 },
	{ tier = "Mythic", weight = 4 },
	{ tier = "Brainrot God", weight = 3 },
}

--====================================================================--
-- The roster: 12 originals, each built from plain parts by the server.
--   cost    = cash to buy it off the lane
--   income  = base cash per second once banked on a base pad
--   speed   = studs per second while it strolls the lane
--   body / accent = the two colours its blocky model is built from
--   accessory = which prop the model factory bolts on
--   scale   = overall size multiplier (gods are bigger, obviously)
--====================================================================--

Brainrots.Characters = {
	{
		name = "Noodle Newt", tier = "Common", cost = 25, income = 1, speed = 8,
		body = Color3.fromRGB(124, 190, 80), accent = Color3.fromRGB(240, 225, 140),
		accessory = "Tail", scale = 0.9,
	},
	{
		name = "DJ Banana", tier = "Common", cost = 75, income = 2, speed = 8.5,
		body = Color3.fromRGB(255, 213, 79), accent = Color3.fromRGB(90, 60, 30),
		accessory = "Headphones", scale = 1.0,
	},
	{
		name = "Captain Croissant", tier = "Uncommon", cost = 200, income = 6, speed = 8,
		body = Color3.fromRGB(214, 164, 110), accent = Color3.fromRGB(140, 95, 50),
		accessory = "CroissantHat", scale = 1.0,
	},
	{
		name = "Pigeon CEO", tier = "Uncommon", cost = 350, income = 10, speed = 9,
		body = Color3.fromRGB(120, 140, 160), accent = Color3.fromRGB(200, 40, 50),
		accessory = "Tie", scale = 0.95,
	},
	{
		name = "Cactus Cowboy", tier = "Rare", cost = 800, income = 24, speed = 8.5,
		body = Color3.fromRGB(46, 160, 80), accent = Color3.fromRGB(146, 104, 58),
		accessory = "CowboyHat", scale = 1.05,
	},
	{
		name = "Sir Boba", tier = "Rare", cost = 1400, income = 42, speed = 7.5,
		body = Color3.fromRGB(245, 230, 200), accent = Color3.fromRGB(244, 114, 182),
		accessory = "Straw", scale = 1.0,
	},
	{
		name = "Toilet Goblin", tier = "Epic", cost = 3500, income = 110, speed = 9.5,
		body = Color3.fromRGB(240, 240, 240), accent = Color3.fromRGB(74, 190, 90),
		accessory = "ToiletTank", scale = 1.05,
	},
	{
		name = "Disco Potato", tier = "Epic", cost = 5500, income = 170, speed = 9,
		body = Color3.fromRGB(160, 110, 60), accent = Color3.fromRGB(210, 215, 225),
		accessory = "DiscoBall", scale = 1.0,
	},
	{
		name = "Turbo Turtle", tier = "Legendary", cost = 14000, income = 450, speed = 11,
		body = Color3.fromRGB(70, 180, 90), accent = Color3.fromRGB(96, 120, 52),
		accessory = "Shell", scale = 1.1,
	},
	{
		name = "Waffle Wizard", tier = "Legendary", cost = 24000, income = 780, speed = 8,
		body = Color3.fromRGB(222, 170, 90), accent = Color3.fromRGB(124, 58, 237),
		accessory = "WizardHat", scale = 1.1,
	},
	{
		name = "Golden Goose", tier = "Mythic", cost = 60000, income = 2100, speed = 9,
		body = Color3.fromRGB(255, 190, 40), accent = Color3.fromRGB(249, 115, 22),
		accessory = "Crown", scale = 1.15,
	},
	{
		name = "Cosmic Cappuccino", tier = "Brainrot God", cost = 150000, income = 5200, speed = 7,
		body = Color3.fromRGB(236, 214, 178), accent = Color3.fromRGB(147, 51, 234),
		accessory = "CupOrbit", scale = 1.3,
	},
}

-- Name lookup, filled once at load.
Brainrots.ByName = {}
for _, def in ipairs(Brainrots.Characters) do
	Brainrots.ByName[def.name] = def
end

--====================================================================--
-- Mutations: rolled per spawn. The chances sum to 12, so 88% of spawns
-- are plain. A mutation multiplies income and tints the model.
--====================================================================--

Brainrots.Mutations = {
	{ name = "Gold", mult = 2, chance = 7, color = Color3.fromRGB(255, 200, 40), tag = "GOLD" },
	{ name = "Diamond", mult = 3, chance = 3.5, color = Color3.fromRGB(140, 230, 255), tag = "DIAMOND" },
	{ name = "Rainbow", mult = 5, chance = 1.5, color = Color3.fromRGB(255, 105, 180), tag = "RAINBOW" },
}

-- Roll one lane spawn: a character definition and a mutation (or nil).
function Brainrots.Roll()
	-- Pick a tier by weight.
	local total = 0
	for _, w in ipairs(Brainrots.TierWeights) do
		total += w.weight
	end
	local r = math.random() * total
	local tierName = "Common"
	for _, w in ipairs(Brainrots.TierWeights) do
		r -= w.weight
		if r <= 0 then
			tierName = w.tier
			break
		end
	end

	-- Pick a character inside that tier.
	local pool = {}
	for _, def in ipairs(Brainrots.Characters) do
		if def.tier == tierName then
			table.insert(pool, def)
		end
	end
	local def = pool[math.random(1, #pool)]

	-- Roll the mutation: cumulative chances out of 100.
	local mutation = nil
	local mroll = math.random() * 100
	local acc = 0
	for _, m in ipairs(Brainrots.Mutations) do
		acc += m.chance
		if mroll < acc then
			mutation = m
			break
		end
	end

	return def, mutation
end

--====================================================================--
-- Derived numbers
--====================================================================--

-- Cash per second a banked character earns before the rebirth multiplier.
function Brainrots.EffectiveIncome(def, mutation)
	if mutation then
		return def.income * mutation.mult
	end
	return def.income
end

-- The label shown on nameplates, prompts and the HUD carry line.
function Brainrots.DisplayName(def, mutation)
	if mutation then
		return mutation.tag .. " " .. def.name
	end
	return def.name
end

-- Rebirth price curve: 25K, 100K, 400K, ... (x4 per rebirth).
function Brainrots.RebirthCost(rebirths)
	return math.floor(25000 * (4 ^ rebirths))
end

-- Permanent income multiplier from rebirths: +50% each, forever.
function Brainrots.RebirthMult(rebirths)
	return 1 + 0.5 * rebirths
end

-- "$950", "$25K", "$1.5M": compact money for HUDs, signs and boards.
function Brainrots.FormatMoney(n)
	n = math.floor(n)
	if n < 1000 then
		return "$" .. n
	end
	if n < 1000000 then
		local v = n / 1000
		if v == math.floor(v) then
			return "$" .. math.floor(v) .. "K"
		end
		return "$" .. string.format("%.1f", v) .. "K"
	end
	local v = n / 1000000
	if v == math.floor(v) then
		return "$" .. math.floor(v) .. "M"
	end
	return "$" .. string.format("%.1f", v) .. "M"
end

return Brainrots
