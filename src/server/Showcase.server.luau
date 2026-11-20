--[[
	Showcase.server.luau — the MAGMA SHOWCASE podium, MAGMA MAYHEM.

	A standalone server script (companion to Main.server.luau, which
	retired Plot 8): builds a broad, densely dressed 3-tier treasury
	stand on the retired Plot 8 footprint — the easternmost plot,
	behind the FRUIT stall on the east shore. NINE top earners stand
	on the tiers (the user, 2026-11-20: "kalau perlu tambahin jangan
	7, tapi 9" + "podiumnya dibikin lebih mewah dan padet"): the
	seven rarity champions plus the #2 Secret (Sentient Lava Lamp)
	and the #2 Mythic (Magma Core Dragon). Each stands on a
	plot-style "dudukan" stand (neon flange ring, slate drum,
	rarity-coloured rim — gold for the champion), each with a light
	beam in its rarity colour and a small name / $/s chip above it.
	A header sign behind the champion names the podium, and a
	stepped canopy (tudung) crowns the whole stand. A gold-and-lava
	medallion on the beach in front marks the photo spot: stand
	there and the podium fills the frame alone — the MAGMA MARKET
	quarter (see Main's BuildMarketRow) now sits far along the
	north shore, out of the shot (user, 2026-11-20).

	Frame: everything is built in a LOCAL frame whose origin is
	Plot 8's platform top centre (148·sin77°, 6, 148·cos77°) and
	whose +Z points at the island centre (the photo side), +X to
	the photo spot's right. ROOT converts local -> world; it is
	Main's plot frame (CFrame.lookAt(centre, origin)) turned 180°,
	so the podium faces the island exactly as the plot did.

	Layout (terraced grandstand, reads poorest -> richest upward;
	heights are studs above the beach — the local frame's ground
	is y -6, its origin the old plot top at y 6):
	  * two ground steps (tops 0.9 and 1.8) climb to the plinth
	    floor (2.7), all in the tiers' own red-carpet / gold-trim
	    finish — the stepped pyramid runs right down to the sand:
	    NO raised slab and NO front steps (user, 2026-11-20:
	    "langsung di bawah aja biar ga tinggi")
	  * tier 1 (top 3.2): Common, Uncommon, Rare
	  * tier 2 (top 6.2): Epic, Legendary, Mythic #2
	  * tier 3 (top 9.2): Mythic #1, the SECRET champion
	    (centre, alone on the axis), Secret #2
	  * the canopy: four posts at the plinth corners, three
	    stepped red roof tiers with gold trim (underside 26.2,
	    cap top 34.7 — vs the old build's sign top at 37.2, and
	    the cast itself sits ~6 studs lower than the first
	    build), hanging orb lamps and pennant swags under the
	    front eave; the header sign hangs just under the roof
	    behind the champion.
	Chips are 152x54 screen pixels (name cap 16 px, income cap
	22 px — modest on purpose, per the user) on FIXED anchor parts,
	MaxDistance 110 so they never render across the map. Verified
	by projection (pinhole, 1920x1080, FOV 70 — the user's Studio
	window): over a photo band (40-58 studs out from the plot
	centre, azimuth +/-20 deg off the island axis, eye heights
	5.0-8.0 over the beach) all 36 chip pairs clear — tightest
	+2.6 px (Basalt Basilisk / champion, dead ahead at the band's
	far edge), and +3.9 px at the medallion itself. The wide
	17-18-stud column spacing of the 3+3+3 stand is what makes
	nine chips fit.

	Collision survey (src-verified against Main.server.luau): the
	ground steps reuse Plot 8's exact footprint (46x32 vs the
	plot's 38x30 — a few studs grander; nearest neighbour Plot
	7's platform corner stays 4+ studs clear). The market
	quarter moved far north along the shore (see Main), so
	nothing stands in the photo axis at all. Ground-level base:
	the lowest step and the flat medallion flood briefly when
	the eruption flood rises to 3.4 (cosmetic, like the beach
	itself). Thieves only ever target Game.Plots (1-7) — the
	showcase is never a target.

	Safety: anchored parts only, no per-frame work, no remotes, no
	DataStore. Uses the same BuildBrainrotModel factory the rest of
	the game uses for its figures and pedestals. Re-paste safe: a previous
	MagmaShowcase folder is destroyed before rebuilding. The ONLY
	Main-side change this design needs is already in Main: the
	Plot 8 retirement in BuildPlayerBases and the MAGMA MARKET
	gantry reposition in BuildMarketRow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))

local showcase = workspace:FindFirstChild("MagmaShowcase")
if showcase then
	showcase:Destroy()
end
showcase = Instance.new("Folder")
showcase.Name = "MagmaShowcase"
showcase.Parent = workspace

--====================================================================--
-- Frame: Plot 8's platform top centre; +Z toward the island.
--====================================================================--

local PLOT8_X = 148 * math.sin(math.rad(77))
local PLOT8_Z = 148 * math.cos(math.rad(77))
local ROOT = CFrame.lookAt(Vector3.new(PLOT8_X, 6, PLOT8_Z), Vector3.new(0, 6, 0))
	* CFrame.Angles(0, math.rad(180), 0)

--====================================================================--
-- Palette (warm metals on deep basalt; neon only as trim)
--====================================================================--

local BASALT = Color3.fromRGB(52, 44, 42)
local BASALT_LIGHT = Color3.fromRGB(88, 74, 68)
local GOLD = Color3.fromRGB(255, 205, 50)
local GOLD_DARK = Color3.fromRGB(196, 148, 32)
local LAVA = Color3.fromRGB(255, 110, 36)
local CARPET_RED = Color3.fromRGB(168, 40, 52)
local INCOME_GREEN = Color3.fromRGB(96, 255, 156)
local STAND_SLATE = Color3.fromRGB(104, 96, 112) -- the plot pedestals' drum colour

--====================================================================--
-- Layout constants (local frame; heights above the frame origin —
-- the beach itself is at local y -6)
--====================================================================--

local TIER_TOP = { -2.8, 0.2, 3.2 } -- tier surface heights (ground is -6)
local PLINTH_TOP = -3.3
local STEP1_TOP = -5.1 -- ground steps: the tiers' own red/gold
local STEP2_TOP = -4.2 -- finish, continued down to the beach
local STAND_H = 1.1 -- dudukan height: flange 0.22 + drum 0.68 + rim 0.20
local SIGN_Y = 23.1
local SIGN_H = 5.2
local SIGN_Z = -6.05
local EAVE_Y = 26.2 -- canopy underside (local frame)
local MEDAL_Z = 56 -- medallion distance in front of the plot centre
-- Widest body dimension per shape, from the factory's body table.
local SHAPE_SPAN = { round = 1.9, tall = 1.6, long = 2.6, box = 1.9 }

-- The cast of nine: every rarity champion, plus the next two
-- highest earners overall (Secret #2, Mythic #2). Selected BY
-- NAME via Brainrots.ByName on purpose: Brainrots.ByRarity is
-- filled in Characters order (cheapest first), so index picks
-- would silently crown the wrong brainrots. anchorY is the chip
-- anchor height from the verified projection above; height is
-- the factory model height (accessories included) and only
-- sizes the rarity beam.
local CAST = {
	{ name = "Pebble Penguin", rarity = "Common", tier = 1, x = -17.5, z = 5.5, anchorY = 6.0, height = 5.1 },
	{ name = "Barbecue Bat", rarity = "Uncommon", tier = 1, x = 0, z = 5.5, anchorY = 6.0, height = 4.0 },
	{ name = "Crispy Capybara", rarity = "Rare", tier = 1, x = 17.5, z = 5.5, anchorY = 6.0, height = 5.6 },
	{ name = "Magma Mariachi Band", rarity = "Epic", tier = 2, x = -18, z = 0.5, anchorY = 11.6, height = 6.0 },
	{ name = "Basalt Basilisk", rarity = "Legendary", tier = 2, x = 0, z = 0.5, anchorY = 12.2, height = 6.1 },
	{ name = "Magma Core Dragon", rarity = "Mythic", tier = 2, x = 18, z = 0.5, anchorY = 11.6, height = 8.0 },
	{ name = "The Grillfather", rarity = "Mythic", tier = 3, x = -16, z = -3, anchorY = 17.4, height = 6.7 },
	{ name = "DO NOT FEED HIM", rarity = "Secret", tier = 3, x = 0, z = -3, anchorY = 17.8, height = 9.1, champion = true },
	{ name = "Sentient Lava Lamp", rarity = "Secret", tier = 3, x = 16, z = -3, anchorY = 17.4, height = 8.0 },
}

--====================================================================--
-- Small builders (local CFrames in, world CFrames out via ROOT;
-- Main's conventions: parts default collidable, decor opts out)
--====================================================================--

local function makePart(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = ROOT * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = showcase
	return p
end

local function makeDisc(name, radius, height, cf, color, material)
	local p = makePart(name, Vector3.new(height, radius * 2, radius * 2), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	-- Cylinder parts lie on their X axis; tip upright.
	p.CFrame = ROOT * cf * CFrame.Angles(0, 0, math.rad(90))
	return p
end

-- A sagging pennant string between two local points: small flags
-- hung along a quadratic bezier, tilted with the string.
local PENNANT_COLORS = {
	Color3.fromRGB(255, 92, 84), Color3.fromRGB(255, 196, 64),
	Color3.fromRGB(64, 200, 220), Color3.fromRGB(140, 230, 120),
	Color3.fromRGB(255, 130, 200),
}
local function pennantString(a, b, count, sag)
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	for i = 1, count do
		local t = i / (count + 1)
		local p = (1 - t) ^ 2 * a + 2 * (1 - t) * t * mid + t ^ 2 * b
		local d = 2 * (1 - t) * (mid - a) + 2 * t * (b - mid)
		local tilt = math.atan2(d.Y, d.X)
		makePart("Pennant", Vector3.new(0.95, 1.1, 0.08),
			CFrame.new(p - Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, 0, tilt),
			PENNANT_COLORS[(i % #PENNANT_COLORS) + 1], Enum.Material.SmoothPlastic)
	end
end

local function makeCoinPile(x, baseY, z)
	for i = 1, 6 do
		local a = i * 2.4
		local r = (i % 3) * 0.45
		local coin = makeDisc("CoinPile", 0.55, 0.16,
			CFrame.new(x + math.cos(a) * r, baseY + 0.1 + (i % 2) * 0.14, z + math.sin(a) * r),
			GOLD, Enum.Material.Metal)
		coin.CanCollide = false
	end
	local heap = makeDisc("CoinHeap", 1.15, 0.5, CFrame.new(x, baseY + 0.25, z), GOLD_DARK, Enum.Material.Metal)
	heap.CanCollide = false
	local top = makeDisc("CoinTop", 0.6, 0.18, CFrame.new(x, baseY + 0.56, z), GOLD, Enum.Material.Neon)
	top.CanCollide = false
end

local function makeLamp(x, baseY, z)
	makePart("LampPost", Vector3.new(0.4, 5.2, 0.4), CFrame.new(x, baseY + 2.6, z),
		Color3.fromRGB(44, 40, 44), Enum.Material.Metal)
	local orb = makePart("LampOrb", Vector3.new(1.15, 1.15, 1.15), CFrame.new(x, baseY + 5.6, z),
		Color3.fromRGB(255, 225, 160), Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Name = "LampGlow"
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Brightness = 1.6
	light.Range = 20
	light.Parent = orb
end

local function makeChest(x, baseY, z)
	makePart("ChestBase", Vector3.new(2.6, 1.3, 1.8), CFrame.new(x, baseY + 0.65, z),
		Color3.fromRGB(110, 72, 40), Enum.Material.Wood)
	makePart("ChestLid", Vector3.new(2.6, 0.55, 1.8),
		CFrame.new(x, baseY + 1.55, z) * CFrame.Angles(-0.5, 0, 0),
		Color3.fromRGB(128, 84, 46), Enum.Material.Wood)
	makePart("ChestBand", Vector3.new(2.7, 0.3, 1.9), CFrame.new(x, baseY + 1.28, z),
		GOLD_DARK, Enum.Material.Metal)
	local glow = makePart("ChestGlow", Vector3.new(2.2, 0.18, 1.4), CFrame.new(x, baseY + 1.32, z),
		GOLD, Enum.Material.Neon)
	glow.CanCollide = false
end

--====================================================================--
-- The ground steps: NO raised slab (user, 2026-11-20 — the tall
-- dark platform and its front steps are gone). Two broad steps
-- in Plot 8's exact footprint climb from the beach to the plinth
-- floor, finished like the tiers themselves — basalt bodies, red
-- carpet treads, gold edge trim — so the stepped red/gold
-- pyramid runs unbroken from the sand to the top tier. A red
-- runner with gold strips marks the centre walkway, and lava
-- torches stand at the first step's front corners.
--====================================================================--

makePart("GroundStep1", Vector3.new(46, 1.2, 32), CFrame.new(0, STEP1_TOP - 0.6, 0),
	BASALT_LIGHT, Enum.Material.Slate)
makePart("GroundStep2", Vector3.new(44.5, 1.2, 27), CFrame.new(0, STEP2_TOP - 0.6, -1.5),
	BASALT_LIGHT, Enum.Material.Slate)
local step1Carpet = makePart("Step1Carpet", Vector3.new(44, 0.1, 30), CFrame.new(0, STEP1_TOP + 0.05, 0),
	CARPET_RED, Enum.Material.Fabric)
step1Carpet.Transparency = 0.5
step1Carpet.CanCollide = false
local step2Carpet = makePart("Step2Carpet", Vector3.new(44.5, 0.1, 3.25),
	CFrame.new(0, STEP2_TOP + 0.05, 10.4), CARPET_RED, Enum.Material.Fabric)
step2Carpet.Transparency = 0.5
step2Carpet.CanCollide = false
makePart("Step1TrimF", Vector3.new(46.6, 0.4, 0.5), CFrame.new(0, STEP1_TOP + 0.1, 15.9), GOLD, Enum.Material.Neon)
makePart("Step1TrimL", Vector3.new(0.5, 0.4, 32.6), CFrame.new(-23, STEP1_TOP + 0.1, 0), GOLD, Enum.Material.Neon)
makePart("Step1TrimR", Vector3.new(0.5, 0.4, 32.6), CFrame.new(23, STEP1_TOP + 0.1, 0), GOLD, Enum.Material.Neon)
makePart("Step2TrimF", Vector3.new(45.1, 0.4, 0.5), CFrame.new(0, STEP2_TOP + 0.1, 11.9), GOLD, Enum.Material.Neon)
local runner1 = makePart("Runner", Vector3.new(10, 0.12, 4), CFrame.new(0, STEP1_TOP + 0.06, 14),
	CARPET_RED, Enum.Material.Fabric)
runner1.CanCollide = false
local runner2 = makePart("Runner", Vector3.new(10, 0.12, 3.25), CFrame.new(0, STEP2_TOP + 0.06, 10.4),
	CARPET_RED, Enum.Material.Fabric)
runner2.CanCollide = false
for _, s in ipairs({ -1, 1 }) do
	local strip1 = makePart("RunnerTrim", Vector3.new(0.3, 0.12, 4),
		CFrame.new(s * 4.85, STEP1_TOP + 0.06, 14), GOLD, Enum.Material.Neon)
	strip1.CanCollide = false
	local strip2 = makePart("RunnerTrim", Vector3.new(0.3, 0.12, 3.25),
		CFrame.new(s * 4.85, STEP2_TOP + 0.06, 10.4), GOLD, Enum.Material.Neon)
	strip2.CanCollide = false
	local torchPost = makePart("StepTorch", Vector3.new(0.35, 3.4, 0.35),
		CFrame.new(s * 21.5, STEP1_TOP + 1.7, 14), Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
	torchPost.CanCollide = false
	local flame = makePart("StepFlame", Vector3.new(0.95, 0.95, 0.95),
		CFrame.new(s * 21.5, STEP1_TOP + 3.75, 14), LAVA, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	flame.CanCollide = false
end

--====================================================================--
-- The stand: plinth + three terraced tiers, gold edges, lava
-- seams, side caps, carpets, a low back wall and two lava-cored
-- obelisks flanking the sign — density without clutter.
--====================================================================--

-- Every block runs from the ground (-6) up to its surface, so
-- the terraces read as one solid stepped pyramid — no floating
-- shelves, no blank wall faces.
makePart("Plinth", Vector3.new(44, PLINTH_TOP + 6, 17.5), CFrame.new(0, (PLINTH_TOP - 6) / 2, 0),
	BASALT_LIGHT, Enum.Material.Slate)
makePart("Tier1", Vector3.new(42, TIER_TOP[1] + 6, 7), CFrame.new(0, (TIER_TOP[1] - 6) / 2, 5.25), BASALT, Enum.Material.Slate)
makePart("Tier2", Vector3.new(43, TIER_TOP[2] + 6, 6.5), CFrame.new(0, (TIER_TOP[2] - 6) / 2, 0.5), BASALT, Enum.Material.Slate)
makePart("Tier3", Vector3.new(39, TIER_TOP[3] + 6, 6.5), CFrame.new(0, (TIER_TOP[3] - 6) / 2, -3), BASALT, Enum.Material.Slate)

makePart("Tier1Edge", Vector3.new(42, 0.4, 0.4), CFrame.new(0, TIER_TOP[1] - 0.05, 8.8), GOLD, Enum.Material.Neon)
makePart("Tier1CapL", Vector3.new(0.4, 0.35, 7), CFrame.new(-20.9, TIER_TOP[1] + 0.02, 5.25), GOLD, Enum.Material.Neon)
makePart("Tier1CapR", Vector3.new(0.4, 0.35, 7), CFrame.new(20.9, TIER_TOP[1] + 0.02, 5.25), GOLD, Enum.Material.Neon)
makePart("Tier1Seam", Vector3.new(42, 0.45, 0.25), CFrame.new(0, (PLINTH_TOP + TIER_TOP[1]) / 2, 8.78), LAVA, Enum.Material.Neon)
makePart("Tier2Edge", Vector3.new(43, 0.4, 0.4), CFrame.new(0, TIER_TOP[2] - 0.05, 3.8), GOLD, Enum.Material.Neon)
makePart("Tier2Seam", Vector3.new(43, 0.5, 0.25), CFrame.new(0, (TIER_TOP[1] + TIER_TOP[2]) / 2, 3.78), LAVA, Enum.Material.Neon)
makePart("Tier2CapL", Vector3.new(0.4, 0.35, 6.5), CFrame.new(-21.4, TIER_TOP[2] + 0.02, 0.5), GOLD, Enum.Material.Neon)
makePart("Tier2CapR", Vector3.new(0.4, 0.35, 6.5), CFrame.new(21.4, TIER_TOP[2] + 0.02, 0.5), GOLD, Enum.Material.Neon)
makePart("Tier3Edge", Vector3.new(39, 0.4, 0.4), CFrame.new(0, TIER_TOP[3] - 0.05, 0.3), GOLD, Enum.Material.Neon)
makePart("Tier3Seam", Vector3.new(39, 0.5, 0.25), CFrame.new(0, (TIER_TOP[2] + TIER_TOP[3]) / 2, 0.28), LAVA, Enum.Material.Neon)
makePart("Tier3CapL", Vector3.new(0.4, 0.35, 6.5), CFrame.new(-19.4, TIER_TOP[3] + 0.02, -3), GOLD, Enum.Material.Neon)
makePart("Tier3CapR", Vector3.new(0.4, 0.35, 6.5), CFrame.new(19.4, TIER_TOP[3] + 0.02, -3), GOLD, Enum.Material.Neon)

-- Red carpets with gold edge strips under each row of stands.
local function carpet(cx, topY, cz, w, d)
	local c = makePart("Carpet", Vector3.new(w, 0.1, d), CFrame.new(cx, topY + 0.05, cz), CARPET_RED, Enum.Material.Fabric)
	c.CanCollide = false
	for _, s in ipairs({ -1, 1 }) do
		local strip = makePart("CarpetTrim", Vector3.new(w, 0.12, 0.3),
			CFrame.new(cx, topY + 0.06, cz + s * (d / 2 - 0.15)), GOLD, Enum.Material.Neon)
		strip.CanCollide = false
	end
end
carpet(0, TIER_TOP[1], 5.5, 40, 6.2)
carpet(0, TIER_TOP[2], 0.5, 41, 5.6)
carpet(0, TIER_TOP[3], -3, 36.5, 5.6)

-- Low back wall with a gold rail, closing the stage's sea side.
makePart("BackWall", Vector3.new(36, 3.2, 0.7), CFrame.new(0, PLINTH_TOP + 1.6, -8.3), BASALT, Enum.Material.Slate)
makePart("BackWallRail", Vector3.new(36.4, 0.35, 0.95), CFrame.new(0, PLINTH_TOP + 3.35, -8.3), GOLD, Enum.Material.Neon)

-- Obelisks on the top tier's back corners: basalt shafts, lava
-- cores facing the photo spot, gold tips — skyline against the sea.
for _, s in ipairs({ -1, 1 }) do
	makePart("Obelisk", Vector3.new(1.6, 9, 1.6), CFrame.new(s * 14.5, TIER_TOP[3] + 4.5, -6.05),
		BASALT, Enum.Material.Slate)
	local core = makePart("ObeliskCore", Vector3.new(0.5, 6.5, 0.15),
		CFrame.new(s * 14.5, TIER_TOP[3] + 3.9, -5.18), LAVA, Enum.Material.Neon)
	core.CanCollide = false
	local tip = makePart("ObeliskTip", Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(s * 14.5, TIER_TOP[3] + 9.55, -6.05), GOLD, Enum.Material.Neon)
	tip.Shape = Enum.PartType.Ball
	tip.CanCollide = false
end

--====================================================================--
-- Header sign: board on two posts BEHIND the champion, face to
-- the photo spot. Gold Luckiest Guy title (the game's title font)
-- with a dark stroke, GothamBold subline, neon halo trim, giant
-- gold coins at both ends, a pennant swag beneath it and
-- diagonals down to the obelisk tips; the canopy (next section)
-- crowns it from above. Its lowest text clears the champion's
-- chip with room to spare at every photo distance.
--====================================================================--

for _, s in ipairs({ -1, 1 }) do
	makePart("SignPost", Vector3.new(0.9, 29.0, 0.9), CFrame.new(s * 7.5, PLINTH_TOP + 14.5, SIGN_Z),
		Color3.fromRGB(44, 40, 44), Enum.Material.Metal)
	makePart("SignCollar", Vector3.new(1.2, 0.5, 1.2), CFrame.new(s * 7.5, SIGN_Y - 3.5, SIGN_Z),
		GOLD, Enum.Material.Neon)
end

local boardCf = CFrame.lookAt(Vector3.new(0, SIGN_Y, SIGN_Z), Vector3.new(0, SIGN_Y, SIGN_Z + 10))
local board = makePart("SignBoard", Vector3.new(24, SIGN_H, 0.45), boardCf,
	Color3.fromRGB(24, 20, 26), Enum.Material.SmoothPlastic)
makePart("SignTrimTop", Vector3.new(24.7, 0.36, 0.3), boardCf * CFrame.new(0, SIGN_H / 2 - 0.18, -0.28), GOLD, Enum.Material.Neon)
makePart("SignTrimBottom", Vector3.new(24.7, 0.36, 0.3), boardCf * CFrame.new(0, -(SIGN_H / 2 - 0.18), -0.28), GOLD, Enum.Material.Neon)
makePart("SignTrimL", Vector3.new(0.36, SIGN_H + 0.7, 0.3), boardCf * CFrame.new(-(24 / 2 - 0.18), 0, -0.28), GOLD, Enum.Material.Neon)
makePart("SignTrimR", Vector3.new(0.36, SIGN_H + 0.7, 0.3), boardCf * CFrame.new(24 / 2 - 0.18, 0, -0.28), GOLD, Enum.Material.Neon)
for _, s in ipairs({ -1, 1 }) do
	local coin = makePart("BoardCoin", Vector3.new(0.3, 3.4, 3.4),
		CFrame.new(s * 8.8, SIGN_Y, SIGN_Z + 0.38) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal)
	coin.Shape = Enum.PartType.Cylinder
	local inner = makePart("BoardCoinInner", Vector3.new(0.34, 2.5, 2.5),
		CFrame.new(s * 8.8, SIGN_Y, SIGN_Z + 0.38) * CFrame.Angles(0, math.rad(90), 0), GOLD_DARK, Enum.Material.Metal)
	inner.Shape = Enum.PartType.Cylinder
end

local signGui = Instance.new("SurfaceGui")
signGui.Name = "SignText"
signGui.Face = Enum.NormalId.Front
signGui.LightInfluence = 0
signGui.Parent = board
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0.07, 0, 0.05, 0)
title.Size = UDim2.new(0.86, 0, 0.60, 0)
title.Font = Enum.Font.LuckiestGuy
title.Text = "MAGMA SHOWCASE"
title.TextColor3 = GOLD
title.TextStrokeColor3 = Color3.fromRGB(20, 12, 4)
title.TextStrokeTransparency = 0.25
title.TextScaled = true
title.Parent = signGui
local sub = Instance.new("TextLabel")
sub.Name = "Subline"
sub.BackgroundTransparency = 1
sub.Position = UDim2.new(0.07, 0, 0.67, 0)
sub.Size = UDim2.new(0.86, 0, 0.28, 0)
sub.Font = Enum.Font.GothamBold
sub.Text = "TOP EARNERS OF THE VOLCANO"
sub.TextColor3 = Color3.fromRGB(255, 240, 210)
sub.TextScaled = true
sub.Parent = signGui

pennantString(Vector3.new(-7.5, SIGN_Y - 3.4, SIGN_Z), Vector3.new(7.5, SIGN_Y - 3.4, SIGN_Z), 5, 0.7)
pennantString(Vector3.new(-7.5, SIGN_Y - 3.5, SIGN_Z), Vector3.new(-14.5, TIER_TOP[3] + 9.2, SIGN_Z), 5, 0.5)
pennantString(Vector3.new(7.5, SIGN_Y - 3.5, SIGN_Z), Vector3.new(14.5, TIER_TOP[3] + 9.2, SIGN_Z), 5, 0.5)

--====================================================================--
-- The canopy (tudung): a stepped pavilion roof over the whole
-- stand — the user's "tudung yang megah". Four posts rise from
-- the plinth corners to a three-tier red roof with gold trim;
-- the tiers step back like the podium below them. Orb lamps
-- hang under the front eave and pennant swags dress the front
-- and sides, so the photo spot frames a crowned stage instead
-- of a bare stack of terraces.
--====================================================================--

local ROOF_RED = Color3.fromRGB(120, 32, 42)
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ 6.5, -7.5 }) do
		makePart("CanopyPost", Vector3.new(1.0, EAVE_Y - PLINTH_TOP, 1.0),
			CFrame.new(sx * 21.5, (PLINTH_TOP + EAVE_Y) / 2, sz),
			Color3.fromRGB(44, 40, 44), Enum.Material.Metal)
		makePart("CanopyCollar", Vector3.new(1.3, 0.5, 1.3), CFrame.new(sx * 21.5, EAVE_Y - 1.0, sz),
			GOLD, Enum.Material.Neon)
		makePart("CanopyBase", Vector3.new(1.4, 0.9, 1.4), CFrame.new(sx * 21.5, PLINTH_TOP + 0.45, sz),
			BASALT, Enum.Material.Slate)
	end
end
makePart("RoofA", Vector3.new(47, 0.9, 20.5), CFrame.new(0, EAVE_Y + 0.45, -0.5), ROOF_RED, Enum.Material.SmoothPlastic)
makePart("RoofATrimF", Vector3.new(47.4, 0.35, 0.4), CFrame.new(0, EAVE_Y + 0.15, 9.85), GOLD, Enum.Material.Neon)
makePart("RoofATrimB", Vector3.new(47.4, 0.35, 0.4), CFrame.new(0, EAVE_Y + 0.15, -10.85), GOLD, Enum.Material.Neon)
makePart("RoofATrimL", Vector3.new(0.4, 0.35, 20.9), CFrame.new(-23.6, EAVE_Y + 0.15, -0.5), GOLD, Enum.Material.Neon)
makePart("RoofATrimR", Vector3.new(0.4, 0.35, 20.9), CFrame.new(23.6, EAVE_Y + 0.15, -0.5), GOLD, Enum.Material.Neon)
makePart("RoofB", Vector3.new(40, 0.9, 16), CFrame.new(0, EAVE_Y + 1.35, -0.5), ROOF_RED, Enum.Material.SmoothPlastic)
makePart("RoofBTrimF", Vector3.new(40.4, 0.35, 0.4), CFrame.new(0, EAVE_Y + 1.05, 7.6), GOLD, Enum.Material.Neon)
makePart("RoofCap", Vector3.new(30, 0.7, 11), CFrame.new(0, EAVE_Y + 2.15, -0.5), ROOF_RED, Enum.Material.SmoothPlastic)
makePart("RoofCapTrim", Vector3.new(30.4, 0.3, 0.4), CFrame.new(0, EAVE_Y + 2.0, 5.1), GOLD, Enum.Material.Neon)
for _, s in ipairs({ -1, 1 }) do
	local crown = makePart("RoofCrown", Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(s * 11, EAVE_Y + 2.7, -0.5), GOLD, Enum.Material.Neon)
	crown.Shape = Enum.PartType.Ball
	crown.CanCollide = false
end
for _, hx in ipairs({ -14, 0, 14 }) do
	local cord = makePart("LampCord", Vector3.new(0.12, 1.7, 0.12), CFrame.new(hx, EAVE_Y - 0.85, 8.8),
		Color3.fromRGB(44, 40, 44), Enum.Material.Metal)
	cord.CanCollide = false
	local orb = makePart("HangingOrb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(hx, EAVE_Y - 2.2, 8.8),
		Color3.fromRGB(255, 225, 160), Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Name = "HangingGlow"
	glow.Color = Color3.fromRGB(255, 200, 120)
	glow.Brightness = 1.4
	glow.Range = 16
	glow.Parent = orb
end
pennantString(Vector3.new(-21.5, EAVE_Y - 0.8, 6.5), Vector3.new(21.5, EAVE_Y - 0.8, 6.5), 15, 1.6)
pennantString(Vector3.new(-21.5, EAVE_Y - 0.8, 6.5), Vector3.new(-21.5, EAVE_Y - 0.8, -7.5), 7, 1.0)
pennantString(Vector3.new(21.5, EAVE_Y - 0.8, 6.5), Vector3.new(21.5, EAVE_Y - 0.8, -7.5), 7, 1.0)

--====================================================================--
-- The nine earners: dudukan stand, model, beam, chip
--====================================================================--

local function standRadius(def)
	local span = SHAPE_SPAN[def.shape] or 1.9
	return math.clamp(span / 2 * def.size * 1.4 + 0.25, 1.35, 2.35)
end

-- The chip, deliberately built EXACTLY like the game's proven
-- overhead tags (Main's makeNameTag; the V3 showcase chip the user
-- verified in-game): only Name / Size / AlwaysOnTop / MaxDistance
-- / Parent on the BillboardGui, labels with a fixed TextSize +
-- TextScaled. A previous version set StudsOffsetWorld /
-- LightInfluence / Adornee before parenting and capped text via
-- a TextBounds signal; the build died inside the first entry's
-- chip step and the uncaught error took the whole cast with it.
local function buildChip(rarityName, def, anchor)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShowcaseChip"
	gui.Size = UDim2.fromOffset(152, 54)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 110
	gui.Parent = anchor

	local rarityInfo = Brainrots.Rarities[rarityName]
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Size = UDim2.new(1, 0, 1, 0)
	tile.BackgroundColor3 = Color3.fromRGB(16, 13, 18)
	tile.BackgroundTransparency = 0.35
	tile.BorderSizePixel = 0
	tile.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = tile
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = tile
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = tile

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.44)
	nameLabel.Position = UDim2.fromScale(0, 0)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 16
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.TextColor3 = rarityInfo.color
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.TextStrokeColor3 = Color3.fromRGB(15, 12, 14)
	nameLabel.Text = def.name
	nameLabel.Parent = tile

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Size = UDim2.fromScale(1, 0.56)
	incomeLabel.Position = UDim2.fromScale(0, 0.44)
	incomeLabel.Font = Enum.Font.GothamBlack
	incomeLabel.TextSize = 22
	incomeLabel.TextScaled = true
	incomeLabel.TextWrapped = true
	incomeLabel.TextColor3 = INCOME_GREEN
	incomeLabel.TextStrokeTransparency = 0.35
	incomeLabel.TextStrokeColor3 = Color3.fromRGB(15, 12, 14)
	incomeLabel.Text = Brainrots.FormatMoney(def.rate) .. "/s"
	incomeLabel.Parent = tile

	return gui
end

local buildFailures = {}
for _, entry in ipairs(CAST) do
	-- Each entry builds inside a pcall: one bad entry must never
	-- again kill the whole cast (see the audit after the loop).
	local ok, err = pcall(function()
	local def = Brainrots.ByName[entry.name]
	assert(def and def.rarity == entry.rarity, "Showcase: cast entry mismatch for " .. entry.name)
	local tierTop = TIER_TOP[entry.tier]
	local rarityInfo = Brainrots.Rarities[entry.rarity]
	local isChampion = entry.champion == true
	local standR = standRadius(def)
	local rimColor = isChampion and GOLD or rarityInfo.beam

	-- Dudukan, mirroring the player-plot pedestals: a neon flange
	-- ring at the base, a slate drum, and a rim on top in the
	-- model's rarity colour (gold for the champion).
	local flange = makeDisc("StandFlange", standR + 0.65, 0.22,
		CFrame.new(entry.x, tierTop + 0.11, entry.z), rimColor, Enum.Material.Neon)
	flange.CanCollide = false
	local drum = makeDisc("Stand", standR, 0.68,
		CFrame.new(entry.x, tierTop + 0.56, entry.z), STAND_SLATE, Enum.Material.Slate)
	local rim = makeDisc("StandRim", standR + 0.18, 0.2,
		CFrame.new(entry.x, tierTop + 1.0, entry.z), rimColor, Enum.Material.Neon)
	rim.CanCollide = false

	-- The model itself, factory-built, facing the photo spot.
	local modelBase = tierTop + STAND_H
	local model = Brainrots.BuildBrainrotModel(def, nil)
	local basePos = (ROOT * CFrame.new(entry.x, modelBase, entry.z)).Position
	local facePos = (ROOT * CFrame.new(entry.x, modelBase, entry.z + 10)).Position
	model:PivotTo(CFrame.lookAt(basePos, facePos))
	model.Parent = showcase
	local label = model:FindFirstChild("BrainrotLabel", true)
	if label then
		label.Enabled = false
	end

	-- Rarity beam around the model, crowning it. The champion's
	-- beam is grander, starts at the tier top (engulfing the
	-- stand), carries a gold ring, orbs, sparkles and a light;
	-- the runner-up Secret gets sparkles of its own.
	local beamH = isChampion and 10.5 or (entry.height + 1.2)
	local beamBase = isChampion and (modelBase - STAND_H) or modelBase
	local beamR = standR + (isChampion and 0.6 or 0.55)
	local beam = makeDisc("Beam", beamR, beamH,
		CFrame.new(entry.x, beamBase + beamH / 2, entry.z),
		isChampion and GOLD or rarityInfo.beam, Enum.Material.Neon)
	beam.Transparency = isChampion and 0.5 or 0.8
	beam.CanCollide = false
	if isChampion then
		local ring = makeDisc("ChampionRing", standR + 0.85, 0.12,
			CFrame.new(entry.x, tierTop + 0.13, entry.z), GOLD, Enum.Material.Neon)
		ring.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Name = "ChampionGlow"
		glow.Color = GOLD
		glow.Brightness = 1.8
		glow.Range = 18
		glow.Parent = beam
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "ChampionSparkles"
		sparkles.SparkleColor = GOLD
		sparkles.Parent = drum
		for _, s in ipairs({ -1, 1 }) do
			local orb = makePart("ChampionOrb", Vector3.new(1.1, 1.1, 1.1),
				CFrame.new(entry.x + s * 4.3, tierTop + 0.55, entry.z + 2.25), GOLD, Enum.Material.Neon)
			orb.Shape = Enum.PartType.Ball
			orb.CanCollide = false
		end
	elseif entry.rarity == "Secret" then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "SecretSparkles"
		sparkles.SparkleColor = rarityInfo.beam
		sparkles.Parent = drum
	end

	-- The chip, on its own invisible anchored anchor part.
	local anchor = makePart("ChipAnchor", Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(entry.x, entry.anchorY, entry.z), BASALT, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanCollide = false
	buildChip(entry.rarity, def, anchor)
	end)
	if not ok then
		table.insert(buildFailures, entry.name .. " -> " .. tostring(err))
	end
end

-- Post-build audit: every cast entry must have produced exactly
-- one model and one chip in the folder. Any shortfall warns
-- LOUDLY, naming each failed entry and its error, instead of
-- silently shipping a half-empty podium.
local placedModels, placedChips = 0, 0
for _, child in ipairs(showcase:GetDescendants()) do
	if child:IsA("Model") then
		placedModels += 1
	elseif child:IsA("BillboardGui") and child.Name == "ShowcaseChip" then
		placedChips += 1
	end
end
if #buildFailures > 0 or placedModels ~= #CAST or placedChips ~= #CAST then
	warn(("[Showcase] AUDIT FAILED: %d/%d models, %d/%d chips placed. Failures: %s"):format(
		placedModels, #CAST, placedChips, #CAST,
		#buildFailures > 0 and table.concat(buildFailures, " | ") or "none recorded"))
end

--====================================================================--
-- Dressing: coin piles, treasure chests, lamps, orb standards,
-- finials — packed into every gap the tiers leave.
--====================================================================--

makeCoinPile(-8.75, TIER_TOP[1], 5.5)
makeCoinPile(8.75, TIER_TOP[1], 5.5)
makeCoinPile(-9, TIER_TOP[2], 0.5)
makeCoinPile(9, TIER_TOP[2], 0.5)
makeCoinPile(0, PLINTH_TOP, -7.1)
makeChest(-20.3, PLINTH_TOP, -7.5)
makeChest(20.3, PLINTH_TOP, -7.5)
makeChest(-13, STEP1_TOP, 13.2)
makeChest(13, STEP1_TOP, 13.2)
makeLamp(-20.3, TIER_TOP[1], 8.3)
makeLamp(20.3, TIER_TOP[1], 8.3)
for _, s in ipairs({ -1, 1 }) do
	makePart("OrbPost", Vector3.new(0.35, 6.5, 0.35), CFrame.new(s * 21.9, PLINTH_TOP + 3.25, 3.5),
		Color3.fromRGB(44, 40, 44), Enum.Material.Metal)
	local orb = makePart("OrbTop", Vector3.new(1.05, 1.05, 1.05), CFrame.new(s * 21.9, PLINTH_TOP + 6.9, 3.5),
		Color3.fromRGB(255, 225, 160), Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	local finial = makePart("Finial", Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(s * 21.2, TIER_TOP[2] + 0.4, 3.45), GOLD, Enum.Material.Neon)
	finial.Shape = Enum.PartType.Ball
	finial.CanCollide = false
end

--====================================================================--
-- Photo-spot medallion: a radial gold-and-lava sun on the beach
-- in front of the podium — stand here, face the showcase: the
-- crowned podium fills the frame alone (the market quarter sits
-- far along the north shore, out of the shot).
-- (Local Y is negative: the medallion lies on the beach at world
-- y~0, six studs below the old plot top this frame is anchored to.)
--====================================================================--

local function medalDisc(name, radius, height, y, color, material)
	local p = makeDisc(name, radius, height, CFrame.new(0, y, MEDAL_Z), color, material)
	p.CanCollide = false
	return p
end
medalDisc("MedallionGold", 8, 0.16, -5.92, GOLD, Enum.Material.Neon)
medalDisc("MedallionBasalt", 6.8, 0.14, -5.8, BASALT, Enum.Material.Slate)
medalDisc("MedallionLava", 4, 0.14, -5.7, LAVA, Enum.Material.Neon)
medalDisc("MedallionCore", 2.6, 0.14, -5.6, GOLD, Enum.Material.Neon)
for i = 0, 7 do
	local a = (i / 8) * math.pi * 2
	local spoke = makePart("MedallionSpoke", Vector3.new(0.5, 0.1, 2.2),
		CFrame.new(math.cos(a) * 5.4, -5.7, MEDAL_Z + math.sin(a) * 5.4) * CFrame.Angles(0, -a + math.pi / 2, 0),
		GOLD, Enum.Material.Neon)
	spoke.CanCollide = false
end

print("[Showcase] MAGMA SHOWCASE podium built on retired Plot 8 (9 earners, champion: "
	.. Brainrots.ByName["DO NOT FEED HIM"].name .. ").")
