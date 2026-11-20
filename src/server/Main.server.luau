--[[
	Main.server.luau — MAGMA MAYHEM: Brainrot Volcano, server bootstrap.

	Paste target: a Script named "Main" in ServerScriptService.

	This script does three jobs and no more:
	  1. BOOTSTRAP — the self-healing place setup, the MagmaRemotes
	     folder the client contract is built on, and the one central
	     Game context (world data + per-player State store) that every
	     server module shares.
	  2. WORLD BUILDING — the whole volcanic island from plain parts:
	     a terraced, colour-zoned island; a volcano with animated
	     lava and an irregular shouldered silhouette; the rainbow
	     parade ring under a gantry gate; three lava pools; three
	     dressed zones (mesa, watchtower, overlook); a bulb marquee
	     over the spawn plaza; eight player base plots built as
	     walled, canopied booths with entrance gantries; three rival
	     NPC booths; a dock; and Chief Magma's quest post. The
	     architecture pass follows STUDY-TOP10-DEEP.md — the top 10
	     are enclosed, signed and eye-level, and so is this island.
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
-- SunRays for cheer, a strong Bloom so the Neon trims/lava/signs glow
-- like the top sheets, and a colour grade that pushes saturation so
-- the palette reads loud instead of washed-out pastel.
for _, fxName in ipairs({ "MagmaAtmosphere", "MagmaSunRays", "MagmaBloom", "MagmaColorGrade" }) do
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
bloom.Intensity = 0.75
bloom.Size = 24
bloom.Threshold = 0.75
bloom.Parent = Lighting
local colorGrade = Instance.new("ColorCorrectionEffect")
colorGrade.Name = "MagmaColorGrade"
colorGrade.Saturation = 0.3
colorGrade.Contrast = 0.08
colorGrade.Brightness = 0
colorGrade.Parent = Lighting

--====================================================================--
-- Small building helpers
--====================================================================--

-- Rebuilt fresh each run (same pattern as the Lighting effects
-- above): if a previous run's folders are still around, clear them
-- first so re-running this script never stacks a second island.
for _, folderName in ipairs({ "MagmaWorld", "MagmaActors" }) do
	local old = Workspace:FindFirstChild(folderName)
	if old then
		old:Destroy()
	end
end

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

-- A GANTRY sign: the totem's bigger sibling (STUDY-TOP10-DEEP.md —
-- the top 10 all crown their worlds with signage at cover scale).
-- Two FAT posts, a wide board with Neon trim, and optional carnival
-- bulbs along the top edge. The board's Front face looks at
-- `lookAtPoint`; returns (title, sub) exactly like makeSignPost, so
-- dynamic signs (plot names) can be rewritten by their owners.
local function makeGantrySign(parent, position, lookAtPoint, w, h, titleText, subText, trimColor, postColor, withBulbs)
	local cf = CFrame.lookAt(position, Vector3.new(lookAtPoint.X, position.Y, lookAtPoint.Z))
	local g = Instance.new("Model")
	g.Name = "Gantry_" .. titleText:sub(1, 12)
	g.Parent = parent
	trimColor = trimColor or Color3.fromRGB(255, 120, 50)
	postColor = postColor or Color3.fromRGB(84, 58, 40)
	local postLen = position.Y + h / 2
	for _, px in ipairs({ -w / 2 + 0.7, w / 2 - 0.7 }) do
		makePart(g, "GantryPost", Vector3.new(1.15, postLen, 1.15),
			cf * CFrame.new(px, (h / 2 - position.Y) / 2, 0),
			postColor, Enum.Material.Wood)
		-- A Neon collar where the post meets the board: a little
		-- jewel of glow that reads at screenshot distance.
		local collar = makePart(g, "PostCollar", Vector3.new(1.45, 0.5, 1.45),
			cf * CFrame.new(px, h / 2 - 0.6, 0), trimColor, Enum.Material.Neon)
		collar.CanCollide = false
	end
	local board = makePart(g, "Board", Vector3.new(w, h, 0.45), cf, Color3.fromRGB(34, 26, 28), Enum.Material.Wood)
	makePart(g, "TrimTop", Vector3.new(w + 0.35, 0.3, 0.55), cf * CFrame.new(0, h / 2, 0), trimColor, Enum.Material.Neon)
	makePart(g, "TrimBottom", Vector3.new(w + 0.35, 0.3, 0.55), cf * CFrame.new(0, -h / 2, 0), trimColor, Enum.Material.Neon)
	if withBulbs then
		-- Carnival bulbs marching along the board's top edge — the
		-- marquee read from Ice Fish's cover, for a handful of parts.
		local n = math.floor(w / 2.3)
		for b = 0, n do
			local bx = -w / 2 + 0.8 + b * ((w - 1.6) / n)
			local bulb = makePart(g, "Bulb", Vector3.new(0.55, 0.55, 0.55),
				cf * CFrame.new(bx, h / 2 + 0.5, 0), Color3.fromRGB(255, 202, 92), Enum.Material.Neon)
			bulb.Shape = Enum.PartType.Ball
			bulb.CanCollide = false
		end
	end
	return attachSign(board, titleText, subText, nil, 56)
end

--====================================================================--
-- Remotes — the client contract. Folder "MagmaRemotes" in
-- ReplicatedStorage; Builder B's client builds against exactly these.
--====================================================================--

local oldRemotes = ReplicatedStorage:FindFirstChild("MagmaRemotes")
if oldRemotes then
	oldRemotes:Destroy()
end
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
	SetSprint = makeRemote("RemoteEvent", "SetSprint"), -- (bool) hold-Shift sprint flag
	-- server -> client
	HudUpdate = makeRemote("RemoteEvent", "HudUpdate"), -- (stateTable)
	Toast = makeRemote("RemoteEvent", "Toast"), -- (title, body, kind)
	-- client -> server -> client
	GetIndexState = makeRemote("RemoteFunction", "GetIndexState"),
}

-- The music shelf: an empty folder the client scans for Sound
-- tracks and plays in rotation (Akmal drops free Studio Toolbox
-- tracks in here himself). Created ONLY if missing and never
-- destroyed on re-run — unlike MagmaRemotes above, wiping this
-- folder would take his inserted tracks with it.
if not ReplicatedStorage:FindFirstChild("MusicTracks") then
	local musicFolder = Instance.new("Folder")
	musicFolder.Name = "MusicTracks"
	musicFolder.Parent = ReplicatedStorage
end

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
		sprinting = false, -- hold-Shift sprint flag (SetSprint remote)
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
	-- The island: one great disc, top surface at Y = 0 (the playable
	-- plane every system is tuned to), in a deepened charcoal-warm
	-- tone — dark ground is what makes the top sheets' neon trim,
	-- coloured patches and booths pop; the old pale sandstone washed
	-- them out in daylight.
	makeDisc(world, "Island", 200, 4, CFrame.new(0, -2, 0),
		Color3.fromRGB(104, 88, 76), Enum.Material.Slate)
	-- A reef step ringing the shoreline, poking just above the surf:
	-- the island gains a terraced edge instead of ending as a plate.
	local reef = makeDisc(world, "ReefRing", 212, 2, CFrame.new(0, -2, 0),
		Color3.fromRGB(74, 64, 60), Enum.Material.Slate)
	reef.CanCollide = false
	-- The ash field: a dark basalt inlay zoning the volcano's domain
	-- (r <= 102 covers the parade ring and the inner mid-ground), so
	-- the island reads in regions — ash heart, bright shore — the way
	-- the top 10 zone their floors.
	local ash = makeDisc(world, "AshField", 102, 0.16, CFrame.new(0, 0, 0),
		Color3.fromRGB(71, 57, 52), Enum.Material.Slate)
	ash.CanCollide = false
	-- Soft colour patches in the outer mid-ground ring: grass and
	-- coral-sand clearings that break the shore's single tone.
	for _, patch in ipairs({
		{ 62, -96, 30, Color3.fromRGB(116, 186, 104) },
		{ 106, 72, 26, Color3.fromRGB(240, 170, 128) },
		{ -122, 58, 28, Color3.fromRGB(126, 192, 110) },
		}) do
		local p = makeDisc(world, "GroundPatch", patch[3], 0.1, CFrame.new(patch[1], 0.06, patch[2]),
			patch[4], Enum.Material.SmoothPlastic)
		p.CanCollide = false
	end
	-- Silhouette islets on the horizon (Brainrot Beach's depth
	-- trick): dark stacked cones far out at sea, so a screenshot's
	-- background has a third layer behind the island.
	for _, isle in ipairs({ { 305, 300 }, { -385, 120 }, { 145, -435 } }) do
		local ix, iz = isle[1], isle[2]
		local d1 = makeDisc(world, "Islet", 42, 3, CFrame.new(ix, -0.6, iz),
			Color3.fromRGB(74, 88, 92), Enum.Material.Slate)
		d1.CanCollide = false
		local d2 = makeDisc(world, "Islet", 27, 3.4, CFrame.new(ix, 1.8, iz),
			Color3.fromRGB(82, 96, 98), Enum.Material.Slate)
		d2.CanCollide = false
		local d3 = makeDisc(world, "IsletPeak", 13, 4, CFrame.new(ix, 4.6, iz),
			Color3.fromRGB(90, 104, 102), Enum.Material.Slate)
		d3.CanCollide = false
	end
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
	-- Start gate: a fat-pillar GANTRY where fresh brainrots march in
	-- (Brainrot Beach's runway header, rebuilt at cover scale) with
	-- three globe lamps crowning the board.
	local gatePos = Vector3.new(0, 0, Game.Parade.radius)
	makeGantrySign(world, gatePos + Vector3.new(0, 9.6, 6), Vector3.new(0, 8, 190), 19, 4.2,
		"BRAINROT PARADE", "Buy them before they march off!", Color3.fromRGB(255, 205, 60),
		Color3.fromRGB(150, 40, 60), false)
	for _, lx in ipairs({ -7, 0, 7 }) do
		local globe = makePart(world, "GateGlobe", Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(lx, 12.6, gatePos.Z + 6), Color3.fromRGB(255, 220, 130), Enum.Material.Neon)
		globe.Shape = Enum.PartType.Ball
		globe.CanCollide = false
	end
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
	-- Rim rocks, jutting like broken teeth — heights now vary hard
	-- (2.5 to 6.4 studs) and one south-side tooth is MISSING, a notch
	-- where the crater spills toward the south lavafall: the rim's
	-- silhouette stops being a perfect crown.
	for i = 1, 12 do
		if i ~= 3 then
			local a = (i / 12) * math.pi * 2 + 0.3
			local pos = Vector3.new(math.cos(a) * 16.5, 68.5, math.sin(a) * 16.5)
			makePart(volcano, "RimRock", Vector3.new(3.5, 2.5 + ((i * 7) % 4) * 1.3, 3),
				CFrame.new(pos) * CFrame.Angles(0.3, a, 0.2), Color3.fromRGB(112, 94, 88), Enum.Material.Slate)
		end
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
	-- Shoulder cones: two smaller stacked-disc cones leaning on the
	-- main cone's flanks (SE and SW), so the volcano's outline is a
	-- mountain RANGE, not one smooth thimble (STUDY-TOP10-DEEP.md,
	-- finding 5). They intersect the main cone on purpose — the seam
	-- is the silhouette.
	for _, sh in ipairs({
		{ x = 37, z = 24, tiers = { { 18, 0, 13 }, { 12.5, 13, 23 }, { 7.5, 23, 31 } } },
		{ x = -33, z = 26, tiers = { { 15, 0, 10 }, { 10, 10, 18 }, { 6, 18, 24 } } },
		}) do
		for i, lv in ipairs(sh.tiers) do
			local color = (i % 2 == 0) and Color3.fromRGB(122, 98, 90) or Color3.fromRGB(146, 116, 102)
			makeDisc(volcano, "ShoulderCone", lv[1], lv[3] - lv[2],
				CFrame.new(sh.x, (lv[2] + lv[3]) / 2, sh.z), color, Enum.Material.Slate)
		end
	end
	-- Outcrop rocks embedded in the slopes: rotated slabs that break
	-- the cone's smooth bands at base and mid-height.
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + 0.8
		local pos = Vector3.new(math.cos(a) * 54, 3.5, math.sin(a) * 54)
		makePart(volcano, "Outcrop", Vector3.new(5 + (i % 3) * 1.6, 4 + (i % 2) * 2, 4),
			CFrame.new(pos) * CFrame.Angles(0.4, a, 0.3), Color3.fromRGB(104, 86, 80), Enum.Material.Slate)
	end
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + 1.7
		local pos = Vector3.new(math.cos(a) * 33, 26, math.sin(a) * 33)
		makePart(volcano, "Outcrop", Vector3.new(3.6, 3, 3),
			CFrame.new(pos) * CFrame.Angles(0.5, a, 0.4), Color3.fromRGB(110, 90, 84), Enum.Material.Slate)
	end
	-- Lava seams: thin Neon rings sitting proud of the cone's step
	-- ledges, registered in the pulse loop — glowing cracks that
	-- stitch the silhouette at three heights.
	for _, seam in ipairs({ { 49.6, 21.6 }, { 39.6, 33.6 }, { 30.6, 45.6 } }) do
		local ring = makeDisc(volcano, "LavaSeam", seam[1], 0.55, CFrame.new(0, seam[2], 0),
			Color3.fromRGB(255, 116, 38), Enum.Material.Neon)
		ring.CanCollide = false
		table.insert(animatedLava, ring)
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
		Color3.fromRGB(90, 80, 82), Enum.Material.Slate)
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
	-- Mesa dressing (STUDY-TOP10-DEEP.md): the Fields plateau stops
	-- being a bare grey box — banded stone cladding on its south and
	-- east faces, corner posts with Neon caps, a railed fence along
	-- its top edges, and a real staircase up the south face.
	-- The two south bands are split around the stair corridor
	-- (x -124..-106) so nothing at all crosses the climb path.
	for _, band in ipairs({
		{ Vector3.new(51, 1.3, 0.5), CFrame.new(-149.5, 5.5, -54.7) },
		{ Vector3.new(51, 1.3, 0.5), CFrame.new(-80.5, 5.5, -54.7) },
		{ Vector3.new(51, 1.3, 0.5), CFrame.new(-149.5, 1.8, -54.7) },
		{ Vector3.new(51, 1.3, 0.5), CFrame.new(-80.5, 1.8, -54.7) },
		{ Vector3.new(0.5, 1.3, 120.6), CFrame.new(-54.7, 5.5, -115) },
		{ Vector3.new(0.5, 1.3, 120.6), CFrame.new(-54.7, 1.8, -115) },
		}) do
		makePart(world, "MesaBand", band[1], band[2], Color3.fromRGB(172, 158, 150), Enum.Material.Slate)
	end
	for _, cx in ipairs({ -174, -56 }) do
		for _, cz in ipairs({ -174, -56 }) do
			makePart(world, "MesaCorner", Vector3.new(2, 11, 2), CFrame.new(cx, 2.5, cz),
				Color3.fromRGB(120, 106, 104), Enum.Material.Slate)
			local cap = makeDisc(world, "MesaCap", 1.5, 0.4, CFrame.new(cx, 8.3, cz),
				Color3.fromRGB(150, 120, 255), Enum.Material.Neon)
			cap.CanCollide = false
		end
	end
	-- Top-edge fencing: posts + two rails, with a gap in the south
	-- run where the staircase arrives.
	for px = -170, -60, 10 do
		if px < -124 or px > -106 then
			makePart(world, "FencePost", Vector3.new(0.35, 2.6, 0.35), CFrame.new(px, 9.3, -56),
				Color3.fromRGB(110, 80, 54), Enum.Material.Wood)
		end
		makePart(world, "FencePost", Vector3.new(0.35, 2.6, 0.35), CFrame.new(-56, 9.3, px),
			Color3.fromRGB(110, 80, 54), Enum.Material.Wood)
	end
	for _, seg in ipairs({ { -147.5, 47 }, { -82.5, 47 } }) do
		makePart(world, "FenceRail", Vector3.new(seg[2], 0.3, 0.3), CFrame.new(seg[1], 9.2, -56),
			Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
		makePart(world, "FenceRail", Vector3.new(seg[2], 0.3, 0.3), CFrame.new(seg[1], 10.2, -56),
			Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
	end
	makePart(world, "FenceRail", Vector3.new(0.3, 0.3, 112), CFrame.new(-56, 9.2, -115),
		Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
	makePart(world, "FenceRail", Vector3.new(0.3, 0.3, 112), CFrame.new(-56, 10.2, -115),
		Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
	-- The staircase, rebuilt to be UNMISSABLE (playtest fix: the old
	-- four slabs were the same dark slate as the cliff and topped
	-- out 1.6 studs BELOW the plateau, so the climb read as a sheer
	-- wall and dead-ended in a jump against the face). Now: warm
	-- sandstone treads that protrude ~2.9 studs each, dark nosing
	-- strips, side stringers, handrails, orb lamps at base and
	-- arrival, a big sign at the base, and a landing slab whose top
	-- is FLUSH with the plateau (y 8.0). SECOND playtest fix: the
	-- landing's underside hovered 0.2 over the top tread (top 6.6),
	-- so the exit still read as a floor capping the stairs and the
	-- last move was a 1.4 jump against its lip; every rise was 1.4.
	-- Now seven treads with 1.0 rises — the whole climb, landing
	-- included, is a plain walk, no jumping, no lip.
	local stairStone = Color3.fromRGB(233, 199, 148)
	local stairWood = Color3.fromRGB(110, 78, 50)
	local stepTops = { 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0 }
	local stepFronts = { -48.8, -45.9, -43.0, -40.1, -37.2, -34.3, -31.4 }
	for i, topY in ipairs(stepTops) do
		local front = stepFronts[i]
		makePart(world, "MesaStep", Vector3.new(14, topY, 5), CFrame.new(-115, topY / 2, front - 2.5),
			stairStone, Enum.Material.Sandstone)
		local nosing = makePart(world, "MesaNosing", Vector3.new(14.2, 0.28, 0.5),
			CFrame.new(-115, topY - 0.14, front + 0.1), stairWood, Enum.Material.Wood)
		nosing.CanCollide = false
	end
	-- Landing: top flush with the plateau top, bridging from the
	-- highest tread over the face to the fence gap (x -124..-106
	-- stays completely clear: fence posts/rails already gap there,
	-- and the south MesaBands are split around this corridor).
	makePart(world, "MesaLanding", Vector3.new(14, 1.2, 4.6), CFrame.new(-115, 7.4, -53.3),
		stairStone, Enum.Material.Sandstone)
	-- Side stringer beams following the slope.
	for _, sx in ipairs({ -122.3, -107.7 }) do
		local mid = Vector3.new(sx, 3.5, -40.1)
		local beam = makePart(world, "MesaStringer", Vector3.new(0.55, 0.9, 18.8),
			CFrame.lookAt(mid, Vector3.new(sx, 7.0, -48.8)), stairWood, Enum.Material.Wood)
		beam.CanCollide = false
	end
	-- Handrails: posts standing on the treads near both edges, one
	-- angled rail per side at waist height.
	for _, hx in ipairs({ -121.5, -108.5 }) do
		for _, post in ipairs({ { -30.6, 1.0 }, { -39.3, 4.0 }, { -48.0, 7.0 } }) do
			makePart(world, "MesaRailPost", Vector3.new(0.35, 2.6, 0.35),
				CFrame.new(hx, post[2] + 1.3, post[1]), stairWood, Enum.Material.Wood)
		end
		local railMid = Vector3.new(hx, 6.6, -39.3)
		local rail = makePart(world, "MesaRail", Vector3.new(0.28, 0.28, 18.4),
			CFrame.lookAt(railMid, Vector3.new(hx, 9.6, -48.0)), stairWood, Enum.Material.Wood)
		rail.CanCollide = false
	end
	-- Orb lamps: one at the stair base, one at the arrival on the
	-- plateau top (just west of the fence gap, outside the corridor).
	for _, lamp in ipairs({ { -125.5, 0, -37 }, { -125.5, 8, -57 } }) do
		makePart(world, "MesaLampPost", Vector3.new(0.4, 5.2, 0.4),
			CFrame.new(lamp[1], lamp[2] + 2.6, lamp[3]), Color3.fromRGB(70, 54, 48), Enum.Material.Slate)
		local orb = makePart(world, "MesaLampOrb", Vector3.new(1.15, 1.15, 1.15),
			CFrame.new(lamp[1], lamp[2] + 5.6, lamp[3]), Color3.fromRGB(255, 196, 96), Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		orb.CanCollide = false
	end
	-- The wayfinding sign at the base, big enough to read from the
	-- plaza side of the mesa.
	makeSignPost(world, Vector3.new(-115, 7.8, -27.5), Vector3.new(-115, 5, 90), 17, 4.4,
		"OBSIDIAN FIELDS", "Stairs up - Rekindle 1 zone", Color3.fromRGB(170, 130, 255))
	-- A watchtower on the plateau's SE shoulder: four legs, an open
	-- cabin and a pitched roof in the zone's purple — the Fields'
	-- landmark silhouette.
	local tw = CFrame.new(-84, 8, -64)
	for _, lx in ipairs({ -3, 3 }) do
		for _, lz in ipairs({ -3, 3 }) do
			makePart(world, "TowerLeg", Vector3.new(0.7, 13, 0.7), tw * CFrame.new(lx, 6.5, lz),
				Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
		end
	end
	makePart(world, "TowerFloor", Vector3.new(9.5, 0.6, 9.5), tw * CFrame.new(0, 13.2, 0),
		Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
	for _, lx in ipairs({ -4.2, 4.2 }) do
		for _, lz in ipairs({ -4.2, 4.2 }) do
			makePart(world, "TowerPost", Vector3.new(0.5, 3.4, 0.5), tw * CFrame.new(lx, 15.2, lz),
				Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
		end
	end
	makePart(world, "TowerWall", Vector3.new(0.5, 3, 9), tw * CFrame.new(-4.5, 15, 0),
		Color3.fromRGB(140, 104, 72), Enum.Material.Wood)
	makePart(world, "TowerWall", Vector3.new(9, 3, 0.5), tw * CFrame.new(0, 15, -4.5),
		Color3.fromRGB(140, 104, 72), Enum.Material.Wood)
	local roofL = makePart(world, "TowerRoof", Vector3.new(6.2, 0.3, 10.5), tw * CFrame.new(-2.55, 18.1, 0) * CFrame.Angles(0, 0, 0.49),
		Color3.fromRGB(70, 60, 66), Enum.Material.Slate)
	roofL.CanCollide = false
	local roofR = makePart(world, "TowerRoof", Vector3.new(6.2, 0.3, 10.5), tw * CFrame.new(2.55, 18.1, 0) * CFrame.Angles(0, 0, -0.49),
		Color3.fromRGB(70, 60, 66), Enum.Material.Slate)
	roofR.CanCollide = false
	local ridge = makePart(world, "TowerRidge", Vector3.new(0.4, 0.4, 10.5), tw * CFrame.new(0, 19.6, 0),
		Color3.fromRGB(150, 120, 255), Enum.Material.Neon)
	ridge.CanCollide = false
	local towerOrb = makePart(world, "TowerOrb", Vector3.new(1.2, 1.2, 1.2), tw * CFrame.new(0, 20.7, 0),
		Color3.fromRGB(150, 120, 255), Enum.Material.Neon)
	towerOrb.Shape = Enum.PartType.Ball
	towerOrb.CanCollide = false
	makeSignPost(world, Vector3.new(-58, 12.5, -66), Vector3.new(0, 10, 60), 13, 3.4,
		"OBSIDIAN FIELDS", "Unlocked at Rekindle 1 — richer wild spawns", Color3.fromRGB(150, 120, 255))
	-- Crater Rim: a high shelf on the volcano's north face, Rekindle 3.
	makePart(world, "RimPlateau", Vector3.new(96, 10, 64), CFrame.new(0, 25, -94),
		Color3.fromRGB(83, 72, 69), Enum.Material.Slate)
	-- Glowing lava cracks stitched across the Rim's top face.
	for i = 1, 4 do
		local crack = makePart(world, "RimCrack", Vector3.new(13 + i * 2, 0.25, 1.5),
			CFrame.new(-30 + i * 17, 30.1, -104 + (i % 2) * 18) * CFrame.Angles(0, i * 0.7, 0),
			Color3.fromRGB(255, 116, 38), Enum.Material.Neon)
		crack.CanCollide = false
	end
	-- Rim dressing: a railed fence along the shelf's south edge and
	-- two tilted rock spires, so the high shelf reads as a built
	-- overlook instead of a floating slab.
	for px = -45, 45, 9 do
		makePart(world, "FencePost", Vector3.new(0.35, 2.6, 0.35), CFrame.new(px, 31.3, -63),
			Color3.fromRGB(110, 80, 54), Enum.Material.Wood)
	end
	makePart(world, "FenceRail", Vector3.new(92, 0.3, 0.3), CFrame.new(0, 31.9, -63),
		Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
	makePart(world, "FenceRail", Vector3.new(92, 0.3, 0.3), CFrame.new(0, 32.4, -63),
		Color3.fromRGB(128, 92, 62), Enum.Material.Wood)
	for _, sp in ipairs({ { -40, -70 }, { 42, -118 } }) do
		makePart(world, "RimSpire", Vector3.new(2.2, 9, 2.2),
			CFrame.new(sp[1], 33, sp[2]) * CFrame.Angles(0.15, sp[1], 0.1),
			Color3.fromRGB(104, 88, 84), Enum.Material.Slate)
	end
	-- (The old rough RimSteps that climbed this line were REMOVED
	-- in the route audit: their top three blocks were embedded
	-- inside the Rim slab above, so the climb dead-ended under the
	-- shelf's floor at y 20 — stairs capped by a floor, exactly the
	-- trap Akmal reported. BuildRimAccess is the only Rim route.)
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
		"SPAWN PLAZA", "Mind the lava. Pet the brainrots.", Color3.fromRGB(255, 110, 50))
	-- THE marquee: a bulb-trimmed MAGMA MAYHEM gantry straddling the
	-- path from the plaza to the parade, the volcano framed behind
	-- it — the island's title shot (STUDY-TOP10-DEEP.md, finding 3;
	-- the pass-1 skip, now built).
	makeGantrySign(world, Vector3.new(0, 12.6, 124), Vector3.new(0, 11, 170), 27, 5.2,
		"MAGMA MAYHEM", "Buy brainrots. Dodge the lava. Trust no goblin.",
		Color3.fromRGB(255, 110, 50), Color3.fromRGB(84, 58, 40), true)
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

		-- Booth dressing (STUDY-TOP10-DEEP.md, finding 2 — the
		-- single biggest gap): cream walls with a Neon top rail turn
		-- the open slab into an enclosed yard, and a striped canopy
		-- on four poles roofs the back half like Big Top's booths.
		-- All of it hugs the platform edges, clear of the pedestal
		-- grid and the front steps.
		makePart(plotFolder, "WallBack", Vector3.new(37, 3.4, 0.7), topCf * CFrame.new(0, 1.7, 14.6),
			Color3.fromRGB(242, 238, 228), Enum.Material.SmoothPlastic)
		makePart(plotFolder, "WallBackRail", Vector3.new(37.4, 0.35, 0.95), topCf * CFrame.new(0, 3.55, 14.6),
			trim, Enum.Material.Neon)
		for _, sx in ipairs({ -18.6, 18.6 }) do
			makePart(plotFolder, "WallSide", Vector3.new(0.7, 3.4, 17), topCf * CFrame.new(sx, 1.7, 6),
				Color3.fromRGB(242, 238, 228), Enum.Material.SmoothPlastic)
			makePart(plotFolder, "WallSideRail", Vector3.new(0.95, 0.35, 17.4), topCf * CFrame.new(sx, 3.55, 6),
				trim, Enum.Material.Neon)
		end
		for _, px in ipairs({ -16.8, 16.8 }) do
			makePart(plotFolder, "CanopyPole", Vector3.new(0.4, 9.6, 0.4), topCf * CFrame.new(px, 4.8, 4.5),
				Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
			makePart(plotFolder, "CanopyPole", Vector3.new(0.4, 11.2, 0.4), topCf * CFrame.new(px, 5.6, 13.8),
				Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
		end
		for k = 0, 4 do
			local stripe = (k % 2 == 0) and trim or Color3.fromRGB(255, 250, 240)
			local awn = makePart(plotFolder, "CanopyPanel", Vector3.new(7, 0.22, 10.6),
				topCf * CFrame.new(-14 + k * 7, 10.4, 9.15) * CFrame.Angles(math.rad(-10), 0, 0),
				stripe, Enum.Material.SmoothPlastic)
			awn.CanCollide = false
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
				-- A Neon flange ring under each pedestal (Ice
				-- Fish's glow-ring read): the grid stops being
				-- dots on a slab and becomes lit display spots.
				local flange = makeDisc(plotFolder, "PedestalRing" .. n, 2.35, 0.22,
					topCf * CFrame.new(lx, 0.11, lz), trim, Enum.Material.Neon)
				flange.CanCollide = false
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

		-- The plot's name rides an entrance GANTRY over the steps
		-- (the base billboards of #5/#8), not a ground totem — same
		-- dynamic labels, rewritten by OnPlayerAdded as before.
		local signPos = topCf * Vector3.new(0, 7.2, -18)
		local signTitle, signSub = makeGantrySign(world, signPos,
			signPos + (topCf.LookVector * 30), 17, 4, "VACANT PLOT", "A brainrot base, awaiting a legend",
			trim, Color3.fromRGB(84, 58, 40), false)

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
		-- Booth dressing, matching the player plots: a back wall and
		-- a red/white striped awning, so a rival stash reads as a
		-- rival SHOP, not a bare tray.
		makePart(folder, "WallBack", Vector3.new(23, 3.2, 0.7), topCf * CFrame.new(0, 1.6, 9.1),
			Color3.fromRGB(122, 64, 56), Enum.Material.SmoothPlastic)
		makePart(folder, "WallBackRail", Vector3.new(23.4, 0.35, 0.95), topCf * CFrame.new(0, 3.35, 9.1),
			Color3.fromRGB(255, 80, 70), Enum.Material.Neon)
		for _, px in ipairs({ -10.5, 10.5 }) do
			makePart(folder, "CanopyPole", Vector3.new(0.4, 8.2, 0.4), topCf * CFrame.new(px, 4.1, 2.5),
				Color3.fromRGB(84, 58, 44), Enum.Material.Wood)
			makePart(folder, "CanopyPole", Vector3.new(0.4, 9.6, 0.4), topCf * CFrame.new(px, 4.8, 8.8),
				Color3.fromRGB(84, 58, 44), Enum.Material.Wood)
		end
		for k = 0, 2 do
			local stripe = (k % 2 == 0) and Color3.fromRGB(255, 84, 74) or Color3.fromRGB(255, 250, 240)
			local awn = makePart(folder, "CanopyPanel", Vector3.new(8, 0.22, 7.6),
				topCf * CFrame.new(-8 + k * 8, 9.3, 5.65) * CFrame.Angles(math.rad(-10), 0, 0),
				stripe, Enum.Material.SmoothPlastic)
			awn.CanCollide = false
		end
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
	-- The dock: a wooden pier reaching into the southern sea with a
	-- roofed hut at its end — shoreline architecture and a foreground
	-- for every south-facing view (Brainrot Beach's deck lesson).
	local dock = Instance.new("Folder")
	dock.Name = "Dock"
	dock.Parent = world
	for k = 0, 4 do
		makePart(dock, "DockPlank", Vector3.new(7.5, 0.5, 9.4), CFrame.new(58, 1.1, 194 + k * 9),
			Color3.fromRGB(140, 104, 72), Enum.Material.Wood)
	end
	for _, pz in ipairs({ 191, 200, 209, 218, 227, 234 }) do
		for _, px in ipairs({ 54.8, 61.2 }) do
			makePart(dock, "DockPost", Vector3.new(0.6, 4.4, 0.6), CFrame.new(px, -0.6, pz),
				Color3.fromRGB(110, 80, 54), Enum.Material.Wood)
		end
	end
	for _, px in ipairs({ 54.5, 61.5 }) do
		makePart(dock, "DockRail", Vector3.new(0.3, 0.3, 45), CFrame.new(px, 2.6, 212),
			Color3.fromRGB(122, 88, 60), Enum.Material.Wood)
		for pz = 194, 230, 9 do
			makePart(dock, "DockRailPost", Vector3.new(0.3, 1.6, 0.3), CFrame.new(px, 1.9, pz),
				Color3.fromRGB(122, 88, 60), Enum.Material.Wood)
		end
	end
	for _, px in ipairs({ 55, 61 }) do
		for _, pz in ipairs({ 225, 232 }) do
			makePart(dock, "HutPost", Vector3.new(0.4, 5.5, 0.4), CFrame.new(px, 4.1, pz),
				Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
		end
	end
	local hutRoofA = makePart(dock, "HutRoof", Vector3.new(8.6, 0.25, 5.6),
		CFrame.new(58, 7.6, 225.8) * CFrame.Angles(math.rad(-28), 0, 0), Color3.fromRGB(255, 92, 84), Enum.Material.SmoothPlastic)
	hutRoofA.CanCollide = false
	local hutRoofB = makePart(dock, "HutRoof", Vector3.new(8.6, 0.25, 5.6),
		CFrame.new(58, 7.6, 231.2) * CFrame.Angles(math.rad(28), 0, 0), Color3.fromRGB(255, 250, 240), Enum.Material.SmoothPlastic)
	hutRoofB.CanCollide = false
	local hutLamp = makePart(dock, "HutLamp", Vector3.new(1.1, 1.1, 1.1), CFrame.new(58, 6.2, 228.5),
		Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	hutLamp.Shape = Enum.PartType.Ball
	hutLamp.CanCollide = false
	makePart(dock, "HutCrate", Vector3.new(1.8, 1.8, 1.8), CFrame.new(56, 2.25, 229),
		Color3.fromRGB(32, 178, 190), Enum.Material.Wood)
	-- Tiki statues in the mid-ground: Chief Magma's stone cousins,
	-- medium silhouettes that give the ring between parade and shore
	-- a population of landmarks.
	for _, tp in ipairs({ { 74, 74 }, { -100, 40 }, { 100, -30 }, { -30, 105 }, { 140, -80 }, { -170, 30 } }) do
		local cf = CFrame.lookAt(Vector3.new(tp[1], 0, tp[2]), Vector3.new(0, 0, 0))
		local tiki = Instance.new("Model")
		tiki.Name = "Tiki"
		tiki.Parent = world
		makePart(tiki, "Base", Vector3.new(2.6, 1.2, 2.6), cf * CFrame.new(0, 0.6, 0),
			Color3.fromRGB(96, 84, 80), Enum.Material.Slate)
		makePart(tiki, "Body", Vector3.new(2.2, 2.8, 2.2), cf * CFrame.new(0, 2.6, 0),
			Color3.fromRGB(104, 90, 86), Enum.Material.Slate)
		makePart(tiki, "Head", Vector3.new(2.5, 2.6, 2.5), cf * CFrame.new(0, 5.3, 0),
			Color3.fromRGB(96, 84, 80), Enum.Material.Slate)
		for _, ex in ipairs({ -0.5, 0.5 }) do
			local eye = makePart(tiki, "Eye", Vector3.new(0.4, 0.4, 0.18), cf * CFrame.new(ex, 5.6, -1.28),
				Color3.fromRGB(255, 170, 50), Enum.Material.Neon)
			eye.CanCollide = false
		end
		makePart(tiki, "Nose", Vector3.new(0.5, 1.1, 0.5), cf * CFrame.new(0, 4.9, -1.35),
			Color3.fromRGB(88, 76, 74), Enum.Material.Slate)
		for s = -1, 1 do
			local spike = makePart(tiki, "CrownSpike", Vector3.new(0.35, 1, 0.35), cf * CFrame.new(s * 0.7, 7.1, 0),
				Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
			spike.CanCollide = false
		end
	end
end

--====================================================================--
-- DENSITY + LIFE PASS (final visual pass before submission)
--
-- Everything below is decoration: Anchored, CanCollide = false,
-- parented under the same world folder, and placed so it never
-- touches a gameplay position (pedestals, pads, spawn, plots,
-- parade path and pool spots all stay exactly where they were).
-- The only collidable additions are the two access staircases
-- (mesa landing in BuildZones above, Crater Rim flight below) —
-- those are functional, not decoration.
--
-- decoMovers registers the few things the ambient loop animates
-- (boats, the lighthouse beam, the walking villagers). The loop
-- re-finds them BY NAME under the world folder on every pass, so
-- a world heal/rebuild can never break it, and it never reads or
-- writes Game state.
--====================================================================--

local decoMovers = {}

local function nc(part)
	part.CanCollide = false
	return part
end

-- Orb lamp in the island's existing style: dark post, warm Neon
-- orb. Used for the new paths, ring road and staircases.
local function makeOrbLamp(parent, x, baseY, z)
	nc(makePart(parent, "LampPost", Vector3.new(0.4, 5.2, 0.4), CFrame.new(x, baseY + 2.6, z),
		Color3.fromRGB(70, 54, 48), Enum.Material.Slate))
	local orb = nc(makePart(parent, "LampOrb", Vector3.new(1.15, 1.15, 1.15),
		CFrame.new(x, baseY + 5.6, z), Color3.fromRGB(255, 196, 96), Enum.Material.Neon))
	orb.Shape = Enum.PartType.Ball
end

-- A chunky blocky islander: legs, torso, arms, head, cap or hair.
-- Poses: "stand", "vendor" (both arms forward onto a counter),
-- "wave" (one arm up). Name-free on purpose — they are inhabitants,
-- not NPCs with jobs to hand out.
local function makeFigure(parent, cf, shirt, pants, skin, pose, hatColor)
	local fig = Instance.new("Model")
	fig.Name = "Figure"
	fig.Parent = parent
	nc(makePart(fig, "LegL", Vector3.new(0.58, 1.5, 0.62), cf * CFrame.new(-0.42, 0.75, 0), pants, Enum.Material.SmoothPlastic))
	nc(makePart(fig, "LegR", Vector3.new(0.58, 1.5, 0.62), cf * CFrame.new(0.42, 0.75, 0), pants, Enum.Material.SmoothPlastic))
	nc(makePart(fig, "Torso", Vector3.new(1.7, 1.9, 0.85), cf * CFrame.new(0, 2.45, 0), shirt, Enum.Material.SmoothPlastic))
	if pose == "vendor" then
		nc(makePart(fig, "ArmL", Vector3.new(0.5, 1.8, 0.55),
			cf * CFrame.new(-1.12, 2.45, -0.15) * CFrame.Angles(math.rad(52), 0, 0), shirt, Enum.Material.SmoothPlastic))
		nc(makePart(fig, "ArmR", Vector3.new(0.5, 1.8, 0.55),
			cf * CFrame.new(1.12, 2.45, -0.15) * CFrame.Angles(math.rad(52), 0, 0), shirt, Enum.Material.SmoothPlastic))
	elseif pose == "wave" then
		nc(makePart(fig, "ArmL", Vector3.new(0.5, 1.8, 0.55), cf * CFrame.new(-1.12, 2.45, 0), shirt, Enum.Material.SmoothPlastic))
		nc(makePart(fig, "ArmR", Vector3.new(0.5, 1.8, 0.55),
			cf * CFrame.new(1.5, 3.8, 0) * CFrame.Angles(0, 0, math.rad(30)), shirt, Enum.Material.SmoothPlastic))
	else
		nc(makePart(fig, "ArmL", Vector3.new(0.5, 1.8, 0.55), cf * CFrame.new(-1.12, 2.45, 0), shirt, Enum.Material.SmoothPlastic))
		nc(makePart(fig, "ArmR", Vector3.new(0.5, 1.8, 0.55), cf * CFrame.new(1.12, 2.45, 0), shirt, Enum.Material.SmoothPlastic))
	end
	nc(makePart(fig, "Head", Vector3.new(1.05, 1.0, 1.0), cf * CFrame.new(0, 4.02, 0), skin, Enum.Material.SmoothPlastic))
	if hatColor then
		nc(makePart(fig, "Cap", Vector3.new(1.14, 0.22, 1.14), cf * CFrame.new(0, 4.62, 0), hatColor, Enum.Material.SmoothPlastic))
		nc(makePart(fig, "CapBrim", Vector3.new(1.14, 0.1, 0.55), cf * CFrame.new(0, 4.48, -0.78), hatColor, Enum.Material.SmoothPlastic))
	else
		nc(makePart(fig, "Hair", Vector3.new(1.12, 0.28, 1.12), cf * CFrame.new(0, 4.6, 0),
			Color3.fromRGB(70, 48, 32), Enum.Material.SmoothPlastic))
	end
	return fig
end

-- A curved-trunk palm: two trunk segments leaning toward (dx, dz),
-- five fronds and two coconuts at the crown.
local function makePalm(parent, x, baseY, z, h, dx, dz)
	local palm = Instance.new("Model")
	palm.Name = "Palm"
	palm.Parent = parent
	local a = Vector3.new(x, baseY - 0.3, z)
	local b = Vector3.new(x + dx * 0.7, baseY + h * 0.52, z + dz * 0.7)
	local c = Vector3.new(x + dx * 1.9, baseY + h, z + dz * 1.9)
	for _, seg in ipairs({ { a, b }, { b, c } }) do
		local mid = (seg[1] + seg[2]) / 2
		local len = (seg[2] - seg[1]).Magnitude + 0.5
		nc(makePart(palm, "Trunk", Vector3.new(0.62, 0.62, len), CFrame.lookAt(mid, seg[2]),
			Color3.fromRGB(146, 108, 74), Enum.Material.Wood))
	end
	for k = 0, 4 do
		local yaw = k * (math.pi * 2 / 5) + x
		local center = c + Vector3.new(math.sin(yaw) * 1.35, -0.35, math.cos(yaw) * 1.35)
		nc(makePart(palm, "Frond", Vector3.new(0.35, 0.18, 3.4),
			CFrame.new(center) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(30), 0, 0),
			Color3.fromRGB(74, 168, 84), Enum.Material.SmoothPlastic))
	end
	for _, off in ipairs({ { -0.4, -0.35, 0.2 }, { 0.45, -0.3, -0.25 } }) do
		local nut = nc(makePart(palm, "Coconut", Vector3.new(0.42, 0.42, 0.42),
			CFrame.new(c + Vector3.new(off[1], off[2], off[3])), Color3.fromRGB(110, 80, 50), Enum.Material.SmoothPlastic))
		nut.Shape = Enum.PartType.Ball
	end
	return palm
end

-- Pennant flags strung between two points, sagging in the middle,
-- colors cycling through the palette. The lived-in look.
local pennantPalette = {
	Color3.fromRGB(255, 90, 80), Color3.fromRGB(255, 180, 60), Color3.fromRGB(120, 220, 120),
	Color3.fromRGB(90, 170, 255), Color3.fromRGB(200, 130, 255), Color3.fromRGB(255, 240, 150),
}
local function makePennants(parent, a, b)
	local mid = (a + b) / 2
	local line = nc(makePart(parent, "PennantLine", Vector3.new(0.06, 0.06, (b - a).Magnitude),
		CFrame.lookAt(mid, b), Color3.fromRGB(60, 44, 36), Enum.Material.Wood))
	line.Name = "PennantLine"
	for i = 1, 9 do
		local t = i / 10
		local pos = a:Lerp(b, t) - Vector3.new(0, math.sin(math.pi * t) * 1.1 + 0.55, 0)
		local yaw = math.atan2(b.X - a.X, b.Z - a.Z)
		nc(makePart(parent, "Pennant", Vector3.new(0.95, 1.05, 0.08),
			CFrame.new(pos) * CFrame.Angles(0, yaw, math.rad((i % 2 == 0) and 6 or -6)),
			pennantPalette[(i % #pennantPalette) + 1], Enum.Material.SmoothPlastic))
	end
end

-- MARKET ROW: seven chunky stalls on the south-east apron between
-- the parade ring and the booths, each with its own vendor, striped
-- canopy, counter goods and hanging sign — plus the MAGMA MARKET
-- gantry over the entrance path.
local function BuildMarketRow()
	local stalls = {
		{ 5, "FRUIT", Color3.fromRGB(255, 110, 80) },
		{ 15, "GEMS", Color3.fromRGB(110, 220, 255) },
		{ 25, "POTIONS", Color3.fromRGB(190, 120, 255) },
		{ 35, "SNACKS", Color3.fromRGB(255, 190, 70) },
		{ 45, "SHELLS", Color3.fromRGB(120, 230, 200) },
		{ 55, "SPICES", Color3.fromRGB(255, 140, 60) },
		{ 65, "TOYS", Color3.fromRGB(250, 130, 190) },
	}
	local shirts = {
		Color3.fromRGB(240, 90, 80), Color3.fromRGB(80, 160, 240), Color3.fromRGB(120, 210, 110),
		Color3.fromRGB(250, 190, 60), Color3.fromRGB(180, 110, 230), Color3.fromRGB(90, 210, 200),
		Color3.fromRGB(245, 130, 170),
	}
	local skins = { Color3.fromRGB(255, 205, 160), Color3.fromRGB(198, 150, 110), Color3.fromRGB(140, 100, 70) }
	local goodsColors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 210, 80) }
	for i, s in ipairs(stalls) do
		local ang = math.rad(s[1])
		local x, z = 112 * math.cos(ang), 112 * math.sin(ang)
		local stall = Instance.new("Folder")
		stall.Name = "MarketStall" .. i
		stall.Parent = world
		local cf = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, 0))
		local wood = Color3.fromRGB(128, 92, 62)
		for _, px in ipairs({ -3.2, 3.2 }) do
			for _, pz in ipairs({ -2.2, 2.2 }) do
				nc(makePart(stall, "StallPost", Vector3.new(0.45, 4.4, 0.45), cf * CFrame.new(px, 2.2, pz),
					wood, Enum.Material.Wood))
			end
		end
		for j = 0, 4 do
			local col = (j % 2 == 0) and s[3] or Color3.fromRGB(245, 240, 230)
			nc(makePart(stall, "StallCanopy", Vector3.new(2.0, 0.22, 5.8),
				cf * CFrame.new(-3.8 + j * 1.9, 4.85, 0) * CFrame.Angles(math.rad(9), 0, 0),
				col, Enum.Material.SmoothPlastic))
		end
		nc(makePart(stall, "StallBack", Vector3.new(9.2, 3.4, 0.3), cf * CFrame.new(0, 1.7, 2.75),
			s[3]:Lerp(Color3.fromRGB(0, 0, 0), 0.35), Enum.Material.SmoothPlastic))
		nc(makePart(stall, "StallCounter", Vector3.new(8.2, 1.5, 1.6), cf * CFrame.new(0, 0.95, -1.6),
			Color3.fromRGB(170, 128, 88), Enum.Material.Wood))
		nc(makePart(stall, "CounterTop", Vector3.new(8.6, 0.25, 2.0), cf * CFrame.new(0, 1.82, -1.6),
			Color3.fromRGB(196, 158, 112), Enum.Material.Wood))
		for g, gx in ipairs({ -2.4, 0, 2.4 }) do
			local good = nc(makePart(stall, "Goods", Vector3.new(0.72, 0.72, 0.72),
				cf * CFrame.new(gx, 2.3, -1.6), goodsColors[g], Enum.Material.SmoothPlastic))
			if g == 2 then
				good.Shape = Enum.PartType.Ball
			end
		end
		for _, cx in ipairs({ -3.4, 3.4 }) do
			nc(makePart(stall, "StallCrate", Vector3.new(1.3, 1.3, 1.3), cf * CFrame.new(cx, 0.65, 1.7),
				Color3.fromRGB(160, 118, 78), Enum.Material.Wood))
		end
		nc(makeDisc(stall, "StallBarrel", 0.75, 1.5, cf * CFrame.new(-4.7, 0.75, 0.6),
			Color3.fromRGB(120, 84, 56), Enum.Material.Wood))
		local board = nc(makePart(stall, "StallSign", Vector3.new(5.5, 1.5, 0.25), cf * CFrame.new(0, 3.55, -2.7),
			Color3.fromRGB(52, 38, 34), Enum.Material.Wood))
		attachSign(board, s[2], nil, s[3])
		-- The vendor, behind the counter, arms forward on it.
		makeFigure(stall, cf * CFrame.new(0, 0, 1.3), shirts[i], Color3.fromRGB(80, 70, 90),
			skins[(i % 3) + 1], "vendor", s[3])
		-- Two stalls get a customer browsing out front.
		if i == 2 or i == 5 then
			makeFigure(stall, cf * CFrame.new(1.6, 0, -4.8) * CFrame.Angles(0, math.rad(180), 0),
				shirts[(i % 7) + 1], Color3.fromRGB(60, 90, 130), skins[((i + 1) % 3) + 1], "stand", nil)
		end
	end
	makeGantrySign(world, Vector3.new(81.9, 9.6, 57.4), Vector3.new(0, 8, 0), 19, 4.2,
		"MAGMA MARKET", "Seven stalls of snacks and shiny things", Color3.fromRGB(255, 150, 60),
		Color3.fromRGB(96, 70, 50), true)
end

-- PLAZA CENTREPIECE: a tiered lava fountain on the plaza-to-parade
-- walkway (0, 104) — clear of the spawn pad (0, 150), the marquee
-- (0, 124) and the parade ring (outer edge r 80). Its lava discs
-- and streams join the existing animatedLava pulse.
local function BuildFountain()
	local f = Instance.new("Folder")
	f.Name = "Fountain"
	f.Parent = world
	local stone = Color3.fromRGB(150, 138, 132)
	local stoneDark = Color3.fromRGB(110, 100, 98)
	nc(makeDisc(f, "FountainBase", 7, 1.0, CFrame.new(0, 0.5, 104), stone, Enum.Material.Slate))
	nc(makeDisc(f, "FountainRim", 7.4, 0.5, CFrame.new(0, 0.95, 104), stoneDark, Enum.Material.Slate))
	nc(makeDisc(f, "FountainMid", 4.6, 0.9, CFrame.new(0, 1.75, 104), stone, Enum.Material.Slate))
	nc(makeDisc(f, "FountainTop", 2.6, 0.8, CFrame.new(0, 2.9, 104), stone, Enum.Material.Slate))
	nc(makeDisc(f, "FountainPillar", 0.85, 3.4, CFrame.new(0, 1.7, 104), stoneDark, Enum.Material.Slate))
	for _, lava in ipairs({
		{ "FountainLavaBase", 6.4, 1.06 }, { "FountainLavaMid", 4.0, 2.26 }, { "FountainLavaTop", 2.0, 3.36 },
		}) do
		local d = nc(makeDisc(f, lava[1], lava[2], 0.18, CFrame.new(0, lava[3], 104),
			Color3.fromRGB(255, 110, 40), Enum.Material.Neon))
		table.insert(animatedLava, d)
	end
	local finial = nc(makePart(f, "FountainFinial", Vector3.new(0.85, 0.85, 0.85), CFrame.new(0, 4.15, 104),
		Color3.fromRGB(255, 110, 40), Enum.Material.Neon))
	finial.Shape = Enum.PartType.Ball
	table.insert(animatedLava, finial)
	-- Falling lava streams: tapered Neon sheets from tier to tier.
	for k = 0, 3 do
		local a1 = math.rad(45 + k * 90)
		local top1 = Vector3.new(1.9 * math.sin(a1), 3.3, 104 + 1.9 * math.cos(a1))
		local bot1 = Vector3.new(3.9 * math.sin(a1), 2.3, 104 + 3.9 * math.cos(a1))
		local s1 = nc(makePart(f, "LavaStream", Vector3.new(0.45, 0.16, (bot1 - top1).Magnitude),
			CFrame.lookAt((top1 + bot1) / 2, bot1), Color3.fromRGB(255, 110, 40), Enum.Material.Neon))
		table.insert(animatedLava, s1)
		local a2 = math.rad(22 + k * 90)
		local top2 = Vector3.new(3.9 * math.sin(a2), 2.25, 104 + 3.9 * math.cos(a2))
		local bot2 = Vector3.new(6.2 * math.sin(a2), 1.1, 104 + 6.2 * math.cos(a2))
		local s2 = nc(makePart(f, "LavaStream", Vector3.new(0.55, 0.16, (bot2 - top2).Magnitude),
			CFrame.lookAt((top2 + bot2) / 2, bot2), Color3.fromRGB(255, 110, 40), Enum.Material.Neon))
		table.insert(animatedLava, s2)
	end
	local crystalColors = {
		Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 130, 220), Color3.fromRGB(150, 255, 170),
		Color3.fromRGB(255, 200, 110), Color3.fromRGB(190, 150, 255), Color3.fromRGB(255, 120, 120),
	}
	for k = 1, 6 do
		local a = math.rad(k * 60 + 15)
		nc(makePart(f, "FountainCrystal", Vector3.new(0.7, 2.2, 0.7),
			CFrame.new(8.6 * math.sin(a), 0.9, 104 + 8.6 * math.cos(a)) * CFrame.Angles(0.4, a, 0.3),
			crystalColors[k], Enum.Material.Glass))
	end
	-- A visitor waving at the fountain.
	makeFigure(f, CFrame.lookAt(Vector3.new(5.5, 0, 95), Vector3.new(0, 0, 104)),
		Color3.fromRGB(90, 200, 220), Color3.fromRGB(70, 70, 80), Color3.fromRGB(198, 150, 110), "wave", nil)
end

-- GROUND BREAKUP: a warm ring road inside the parade ring, tiled
-- walking paths from the plaza to the zones, and more coloured
-- ground patches — no big unbroken flat surface left.
local function BuildGroundDressing()
	for i = 0, 43 do
		local ang = (i / 44) * math.pi * 2
		local x, z = 95 * math.cos(ang), 95 * math.sin(ang)
		nc(makePart(world, "RingRoad", Vector3.new(7.6, 0.18, 5),
			CFrame.lookAt(Vector3.new(x, 0.09, z), Vector3.new(0, 0.09, 0)),
			(i % 2 == 0) and Color3.fromRGB(196, 164, 128) or Color3.fromRGB(174, 142, 114),
			Enum.Material.Sandstone))
	end
	local function layPath(x1, z1, x2, z2)
		local dist = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
		local steps = math.ceil(dist / 5)
		for s = 0, steps do
			local t = s / steps
			nc(makeDisc(world, "PathTile", 1.9, 0.16,
				CFrame.new(x1 + (x2 - x1) * t, 0.08, z1 + (z2 - z1) * t),
				(s % 2 == 0) and Color3.fromRGB(238, 220, 180) or Color3.fromRGB(240, 150, 120),
				Enum.Material.Sandstone))
		end
	end
	layPath(6, 136, -50, 104) -- plaza -> Beach Pool
	layPath(10, 134, 76, 64) -- plaza -> Magma Market
	layPath(-14, 128, -108, -30) -- plaza -> Obsidian Fields stairs
	layPath(16, 150, 54, 192) -- plaza -> the docks
	for _, p in ipairs({
		{ 135, -55, 20, Color3.fromRGB(110, 190, 90) },
		{ 150, -5, 18, Color3.fromRGB(245, 150, 130) },
		{ 30, -145, 22, Color3.fromRGB(240, 214, 160) },
		{ -160, -25, 20, Color3.fromRGB(110, 190, 90) },
		{ -152, 80, 18, Color3.fromRGB(245, 150, 130) },
		{ 95, -105, 20, Color3.fromRGB(110, 190, 90) },
		}) do
		nc(makeDisc(world, "GroundPatch", p[3], 0.14, CFrame.new(p[1], 0.07, p[2]), p[4], Enum.Material.SmoothPlastic))
	end
end

-- BEACH + OCEAN LIFE: rock and coral in the shallows, striped
-- buoys, three bobbing boats off the coasts, and a banded
-- lighthouse on its own rock with a rotating beam.
local function BuildOceanLife()
	for _, cl in ipairs({ { 200, 214 }, { 250, 220 }, { 300, 208 }, { 340, 216 }, { 30, 222 } }) do
		local ang = math.rad(cl[1])
		local cx, cz = cl[2] * math.cos(ang), cl[2] * math.sin(ang)
		for j = 1, 3 do
			local s = 3.2 + j * 0.9
			nc(makePart(world, "ShallowRock", Vector3.new(s, s * 0.7, s * 0.85),
				CFrame.new(cx + (j - 2) * 3.4, -1.2, cz + ((j % 2) * 5) - 2.5) * CFrame.Angles(0.3, j * 1.3, 0.2),
				Color3.fromRGB(128, 120, 118), Enum.Material.Slate))
		end
	end
	local coralColors = { Color3.fromRGB(255, 130, 170), Color3.fromRGB(255, 160, 80), Color3.fromRGB(190, 130, 255) }
	for j = 1, 10 do
		local ang = math.rad(20 + j * 21)
		local r = 203 + (j % 3) * 4
		local coral = nc(makePart(world, "Coral", Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(r * math.cos(ang), -1.4, r * math.sin(ang)), coralColors[(j % 3) + 1], Enum.Material.SmoothPlastic))
		coral.Shape = Enum.PartType.Ball
	end
	for j = 1, 6 do
		local ang = math.rad(j * 55 + 15)
		local bx, bz = 235 * math.cos(ang), 235 * math.sin(ang)
		nc(makeDisc(world, "Buoy", 0.9, 1.6, CFrame.new(bx, -1.1, bz),
			(j % 2 == 0) and Color3.fromRGB(230, 60, 50) or Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic))
		local tip = nc(makePart(world, "BuoyTip", Vector3.new(0.55, 0.55, 0.55), CFrame.new(bx, 0.05, bz),
			Color3.fromRGB(255, 160, 60), Enum.Material.Neon))
		tip.Shape = Enum.PartType.Ball
	end
	local function buildBoat(name, x, z, lookX, lookZ, sailColor, phase)
		local boat = Instance.new("Model")
		boat.Name = name
		boat.Parent = world
		local cf = CFrame.lookAt(Vector3.new(x, -1.9, z), Vector3.new(lookX, -1.9, lookZ))
		local hullWood = Color3.fromRGB(122, 84, 54)
		nc(makePart(boat, "Hull", Vector3.new(3.0, 1.1, 7.2), cf * CFrame.new(0, 0.55, 0), hullWood, Enum.Material.Wood))
		for _, sx in ipairs({ -1.35, 1.35 }) do
			nc(makePart(boat, "Gunwale", Vector3.new(0.3, 0.5, 7.2), cf * CFrame.new(sx, 1.25, 0),
				Color3.fromRGB(90, 60, 38), Enum.Material.Wood))
		end
		nc(makePart(boat, "Bow", Vector3.new(2.6, 1.0, 2.2),
			cf * CFrame.new(0, 0.6, -4.2) * CFrame.Angles(0, math.rad(45), 0), hullWood, Enum.Material.Wood))
		nc(makePart(boat, "Stern", Vector3.new(3.0, 1.3, 0.4), cf * CFrame.new(0, 0.8, 3.5),
			Color3.fromRGB(90, 60, 38), Enum.Material.Wood))
		nc(makePart(boat, "Mast", Vector3.new(0.28, 6.0, 0.28), cf * CFrame.new(0, 3.6, -0.3),
			Color3.fromRGB(96, 70, 50), Enum.Material.Wood))
		nc(makePart(boat, "Sail", Vector3.new(2.7, 3.8, 0.14), cf * CFrame.new(0, 3.9, 0.85),
			Color3.fromRGB(246, 242, 235), Enum.Material.SmoothPlastic))
		nc(makePart(boat, "Flag", Vector3.new(0.9, 0.55, 0.1), cf * CFrame.new(0.45, 6.9, -0.3),
			sailColor, Enum.Material.Neon))
		nc(makePart(boat, "BoatCrate", Vector3.new(1.1, 1.1, 1.1), cf * CFrame.new(0.6, 1.6, 2.6),
			Color3.fromRGB(160, 118, 78), Enum.Material.Wood))
		nc(makeDisc(boat, "BoatBarrel", 0.55, 1.1, cf * CFrame.new(-0.7, 1.6, 2.2),
			Color3.fromRGB(120, 84, 56), Enum.Material.Wood))
		table.insert(decoMovers, { name = name, kind = "boat", base = boat:GetPivot(), phase = phase })
	end
	buildBoat("Boat1", 88, 250, 140, 262, Color3.fromRGB(255, 120, 80), 0)
	buildBoat("Boat2", -128, 208, -190, 190, Color3.fromRGB(110, 220, 255), 2.1)
	buildBoat("Boat3", 228, -52, 280, -90, Color3.fromRGB(255, 200, 90), 4.2)
	-- The lighthouse: rock stack, four red/white bands, gallery,
	-- Neon lamp and the rotating beam the ambient loop sweeps.
	local lh = Instance.new("Folder")
	lh.Name = "Lighthouse"
	lh.Parent = world
	nc(makeDisc(lh, "LightRock", 7.5, 2, CFrame.new(152, -0.8, -152), Color3.fromRGB(120, 112, 110), Enum.Material.Slate))
	nc(makeDisc(lh, "LightRock", 5.5, 2, CFrame.new(152, 0.6, -152), Color3.fromRGB(132, 124, 122), Enum.Material.Slate))
	for i = 0, 3 do
		nc(makeDisc(lh, "LightBand", 3.0, 3.2, CFrame.new(152, 3.2 + i * 3.2, -152),
			(i % 2 == 0) and Color3.fromRGB(242, 240, 235) or Color3.fromRGB(215, 60, 55), Enum.Material.SmoothPlastic))
	end
	nc(makeDisc(lh, "LightGallery", 3.9, 0.5, CFrame.new(152, 14.65, -152), Color3.fromRGB(70, 58, 55), Enum.Material.Slate))
	local lampBall = nc(makePart(lh, "LightLamp", Vector3.new(2.2, 2.2, 2.2), CFrame.new(152, 16.1, -152),
		Color3.fromRGB(255, 230, 150), Enum.Material.Neon))
	lampBall.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 140)
	light.Range = 60
	light.Brightness = 2
	light.Parent = lampBall
	nc(makeDisc(lh, "LightCap", 2.4, 1.8, CFrame.new(152, 17.9, -152), Color3.fromRGB(70, 58, 55), Enum.Material.Slate))
	local beam = nc(makePart(world, "LighthouseBeam", Vector3.new(1.3, 1.3, 30),
		CFrame.new(152, 16.1, -152) * CFrame.new(0, 0, -15.5), Color3.fromRGB(255, 240, 180), Enum.Material.Neon))
	beam.Transparency = 0.55
	table.insert(decoMovers, { name = "LighthouseBeam", kind = "beam", base = Vector3.new(152, 16.1, -152) })
end

-- SIGNAGE + LIFE: directional signs, pennant strings over the
-- market / plaza / dock, orb lamps along the ring road, and the
-- plaza + dock inhabitants.
local function BuildSignageLife()
	makeSignPost(world, Vector3.new(34, 4.8, 176), Vector3.new(0, 4, 148), 11, 3.2,
		"THE DOCKS", "Boats and sea breeze", Color3.fromRGB(80, 200, 210))
	makeSignPost(world, Vector3.new(-42, 4.8, 118), Vector3.new(0, 4, 140), 12, 3.2,
		"BEACH POOL", "Mind the lava - it is warm", Color3.fromRGB(90, 180, 255))
	makeSignPost(world, Vector3.new(64, 4.8, 40), Vector3.new(30, 4, 90), 13, 3.2,
		"MAGMA MARKET", "Seven stalls of snacks", Color3.fromRGB(255, 150, 60))
	-- Pennant poles: market arc (r 106), plaza crossing, dock mouth.
	local poleTops = {}
	local function pennantPole(x, z, h)
		nc(makePart(world, "PennantPole", Vector3.new(0.35, h, 0.35), CFrame.new(x, h / 2, z),
			Color3.fromRGB(110, 80, 54), Enum.Material.Wood))
		local tip = nc(makePart(world, "PoleTip", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, h + 0.25, z),
			Color3.fromRGB(255, 220, 130), Enum.Material.Neon))
		tip.Shape = Enum.PartType.Ball
		table.insert(poleTops, Vector3.new(x, h, z))
	end
	pennantPole(102.4, 27.4, 9.5)
	pennantPole(86.8, 60.8, 9.5)
	pennantPole(60.8, 86.8, 9.5)
	makePennants(world, poleTops[1], poleTops[2])
	makePennants(world, poleTops[2], poleTops[3])
	pennantPole(-21, 142, 10)
	pennantPole(21, 142, 10)
	makePennants(world, poleTops[4], poleTops[5])
	pennantPole(51, 192, 8.5)
	pennantPole(65, 192, 8.5)
	makePennants(world, poleTops[6], poleTops[7])
	-- Orb lamps along the ring road.
	for _, deg in ipairs({ 30, 90, 150, 210, 270, 330 }) do
		local ang = math.rad(deg)
		makeOrbLamp(world, 95 * math.cos(ang), 0, 95 * math.sin(ang))
	end
	-- Plaza stall vendors (behind the two existing plaza counters).
	makeFigure(world, CFrame.lookAt(Vector3.new(28.3, 0, 160.6), Vector3.new(0, 0, 148)),
		Color3.fromRGB(240, 120, 90), Color3.fromRGB(80, 70, 90), Color3.fromRGB(255, 205, 160), "vendor",
		Color3.fromRGB(255, 170, 60))
	makeFigure(world, CFrame.lookAt(Vector3.new(-28.3, 0, 160.6), Vector3.new(0, 0, 148)),
		Color3.fromRGB(110, 190, 240), Color3.fromRGB(70, 80, 100), Color3.fromRGB(140, 100, 70), "vendor",
		Color3.fromRGB(120, 220, 160))
	-- Visitors: one waving by the Chief, one at the dock hut gazing
	-- out to sea, one strolling to the Beach Pool.
	makeFigure(world, CFrame.lookAt(Vector3.new(-13, 0, 136), Vector3.new(17, 0, 134)),
		Color3.fromRGB(250, 200, 80), Color3.fromRGB(90, 90, 110), Color3.fromRGB(198, 150, 110), "wave", nil)
	makeFigure(world, CFrame.lookAt(Vector3.new(58, 0, 224), Vector3.new(58, 0, 300)),
		Color3.fromRGB(150, 220, 160), Color3.fromRGB(70, 90, 120), Color3.fromRGB(255, 205, 160), "stand", nil)
	makeFigure(world, CFrame.lookAt(Vector3.new(-52, 0, 108), Vector3.new(-62, 0, 98)),
		Color3.fromRGB(230, 130, 200), Color3.fromRGB(80, 70, 95), Color3.fromRGB(140, 100, 70), "stand", nil)
end

-- A small overhead name tag on a figure's head — the BillboardGui
-- pattern the brainrot cast labels use, shrunk to one friendly
-- first name. Parented to the Head part, so it rides wherever the
-- figure is placed (or walked) for free.
local function makeNameTag(fig, name)
	local head = fig:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(140, 32)
	gui.StudsOffset = Vector3.new(0, 1.05, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	gui.Parent = head
	local l = makeLabel(gui, "Name", name, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0),
		Enum.Font.GothamBold, 16, Color3.fromRGB(255, 250, 235))
	l.TextStrokeTransparency = 0.35
end

-- VILLAGERS: six islanders who actually WALK the island on one big
-- looping route — plaza -> market row fronts -> the booths apron
-- -> down the dock path and back -> the Beach Pool path -> home —
-- plus two chatting pairs (market, fountain). A solo playtest (and
-- the judging screenshots) should never feel like a ghost town.
-- The route stays on flat ground (y = 0) the whole way: outside
-- the parade ring (outer edge r 80), in front of the market
-- counters (fronts at r 104, counters end at r 109), behind the
-- stalls along the booths apron (r 124, plot fronts at r 133),
-- skirting the plaza disc (r 17 at (0, 150)) and the fountain
-- (crystal ring r 8.6 at (0, 104)). Every waypoint was checked
-- against the signs, palms and stalls it passes.
-- Movement rides the ambient loop via decoMovers (kind
-- "villager"): each figure's part offsets are captured at build
-- time relative to its start CFrame, and the loop re-places every
-- part from the clock each pass — position, bob and limb swing
-- are pure functions of time, so a heal/rebuild can never desync
-- a walker, and the loop stays nil-safe if one is missing.
local function BuildVillagers()
	local pts = {
		Vector3.new(0, 0, 134), Vector3.new(24, 0, 122), Vector3.new(48.8, 0, 91.8),
		Vector3.new(73.5, 0, 73.5), Vector3.new(91.8, 0, 48.8), Vector3.new(102.4, 0, 18.1),
		Vector3.new(116.5, 0, 42.4), Vector3.new(95, 0, 79.7), Vector3.new(62, 0, 107.4),
		Vector3.new(21.5, 0, 121), Vector3.new(-21.5, 0, 121), Vector3.new(6, 0, 130),
		Vector3.new(24, 0, 138), Vector3.new(42, 0, 166), Vector3.new(54, 0, 190),
		Vector3.new(44, 0, 195), Vector3.new(36, 0, 164), Vector3.new(18, 0, 140),
		Vector3.new(-14, 0, 120), Vector3.new(-34, 0, 110), Vector3.new(-46, 0, 100),
		Vector3.new(-28, 0, 118), Vector3.new(4, 0, 116),
	}
	local segs, total = {}, 0
	for i = 1, #pts do
		local a, b = pts[i], pts[(i % #pts) + 1]
		local len = (b - a).Magnitude
		segs[i] = { a = a, b = b, len = len, dir = (b - a) / len }
		total += len
	end
	local route = { segs = segs, total = total }
	local function routePoint(d)
		d = d % total
		for _, s in ipairs(segs) do
			if d <= s.len then
				return s.a:Lerp(s.b, d / s.len), s.dir
			end
			d -= s.len
		end
		return segs[#segs].b, segs[#segs].dir
	end
	local folk = {
		{ name = "Bimo", shirt = Color3.fromRGB(240, 90, 80), pants = Color3.fromRGB(70, 80, 110),
			skin = Color3.fromRGB(255, 205, 160), hat = Color3.fromRGB(255, 170, 60) },
		{ name = "Sari", shirt = Color3.fromRGB(250, 200, 80), pants = Color3.fromRGB(90, 90, 120),
			skin = Color3.fromRGB(198, 150, 110), hat = nil },
		{ name = "Dedi", shirt = Color3.fromRGB(90, 200, 255), pants = Color3.fromRGB(60, 70, 90),
			skin = Color3.fromRGB(140, 100, 70), hat = Color3.fromRGB(120, 220, 160) },
		{ name = "Rina", shirt = Color3.fromRGB(230, 130, 200), pants = Color3.fromRGB(80, 70, 95),
			skin = Color3.fromRGB(255, 205, 160), hat = nil },
		{ name = "Joko", shirt = Color3.fromRGB(120, 210, 110), pants = Color3.fromRGB(70, 90, 120),
			skin = Color3.fromRGB(198, 150, 110), hat = Color3.fromRGB(255, 120, 80) },
		{ name = "Maya", shirt = Color3.fromRGB(180, 110, 230), pants = Color3.fromRGB(60, 60, 85),
			skin = Color3.fromRGB(140, 100, 70), hat = nil },
	}
	for i, f in ipairs(folk) do
		-- Even phase spacing on the shared loop at one shared speed:
		-- the six stay spread around the island forever, never bunch.
		local phase = (i - 1) * total / #folk
		local p0, d0 = routePoint(phase)
		local cf0 = CFrame.lookAt(p0, p0 + d0)
		local fig = makeFigure(world, cf0, f.shirt, f.pants, f.skin, "stand", f.hat)
		fig.Name = "Villager_" .. f.name
		makeNameTag(fig, f.name)
		local parts = {}
		for _, ch in ipairs(fig:GetChildren()) do
			if ch:IsA("BasePart") then
				local rec = { n = ch.Name, cf = cf0:Inverse() * ch.CFrame }
				if ch.Name == "LegL" or ch.Name == "LegR" or ch.Name == "ArmL" or ch.Name == "ArmR" then
					local half = ch.Size.Y / 2
					rec.swing = {
						pivot = rec.cf.Position + Vector3.new(0, half, 0),
						half = half,
						k = (ch.Name == "LegL" and 0.45) or (ch.Name == "LegR" and -0.45)
							or (ch.Name == "ArmL" and -0.3) or 0.3,
					}
				end
				table.insert(parts, rec)
			end
		end
		table.insert(decoMovers, {
			name = fig.Name, kind = "villager", route = route,
			speed = 7, phase = phase, parts = parts,
		})
	end
	-- Chatting pair at the market: two islanders facing each other
	-- in front of the SNACKS stall (the stall math from
	-- BuildMarketRow, angle 35, fronts toward the island centre).
	local sang = math.rad(35)
	local scf = CFrame.lookAt(
		Vector3.new(112 * math.cos(sang), 0, 112 * math.sin(sang)), Vector3.new(0, 0, 0))
	local mA = (scf * CFrame.new(-1.8, 0, -5.6)).Position
	local mB = (scf * CFrame.new(1.8, 0, -5.6)).Position
	local tono = makeFigure(world, CFrame.lookAt(mA, mB),
		Color3.fromRGB(255, 150, 60), Color3.fromRGB(70, 80, 100), Color3.fromRGB(255, 205, 160), "stand", nil)
	makeNameTag(tono, "Tono")
	local wati = makeFigure(world, CFrame.lookAt(mB, mA),
		Color3.fromRGB(110, 220, 255), Color3.fromRGB(80, 70, 95), Color3.fromRGB(198, 150, 110), "stand",
		Color3.fromRGB(250, 130, 190))
	makeNameTag(wati, "Wati")
	-- Chatting pair at the fountain, west side, clear of the
	-- crystal ring (r 8.6) and of the villagers' route south of it.
	local fA, fB = Vector3.new(-8, 0, 97), Vector3.new(-11, 0, 100.5)
	local rudi = makeFigure(world, CFrame.lookAt(fA, fB),
		Color3.fromRGB(150, 220, 160), Color3.fromRGB(60, 70, 90), Color3.fromRGB(140, 100, 70), "stand", nil)
	makeNameTag(rudi, "Rudi")
	local sinta = makeFigure(world, CFrame.lookAt(fB, fA),
		Color3.fromRGB(255, 110, 90), Color3.fromRGB(90, 90, 110), Color3.fromRGB(255, 205, 160), "stand", nil)
	makeNameTag(sinta, "Sinta")
end

-- PALMS: sixteen curved palms — the empty north/west/east shore
-- ring, the gaps between booths (in front of the plot line, never
-- blocking an entrance), and a pair watching the dock.
local function BuildPalms()
	local shore = { { 185, 124 }, { 205, 130 }, { 230, 122 }, { 255, 128 }, { 280, 124 }, { 305, 130 }, { 330, 122 }, { 355, 126 } }
	for i, s in ipairs(shore) do
		local ang = math.rad(s[1])
		local x, z = s[2] * math.cos(ang), s[2] * math.sin(ang)
		makePalm(world, x, 0, z, 9 + (i % 4), math.cos(ang), math.sin(ang))
	end
	for i, deg in ipairs({ 35, 57, 79, 101, 123, 145 }) do
		local ang = math.rad(deg)
		local x, z = 116 * math.cos(ang), 116 * math.sin(ang)
		makePalm(world, x, 0, z, 9.5 + (i % 3), math.cos(ang), math.sin(ang))
	end
	makePalm(world, 38, 0, 184, 10.5, -0.3, 0.95)
	makePalm(world, 80, 0, 176, 9.5, 0.4, 0.9)
end

-- SKY LAYER: floating islets with crystals for eye-level depth, a
-- static smoke-puff ring stack above the crater, and glowing
-- embers frozen mid-drift over the lava lake.
local function BuildSkyLayer()
	for idx, islet in ipairs({ { 280, 55, -180 }, { -300, 68, 140 }, { 60, 82, -320 } }) do
		local x, y, z = islet[1], islet[2], islet[3]
		local g = Instance.new("Folder")
		g.Name = "SkyIslet" .. idx
		g.Parent = world
		nc(makeDisc(g, "IsletRock", 9, 2.2, CFrame.new(x, y - 1, z), Color3.fromRGB(126, 110, 104), Enum.Material.Slate))
		nc(makeDisc(g, "IsletGrass", 8.6, 0.7, CFrame.new(x, y + 0.4, z), Color3.fromRGB(105, 185, 95), Enum.Material.SmoothPlastic))
		nc(makeDisc(g, "IsletUnder", 6.5, 3, CFrame.new(x, y - 3.6, z), Color3.fromRGB(116, 102, 98), Enum.Material.Slate))
		nc(makeDisc(g, "IsletUnder", 4, 3.5, CFrame.new(x, y - 6.6, z), Color3.fromRGB(106, 94, 90), Enum.Material.Slate))
		nc(makeDisc(g, "IsletTip", 1.8, 4, CFrame.new(x, y - 10, z), Color3.fromRGB(96, 86, 84), Enum.Material.Slate))
		local cols = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 150, 220), Color3.fromRGB(170, 255, 190) }
		for k = 1, 3 do
			local a = math.rad(k * 120 + idx * 40)
			nc(makePart(g, "IsletCrystal", Vector3.new(0.8, 3, 0.8),
				CFrame.new(x + 4.5 * math.sin(a), y + 2, z + 4.5 * math.cos(a)) * CFrame.Angles(0.35, a, 0.25),
				cols[k], Enum.Material.Glass))
		end
		if idx == 1 then
			makePalm(g, x + 2, y + 0.75, z - 2, 6, 0.3, 0.9)
		end
	end
	for ring, cfg in ipairs({ { 80, 5.5 }, { 90.5, 8 }, { 101, 10.5 } }) do
		for j = 0, 7 do
			local a = (j / 8) * math.pi * 2 + ring * 0.4
			local puff = nc(makePart(world, "SmokePuff", Vector3.new(3.4, 3.4, 3.4),
				CFrame.new(cfg[2] * math.cos(a), cfg[1], cfg[2] * math.sin(a)),
				Color3.fromRGB(240, 244, 248), Enum.Material.SmoothPlastic))
			puff.Shape = Enum.PartType.Ball
			puff.Transparency = 0.3
		end
	end
	for j = 1, 14 do
		local a = j * 2.399963
		local r = 1.5 + (j % 5) * 1.3
		local ember = nc(makePart(world, "Ember", Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(r * math.cos(a), 71 + j * 1.8, r * math.sin(a)),
			Color3.fromRGB(255, 150, 50), Enum.Material.Neon))
		ember.Shape = Enum.PartType.Ball
	end
end

-- CRATER RIM ACCESS (audit + fix): the old RimSteps start floating
-- at y 8.3 under the shelf and their top two are buried INSIDE the
-- Rim slab (tops 24.3 / 27.7 vs slab y 20..30) — there was no
-- clean climb to the Rim (top y 30). This flight runs up the open
-- ground east of the volcano: twelve protruding sandstone treads,
-- a flush landing onto the Rim's south-east corner, handrail,
-- stringer, lamps and a base sign — same language as the mesa fix.
local function BuildRimAccess()
	local stone = Color3.fromRGB(226, 192, 148)
	local wood = Color3.fromRGB(110, 78, 50)
	for i = 0, 11 do
		local top = 2.5 * (i + 1)
		local front = -33 - i * 2.9
		makePart(world, "RimFlightStep", Vector3.new(8, top, 5.5), CFrame.new(56, top / 2, front - 2.75),
			stone, Enum.Material.Sandstone)
		local nosing = makePart(world, "RimNosing", Vector3.new(8.2, 0.28, 0.5),
			CFrame.new(56, top - 0.14, front + 0.1), wood, Enum.Material.Wood)
		nosing.CanCollide = false
	end
	-- Landing flush with the Rim top (y 30.0), bridging west from
	-- the flight onto the shelf.
	makePart(world, "RimLanding", Vector3.new(14, 1.2, 7), CFrame.new(51, 29.4, -67),
		stone, Enum.Material.Sandstone)
	local beamMid = Vector3.new(60.4, 15, -48.95)
	local beam = makePart(world, "RimStringer", Vector3.new(0.55, 0.9, 44.1),
		CFrame.lookAt(beamMid, Vector3.new(60.4, 29.6, -65.5)), wood, Enum.Material.Wood)
	beam.CanCollide = false
	for _, post in ipairs({ { -38, 5.0 }, { -47, 12.5 }, { -56, 20.0 }, { -63, 27.5 } }) do
		makePart(world, "RimRailPost", Vector3.new(0.35, 2.6, 0.35),
			CFrame.new(59.6, post[2] + 1.3, post[1]), wood, Enum.Material.Wood)
	end
	local railMid = Vector3.new(59.6, 18.97, -50.5)
	local rail = makePart(world, "RimRail", Vector3.new(0.28, 0.28, 34.8),
		CFrame.lookAt(railMid, Vector3.new(59.6, 30.2, -63.8)), wood, Enum.Material.Wood)
	rail.CanCollide = false
	makeOrbLamp(world, 63.5, 0, -29)
	makeOrbLamp(world, 46, 30, -66)
	makeSignPost(world, Vector3.new(56, 7.7, -25.5), Vector3.new(56, 5, 90), 15, 4.2,
		"CRATER RIM", "Stairs up - Rekindle 3 zone", Color3.fromRGB(255, 120, 60))
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

-- Ambient life loop: boats bobbing at anchor, the lighthouse
-- beam sweeping the bay, and the villagers walking their loop.
-- This is the ONE decoration-only motion loop: it re-finds its
-- parts by name under the world folder on every pass (a
-- heal/rebuild simply leaves it idling on nils), its body is
-- pcall-wrapped so an error can never reach gameplay, and it
-- never reads or writes Game state. It ticks at 0.06 s so the
-- walkers glide instead of stepping (the boats and beam are pure
-- functions of the clock, so the faster tick only smooths them).
task.spawn(function()
	while true do
		pcall(function()
			local t = os.clock()
			for _, mv in ipairs(decoMovers) do
				local inst = world:FindFirstChild(mv.name, true)
				if inst then
					if mv.kind == "boat" and inst:IsA("Model") then
						inst:PivotTo(mv.base
							* CFrame.new(0, math.sin(t * 0.9 + mv.phase) * 0.3, 0)
							* CFrame.Angles(math.sin(t * 0.7 + mv.phase) * 0.02, 0, math.cos(t * 0.8 + mv.phase) * 0.03))
					elseif mv.kind == "beam" and inst:IsA("BasePart") then
						inst.CFrame = CFrame.new(mv.base) * CFrame.Angles(0, t * 0.45, 0) * CFrame.new(0, 0, -15.5)
					elseif mv.kind == "villager" and inst:IsA("Model") then
						-- Walk the shared loop: distance along the
						-- route is a pure function of the clock, so
						-- position, heading, bob and limb swing all
						-- agree with each other on every pass.
						local d = (t * mv.speed + mv.phase) % mv.route.total
						local pos, dir, acc = nil, nil, 0
						for _, s in ipairs(mv.route.segs) do
							if d <= acc + s.len then
								pos = s.a:Lerp(s.b, (d - acc) / s.len)
								dir = s.dir
								break
							end
							acc += s.len
						end
						if pos and dir then
							local ph = d * 2.2
							local bob = math.abs(math.sin(ph)) * 0.13
							local frame = CFrame.lookAt(
								Vector3.new(pos.X, bob, pos.Z),
								Vector3.new(pos.X + dir.X, bob, pos.Z + dir.Z))
								* CFrame.Angles(0, 0, math.sin(ph) * 0.035)
							local sw = math.sin(ph)
							for _, pe in ipairs(mv.parts) do
								local p = inst:FindFirstChild(pe.n)
								if p then
									if pe.swing then
										p.CFrame = frame * (CFrame.new(pe.swing.pivot)
											* CFrame.Angles(sw * pe.swing.k, 0, 0)
											* CFrame.new(0, -pe.swing.half, 0))
									else
										p.CFrame = frame * pe.cf
									end
								end
							end
						end
					end
				end
			end
		end)
		task.wait(0.06)
	end
end)

--====================================================================--
-- FINAL DENSITY PASS: colour the grey mid-ground + neon ground trim
--
-- Akmal's verdict on the villager build, twice over: still "kurang
-- padet / kurang rame". His high-angle screenshot shows why — the
-- booth / market / volcano cores are busy, but the big grey flats
-- between zones read empty and muted, and the #2 leaderboard sheet
-- gets its crowded look largely from NEON GROUND TRIMMING: bright
-- glowing edge strips lining its paths and pads against darker
-- ground. So this pass does exactly those two things, decoration
-- only, under the same world folder (heal/rebuild pattern intact):
--   1. a patchwork of flat coloured ground discs over the bare
--      flats (ash band around the volcano, north / east / west
--      shores, the gaps between apron, plaza and beach path);
--   2. thin Neon trim strips edging the ring road's outer edge,
--      the plaza rim and the booths apron front, cycling cyan /
--      hot pink / warm yellow like the #2 sheet;
--   3. prop vignettes (crate clusters, rock piles with palm
--      saplings, torch stands) grouped in the flats, never on a
--      walkway, path, pad or the villagers' route;
--   4. three more pennant strings across the plaza / market /
--      apron sightlines for colour at eye level.
-- Nothing here touches a gameplay position or Game state, and the
-- static parts need no decoMovers registration.
--====================================================================--

local function BuildFinalDensity()
	-- 1. Ground patchwork: flat discs (top Y = 0.16, above the ash
	-- field's 0.08 and both older patch layers, below the beach
	-- discs) in the island's four clearing colours.
	local patchSand = Color3.fromRGB(238, 202, 140)
	local patchTeal = Color3.fromRGB(64, 196, 178)
	local patchCoral = Color3.fromRGB(245, 140, 110)
	local patchGrass = Color3.fromRGB(116, 186, 104)
	for _, p in ipairs({
		-- the ash band around the volcano base (r 81-101)
		{ -84, -31, 10, patchTeal }, { 42, -80, 9, patchGrass }, { -80, 45, 9, patchSand },
		-- north flats and shore
		{ 75, -150, 13, patchTeal }, { -15, -165, 15, patchCoral }, { -25, -140, 10, patchGrass },
		{ 135, -120, 15, patchSand }, { 105, -70, 11, patchSand },
		-- east flats and shore
		{ 176, 28, 12, patchSand }, { 165, -85, 12, patchTeal }, { 175, -30, 11, patchCoral },
		{ 142, 112, 12, patchTeal }, { 120, 140, 10, patchGrass },
		-- west flats and shore
		{ -70, -8, 11, patchTeal }, { -66, 64, 10, patchCoral },
		{ -112, 108, 11, patchTeal }, { -172, 42, 12, patchSand },
		}) do
		nc(makeDisc(world, "GroundPatch", p[3], 0.16, CFrame.new(p[1], 0.08, p[2]),
			p[4], Enum.Material.SmoothPlastic))
	end

	-- 2. Neon ground trim: thin glowing strips (top Y = 0.18) in
	-- the #2 sheet's cyan / pink / yellow cycle.
	local neonCycle = {
		Color3.fromRGB(64, 225, 255), Color3.fromRGB(255, 92, 200), Color3.fromRGB(255, 205, 60),
	}
	local function neonStrip(x, z, lookX, lookZ, length, color)
		nc(makePart(world, "NeonTrim", Vector3.new(length, 0.16, 0.8),
			CFrame.lookAt(Vector3.new(x, 0.1, z), Vector3.new(lookX, 0.1, lookZ)),
			color, Enum.Material.Neon))
	end
	-- (a) the ring road's outer edge (r 98.6, just outside the
	-- road tiles at r 92.5-97.5, inside the tiki ring at r 100):
	-- a dashed glow line all the way around the parade.
	for i = 0, 23 do
		local a = (i / 24) * math.pi * 2 + 0.1
		neonStrip(98.6 * math.cos(a), 98.6 * math.sin(a), 0, 0, 9.8, neonCycle[(i % 3) + 1])
	end
	-- (b) the plaza rim: a near-continuous glow ring on the ground
	-- around the plaza disc's base (plaza r 17 at (0, 150)).
	for i = 0, 13 do
		local a = (i / 14) * math.pi * 2
		neonStrip(18.2 * math.cos(a), 150 + 18.2 * math.sin(a), 0, 150, 7.6, neonCycle[(i % 3) + 1])
	end
	-- (c) the booths apron front edge (r 128.5, between the
	-- villagers' apron lane at r 124 and the plot steps at r 130+),
	-- dashed along the whole south fan the plots occupy.
	for i = 0, 11 do
		local a = math.rad(20 + i * (140 / 11))
		neonStrip(128.5 * math.cos(a), 128.5 * math.sin(a), 0, 0, 12.5, neonCycle[(i % 3) + 1])
	end

	-- 3. Prop vignettes in the flats, grouped like little supply
	-- dumps and clearings — never uniform confetti.
	local function crateCluster(x, z, yaw, c1, c2, c3)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		makePart(world, "Crate", Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(0, 1.2, 0),
			c1, Enum.Material.Wood)
		makePart(world, "Crate", Vector3.new(2, 2, 2), cf * CFrame.new(1.8, 1, 1.4),
			c2, Enum.Material.Wood)
		makePart(world, "Crate", Vector3.new(1.7, 1.7, 1.7), cf * CFrame.new(0.4, 3.25, 0.2),
			c3, Enum.Material.Wood)
		local barrel = makePart(world, "Barrel", Vector3.new(1.7, 2.6, 1.7), cf * CFrame.new(-2.1, 1.3, 1.2),
			Color3.fromRGB(150, 104, 66), Enum.Material.Wood)
		barrel.Shape = Enum.PartType.Cylinder
		local band = makePart(world, "BarrelBand", Vector3.new(1.85, 0.35, 1.85), cf * CFrame.new(-2.1, 1.9, 1.2),
			Color3.fromRGB(255, 92, 200), Enum.Material.Neon)
		band.Shape = Enum.PartType.Cylinder
		band.CanCollide = false
	end
	local crateA = { Color3.fromRGB(32, 178, 190), Color3.fromRGB(255, 110, 90), Color3.fromRGB(255, 205, 60) }
	local crateB = { Color3.fromRGB(255, 150, 60), Color3.fromRGB(90, 200, 255), Color3.fromRGB(140, 230, 90) }
	crateCluster(88, -52, 0.5, crateA[1], crateA[2], crateA[3]) -- NE inner flat
	crateCluster(-118, -8, 1.2, crateB[1], crateB[2], crateB[3]) -- west flat, clear of the Fields path
	crateCluster(155, 65, -0.4, crateA[2], crateA[3], crateA[1]) -- east shore strip
	crateCluster(-142, -28, 0.9, crateB[2], crateB[3], crateB[1]) -- south of the Fields plateau
	crateCluster(48, 128, 2.4, crateA[3], crateA[1], crateA[2]) -- between fountain and plaza

	local function rockSapling(x, z, yaw)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		makePart(world, "ShoreRock", Vector3.new(2.6, 1.8, 2.4), cf * CFrame.new(0, 0.7, 0)
			* CFrame.Angles(0.2, 0.6, 0.15), Color3.fromRGB(140, 130, 124), Enum.Material.Slate)
		makePart(world, "ShoreRock", Vector3.new(1.9, 1.3, 1.7), cf * CFrame.new(2.2, 0.5, 0.8)
			* CFrame.Angles(0.3, 1.7, 0.2), Color3.fromRGB(196, 130, 110), Enum.Material.Slate)
		makePart(world, "ShoreRock", Vector3.new(1.5, 1.0, 1.4), cf * CFrame.new(-1.9, 0.4, 0.9)
			* CFrame.Angles(0.15, 3.1, 0.3), Color3.fromRGB(140, 130, 124), Enum.Material.Slate)
		-- A palm sapling: one slim trunk, three fronds — the big
		-- palms' little sibling, cheap at four parts.
		local top = (cf * CFrame.new(-0.5, 3.1, -2.2)).Position
		nc(makePart(world, "SaplingTrunk", Vector3.new(0.4, 3.2, 0.4), cf * CFrame.new(-0.5, 1.6, -2.2)
			* CFrame.Angles(math.rad(6), 0, math.rad(4)), Color3.fromRGB(146, 108, 74), Enum.Material.Wood))
		for k = 0, 2 do
			local fyaw = yaw + k * (math.pi * 2 / 3) + 0.5
			nc(makePart(world, "SaplingFrond", Vector3.new(0.3, 0.15, 2.6),
				CFrame.new(top + Vector3.new(math.sin(fyaw) * 0.9, 0.15, math.cos(fyaw) * 0.9))
					* CFrame.Angles(0, fyaw, 0) * CFrame.Angles(math.rad(28), 0, 0),
				Color3.fromRGB(74, 168, 84), Enum.Material.SmoothPlastic))
		end
	end
	rockSapling(128, -95, 0.8) -- NE shore flat
	rockSapling(-38, -150, 2.1) -- north shore, beside the coral clearing
	rockSapling(60, -120, 1.4) -- north flat east of the Rim shelf
	rockSapling(-175, -5, 2.8) -- far west shore

	local function torchStand(x, z, yaw)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		makePart(world, "TikiPost", Vector3.new(0.35, 4.4, 0.35), cf * CFrame.new(0, 2.2, 0),
			Color3.fromRGB(110, 80, 54), Enum.Material.Wood)
		local flame = makePart(world, "TikiFlame", Vector3.new(1, 1.25, 1), cf * CFrame.new(0, 4.9, 0),
			Color3.fromRGB(255, 160, 50), Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
		makePart(world, "Crate", Vector3.new(1.7, 1.7, 1.7), cf * CFrame.new(2.2, 0.85, 0.6),
			Color3.fromRGB(32, 178, 190), Enum.Material.Wood)
		local barrel = makePart(world, "Barrel", Vector3.new(1.7, 2.6, 1.7), cf * CFrame.new(-2.0, 1.3, 0.4),
			Color3.fromRGB(150, 104, 66), Enum.Material.Wood)
		barrel.Shape = Enum.PartType.Cylinder
	end
	torchStand(-150, 115, 0.7) -- SW shore flat
	torchStand(95, -135, 1.9) -- north-east shore flat

	-- 4. Pennant strings across the plaza / market / apron
	-- sightlines, strung between the existing poles (tops noted
	-- from BuildSignageLife) plus one new pole east of the market.
	nc(makePart(world, "PennantPole", Vector3.new(0.35, 9.5, 0.35), CFrame.new(128, 4.75, 62),
		Color3.fromRGB(110, 80, 54), Enum.Material.Wood))
	local tip = nc(makePart(world, "PoleTip", Vector3.new(0.5, 0.5, 0.5), CFrame.new(128, 9.75, 62),
		Color3.fromRGB(255, 220, 130), Enum.Material.Neon))
	tip.Shape = Enum.PartType.Ball
	makePennants(world, Vector3.new(21, 10, 142), Vector3.new(60.8, 9.5, 86.8)) -- plaza -> market arc
	makePennants(world, Vector3.new(-21, 10, 142), Vector3.new(51, 8.5, 192)) -- plaza -> dock mouth
	makePennants(world, Vector3.new(102.4, 9.5, 27.4), Vector3.new(128, 9.5, 62)) -- market -> east apron
end

--====================================================================--
-- OBSIDIAN FIELDS DRESSING: the plateau was the last bare slab on
-- the island — a big dark table with a pool in the middle and a
-- watchtower in the corner. This pass gives the zone its own
-- signature: obsidian crystal clusters with Neon tips, pool-side
-- dressing in the Beach Pool's language, a glowing rim line on
-- the cliff faces the island sees, a small ruin on the north
-- side, three inhabitants, and pennant strings tying the
-- watchtower into the plateau. Decoration only — the pool, the
-- stair corridor (x -124..-106) and every walking line on the
-- plateau stay exactly as they were.
--====================================================================--

local function BuildFieldsDressing()
	local topY = 8 -- the plateau's walking surface
	local zonePurple = Color3.fromRGB(170, 120, 255)
	local zoneCyan = Color3.fromRGB(64, 225, 255)

	-- 1. Obsidian crystal clusters: tilted Glass spikes in the
	-- zone's existing shard language, grouped at the edges and
	-- mid areas; the two tallest in each cluster wear a Neon tip.
	-- Centres were checked against the shard/gem field, the pool
	-- deck (r 13.6 at (-112,-112) — every centre is 19+ clear),
	-- the stair corridor and the watchtower footprint.
	local clusters = {
		{ -163, -163 }, { -166, -122 }, { -80, -166 },
		{ -61, -131 }, { -152, -66 }, { -86, -122 },
	}
	local spikePlan = {
		{ 0, 0, 5.5, 1.7, 0.10, 0.06 },
		{ 2.2, 0.8, 3.8, 1.4, -0.08, 0.12 },
		{ -1.9, 1.1, 3.0, 1.3, 0.14, -0.05 },
		{ 0.7, -2.1, 2.3, 1.1, -0.05, -0.10 },
	}
	for ci, c in ipairs(clusters) do
		local glass = (ci % 2 == 0) and Color3.fromRGB(44, 28, 60) or Color3.fromRGB(26, 22, 36)
		local tipColor = (ci % 2 == 0) and zoneCyan or zonePurple
		for si, s in ipairs(spikePlan) do
			local h = s[3]
			local cf = CFrame.new(c[1] + s[1], topY + h / 2 - 0.5, c[2] + s[2])
				* CFrame.Angles(s[5], ci * 1.3 + si, s[6])
			makePart(world, "CrystalSpike", Vector3.new(s[4], h, s[4]), cf, glass, Enum.Material.Glass)
			if si <= 2 then
				local tip = nc(makePart(world, "CrystalTip", Vector3.new(0.5, 0.5, 0.5),
					cf * CFrame.new(0, h / 2 + 0.15, 0), tipColor, Enum.Material.Neon))
				tip.Shape = Enum.PartType.Ball
			end
		end
	end

	-- 2. Pool-side dressing, mirroring the Beach Pool's language
	-- (pole + shade umbrellas; flat towels become loungers), set
	-- on the deck ring and just off it — never in the water and
	-- never on the south approach from the stairs.
	local poolC = Vector3.new(-112, topY, -112)
	for _, um in ipairs({
		{ x = -121.5, z = -120.5, c = Color3.fromRGB(190, 120, 255) },
		{ x = -99.5, z = -119, c = Color3.fromRGB(64, 224, 255) },
		}) do
		local cf = CFrame.new(um.x, topY, um.z)
		makePart(world, "UmbrellaPole", Vector3.new(0.25, 4.6, 0.25), cf * CFrame.new(0, 2.3, 0),
			Color3.fromRGB(240, 240, 235), Enum.Material.Metal)
		local shade = makeDisc(world, "UmbrellaShade", 3.6, 0.5, cf * CFrame.new(0, 4.7, 0), um.c,
			Enum.Material.SmoothPlastic)
		shade.CanCollide = false
	end
	for _, lg in ipairs({
		{ x = -124.5, z = -114.5, c = Color3.fromRGB(250, 244, 228) },
		{ x = -118, z = -124.5, c = Color3.fromRGB(190, 120, 255) },
		{ x = -100.5, z = -108, c = Color3.fromRGB(64, 224, 255) },
		}) do
		local cf = CFrame.lookAt(Vector3.new(lg.x, topY, lg.z), poolC)
		local slab = makePart(world, "Lounger", Vector3.new(1.9, 0.35, 3.6), cf * CFrame.new(0, 0.28, 0),
			lg.c, Enum.Material.SmoothPlastic)
		slab.CanCollide = false
		local back = makePart(world, "LoungerBack", Vector3.new(1.9, 1.3, 0.25),
			cf * CFrame.new(0, 0.75, 1.75) * CFrame.Angles(math.rad(-32), 0, 0), lg.c,
			Enum.Material.SmoothPlastic)
		back.CanCollide = false
	end
	-- The pool's own totem on the deck's east rim, facing out over
	-- the plateau; its posts sink into the slab like every totem.
	makeSignPost(world, Vector3.new(-96.5, 11.3, -112), Vector3.new(-40, 0, -112), 11, 3.4,
		"FIELDS POOL", "Luck x1.5 - the obsidian waters run rich", zonePurple)

	-- 3. Plateau rim neon: dashed strips glued to the south and
	-- east cliff faces just under the top edge (y 7.3, above the
	-- MesaBands), so the plateau's outline glows back at the
	-- island. The south run skips the stair corridor, as the
	-- bands and fence already do.
	local southX = { -170, -162, -154, -146, -138, -130, -98, -90, -82, -74, -66, -60 }
	for i, sx in ipairs(southX) do
		local strip = makePart(world, "RimGlow", Vector3.new(4, 0.35, 0.18),
			CFrame.new(sx, 7.3, -54.8), (i % 2 == 0) and zoneCyan or zonePurple, Enum.Material.Neon)
		strip.CanCollide = false
	end
	for i = 1, 14 do
		local ez = -170 + (i - 1) * 8
		local strip = makePart(world, "RimGlow", Vector3.new(0.18, 0.35, 4),
			CFrame.new(-54.8, 7.3, ez), (i % 2 == 0) and zonePurple or zoneCyan, Enum.Material.Neon)
		strip.CanCollide = false
	end

	-- 4. A small ruin on the north side: three standing pillars,
	-- the tallest still wearing a Neon rune strip, and one fallen
	-- brother in front — the zone's photo landmark.
	local ruinStone = Color3.fromRGB(44, 38, 52)
	makePart(world, "RuinPillar", Vector3.new(2.6, 7, 2.6), CFrame.new(-147, topY + 3.5, -163),
		ruinStone, Enum.Material.Slate)
	makePart(world, "RuinPillar", Vector3.new(2.8, 9.5, 2.8), CFrame.new(-138.5, topY + 4.75, -165.5),
		ruinStone, Enum.Material.Slate)
	makePart(world, "RuinPillar", Vector3.new(2.6, 5, 2.6), CFrame.new(-130, topY + 2.5, -162),
		ruinStone, Enum.Material.Slate)
	local rune = makePart(world, "RuinRune", Vector3.new(0.55, 4.2, 0.18),
		CFrame.new(-138.5, topY + 5.6, -164.05), zoneCyan, Enum.Material.Neon)
	rune.CanCollide = false
	makePart(world, "RuinFallen", Vector3.new(2.4, 6.5, 2.4),
		CFrame.new(-134, topY + 1.2, -156.5) * CFrame.Angles(math.rad(84), 0.4, 0), ruinStone, Enum.Material.Slate)

	-- 5. Inhabitants: Udin fishes the lava pool from its SE rim
	-- (rod, line and bobber over the water), and Putri and Bagus
	-- chat beside the south-west crystal cluster. Statics on
	-- purpose — the island mover stays untouched.
	local udinCf = CFrame.lookAt(Vector3.new(-100, topY, -103), Vector3.new(-112, topY, -112))
	local udin = makeFigure(world, udinCf, Color3.fromRGB(255, 170, 60), Color3.fromRGB(70, 80, 110),
		Color3.fromRGB(198, 150, 110), "stand", Color3.fromRGB(64, 156, 255))
	makeNameTag(udin, "Udin")
	local fwd, rgt = udinCf.LookVector, udinCf.RightVector
	local hand = udinCf.Position + rgt * 1.0 + fwd * 0.3 + Vector3.new(0, 2.7, 0)
	local tipP = hand + fwd * 5.2 + Vector3.new(0, -1.4, 0)
	local rod = makePart(world, "FishingRod", Vector3.new(0.12, 0.12, (tipP - hand).Magnitude),
		CFrame.lookAt((hand + tipP) / 2, tipP), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	rod.CanCollide = false
	local lineLen = tipP.Y - 8.75
	local fishLine = makePart(world, "FishingLine", Vector3.new(0.04, lineLen, 0.04),
		CFrame.new(tipP.X, 8.75 + lineLen / 2, tipP.Z), Color3.fromRGB(240, 240, 235),
		Enum.Material.SmoothPlastic)
	fishLine.CanCollide = false
	local bobber = makePart(world, "Bobber", Vector3.new(0.34, 0.34, 0.34), CFrame.new(tipP.X, 8.8, tipP.Z),
		Color3.fromRGB(255, 80, 70), Enum.Material.Neon)
	bobber.Shape = Enum.PartType.Ball
	bobber.CanCollide = false
	local putri = makeFigure(world, CFrame.lookAt(Vector3.new(-147.5, topY, -60.5), Vector3.new(-144.8, topY, -63.2)),
		Color3.fromRGB(255, 110, 160), Color3.fromRGB(80, 70, 95), Color3.fromRGB(255, 205, 160), "stand", nil)
	makeNameTag(putri, "Putri")
	local bagus = makeFigure(world, CFrame.lookAt(Vector3.new(-144.8, topY, -63.2), Vector3.new(-147.5, topY, -60.5)),
		Color3.fromRGB(64, 200, 190), Color3.fromRGB(60, 70, 90), Color3.fromRGB(140, 100, 70), "stand",
		Color3.fromRGB(255, 205, 60))
	makeNameTag(bagus, "Bagus")

	-- 6. Pennant strings: a pole by the stair arrival and one on
	-- the east side, both strung up to the watchtower roof — the
	-- plateau joins the island's pennant system.
	local function fieldsPole(x, z)
		nc(makePart(world, "PennantPole", Vector3.new(0.35, 9.5, 0.35), CFrame.new(x, topY + 4.75, z),
			Color3.fromRGB(110, 80, 54), Enum.Material.Wood))
		local tip = nc(makePart(world, "PoleTip", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, topY + 9.75, z),
			zonePurple, Enum.Material.Neon))
		tip.Shape = Enum.PartType.Ball
		return Vector3.new(x, topY + 9.5, z)
	end
	local poleA = fieldsPole(-130, -62)
	local poleB = fieldsPole(-62, -100)
	makePennants(world, poleA, Vector3.new(-88, topY + 17.5, -64))
	makePennants(world, Vector3.new(-80, topY + 17.5, -64), poleB)
end

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
BuildMarketRow()
BuildFountain()
BuildGroundDressing()
BuildOceanLife()
BuildSignageLife()
BuildVillagers()
BuildPalms()
BuildSkyLayer()
BuildRimAccess()
BuildFinalDensity()
BuildFieldsDressing()

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
