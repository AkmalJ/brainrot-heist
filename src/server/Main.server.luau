--[[
	Main.server.luau — MAGMA MAYHEM: Brainrot Volcano, server bootstrap.

	Paste target: a Script named "Main" in ServerScriptService.

	This script does three jobs and no more:
	  1. BOOTSTRAP — the self-healing place setup, the MagmaRemotes
	     folder the client contract is built on, and the one central
	     Game context (world data + per-player State store) that every
	     server module shares.
	  2. WORLD BUILDING — the whole volcanic island from plain parts:
	     volcano with animated lava, the obsidian parade ring, three
	     lava pools, three zones, eight player base plots, three rival
	     NPC bases, Chief Magma's quest post and the shop plaza.
	  3. WIRING — requires Economy / Conveyor / Thieves / Eruption /
	     Progression and calls their Init(Game) in dependency order.

	All gameplay rules live in those modules; all catalogue data lives
	in ReplicatedStorage (Brainrots, Upgrades). No DataStore: a session
	is a fresh eruption. Everything is server-authoritative.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))
local Upgrades = require(ReplicatedStorage:WaitForChild("Upgrades"))

--====================================================================--
-- Self-healing place setup (kept from Brainrot Heist v2.1, proven):
-- characters auto-load on join, and the starter ground (Baseplate,
-- SpawnLocation, terrain) is cleared so it cannot sit above the
-- procedural world's ground plane and bury it. Runs before any world
-- building, so no manual place settings are ever needed. Terrain is a
-- BasePart that cannot be Destroy()ed; it is emptied via Clear().
--====================================================================--

Players.CharacterAutoLoads = true
Workspace.Terrain:Clear()
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("BasePart") and child ~= Workspace.Terrain then
		child:Destroy()
	end
end

--====================================================================--
-- Look of the island: bright tropical midday, saturated colour, neon
-- glow trims popping against a cyan sky — the grade the competition's
-- top sheets all share (STUDY-TOP5-VISUAL.md). Set in code so every
-- place that hosts the game gets the same look.
--====================================================================--

Lighting.ClockTime = 13.4
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(178, 205, 235)
Lighting.OutdoorAmbient = Color3.fromRGB(168, 198, 232)
Lighting.GlobalShadows = true
Lighting.FogColor = Color3.fromRGB(178, 224, 248)
Lighting.FogStart = 420
Lighting.FogEnd = 1400
Lighting.EnvironmentDiffuseScale = 0.7
Lighting.EnvironmentSpecularScale = 0.8

-- Post/sky dressing, rebuilt fresh each run so re-running this script
-- never stacks duplicates: a thin bright Atmosphere for depth, a mild
-- SunRays for cheer, and a gentle Bloom so the Neon trims glow.
for _, fxName in ipairs({ "MagmaAtmosphere", "MagmaSunRays", "MagmaBloom" }) do
	local old = Lighting:FindFirstChild(fxName)
	if old then
		old:Destroy()
	end
end
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "MagmaAtmosphere"
atmosphere.Density = 0.18
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(196, 230, 252)
atmosphere.Decay = Color3.fromRGB(255, 214, 170)
atmosphere.Glare = 0.35
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting
local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "MagmaSunRays"
sunRays.Intensity = 0.06
sunRays.Spread = 0.8
sunRays.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "MagmaBloom"
bloom.Intensity = 0.35
bloom.Size = 28
bloom.Threshold = 0.85
bloom.Parent = Lighting

--====================================================================--
-- Small building helpers
--====================================================================--

local world = Instance.new("Folder")
world.Name = "MagmaWorld"
world.Parent = Workspace

local actors = Instance.new("Folder")
actors.Name = "MagmaActors"
actors.Parent = Workspace

-- An anchored part with smooth faces. Collidable unless told otherwise.
local function makePart(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A flat cylinder (disc) standing upright: Roblox cylinders lie on
-- their X axis, so rotate 90 degrees around Z to stand one up.
local function makeDisc(parent, name, radius, height, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeLabel(parent, name, text, size, position, font, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = true
	l.TextStrokeTransparency = 0.55
	l.TextStrokeColor3 = Color3.fromRGB(24, 14, 12)
	l.Parent = parent
	return l
end

-- A SurfaceGui sign face on an existing part (its Front, -Z, face).
-- Returns (titleLabel, subLabel) so callers can rewrite the text.
local function attachSign(part, titleText, subText, titleColor, titleSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.Parent = part
	local title = makeLabel(gui, "Title", titleText,
		UDim2.fromScale(1, subText and 0.58 or 1), UDim2.fromScale(0, 0),
		Enum.Font.GothamBlack, titleSize or 44, titleColor or Color3.fromRGB(255, 240, 220))
	local sub = nil
	if subText then
		sub = makeLabel(gui, "Sub", subText,
			UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.58),
			Enum.Font.GothamBold, 26, Color3.fromRGB(255, 214, 170))
	end
	return title, sub
end

-- A framed totem sign: dark board, Neon trim, two wooden posts. The
-- board's Front face looks at `lookAtPoint`. Returns (title, sub).
local function makeSignPost(parent, position, lookAtPoint, w, h, titleText, subText, trimColor)
	local cf = CFrame.lookAt(position, Vector3.new(lookAtPoint.X, position.Y, lookAtPoint.Z))
	local g = Instance.new("Model")
	g.Name = "Sign_" .. titleText:sub(1, 12)
	g.Parent = parent
	-- Posts run from the ground (local Y = -position.Y) to the board top.
	local postLen = position.Y + h / 2
	for _, px in ipairs({ -w / 2 + 0.4, w / 2 - 0.4 }) do
		makePart(g, "Post", Vector3.new(0.45, postLen, 0.45),
			cf * CFrame.new(px, (h / 2 - position.Y) / 2, 0),
			Color3.fromRGB(96, 66, 44), Enum.Material.Wood)
	end
	local board = makePart(g, "Board", Vector3.new(w, h, 0.4), cf, Color3.fromRGB(38, 30, 30), Enum.Material.Wood)
	makePart(g, "TrimTop", Vector3.new(w + 0.3, 0.28, 0.5), cf * CFrame.new(0, h / 2, 0), trimColor or Color3.fromRGB(255, 120, 50), Enum.Material.Neon)
	makePart(g, "TrimBottom", Vector3.new(w + 0.3, 0.28, 0.5), cf * CFrame.new(0, -h / 2, 0), trimColor or Color3.fromRGB(255, 120, 50), Enum.Material.Neon)
	return attachSign(board, titleText, subText)
end

--====================================================================--
-- Remotes — the client contract. Folder "MagmaRemotes" in
-- ReplicatedStorage; Builder B's client builds against exactly these.
--====================================================================--

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "MagmaRemotes"
remotesFolder.Parent = ReplicatedStorage

local function makeRemote(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotesFolder
	return r
end

local Remotes = {
	-- client -> server (fire-and-forget; the server validates all)
	BuyBrainrot = makeRemote("RemoteEvent", "BuyBrainrot"), -- (paradeId)
	CollectCash = makeRemote("RemoteEvent", "CollectCash"),
	BuyUpgrade = makeRemote("RemoteEvent", "BuyUpgrade"), -- (trackName, tier)
	DoRekindle = makeRemote("RemoteEvent", "DoRekindle"),
	ToggleLock = makeRemote("RemoteEvent", "ToggleLock"),
	ClaimQuest = makeRemote("RemoteEvent", "ClaimQuest"),
	RerollMutation = makeRemote("RemoteEvent", "RerollMutation"), -- (pedestalIndex)
	-- server -> client
	HudUpdate = makeRemote("RemoteEvent", "HudUpdate"), -- (stateTable)
	Toast = makeRemote("RemoteEvent", "Toast"), -- (title, body, kind)
	-- client -> server -> client
	GetIndexState = makeRemote("RemoteFunction", "GetIndexState"),
}

--====================================================================--
-- The Game context: one table every server module shares. World data
-- is filled by the builders below; State is THE per-player store —
-- one entry per player, created on join, destroyed on leave.
--====================================================================--

local Game = {
	Remotes = Remotes,
	State = {}, -- [Player] = playerState (see NewPlayerState)
	Plots = {}, -- player base plots, filled by BuildPlayerBases
	RivalBases = {}, -- rival NPC bases, filled by BuildRivalBases
	Pools = {}, -- lava pools (wild-catch zones)
	ShopPads = {}, -- [trackName] = pad Part
	Parade = { center = Vector3.new(0, 0, 0), radius = 72, y = 1.05 },
	Flood = { part = nil, baseY = -6, floodY = 3.4, safeY = 5.2, active = false },
	Zones = {
		["Ashen Beach"] = { unlockRebirth = 0 },
		["Obsidian Fields"] = { unlockRebirth = 1 },
		["Crater Rim"] = { unlockRebirth = 3 },
	},
	EventState = { name = "None", endsAt = 0, incomeMult = 1, mutationOddsMult = 1 },
	EruptionState = { phase = "calm", at = 0 },
	LooseItems = {}, -- dropped brainrots lying in the world
	Modules = {},
	WorldFolder = world,
	ActorsFolder = actors,
}

-- Toast helpers (the Toast remote): one for a player, one for all.
function Game.Toast(player, title, body, kind)
	Remotes.Toast:FireClient(player, title, body, kind or "info")
end

function Game.ToastAll(title, body, kind)
	Remotes.Toast:FireAllClients(title, body, kind or "info")
end

-- Balance mutators. Earning through income/collection counts toward
-- the lifetime total the quests read; quest rewards pass false.
function Game.AddCash(player, amount, countsAsEarned)
	local st = Game.State[player]
	if not st then
		return
	end
	st.cash += amount
	if countsAsEarned then
		st.lifetimeEarned += amount
	end
end

function Game.AddGems(player, amount)
	local st = Game.State[player]
	if not st then
		return
	end
	st.gems += amount
end

-- A fresh per-player state: THE one store for everything about a
-- player. Modules read and write this table, never their own copies.
local function NewPlayerState(player, plot)
	return {
		player = player,
		plot = plot,
		cash = Brainrots.StartingCash,
		gems = 0,
		lifetimeEarned = 0,
		rebirth = 0,
		multiplier = 1,
		pedestalsMax = Upgrades.BasePedestals,
		pedestals = {}, -- [index] = { defName, mutationName, accrued, model, prompt }
		upgrades = { ["Speed Boots"] = 0, ["Carry Harness"] = 0, ["Base Lock"] = 0, ["Luck Charm"] = 0 },
		lockState = "open", -- "open" | "locked" | "cooldown"
		lockEndsAt = 0,
		carried = nil, -- { defName, mutationName, model, source }
		discovered = {}, -- [brainrotName] = true
		ownedCounts = {}, -- [brainrotName] = count (placed + carried)
		indexMilestonesClaimed = {},
		zonesUnlocked = { ["Ashen Beach"] = true },
		questIndex = 1,
		lastZoneToastAt = 0,
		stats = {
			bought = 0, wildCaught = 0, placedTotal = 0, maxPlaced = 0,
			mutatedPlaced = 0, stoleBack = 0, rivalSteals = 0,
			eruptionsSurvived = 0, rekindles = 0, bestRarityOrder = 0,
		},
	}
end

--====================================================================--
-- WORLD BUILDING
--====================================================================--

-- Lava parts the animation loop pulses (crater lake, pools, lavafall).
local animatedLava = {}

local function BuildIslandGround()
	-- The sea first: one huge bright-cyan disc under everything, so a
	-- wide screenshot reads tropical ocean instead of empty void.
	local ocean = makeDisc(world, "Ocean", 720, 1.2, CFrame.new(0, -2.4, 0),
		Color3.fromRGB(38, 168, 235), Enum.Material.SmoothPlastic)
	ocean.CanCollide = false
	-- A white foam ring where the surf meets the shore.
	local foam = makeDisc(world, "ShoreFoam", 207, 0.5, CFrame.new(0, -1.55, 0),
		Color3.fromRGB(240, 252, 255), Enum.Material.SmoothPlastic)
	foam.CanCollide = false
	-- The island: one great ash disc, top surface at Y = 0, in a warm
	-- sunlit tone (bright grade — no more dusk grey).
	makeDisc(world, "Island", 200, 4, CFrame.new(0, -2, 0),
		Color3.fromRGB(150, 136, 128), Enum.Material.Slate)
	-- Sandy beach patches around the south shore.
	for _, patch in ipairs({
		{ 0, 168, 34 }, { -70, 140, 26 }, { 75, 138, 28 }, { -130, 95, 22 }, { 132, 92, 24 },
	}) do
		makeDisc(world, "Beach", patch[3], 0.5, CFrame.new(patch[1], 0.05, patch[2]),
			Color3.fromRGB(238, 202, 140), Enum.Material.Sand)
	end
	-- The eruption flood: a lava sheet that sleeps under the island
	-- (baseY) and rises over the lowlands when the volcano blows.
	local flood = makeDisc(world, "LavaFlood", 196, 1.2, CFrame.new(0, Game.Flood.baseY, 0),
		Color3.fromRGB(255, 96, 32), Enum.Material.Neon)
	flood.CanCollide = false
	flood.Transparency = 0.12
	Game.Flood.part = flood
end

-- The parade ring's rainbow: six saturated colours cycling segment to
-- segment, so the lane reads as a carnival track from any angle.
local RING_COLORS = {
	Color3.fromRGB(255, 92, 84), Color3.fromRGB(255, 196, 64), Color3.fromRGB(32, 201, 181),
	Color3.fromRGB(240, 92, 200), Color3.fromRGB(64, 156, 255), Color3.fromRGB(140, 230, 90),
}

local function BuildParadeRing()
	-- The rainbow parade ring: 28 saturated segments in a circle of
	-- radius 72 around the volcano. Conveyor marches the cast along it.
	local ring = Instance.new("Folder")
	ring.Name = "ParadeRing"
	ring.Parent = world
	for i = 0, 27 do
		local a = (i / 28) * math.pi * 2
		local pos = Vector3.new(math.cos(a) * Game.Parade.radius, 0.5, math.sin(a) * Game.Parade.radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0.5, 0))
		makePart(ring, "RingSegment", Vector3.new(11, 1, 16.5), cf,
			RING_COLORS[(i % #RING_COLORS) + 1], Enum.Material.SmoothPlastic)
		-- A Neon curb strip along the segment's outer edge: the glow
		-- line that carries the lane's colour at thumbnail scale.
		local curb = makePart(ring, "RingCurb", Vector3.new(11, 0.3, 1.2), cf * CFrame.new(0, 0.55, 7.6),
			RING_COLORS[((i + 2) % #RING_COLORS) + 1], Enum.Material.Neon)
		curb.CanCollide = false
	end
	-- Lamp posts ringing the parade, orbs cycling the same rainbow.
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.2
		local pos = Vector3.new(math.cos(a) * 86, 0, math.sin(a) * 86)
		makePart(ring, "RingLampPost", Vector3.new(0.4, 6.5, 0.4), CFrame.new(pos + Vector3.new(0, 3.25, 0)),
			Color3.fromRGB(70, 62, 66), Enum.Material.Metal)
		local orb = makePart(ring, "RingLampOrb", Vector3.new(1.15, 1.15, 1.15), CFrame.new(pos + Vector3.new(0, 6.9, 0)),
			RING_COLORS[(i % #RING_COLORS) + 1], Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		orb.CanCollide = false
	end
	-- Start gate: two posts + a banner where fresh brainrots march in.
	local gatePos = Vector3.new(0, 0, Game.Parade.radius)
	makeSignPost(world, gatePos + Vector3.new(0, 5.2, 6), Vector3.new(0, 5, 190), 13, 3.4,
		"BRAINROT PARADE", "Buy them before they march off!", Color3.fromRGB(255, 205, 60))
end

local function BuildVolcano()
	local volcano = Instance.new("Folder")
	volcano.Name = "Volcano"
	volcano.Parent = world
	-- A cone of six stacked discs, warm sunlit rock with basalt banding.
	local levels = {
		{ 60, 0, 10 }, { 48, 10, 22 }, { 38, 22, 34 },
		{ 29, 34, 46 }, { 22, 46, 57 }, { 17, 57, 67 },
	}
	for i, lv in ipairs(levels) do
		local color = (i % 2 == 0) and Color3.fromRGB(122, 98, 90) or Color3.fromRGB(146, 116, 102)
		makeDisc(volcano, "Cone", lv[1], lv[3] - lv[2], CFrame.new(0, (lv[2] + lv[3]) / 2, 0),
			color, Enum.Material.Slate)
	end
	-- Sandy terrace rings hugging two cone levels: bright bands that
	-- break the cone's silhouette into layered, sunlit steps.
	makeDisc(volcano, "TerraceLow", 40.5, 1.4, CFrame.new(0, 22.4, 0),
		Color3.fromRGB(232, 186, 124), Enum.Material.Sand)
	makeDisc(volcano, "TerraceHigh", 24.5, 1.4, CFrame.new(0, 46.4, 0),
		Color3.fromRGB(238, 198, 138), Enum.Material.Sand)
	-- Crater floor + the lava lake the whole island can see.
	makeDisc(volcano, "CraterFloor", 15.5, 1.5, CFrame.new(0, 66.6, 0),
		Color3.fromRGB(40, 34, 34), Enum.Material.Slate)
	local lake = makeDisc(volcano, "CraterLake", 11.5, 1, CFrame.new(0, 67.4, 0),
		Color3.fromRGB(255, 110, 36), Enum.Material.Neon)
	lake.CanCollide = false
	table.insert(animatedLava, lake)
	local glow = Instance.new("PointLight")
	glow.Name = "CraterGlow"
	glow.Color = Color3.fromRGB(255, 130, 50)
	glow.Brightness = 3
	glow.Range = 60
	glow.Parent = lake
	-- Crater smoke: a soft white plume drifting up off the lake, so
	-- the summit reads alive from every corner of the island.
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "CraterSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(245, 248, 250), Color3.fromRGB(205, 214, 222))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 7),
		NumberSequenceKeypoint.new(1, 20),
	})
	smoke.Lifetime = NumberRange.new(2.6, 4.2)
	smoke.Rate = 13
	smoke.Speed = NumberRange.new(6, 9.5)
	smoke.SpreadAngle = Vector2.new(16, 16)
	smoke.Acceleration = Vector3.new(0.6, 1.2, 0)
	-- The emitter hangs on an upright invisible vent above the lake:
	-- parented to the (rotated) lake disc itself it would spray
	-- sideways, since emitters fire along their parent's local Y.
	local vent = makePart(volcano, "SmokeVent", Vector3.new(1, 1, 1), CFrame.new(0, 68.4, 0),
		Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	vent.Transparency = 1
	vent.CanCollide = false
	smoke.Parent = vent
	-- Rim rocks, jutting like broken teeth.
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2 + 0.3
		local pos = Vector3.new(math.cos(a) * 16.5, 68.5, math.sin(a) * 16.5)
		makePart(volcano, "RimRock", Vector3.new(3.5, 3 + (i % 3), 3),
			CFrame.new(pos) * CFrame.Angles(0.3, a, 0.2), Color3.fromRGB(112, 94, 88), Enum.Material.Slate)
	end
	-- Lavafalls: neon sheets hugging all four slopes (the cone leans
	-- ~33 degrees; the sheets lean 27 and sit proud of it), so the
	-- lava reads from every side of the island, not just the south.
	for _, deg in ipairs({ 0, 90, 180, 270 }) do
		local fallCf = CFrame.Angles(0, math.rad(deg), 0)
			* CFrame.new(0, 36, 31) * CFrame.Angles(math.rad(-27), 0, 0)
		local fall = makePart(volcano, "Lavafall", Vector3.new(7, 52, 1.2), fallCf,
			Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
		fall.CanCollide = false
		table.insert(animatedLava, fall)
	end
end

local function BuildLavaPools()
	-- Three wild-catch pools, one per zone. The Fields and Rim pools
	-- sit on their plateaus (built in BuildZones, positions agreed here).
	local poolDefs = {
		{ name = "Beach Pool", pos = Vector3.new(-62, 0.35, 98), radius = 10, zone = "Ashen Beach", luck = 1 },
		{ name = "Fields Pool", pos = Vector3.new(-112, 8.35, -112), radius = 11, zone = "Obsidian Fields", luck = 1.5 },
		{ name = "Rim Pool", pos = Vector3.new(0, 30.35, -92), radius = 10, zone = "Crater Rim", luck = 2.5 },
	}
	for _, pd in ipairs(poolDefs) do
		-- A bright sand deck under each pool, so the lava sits in a
		-- dressed clearing instead of bare ground.
		local deck = makeDisc(world, "PoolDeck", pd.radius + 2.6, 0.35,
			CFrame.new(pd.pos.X, pd.pos.Y - 0.32, pd.pos.Z), Color3.fromRGB(238, 202, 140), Enum.Material.Sand)
		deck.CanCollide = false
		local poolPart = makeDisc(world, pd.name, pd.radius, 0.7,
			CFrame.new(pd.pos.X, pd.pos.Y, pd.pos.Z), Color3.fromRGB(255, 104, 34), Enum.Material.Neon)
		poolPart.CanCollide = false
		table.insert(animatedLava, poolPart)
		-- A ring of rocks keeps the lava politely in.
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			local rp = pd.pos + Vector3.new(math.cos(a) * (pd.radius + 1.2), 0.4, math.sin(a) * (pd.radius + 1.2))
			makePart(world, "PoolRock", Vector3.new(2.2, 1.4, 2), CFrame.new(rp) * CFrame.Angles(0.2, a, 0.3),
				Color3.fromRGB(104, 90, 86), Enum.Material.Slate)
		end
		table.insert(Game.Pools, {
			name = pd.name, position = pd.pos + Vector3.new(0, 0.6, 0),
			radius = pd.radius, zone = pd.zone, zoneLuck = pd.luck, part = poolPart,
		})
	end
end

local function BuildZones()
	-- Obsidian Fields: a high plateau NW, unlocked at Rekindle 1.
	makePart(world, "FieldsPlateau", Vector3.new(120, 16, 120), CFrame.new(-115, 0, -115),
		Color3.fromRGB(132, 118, 120), Enum.Material.Slate)
	for i = 1, 12 do
		local x = -115 + ((i * 37) % 100) - 50
		local z = -115 + ((i * 53) % 100) - 50
		makePart(world, "ObsidianShard", Vector3.new(1.6, 5 + (i % 4) * 2, 1.6),
			CFrame.new(x, 10.5, z) * CFrame.Angles(0.12, i, 0.08),
			Color3.fromRGB(22, 20, 30), Enum.Material.Glass)
	end
	-- Bright gem shards jutting between the obsidian: saturated glass
	-- crystals that give the Fields a treasure-field sparkle.
	local gemColors = {
		Color3.fromRGB(64, 224, 255), Color3.fromRGB(255, 92, 200), Color3.fromRGB(150, 255, 110),
		Color3.fromRGB(255, 205, 60), Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 120, 90),
	}
	for i = 1, 6 do
		local x = -115 + ((i * 29) % 88) - 44
		local z = -115 + ((i * 43) % 88) - 44
		local gem = makePart(world, "GemShard", Vector3.new(2, 4.5 + (i % 3), 2),
			CFrame.new(x, 10, z) * CFrame.Angles(0.5, i * 0.9, 0.5),
			gemColors[i], Enum.Material.Glass)
		gem.CanCollide = false
	end
	makeSignPost(world, Vector3.new(-58, 12.5, -66), Vector3.new(0, 10, 60), 13, 3.4,
		"OBSIDIAN FIELDS", "Unlocked at Rekindle 1 — richer wild spawns", Color3.fromRGB(150, 120, 255))
	-- Crater Rim: a high shelf on the volcano's north face, Rekindle 3.
	makePart(world, "RimPlateau", Vector3.new(96, 10, 64), CFrame.new(0, 25, -94),
		Color3.fromRGB(122, 106, 102), Enum.Material.Slate)
	-- Glowing lava cracks stitched across the Rim's top face.
	for i = 1, 4 do
		local crack = makePart(world, "RimCrack", Vector3.new(13 + i * 2, 0.25, 1.5),
			CFrame.new(-30 + i * 17, 30.1, -104 + (i % 2) * 18) * CFrame.Angles(0, i * 0.7, 0),
			Color3.fromRGB(255, 116, 38), Enum.Material.Neon)
		crack.CanCollide = false
	end
	-- Rough stone steps climbing from the Fields toward the Rim.
	for i = 0, 5 do
		makePart(world, "RimStep", Vector3.new(10, 2.4, 8),
			CFrame.new(-46 + i * 8, 9.5 + i * 3.4, -98), Color3.fromRGB(118, 104, 100), Enum.Material.Slate)
	end
	makeSignPost(world, Vector3.new(0, 34.5, -60), Vector3.new(0, 32, 60), 13, 3.4,
		"CRATER RIM", "Unlocked at Rekindle 3 — the wildest spawns", Color3.fromRGB(255, 90, 60))
end

local function BuildSpawnPlaza()
	-- The plaza: a stone disc on the south shore where everyone lands.
	makeDisc(world, "Plaza", 17, 1.2, CFrame.new(0, 0, 150),
		Color3.fromRGB(158, 144, 136), Enum.Material.Slate)
	-- A coral Neon inlay ring on the plaza face: the spawn point's
	-- colour signature, visible the second a player lands.
	local inlay = makeDisc(world, "PlazaInlay", 15.2, 0.25, CFrame.new(0, 0.62, 150),
		Color3.fromRGB(255, 110, 90), Enum.Material.Neon)
	inlay.CanCollide = false
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "IslandSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 1.1, 150)
	spawn.Color = Color3.fromRGB(140, 130, 126)
	spawn.Material = Enum.Material.Slate
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = world

	makeSignPost(world, Vector3.new(-15, 5, 131), Vector3.new(0, 4, 152), 14, 3.6,
		"MAGMA MAYHEM", "Buy brainrots. Dodge the lava. Trust no goblin.", Color3.fromRGB(255, 110, 50))
	makeSignPost(world, Vector3.new(-19, 4.6, 158), Vector3.new(0, 4, 148), 12, 3.2,
		"HOW TO PLAY", "Parade -> carry home -> bank -> collect -> REKINDLE", Color3.fromRGB(120, 220, 255))

	-- Chief Magma himself: a broad magma golem on a podium, quest-giver
	-- and island landlord. Built from parts like everything else here.
	local chief = Instance.new("Model")
	chief.Name = "ChiefMagma"
	chief.Parent = world
	local base = CFrame.new(17, 0.6, 134)
	makeDisc(chief, "Podium", 3.4, 1.2, base, Color3.fromRGB(60, 52, 52), Enum.Material.Slate)
	makePart(chief, "Legs", Vector3.new(2.2, 1.6, 1.4), base * CFrame.new(0, 1.4, 0), Color3.fromRGB(52, 46, 46), Enum.Material.Slate)
	makePart(chief, "Body", Vector3.new(3.4, 3.2, 2.2), base * CFrame.new(0, 3.8, 0), Color3.fromRGB(200, 80, 40), Enum.Material.CrackedLava)
	makePart(chief, "Head", Vector3.new(2.2, 2.2, 2.2), base * CFrame.new(0, 6.4, 0), Color3.fromRGB(70, 60, 58), Enum.Material.Slate)
	for _, ex in ipairs({ -0.45, 0.45 }) do
		local eye = makePart(chief, "Eye", Vector3.new(0.34, 0.34, 0.16), base * CFrame.new(ex, 6.6, -1.12),
			Color3.fromRGB(255, 170, 50), Enum.Material.Neon)
		eye.CanCollide = false
	end
	for i = 1, 5 do
		local a = (i - 3) * 0.5
		makePart(chief, "CrownSpike", Vector3.new(0.4, 1.1, 0.4),
			base * CFrame.new(math.sin(a) * 0.95, 7.9, math.cos(a) * 0.4 - 0.4), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	end
	makeSignPost(world, Vector3.new(17, 4.6, 126), Vector3.new(0, 4, 148), 12, 3.2,
		"CHIEF MAGMA", "Contracts pay cash + gems. Check your quest panel!", Color3.fromRGB(255, 170, 60))

	-- Shop pads for the four upgrade tracks (Progression arms them).
	local padColors = {
		["Speed Boots"] = Color3.fromRGB(90, 200, 255),
		["Carry Harness"] = Color3.fromRGB(255, 190, 80),
		["Base Lock"] = Color3.fromRGB(150, 240, 160),
		["Luck Charm"] = Color3.fromRGB(230, 140, 255),
	}
	local padX = { -16.5, -5.5, 5.5, 16.5 }
	for i, trackName in ipairs(Upgrades.TrackOrder) do
		local pad = makeDisc(world, "ShopPad_" .. trackName, 3.6, 0.5,
			CFrame.new(padX[i], 0.55, 167), padColors[trackName], Enum.Material.Neon)
		pad.CanCollide = false
		Game.ShopPads[trackName] = pad
		makeSignPost(world, Vector3.new(padX[i], 4.2, 173), Vector3.new(padX[i], 3.5, 150), 8.5, 2.6,
			string.upper(trackName), Upgrades.Tracks[trackName].blurb, padColors[trackName])
	end

	-- Two market stalls flanking the shop row: striped awnings and
	-- crate stacks, so the plaza reads as a bazaar, not a parking lot.
	for _, stall in ipairs({
		{ x = -27, stripe = Color3.fromRGB(255, 92, 84) },
		{ x = 27, stripe = Color3.fromRGB(32, 201, 181) },
	}) do
		local cf = CFrame.lookAt(Vector3.new(stall.x, 0, 158), Vector3.new(0, 0, 148))
		for _, px in ipairs({ -3.4, 3.4 }) do
			makePart(world, "StallPost", Vector3.new(0.4, 5.4, 0.4),
				cf * CFrame.new(px, 2.7, 0), Color3.fromRGB(122, 88, 60), Enum.Material.Wood)
		end
		for s = 0, 3 do
			local stripeColor = (s % 2 == 0) and stall.stripe or Color3.fromRGB(255, 250, 240)
			local awn = makePart(world, "StallAwning", Vector3.new(2, 0.25, 5.4),
				cf * CFrame.new(-3 + s * 2, 5.6, 0) * CFrame.Angles(math.rad(14), 0, 0),
				stripeColor, Enum.Material.SmoothPlastic)
			awn.CanCollide = false
		end
		makePart(world, "StallCounter", Vector3.new(7.6, 1.6, 2.2),
			cf * CFrame.new(0, 0.8, 0), Color3.fromRGB(140, 104, 72), Enum.Material.Wood)
		makePart(world, "StallCrate", Vector3.new(1.7, 1.7, 1.7),
			cf * CFrame.new(-2.2, 2.45, 0), stall.stripe, Enum.Material.Wood)
		makePart(world, "StallCrate", Vector3.new(1.4, 1.4, 1.4),
			cf * CFrame.new(0.2, 2.3, 0), Color3.fromRGB(255, 205, 60), Enum.Material.Wood)
	end
end

local PLOT_TRIM_COLORS = {
	Color3.fromRGB(255, 110, 80), Color3.fromRGB(255, 190, 70), Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(90, 200, 255), Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 130, 200),
	Color3.fromRGB(140, 255, 220), Color3.fromRGB(255, 255, 160),
}

local function BuildPlayerBases()
	-- Eight raised plots fanning across the south shore, high enough
	-- (top Y = 6) to stay dry when the eruption flood rises to 3.4.
	for i = 1, 8 do
		local theta = math.rad(-77 + (i - 1) * 22)
		local px, pz = 148 * math.sin(theta), 148 * math.cos(theta)
		local topCf = CFrame.lookAt(Vector3.new(px, 6, pz), Vector3.new(0, 6, 0))
		local plotFolder = Instance.new("Folder")
		plotFolder.Name = "Plot" .. i
		plotFolder.Parent = world
		makePart(plotFolder, "Platform", Vector3.new(38, 12, 30), topCf * CFrame.new(0, -6, 0),
			Color3.fromRGB(134, 120, 114), Enum.Material.Slate)
		-- Neon trim frame so each base reads from across the island.
		local trim = PLOT_TRIM_COLORS[i]
		makePart(plotFolder, "TrimF", Vector3.new(38.6, 0.5, 0.6), topCf * CFrame.new(0, 0.1, -15), trim, Enum.Material.Neon)
		makePart(plotFolder, "TrimB", Vector3.new(38.6, 0.5, 0.6), topCf * CFrame.new(0, 0.1, 15), trim, Enum.Material.Neon)
		makePart(plotFolder, "TrimL", Vector3.new(0.6, 0.5, 30.6), topCf * CFrame.new(-19, 0.1, 0), trim, Enum.Material.Neon)
		makePart(plotFolder, "TrimR", Vector3.new(0.6, 0.5, 30.6), topCf * CFrame.new(19, 0.1, 0), trim, Enum.Material.Neon)
		-- A translucent carpet in the plot's own colour under the
		-- pedestal grid: from any height the base glows its colour.
		local carpet = makePart(plotFolder, "Carpet", Vector3.new(34, 0.12, 26), topCf * CFrame.new(0, 0.06, 0),
			trim, Enum.Material.SmoothPlastic)
		carpet.Transparency = 0.45
		carpet.CanCollide = false
		-- Twin torch posts flanking the front steps, orbs in trim colour.
		for _, tx in ipairs({ -7, 7 }) do
			makePart(plotFolder, "TorchPost", Vector3.new(0.35, 3.4, 0.35), topCf * CFrame.new(tx, 1.7, -14.6),
				Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
			local orb = makePart(plotFolder, "TorchOrb", Vector3.new(0.95, 0.95, 0.95), topCf * CFrame.new(tx, 3.75, -14.6),
				trim, Enum.Material.Neon)
			orb.Shape = Enum.PartType.Ball
			orb.CanCollide = false
		end

		-- 25 pedestals in a 5x5 grid — enough for the base 6 slots plus
		-- every Rekindle's +2 (max 22). Only the first pedestalsMax are
		-- unlocked; the rest stand dark until Rekindles add slots.
		local pedestalCFrames, pedestalParts = {}, {}
		local n = 0
		for row = 1, 5 do
			for col = 1, 5 do
				n += 1
				local lx = -14.4 + (col - 1) * 7.2
				local lz = -10 + (row - 1) * 5
				local ped = makeDisc(plotFolder, "Pedestal" .. n, 1.7, 1.1,
					topCf * CFrame.new(lx, 0.55, lz), Color3.fromRGB(104, 96, 112), Enum.Material.Slate)
				table.insert(pedestalParts, ped)
				-- Pedestal CFrames keep the plot's own facing (-Z toward
				-- the island), so banked brainrots face their owner.
				table.insert(pedestalCFrames, topCf * CFrame.new(lx, 1.1, lz))
			end
		end

		-- The collect pad: step on it to sweep every pedestal's accrued
		-- cash at once (Economy watches it).
		local collectPad = makeDisc(plotFolder, "CollectPad", 2.2, 0.5, topCf * CFrame.new(0, 0.25, -13.6),
			Color3.fromRGB(90, 255, 140), Enum.Material.Neon)
		collectPad.CanCollide = false

		-- The lock dome: invisible until Thieves raises the forcefield.
		local dome = makePart(plotFolder, "LockDome", Vector3.new(40, 17, 32), topCf * CFrame.new(0, 3.5, 0),
			Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		dome.Shape = Enum.PartType.Ball
		dome.CanCollide = false
		dome.Transparency = 1

		local signPos = topCf * Vector3.new(0, 4.6, -16.5)
		local signTitle, signSub = makeSignPost(world, signPos,
			signPos + (topCf.LookVector * 30), 13, 3.2, "VACANT PLOT", "A brainrot base, awaiting a legend")

		-- Two stone steps climb the platform's front face, so owners,
		-- visitors and thieves can all get up from the beach.
		makePart(plotFolder, "StepLow", Vector3.new(10, 2, 3), topCf * CFrame.new(0, -5, -16.5),
			Color3.fromRGB(126, 112, 108), Enum.Material.Slate)
		makePart(plotFolder, "StepHigh", Vector3.new(10, 4, 2.6), topCf * CFrame.new(0, -4, -15.2),
			Color3.fromRGB(130, 116, 112), Enum.Material.Slate)

		-- Owners spawn on their own doorstep, facing their collection.
		local spawnPos = topCf:PointToWorldSpace(Vector3.new(0, 0.4, -12.6))
		Game.Plots[i] = {
			index = i, topCf = topCf, centerTop = Vector3.new(px, 6, pz),
			pedestalCFrames = pedestalCFrames, pedestalParts = pedestalParts,
			collectPad = collectPad, lockDome = dome,
			signTitle = signTitle, signSub = signSub,
			spawnCFrame = CFrame.lookAt(spawnPos, Vector3.new(px, 8.5, pz)),
			owner = nil,
		}
	end
end

local function BuildRivalBases()
	-- Three rival NPC stashes: pre-stocked pedestals a brave player can
	-- grab from — if they outrun the guard (Thieves runs the chase).
	local rivals = {
		{ name = "CAPTAIN CINDERS", zone = "Ashen Beach", top = Vector3.new(-98, 3, 62) },
		{ name = "MADAME EMBER", zone = "Obsidian Fields", top = Vector3.new(-78, 14, -142) },
		{ name = "THE ASHEN DUKE", zone = "Crater Rim", top = Vector3.new(26, 33, -96) },
	}
	for i, rv in ipairs(rivals) do
		local topCf = CFrame.lookAt(rv.top, Vector3.new(0, rv.top.Y, 0))
		local folder = Instance.new("Folder")
		folder.Name = "RivalBase" .. i
		folder.Parent = world
		makePart(folder, "Platform", Vector3.new(24, 6, 19), topCf * CFrame.new(0, -3, 0),
			Color3.fromRGB(110, 96, 96), Enum.Material.Slate)
		-- A full red Neon trim frame (was a single front strip), so a
		-- rival stash glows "steal me" from every approach.
		makePart(folder, "Trim", Vector3.new(24.6, 0.5, 0.6), topCf * CFrame.new(0, 0.1, -9.5),
			Color3.fromRGB(255, 80, 70), Enum.Material.Neon)
		makePart(folder, "TrimBack", Vector3.new(24.6, 0.5, 0.6), topCf * CFrame.new(0, 0.1, 9.5),
			Color3.fromRGB(255, 80, 70), Enum.Material.Neon)
		makePart(folder, "TrimLeft", Vector3.new(0.6, 0.5, 19.6), topCf * CFrame.new(-12, 0.1, 0),
			Color3.fromRGB(255, 80, 70), Enum.Material.Neon)
		makePart(folder, "TrimRight", Vector3.new(0.6, 0.5, 19.6), topCf * CFrame.new(12, 0.1, 0),
			Color3.fromRGB(255, 80, 70), Enum.Material.Neon)
		local pedestalCFrames, pedestalParts = {}, {}
		for k = 1, 4 do
			local lx = -6.75 + (k - 1) * 4.5
			local ped = makeDisc(folder, "RivalPedestal" .. k, 1.6, 1.1,
				topCf * CFrame.new(lx, 0.55, 0), Color3.fromRGB(96, 88, 100), Enum.Material.Slate)
			table.insert(pedestalParts, ped)
			table.insert(pedestalCFrames, topCf * CFrame.new(lx, 1.1, 0))
		end
		local signPos = topCf * Vector3.new(0, 4.4, -11.5)
		makeSignPost(world, signPos, signPos + (topCf.LookVector * 30), 12, 3,
			rv.name, "Steal from me. I DARE you.", Color3.fromRGB(255, 90, 70))
		Game.RivalBases[i] = {
			index = i, name = rv.name, zone = rv.zone, topCf = topCf, centerTop = rv.top,
			pedestalCFrames = pedestalCFrames, pedestalParts = pedestalParts,
			guardPost = topCf:PointToWorldSpace(Vector3.new(9, 1, 8)),
			slots = {}, -- [k] = { defName, mutationName, model } (Thieves stocks these)
		}
	end
end

local function BuildDressing()
	-- Set dressing, layered at three scales (STUDY-TOP5-VISUAL.md):
	-- big silhouettes (lush palms), medium structures (torches, crate
	-- clusters, umbrellas) and small scatter (flower tufts, shore
	-- rocks) — so no quadrant of any screenshot is bare flat ground.
	-- Lush palms: warm trunk, two stacked green canopies, coconuts.
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2 + 0.35
		local r = 118 + (i % 3) * 22
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if math.abs(pos.Z - 150) > 26 or math.abs(pos.X) > 30 then
			local tilt = CFrame.Angles(math.rad((i % 5) - 2) * 3, 0, math.rad((i % 4) - 2) * 3)
			local trunk = makePart(world, "PalmTrunk", Vector3.new(0.85, 7, 0.85),
				CFrame.new(pos + Vector3.new(0, 3.5, 0)) * tilt, Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
			trunk.Shape = Enum.PartType.Cylinder
			local canopyLow = makePart(world, "PalmCanopy", Vector3.new(6.4, 1.7, 6.4),
				CFrame.new(pos + Vector3.new(0, 7.3, 0)), Color3.fromRGB(66, 178, 76), Enum.Material.Grass)
			canopyLow.Shape = Enum.PartType.Ball
			canopyLow.CanCollide = false
			local canopyHigh = makePart(world, "PalmCanopyTop", Vector3.new(4.4, 1.4, 4.4),
				CFrame.new(pos + Vector3.new(0, 8.3, 0)), Color3.fromRGB(96, 208, 94), Enum.Material.Grass)
			canopyHigh.Shape = Enum.PartType.Ball
			canopyHigh.CanCollide = false
			for c = 1, 3 do
				local ca = (c / 3) * math.pi * 2 + i
				local nut = makePart(world, "Coconut", Vector3.new(0.65, 0.65, 0.65),
					CFrame.new(pos + Vector3.new(math.cos(ca) * 0.8, 6.6, math.sin(ca) * 0.8)),
					Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
				nut.Shape = Enum.PartType.Ball
				nut.CanCollide = false
			end
		end
	end
	-- Shore rocks, sun-bleached (every fourth wears a coral tint).
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2 + 0.9
		local r = 96 + (i % 4) * 24
		local pos = Vector3.new(math.cos(a) * r, 0.6, math.sin(a) * r)
		local rockColor = (i % 4 == 0) and Color3.fromRGB(196, 130, 110) or Color3.fromRGB(140, 130, 124)
		makePart(world, "ShoreRock", Vector3.new(2 + (i % 3), 1.6 + (i % 2), 2.4),
			CFrame.new(pos) * CFrame.Angles(0.2, i * 1.3, 0.15), rockColor, Enum.Material.Slate)
	end
	-- Tiki torches scattered through the mid-ground ring: a wooden
	-- pole and a Neon flame orb — the island's confetti of light dots.
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + 0.75
		local pos = Vector3.new(math.cos(a) * 100, 0, math.sin(a) * 100)
		makePart(world, "TikiPost", Vector3.new(0.35, 4.4, 0.35), CFrame.new(pos + Vector3.new(0, 2.2, 0)),
			Color3.fromRGB(110, 80, 54), Enum.Material.Wood)
		local flame = makePart(world, "TikiFlame", Vector3.new(1, 1.25, 1), CFrame.new(pos + Vector3.new(0, 4.9, 0)),
			Color3.fromRGB(255, 160, 50), Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
	end
	-- Crate and barrel clusters: little supply dumps with bright
	-- painted wood, parked where screenshots used to show bare disc.
	for _, cl in ipairs({
		{ x = -38, z = 118 }, { x = 96, z = 44 }, { x = -96, z = -30 }, { x = 40, z = -108 },
	}) do
		local cf = CFrame.new(cl.x, 0, cl.z)
		makePart(world, "Crate", Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(0, 1.2, 0),
			Color3.fromRGB(32, 178, 190), Enum.Material.Wood)
		makePart(world, "Crate", Vector3.new(2, 2, 2), cf * CFrame.new(1.8, 1, 1.4),
			Color3.fromRGB(255, 110, 90), Enum.Material.Wood)
		makePart(world, "Crate", Vector3.new(1.7, 1.7, 1.7), cf * CFrame.new(0.4, 3.25, 0.2),
			Color3.fromRGB(255, 205, 60), Enum.Material.Wood)
		local barrel = makePart(world, "Barrel", Vector3.new(1.7, 2.6, 1.7), cf * CFrame.new(-2.1, 1.3, 1.2),
			Color3.fromRGB(150, 104, 66), Enum.Material.Wood)
		barrel.Shape = Enum.PartType.Cylinder
		local band = makePart(world, "BarrelBand", Vector3.new(1.85, 0.35, 1.85), cf * CFrame.new(-2.1, 1.9, 1.2),
			Color3.fromRGB(255, 92, 200), Enum.Material.Neon)
		band.Shape = Enum.PartType.Cylinder
		band.CanCollide = false
	end
	-- Beach umbrellas and towels on the south sand.
	for i, um in ipairs({
		{ x = -52, z = 158, c = Color3.fromRGB(255, 92, 84) },
		{ x = 58, z = 152, c = Color3.fromRGB(64, 156, 255) },
		{ x = -8, z = 178, c = Color3.fromRGB(255, 205, 60) },
	}) do
		local cf = CFrame.new(um.x, 0, um.z)
		makePart(world, "UmbrellaPole", Vector3.new(0.25, 4.6, 0.25), cf * CFrame.new(0, 2.3, 0),
			Color3.fromRGB(240, 240, 235), Enum.Material.Metal)
		local shade = makeDisc(world, "UmbrellaShade", 3.6, 0.5, cf * CFrame.new(0, 4.7, 0), um.c,
			Enum.Material.SmoothPlastic)
		shade.CanCollide = false
		local towel = makePart(world, "BeachTowel", Vector3.new(3.4, 0.14, 5), cf * CFrame.new(2.8, 0.1, 1.5),
			um.c, Enum.Material.SmoothPlastic)
		towel.CanCollide = false
	end
	-- Flower tufts: tiny saturated blooms dotted over the inner
	-- field — small-scale detail that survives downscaling as colour.
	local tuftColors = {
		Color3.fromRGB(255, 110, 180), Color3.fromRGB(255, 225, 90),
		Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 140, 70),
	}
	for i = 1, 24 do
		local a = (i / 24) * math.pi * 2 + 0.5
		local r = 88 + (i % 5) * 9
		local pos = Vector3.new(math.cos(a) * r, 0.45, math.sin(a) * r)
		local tuft = makePart(world, "FlowerTuft", Vector3.new(1.1, 0.9, 1.1), CFrame.new(pos),
			tuftColors[(i % #tuftColors) + 1], Enum.Material.Grass)
		tuft.Shape = Enum.PartType.Ball
		tuft.CanCollide = false
	end
	-- A stepping-disc path from the plaza to the parade ring,
	-- alternating coral and cream — a colour trail for the eye.
	for i = 0, 5 do
		local stoneColor = (i % 2 == 0) and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(250, 244, 228)
		local stone = makeDisc(world, "PathStone", 2.3, 0.3, CFrame.new(0, 0.1, 130 - i * 9),
			stoneColor, Enum.Material.SmoothPlastic)
		stone.CanCollide = false
	end
	-- Lamp posts around the plaza and the parade's south arc.
	for i = 1, 6 do
		local a = math.rad(35 + i * 22)
		local pos = Vector3.new(math.cos(a) * 92, 0, math.sin(a) * 92)
		if pos.Z > 20 then
			makePart(world, "LampPost", Vector3.new(0.4, 6.5, 0.4), CFrame.new(pos + Vector3.new(0, 3.25, 0)),
				Color3.fromRGB(80, 74, 78), Enum.Material.Metal)
			local orb = makePart(world, "LampOrb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, 6.9, 0)),
				Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
			orb.Shape = Enum.PartType.Ball
			orb.CanCollide = false
		end
	end
end

-- Animate the lava: a slow pulse runs through every registered lava
-- part so the island always looks one sneeze from erupting.
task.spawn(function()
	while true do
		local t = os.clock()
		for i, part in ipairs(animatedLava) do
			local pulse = 0.5 + 0.5 * math.sin(t * 2.1 + i * 1.73)
			part.Color = Color3.fromRGB(255, 94 + math.floor(44 * pulse), 28 + math.floor(20 * pulse))
		end
		task.wait(0.15)
	end
end)

--====================================================================--
-- Build the island
--====================================================================--

BuildIslandGround()
BuildZones()
BuildVolcano()
BuildParadeRing()
BuildLavaPools()
BuildSpawnPlaza()
BuildPlayerBases()
BuildRivalBases()
BuildDressing()

--====================================================================--
-- Player lifecycle: claim a plot, create the State entry, land the
-- character in front of its base. Modules hang their own join hooks
-- off Game.Modules (Economy.PlayerLeft cleans up on the way out).
--====================================================================--

local function ClaimPlot(player)
	for _, plot in ipairs(Game.Plots) do
		if not plot.owner then
			plot.owner = player
			return plot
		end
	end
	-- More players than plots (a very good day): share plot 1.
	return Game.Plots[1]
end

local function OnPlayerAdded(player)
	if Game.State[player] then
		return
	end
	local plot = ClaimPlot(player)
	Game.State[player] = NewPlayerState(player, plot)
	if plot.signTitle then
		plot.signTitle.Text = string.upper(player.DisplayName) .. "'S BASE"
	end
	if plot.signSub then
		plot.signSub.Text = "Home of a rising brainrot legend"
	end

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			character:PivotTo(plot.spawnCFrame)
		end
		if Game.ApplyMovement then
			Game.ApplyMovement(player)
		end
		local economy = Game.Modules.Economy
		if economy and economy.OnCharacterSpawned then
			economy.OnCharacterSpawned(player, character)
		end
	end)
end

local function OnPlayerRemoving(player)
	local st = Game.State[player]
	if not st then
		return
	end
	local economy = Game.Modules.Economy
	if economy and economy.PlayerLeft then
		economy.PlayerLeft(player)
	end
	local plot = st.plot
	if plot and plot.owner == player then
		plot.owner = nil
		if plot.signTitle then
			plot.signTitle.Text = "VACANT PLOT"
		end
		if plot.signSub then
			plot.signSub.Text = "A brainrot base, awaiting a legend"
		end
	end
	Game.State[player] = nil
end

--====================================================================--
-- Module wiring: require the five server systems and Init them in
-- dependency order (Economy first — everyone spends through it;
-- Progression next — everyone reads its quest/luck helpers).
--====================================================================--

local ServerScriptService = game:GetService("ServerScriptService")
Game.Modules.Economy = require(ServerScriptService:WaitForChild("Economy"))
Game.Modules.Progression = require(ServerScriptService:WaitForChild("Progression"))
Game.Modules.Conveyor = require(ServerScriptService:WaitForChild("Conveyor"))
Game.Modules.Thieves = require(ServerScriptService:WaitForChild("Thieves"))
Game.Modules.Eruption = require(ServerScriptService:WaitForChild("Eruption"))

Game.Modules.Economy.Init(Game)
Game.Modules.Progression.Init(Game)
Game.Modules.Conveyor.Init(Game)
Game.Modules.Thieves.Init(Game)
Game.Modules.Eruption.Init(Game)

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end
