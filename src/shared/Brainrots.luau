--[[
	Brainrots.luau — the shared catalogue for MAGMA MAYHEM: Brainrot Volcano.

	Paste target: a ModuleScript named "Brainrots" in ReplicatedStorage.
	The server modules and the client HUD all require this one module, so
	the cast, the prices, the mutation maths and the model factory live in
	exactly one place.

	Contents:
	  * 44 original volcano-and-grill brainrots across 7 rarities, each
	    with a price, an income rate, a carry effect and a one-line joke.
	  * The mutation ladder: Charred x2, Molten x3.5, Obsidian x5,
	    Golden x7.5, MagmaCore x10, with roll odds.
	  * Spawn rolling (parade + wild pools, with event/luck multipliers).
	  * BuildBrainrotModel: the part-built character factory the parade,
	    the pedestals, the wild pools and the thieves all share, with its
	    name / rarity / $/s BillboardGui label.
	  * Index milestones for the collection book.
]]

local Brainrots = {}

-- Cash every player starts a session (and every Rekindle) with: enough
-- for an Ashy Meatball and a dream.
Brainrots.StartingCash = 100

-- Gem cost of re-rolling one placed brainrot's mutation (Progression
-- shop talk lives in Economy; the price of the gamble lives here).
Brainrots.RerollGemCost = 5

--====================================================================--
-- Rarities: order drives bragging rights and quest checks; color
-- dresses labels, pads and beams; weight is the parade spawn share.
--====================================================================--

Brainrots.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(168, 168, 168), beam = Color3.fromRGB(200, 200, 200), weight = 34 },
	Uncommon = { order = 2, color = Color3.fromRGB(95, 200, 110), beam = Color3.fromRGB(140, 240, 150), weight = 26 },
	Rare = { order = 3, color = Color3.fromRGB(70, 140, 255), beam = Color3.fromRGB(110, 175, 255), weight = 18 },
	Epic = { order = 4, color = Color3.fromRGB(170, 85, 255), beam = Color3.fromRGB(200, 140, 255), weight = 11 },
	Legendary = { order = 5, color = Color3.fromRGB(255, 170, 30), beam = Color3.fromRGB(255, 205, 90), weight = 6 },
	Mythic = { order = 6, color = Color3.fromRGB(255, 70, 150), beam = Color3.fromRGB(255, 120, 185), weight = 3.5 },
	Secret = { order = 7, color = Color3.fromRGB(255, 240, 240), beam = Color3.fromRGB(255, 255, 255), weight = 1.5 },
}

-- Rarity names sorted by order, for pools and "at least this rarity"
-- quest checks.
Brainrots.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

--====================================================================--
-- Mutations: rolled per spawn. Chances are percentages out of 100 and
-- sum to 15, so 85% of spawns are plain. A mutation multiplies income,
-- prefixes the name and re-dresses the model.
--====================================================================--

Brainrots.Mutations = {
	{ name = "Charred", mult = 2, chance = 8, color = Color3.fromRGB(52, 46, 44), prefix = "CHARRED" },
	{ name = "Molten", mult = 3.5, chance = 4, color = Color3.fromRGB(255, 110, 40), prefix = "MOLTEN" },
	{ name = "Obsidian", mult = 5, chance = 2, color = Color3.fromRGB(24, 20, 34), prefix = "OBSIDIAN" },
	{ name = "Golden", mult = 7.5, chance = 0.8, color = Color3.fromRGB(255, 205, 50), prefix = "GOLDEN" },
	{ name = "MagmaCore", mult = 10, chance = 0.2, color = Color3.fromRGB(255, 70, 20), prefix = "MAGMACORE" },
}

-- Mutation lookup by name, filled once at load (below the cast).
Brainrots.MutationByName = {}
for _, m in ipairs(Brainrots.Mutations) do
	Brainrots.MutationByName[m.name] = m
end

--====================================================================--
-- The cast: 44 originals, built from plain parts by the factory below.
--   rate        = base cash per second once banked on a pedestal
--   price       = cash to buy it off the parade
--   body/accent = the two colours its blocky model is built from
--   shape       = "box" | "round" | "tall" | "long" body plan
--   accessory   = which prop the factory bolts on
--   size        = overall scale (gods are bigger, obviously)
--   speed       = studs per second while it marches the parade ring
--   carryEffect = "none" | "slow" | "heavy" | "speed" | "jump" — what
--                 carrying it does to your movement (see Progression)
--   joke        = the one-liner the index book shows
--====================================================================--

Brainrots.Characters = {
	-- COMMON ------------------------------------------------------------
	{ name = "Ashy Meatball", rarity = "Common", rate = 1, price = 25,
		body = Color3.fromRGB(150, 84, 60), accent = Color3.fromRGB(90, 50, 38),
		shape = "round", accessory = "GrillHat", size = 0.85, speed = 9, carryEffect = "none",
		joke = "Rolled off the grill in 1347. Never stopped rolling." },
	{ name = "Pumice Pup", rarity = "Common", rate = 2, price = 60,
		body = Color3.fromRGB(178, 172, 160), accent = Color3.fromRGB(240, 160, 190),
		shape = "box", accessory = "Flower", size = 0.8, speed = 10, carryEffect = "none",
		joke = "A dog made of bath rock. Floats. Judges you." },
	{ name = "Smoky Sardine", rarity = "Common", rate = 3, price = 100,
		body = Color3.fromRGB(150, 165, 180), accent = Color3.fromRGB(255, 140, 60),
		shape = "long", accessory = "Antenna", size = 0.75, speed = 11, carryEffect = "none",
		joke = "Smells like a campfire that owes you money." },
	{ name = "Charcoal Chick", rarity = "Common", rate = 4, price = 150,
		body = Color3.fromRGB(70, 64, 62), accent = Color3.fromRGB(255, 190, 60),
		shape = "round", accessory = "Mohawk", size = 0.8, speed = 10, carryEffect = "none",
		joke = "Hatched from a barbecue. Tastes victory." },
	{ name = "Soot Sprite", rarity = "Common", rate = 6, price = 250,
		body = Color3.fromRGB(96, 92, 104), accent = Color3.fromRGB(200, 200, 220),
		shape = "round", accessory = "Antenna", size = 0.7, speed = 12, carryEffect = "speed",
		joke = "Powered by chimney dust and spite." },
	{ name = "Ember Eel", rarity = "Common", rate = 9, price = 400,
		body = Color3.fromRGB(230, 110, 50), accent = Color3.fromRGB(255, 210, 110),
		shape = "long", accessory = "Shades", size = 0.85, speed = 11, carryEffect = "none",
		joke = "Slippery, smug, slightly on fire." },
	{ name = "Toasty Toad", rarity = "Common", rate = 13, price = 600,
		body = Color3.fromRGB(214, 164, 100), accent = Color3.fromRGB(140, 95, 50),
		shape = "round", accessory = "ChefHat", size = 0.9, speed = 9, carryEffect = "none",
		joke = "Golden brown and legally a pastry now." },
	{ name = "Cinder Snail", rarity = "Common", rate = 18, price = 850,
		body = Color3.fromRGB(170, 120, 90), accent = Color3.fromRGB(60, 55, 60),
		shape = "round", accessory = "Shell", size = 0.9, speed = 7, carryEffect = "slow",
		joke = "Slow because his house is a volcano chunk." },
	{ name = "Clinker Cat", rarity = "Common", rate = 21, price = 1050,
		body = Color3.fromRGB(120, 116, 120), accent = Color3.fromRGB(255, 170, 90),
		shape = "box", accessory = "Flower", size = 0.85, speed = 10, carryEffect = "none",
		joke = "Purrs in gravel. Hairballs are just rocks." },
	{ name = "Pebble Penguin", rarity = "Common", rate = 32, price = 1600,
		body = Color3.fromRGB(52, 58, 72), accent = Color3.fromRGB(245, 245, 245),
		shape = "tall", accessory = "Shades", size = 0.95, speed = 9, carryEffect = "none",
		joke = "Came for the ice. Stayed for the barbecue." },

	-- UNCOMMON ----------------------------------------------------------
	{ name = "Kebab Crab", rarity = "Uncommon", rate = 45, price = 2800,
		body = Color3.fromRGB(225, 90, 60), accent = Color3.fromRGB(200, 200, 205),
		shape = "box", accessory = "Spatula", size = 0.95, speed = 9, carryEffect = "none",
		joke = "Armed with a skewer and zero remorse." },
	{ name = "Fondue Fox", rarity = "Uncommon", rate = 65, price = 4000,
		body = Color3.fromRGB(240, 150, 60), accent = Color3.fromRGB(250, 230, 190),
		shape = "box", accessory = "ChefHat", size = 0.9, speed = 12, carryEffect = "speed",
		joke = "Dips everything. Including himself. Often." },
	{ name = "Tiki Torch Tortoise", rarity = "Uncommon", rate = 90, price = 5500,
		body = Color3.fromRGB(90, 150, 80), accent = Color3.fromRGB(255, 150, 50),
		shape = "round", accessory = "Torch", size = 1.0, speed = 7, carryEffect = "slow",
		joke = "A walking luau with a shell." },
	{ name = "Grill Sergeant", rarity = "Uncommon", rate = 120, price = 7500,
		body = Color3.fromRGB(105, 120, 70), accent = Color3.fromRGB(60, 40, 30),
		shape = "box", accessory = "GrillHat", size = 1.0, speed = 9, carryEffect = "none",
		joke = "Barks orders. Flips burgers. Flips tables." },
	{ name = "Lava Lamprey", rarity = "Uncommon", rate = 160, price = 10000,
		body = Color3.fromRGB(160, 70, 90), accent = Color3.fromRGB(255, 120, 90),
		shape = "long", accessory = "Antenna", size = 0.9, speed = 11, carryEffect = "none",
		joke = "Attaches to boats. And grills. And ankles." },
	{ name = "S'more Golem", rarity = "Uncommon", rate = 210, price = 13000,
		body = Color3.fromRGB(235, 225, 205), accent = Color3.fromRGB(110, 70, 45),
		shape = "tall", accessory = "Torch", size = 1.05, speed = 8, carryEffect = "none",
		joke = "Graham, marshmallow, and a dream." },
	{ name = "Coal Kangaroo", rarity = "Uncommon", rate = 260, price = 16500,
		body = Color3.fromRGB(88, 80, 78), accent = Color3.fromRGB(230, 200, 170),
		shape = "box", accessory = "Mohawk", size = 1.0, speed = 11, carryEffect = "jump",
		joke = "Pouch full of briquettes and secrets." },
	{ name = "Brimstone Bunny", rarity = "Uncommon", rate = 320, price = 21000,
		body = Color3.fromRGB(200, 90, 80), accent = Color3.fromRGB(255, 200, 90),
		shape = "box", accessory = "Horns", size = 0.9, speed = 13, carryEffect = "speed",
		joke = "Hops so fast the carrots cook themselves." },
	{ name = "Barbecue Bat", rarity = "Uncommon", rate = 380, price = 25000,
		body = Color3.fromRGB(80, 60, 90), accent = Color3.fromRGB(240, 120, 70),
		shape = "box", accessory = "Wings", size = 0.85, speed = 13, carryEffect = "speed",
		joke = "Only awake at grill o'clock. Which is always." },

	-- RARE ---------------------------------------------------------------
	{ name = "Obsidian Owl", rarity = "Rare", rate = 450, price = 30000,
		body = Color3.fromRGB(38, 34, 48), accent = Color3.fromRGB(150, 120, 255),
		shape = "round", accessory = "Shades", size = 0.95, speed = 10, carryEffect = "none",
		joke = "Sees through stone. And your search history." },
	{ name = "Magma Meerkat", rarity = "Rare", rate = 600, price = 40000,
		body = Color3.fromRGB(215, 150, 90), accent = Color3.fromRGB(255, 110, 50),
		shape = "box", accessory = "Antenna", size = 0.9, speed = 11, carryEffect = "none",
		joke = "Stands guard over absolutely nothing." },
	{ name = "Pyro Platypus", rarity = "Rare", rate = 800, price = 55000,
		body = Color3.fromRGB(130, 95, 70), accent = Color3.fromRGB(255, 170, 60),
		shape = "box", accessory = "Propeller", size = 0.95, speed = 10, carryEffect = "none",
		joke = "Venomous, egg-laying, and lightly grilled." },
	{ name = "Caldera Camel", rarity = "Rare", rate = 1050, price = 72000,
		body = Color3.fromRGB(205, 160, 105), accent = Color3.fromRGB(255, 100, 40),
		shape = "tall", accessory = "Shell", size = 1.1, speed = 8, carryEffect = "slow",
		joke = "Stores lava in the humps. Do not shake." },
	{ name = "Sulfur Seahorse", rarity = "Rare", rate = 1350, price = 95000,
		body = Color3.fromRGB(240, 205, 80), accent = Color3.fromRGB(120, 220, 160),
		shape = "long", accessory = "Halo", size = 0.9, speed = 11, carryEffect = "none",
		joke = "Smells like a match factory in a thunderstorm." },
	{ name = "Furnace Ferret", rarity = "Rare", rate = 1700, price = 120000,
		body = Color3.fromRGB(165, 110, 75), accent = Color3.fromRGB(90, 85, 90),
		shape = "box", accessory = "Mohawk", size = 0.9, speed = 13, carryEffect = "speed",
		joke = "Steals socks and stokes boilers." },
	{ name = "Volcano Vole Esquire", rarity = "Rare", rate = 2100, price = 150000,
		body = Color3.fromRGB(110, 90, 110), accent = Color3.fromRGB(255, 205, 60),
		shape = "box", accessory = "Crown", size = 0.85, speed = 9, carryEffect = "none",
		joke = "A gentleman. A scholar. A rodent of means." },
	{ name = "Crispy Capybara", rarity = "Rare", rate = 2600, price = 185000,
		body = Color3.fromRGB(150, 105, 65), accent = Color3.fromRGB(240, 200, 120),
		shape = "box", accessory = "Flower", size = 1.05, speed = 8, carryEffect = "none",
		joke = "World's chillest potato, well done." },

	-- EPIC ---------------------------------------------------------------
	{ name = "Ember Emperor Penguin", rarity = "Epic", rate = 3000, price = 220000,
		body = Color3.fromRGB(40, 42, 58), accent = Color3.fromRGB(255, 160, 50),
		shape = "tall", accessory = "Crown", size = 1.15, speed = 8, carryEffect = "slow",
		joke = "Rules an empire of one iceberg. It is melting." },
	{ name = "Tectonic Tapir", rarity = "Epic", rate = 4200, price = 320000,
		body = Color3.fromRGB(100, 95, 110), accent = Color3.fromRGB(230, 120, 80),
		shape = "long", accessory = "Shell", size = 1.15, speed = 8, carryEffect = "heavy",
		joke = "His naps register on seismographs." },
	{ name = "Lava Kraken Jr.", rarity = "Epic", rate = 5800, price = 450000,
		body = Color3.fromRGB(235, 90, 55), accent = Color3.fromRGB(255, 190, 90),
		shape = "round", accessory = "Antenna", size = 1.1, speed = 10, carryEffect = "none",
		joke = "Eight arms, all flipping burgers at once." },
	{ name = "Grillmaster Golem", rarity = "Epic", rate = 7500, price = 600000,
		body = Color3.fromRGB(80, 74, 78), accent = Color3.fromRGB(255, 130, 50),
		shape = "tall", accessory = "Spatula", size = 1.2, speed = 7, carryEffect = "heavy",
		joke = "Forged in a volcano, seasoned to perfection." },
	{ name = "Phoenix Dachshund", rarity = "Epic", rate = 9500, price = 780000,
		body = Color3.fromRGB(245, 120, 45), accent = Color3.fromRGB(255, 215, 90),
		shape = "long", accessory = "Wings", size = 1.0, speed = 12, carryEffect = "none",
		joke = "Burns down, pops back up, demands a treat." },
	{ name = "Obsidian Ocelot", rarity = "Epic", rate = 12000, price = 1000000,
		body = Color3.fromRGB(30, 28, 40), accent = Color3.fromRGB(200, 170, 255),
		shape = "box", accessory = "Shades", size = 1.0, speed = 13, carryEffect = "speed",
		joke = "A shadow with spots and a mortgage." },
	{ name = "Magma Mariachi Band", rarity = "Epic", rate = 15500, price = 1300000,
		body = Color3.fromRGB(238, 232, 220), accent = Color3.fromRGB(200, 50, 60),
		shape = "box", accessory = "GrillHat", size = 1.15, speed = 9, carryEffect = "none",
		joke = "Four skeletons. One trumpet. Zero refunds." },

	-- LEGENDARY ------------------------------------------------------------
	{ name = "Magma Mammoth", rarity = "Legendary", rate = 18000, price = 1600000,
		body = Color3.fromRGB(120, 85, 70), accent = Color3.fromRGB(255, 140, 50),
		shape = "tall", accessory = "Horns", size = 1.35, speed = 7, carryEffect = "heavy",
		joke = "Extinct? He never got the memo." },
	{ name = "Caldera Kraken", rarity = "Legendary", rate = 26000, price = 2400000,
		body = Color3.fromRGB(190, 60, 50), accent = Color3.fromRGB(255, 180, 70),
		shape = "round", accessory = "Crown", size = 1.3, speed = 9, carryEffect = "heavy",
		joke = "The volcano is his hot tub." },
	{ name = "Solar Flare Flamingo", rarity = "Legendary", rate = 38000, price = 3600000,
		body = Color3.fromRGB(255, 130, 150), accent = Color3.fromRGB(255, 225, 120),
		shape = "tall", accessory = "Halo", size = 1.2, speed = 12, carryEffect = "speed",
		joke = "Stands on one leg at 5,778 degrees." },
	{ name = "Pyroclast Panda", rarity = "Legendary", rate = 55000, price = 5200000,
		body = Color3.fromRGB(240, 238, 235), accent = Color3.fromRGB(45, 42, 45),
		shape = "round", accessory = "Flower", size = 1.25, speed = 8, carryEffect = "slow",
		joke = "Eats bamboo. The bamboo is on fire. He is calm." },
	{ name = "Basalt Basilisk", rarity = "Legendary", rate = 68000, price = 6800000,
		body = Color3.fromRGB(52, 50, 58), accent = Color3.fromRGB(255, 90, 50),
		shape = "long", accessory = "Horns", size = 1.3, speed = 7, carryEffect = "heavy",
		joke = "One look turns you to stone. The stone is also looking." },

	-- MYTHIC ---------------------------------------------------------------
	{ name = "World Turtle Barbecue", rarity = "Mythic", rate = 90000, price = 9000000,
		body = Color3.fromRGB(85, 130, 80), accent = Color3.fromRGB(255, 120, 50),
		shape = "round", accessory = "VolcanoHat", size = 1.6, speed = 6, carryEffect = "heavy",
		joke = "The island is his shell. The shell is a grill." },
	{ name = "Magma Core Dragon", rarity = "Mythic", rate = 140000, price = 15000000,
		body = Color3.fromRGB(170, 40, 45), accent = Color3.fromRGB(255, 160, 40),
		shape = "tall", accessory = "Wings", size = 1.5, speed = 8, carryEffect = "heavy",
		joke = "Hoards gold, but prefers hoarding sausages." },
	{ name = "The Grillfather", rarity = "Mythic", rate = 210000, price = 24000000,
		body = Color3.fromRGB(45, 42, 50), accent = Color3.fromRGB(255, 205, 60),
		shape = "box", accessory = "Crown", size = 1.3, speed = 8, carryEffect = "slow",
		joke = "He made the volcano an offer it couldn't refuse." },

	-- SECRET ---------------------------------------------------------------
	{ name = "Sentient Lava Lamp", rarity = "Secret", rate = 450000, price = 55000000,
		body = Color3.fromRGB(255, 90, 120), accent = Color3.fromRGB(140, 220, 255),
		shape = "tall", accessory = "LavaLamp", size = 1.2, speed = 9, carryEffect = "none",
		joke = "It knows what you did. It bubbles approvingly." },
	{ name = "DO NOT FEED HIM", rarity = "Secret", rate = 2500000, price = 250000000,
		body = Color3.fromRGB(200, 50, 45), accent = Color3.fromRGB(255, 230, 90),
		shape = "round", accessory = "Horns", size = 1.8, speed = 6, carryEffect = "heavy",
		joke = "The sign was clear. Someone fed him. Now this." },
}

-- Name + rarity-pool lookups, filled once at load.
Brainrots.ByName = {}
Brainrots.ByRarity = {}
for _, def in ipairs(Brainrots.Characters) do
	Brainrots.ByName[def.name] = def
	if not Brainrots.ByRarity[def.rarity] then
		Brainrots.ByRarity[def.rarity] = {}
	end
	table.insert(Brainrots.ByRarity[def.rarity], def)
end

--====================================================================--
-- Spawn rolling
--====================================================================--

-- Roll a rarity name by parade weights. zoneLuck (1 = normal) tilts
-- the roll toward the top: wild pools in richer zones pass 1.5 / 2.5,
-- which effectively re-rolls and keeps the better rarity.
local function rollRarityOnce()
	local total = 0
	for _, name in ipairs(Brainrots.RarityOrder) do
		total += Brainrots.Rarities[name].weight
	end
	local r = math.random() * total
	for _, name in ipairs(Brainrots.RarityOrder) do
		r -= Brainrots.Rarities[name].weight
		if r <= 0 then
			return name
		end
	end
	return "Common"
end

function Brainrots.RollRarity(zoneLuck)
	local best = rollRarityOnce()
	if zoneLuck and zoneLuck > 1 then
		-- Luck buys extra draws; keep the rarest result.
		local draws = math.floor(zoneLuck)
		if math.random() < (zoneLuck - draws) then
			draws += 1
		end
		for _ = 1, draws do
			local again = rollRarityOnce()
			if Brainrots.Rarities[again].order > Brainrots.Rarities[best].order then
				best = again
			end
		end
	end
	return best
end

-- Roll a mutation (or nil for plain). oddsMult stretches every chance:
-- Mutation Storm passes 3, a Luck Charm re-roll passes 1 + luck.
function Brainrots.RollMutation(oddsMult)
	oddsMult = oddsMult or 1
	local roll = math.random() * 100
	local acc = 0
	for _, m in ipairs(Brainrots.Mutations) do
		acc += m.chance * oddsMult
		if roll < acc then
			return m
		end
	end
	return nil
end

-- Roll one full spawn: (def, mutationOrNil). opts = { oddsMult, zoneLuck }.
function Brainrots.RollSpawn(opts)
	opts = opts or {}
	local rarity = Brainrots.RollRarity(opts.zoneLuck)
	local pool = Brainrots.ByRarity[rarity]
	local def = pool[math.random(1, #pool)]
	local mutation = Brainrots.RollMutation(opts.oddsMult)
	return def, mutation
end

--====================================================================--
-- Derived numbers + display
--====================================================================--

-- Cash per second a brainrot earns before rebirth/event multipliers.
function Brainrots.EffectiveRate(def, mutation)
	if mutation then
		return math.floor(def.rate * mutation.mult)
	end
	return def.rate
end

-- "MOLTEN Kebab Crab": the label shown on models, prompts and the HUD.
function Brainrots.DisplayName(def, mutation)
	if mutation then
		return mutation.prefix .. " " .. def.name
	end
	return def.name
end

-- Catch chance (0..1) for a wild spawn of this rarity, before luck.
Brainrots.CatchChance = {
	Common = 0.9, Uncommon = 0.8, Rare = 0.65, Epic = 0.45,
	Legendary = 0.28, Mythic = 0.16, Secret = 0.08,
}

-- Gems a wild catch of this rarity pays on top of the brainrot itself.
Brainrots.CatchGems = {
	Common = 0, Uncommon = 0, Rare = 0, Epic = 1,
	Legendary = 2, Mythic = 4, Secret = 10,
}

-- "$950", "$25K", "$1.5M", "$2.5B": compact money for HUDs and signs.
function Brainrots.FormatMoney(n)
	n = math.floor(n)
	if n < 1000 then
		return "$" .. n
	end
	local units = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if n >= u[1] then
			local v = n / u[1]
			if v == math.floor(v) then
				return "$" .. math.floor(v) .. u[2]
			end
			return "$" .. string.format("%.1f", v) .. u[2]
		end
	end
	return "$" .. n
end

--====================================================================--
-- Index milestones: discovering this many of the 44 pays gems and a
-- title for the collection book (awarded by Progression).
--====================================================================--

Brainrots.IndexMilestones = {
	{ count = 5, gems = 5, title = "Ash Sniffer" },
	{ count = 10, gems = 10, title = "Grill Scout" },
	{ count = 15, gems = 15, title = "Ember Ranger" },
	{ count = 20, gems = 25, title = "Obsidian Hunter" },
	{ count = 25, gems = 40, title = "Caldera Collector" },
	{ count = 30, gems = 60, title = "Magma Curator" },
	{ count = 35, gems = 90, title = "Volcano Archivist" },
	{ count = 40, gems = 140, title = "Keeper of the Crater" },
	{ count = 44, gems = 250, title = "BRAINROT VOLCANO MASTER" },
}

--====================================================================--
-- Model factory: every brainrot in the world — parade, pedestal, wild,
-- carried, stolen — is this one part-built character, so the cast looks
-- the same wherever it stands. All parts are Anchored and the model is
-- moved with PivotTo: no physics, no Humanoid, no surprises.
--====================================================================--

local function factoryPart(parent, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Accessory builders: (model, headTopY, def) — small part clusters that
-- sit on or beside the head. Keyed by the cast's accessory names.
local accessoryBuilders = {}

function accessoryBuilders.GrillHat(model, topY, def)
	factoryPart(model, "HatBrim", Vector3.new(1.7, 0.18, 1.7), CFrame.new(0, topY + 0.1, 0), Color3.fromRGB(40, 40, 46))
	factoryPart(model, "HatTop", Vector3.new(1.15, 0.65, 1.15), CFrame.new(0, topY + 0.5, 0), Color3.fromRGB(40, 40, 46))
	factoryPart(model, "HatBand", Vector3.new(1.22, 0.2, 1.22), CFrame.new(0, topY + 0.28, 0), Color3.fromRGB(255, 110, 50), Enum.Material.Neon)
end

function accessoryBuilders.ChefHat(model, topY, def)
	factoryPart(model, "HatBand", Vector3.new(1.25, 0.35, 1.25), CFrame.new(0, topY + 0.18, 0), Color3.fromRGB(245, 245, 245))
	factoryPart(model, "HatPuff", Vector3.new(1.55, 0.8, 1.55), CFrame.new(0, topY + 0.7, 0), Color3.fromRGB(250, 250, 250), nil, Enum.PartType.Ball)
end

function accessoryBuilders.Crown(model, topY, def)
	local gold = Color3.fromRGB(255, 205, 50)
	factoryPart(model, "CrownBand", Vector3.new(1.3, 0.4, 1.3), CFrame.new(0, topY + 0.22, 0), gold, Enum.Material.Metal)
	for i = 1, 4 do
		local a = (i - 1) * math.pi / 2 + math.pi / 4
		factoryPart(model, "CrownSpike", Vector3.new(0.28, 0.55, 0.28),
			CFrame.new(math.cos(a) * 0.5, topY + 0.6, math.sin(a) * 0.5), gold, Enum.Material.Metal)
	end
end

function accessoryBuilders.Horns(model, topY, def)
	for _, s in ipairs({ -1, 1 }) do
		factoryPart(model, "Horn", Vector3.new(0.3, 1.0, 0.3),
			CFrame.new(s * 0.62, topY + 0.4, 0) * CFrame.Angles(0, 0, s * -0.5),
			Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic)
	end
end

function accessoryBuilders.Mohawk(model, topY, def)
	factoryPart(model, "Mohawk", Vector3.new(0.25, 0.7, 1.3), CFrame.new(0, topY + 0.35, 0),
		Color3.fromRGB(255, 80, 90), Enum.Material.Neon)
end

function accessoryBuilders.Antenna(model, topY, def)
	factoryPart(model, "AntennaStalk", Vector3.new(0.12, 0.8, 0.12), CFrame.new(0, topY + 0.4, 0), Color3.fromRGB(60, 60, 66))
	factoryPart(model, "AntennaOrb", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, topY + 0.95, 0),
		def.accent, Enum.Material.Neon, Enum.PartType.Ball)
end

function accessoryBuilders.Flower(model, topY, def)
	factoryPart(model, "FlowerStem", Vector3.new(0.1, 0.5, 0.1), CFrame.new(0.55, topY + 0.25, 0), Color3.fromRGB(70, 160, 80))
	factoryPart(model, "FlowerHead", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.55, topY + 0.6, 0),
		Color3.fromRGB(255, 150, 190), Enum.Material.Neon, Enum.PartType.Ball)
end

function accessoryBuilders.Shades(model, topY, def)
	-- A single dark band across the eyes: instant cool.
	factoryPart(model, "Shades", Vector3.new(1.34, 0.34, 0.12), CFrame.new(0, topY - 0.55, -0.62),
		Color3.fromRGB(18, 18, 24), Enum.Material.Glass)
end

function accessoryBuilders.Shell(model, topY, def)
	factoryPart(model, "ShellBack", Vector3.new(1.7, 1.5, 0.7), CFrame.new(0, 0.4, 0.85),
		def.accent, Enum.Material.Slate, Enum.PartType.Ball)
end

function accessoryBuilders.Torch(model, topY, def)
	factoryPart(model, "TorchStick", Vector3.new(0.18, 1.3, 0.18), CFrame.new(1.15, 0.7, 0), Color3.fromRGB(110, 75, 45))
	factoryPart(model, "TorchFlame", Vector3.new(0.55, 0.8, 0.55), CFrame.new(1.15, 1.6, 0),
		Color3.fromRGB(255, 140, 40), Enum.Material.Neon, Enum.PartType.Ball)
end

function accessoryBuilders.Spatula(model, topY, def)
	factoryPart(model, "SpatulaHandle", Vector3.new(0.14, 1.1, 0.14),
		CFrame.new(1.15, 0.6, 0) * CFrame.Angles(0, 0, -0.4), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	factoryPart(model, "SpatulaHead", Vector3.new(0.6, 0.5, 0.1),
		CFrame.new(1.4, 1.25, 0) * CFrame.Angles(0, 0, -0.4), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
end

function accessoryBuilders.Wings(model, topY, def)
	for _, s in ipairs({ -1, 1 }) do
		factoryPart(model, "Wing", Vector3.new(1.3, 0.7, 0.14),
			CFrame.new(s * 1.05, 0.75, 0.55) * CFrame.Angles(0, s * 0.5, s * 0.35),
			def.accent, Enum.Material.SmoothPlastic)
	end
end

function accessoryBuilders.Halo(model, topY, def)
	-- Cylinder parts lie on their X axis; rotate to lie flat.
	factoryPart(model, "Halo", Vector3.new(0.14, 1.15, 1.15),
		CFrame.new(0, topY + 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 235, 140), Enum.Material.Neon, Enum.PartType.Cylinder)
end

function accessoryBuilders.Propeller(model, topY, def)
	factoryPart(model, "PropStick", Vector3.new(0.12, 0.45, 0.12), CFrame.new(0, topY + 0.22, 0), Color3.fromRGB(60, 60, 66))
	factoryPart(model, "PropBlade", Vector3.new(1.5, 0.1, 0.3), CFrame.new(0, topY + 0.5, 0), def.accent)
end

function accessoryBuilders.VolcanoHat(model, topY, def)
	factoryPart(model, "MiniVolcano", Vector3.new(0.8, 1.2, 1.2),
		CFrame.new(0, topY + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(80, 70, 68), Enum.Material.Slate, Enum.PartType.Cylinder)
	factoryPart(model, "MiniLava", Vector3.new(0.25, 0.6, 0.6),
		CFrame.new(0, topY + 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 110, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
end

function accessoryBuilders.LavaLamp(model, topY, def)
	factoryPart(model, "LampBase", Vector3.new(0.25, 0.8, 0.8),
		CFrame.new(0, topY + 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(60, 60, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
	factoryPart(model, "LampGlass", Vector3.new(1.0, 0.85, 0.85),
		CFrame.new(0, topY + 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 90, 120), Enum.Material.Neon, Enum.PartType.Cylinder)
end

-- Build one brainrot character model. mutationName may be nil.
-- Returns the Model with attributes DefName / MutationName / Rarity /
-- Rate set, PrimaryPart = Body, origin at the ground between its feet.
function Brainrots.BuildBrainrotModel(def, mutationName)
	local mutation = mutationName and Brainrots.MutationByName[mutationName] or nil
	local s = def.size
	local model = Instance.new("Model")
	model.Name = Brainrots.DisplayName(def, mutation)

	-- Body plan by shape.
	local bodySize, bodyY
	if def.shape == "round" then
		bodySize, bodyY = Vector3.new(1.9, 1.9, 1.9), 1.0
	elseif def.shape == "tall" then
		bodySize, bodyY = Vector3.new(1.6, 2.6, 1.6), 1.35
	elseif def.shape == "long" then
		bodySize, bodyY = Vector3.new(2.6, 1.3, 1.4), 0.85
	else -- "box"
		bodySize, bodyY = Vector3.new(1.9, 1.8, 1.7), 0.95
	end
	bodySize *= s
	bodyY *= s

	local bodyColor = def.body
	local bodyMaterial = Enum.Material.SmoothPlastic
	if mutation then
		if mutation.name == "Charred" then
			bodyColor = def.body:Lerp(mutation.color, 0.75)
			bodyMaterial = Enum.Material.Slate
		elseif mutation.name == "Obsidian" then
			bodyColor = mutation.color
			bodyMaterial = Enum.Material.Glass
		elseif mutation.name == "Golden" then
			bodyColor = mutation.color
			bodyMaterial = Enum.Material.Metal
		elseif mutation.name == "Molten" or mutation.name == "MagmaCore" then
			bodyColor = def.body:Lerp(mutation.color, 0.55)
			bodyMaterial = Enum.Material.Neon
		end
	end

	local bodyShape = nil
	if def.shape == "round" then
		bodyShape = Enum.PartType.Ball
	end
	local body = factoryPart(model, "Body", bodySize, CFrame.new(0, bodyY, 0), bodyColor, bodyMaterial, bodyShape)

	-- Feet: two little boots so the march reads at a distance.
	for _, fx in ipairs({ -0.45, 0.45 }) do
		factoryPart(model, "Foot", Vector3.new(0.55, 0.3, 0.8) * s,
			CFrame.new(fx * s, 0.15 * s, -0.15 * s), Color3.fromRGB(50, 42, 40))
	end

	-- Head with a part-built face (two eyes + grin) on the front (-Z).
	local headSize = 1.25 * s
	local headY = bodyY + (bodySize.Y / 2) + (headSize / 2) - 0.08 * s
	local head = factoryPart(model, "Head", Vector3.new(headSize, headSize, headSize),
		CFrame.new(0, headY, 0), def.accent, Enum.Material.SmoothPlastic)
	for _, ex in ipairs({ -0.28, 0.28 }) do
		factoryPart(model, "Eye", Vector3.new(0.2, 0.26, 0.1) * s,
			CFrame.new(ex * s, headY + 0.12 * s, -(headSize / 2) - 0.03), Color3.fromRGB(20, 18, 22))
	end
	factoryPart(model, "Grin", Vector3.new(0.55, 0.12, 0.1) * s,
		CFrame.new(0, headY - 0.3 * s, -(headSize / 2) - 0.03), Color3.fromRGB(20, 18, 22))

	local topY = headY + headSize / 2
	local build = accessoryBuilders[def.accessory]
	if build then
		build(model, topY, def)
	end

	-- Mutated spawns glow: a point light sells Molten / MagmaCore.
	if mutation and (mutation.name == "Molten" or mutation.name == "MagmaCore") then
		local light = Instance.new("PointLight")
		light.Color = mutation.color
		light.Brightness = 2
		light.Range = 9
		light.Parent = body
	end

	-- The label: name (mutation prefix first), rarity, $/s.
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.fromOffset(230, 84)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Parent = head

	local function labelLine(name, text, yScale, hScale, size, color, bold)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, hScale)
		l.Position = UDim2.fromScale(0, yScale)
		l.Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold
		l.TextSize = size
		l.TextColor3 = color
		l.Text = text
		l.TextStrokeTransparency = 0.45
		l.TextStrokeColor3 = Color3.fromRGB(15, 12, 14)
		l.Parent = gui
		return l
	end
	labelLine("NameLabel", "", 0, 0.42, 20, Color3.fromRGB(255, 255, 255), true)
	labelLine("RarityLabel", "", 0.42, 0.3, 15, Color3.fromRGB(255, 255, 255), false)
	labelLine("RateLabel", "", 0.7, 0.3, 15, Color3.fromRGB(160, 255, 170), false)

	model.PrimaryPart = body
	model:SetAttribute("DefName", def.name)
	model:SetAttribute("MutationName", mutationName or "")
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Rate", Brainrots.EffectiveRate(def, mutation))
	Brainrots.SetModelLabel(model, def, mutation)
	return model
end

-- Refresh a model's label (after a mutation re-roll, say) without
-- rebuilding the whole character.
function Brainrots.SetModelLabel(model, def, mutation)
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("BrainrotLabel")
	if not gui then
		return
	end
	local rarityInfo = Brainrots.Rarities[def.rarity]
	local nameLabel = gui:FindFirstChild("NameLabel")
	local rarityLabel = gui:FindFirstChild("RarityLabel")
	local rateLabel = gui:FindFirstChild("RateLabel")
	if nameLabel then
		nameLabel.Text = Brainrots.DisplayName(def, mutation)
		nameLabel.TextColor3 = mutation and mutation.color or Color3.fromRGB(255, 255, 255)
	end
	if rarityLabel then
		rarityLabel.Text = string.upper(def.rarity)
		rarityLabel.TextColor3 = rarityInfo.color
	end
	if rateLabel then
		rateLabel.Text = Brainrots.FormatMoney(Brainrots.EffectiveRate(def, mutation)) .. "/s"
	end
	model.Name = Brainrots.DisplayName(def, mutation)
	model:SetAttribute("MutationName", mutation and mutation.name or "")
	model:SetAttribute("Rate", Brainrots.EffectiveRate(def, mutation))
end

return Brainrots
