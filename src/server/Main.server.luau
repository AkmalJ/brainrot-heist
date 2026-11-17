--[[
	Main.server.luau — BRAINROT HEIST, server side.

	Paste target: a Script named "Main" in ServerScriptService.

	This one script builds the entire world from plain parts (no external
	assets) and then runs the whole game, server-authoritatively:

	  * A winding lane crosses a bright meadow. Brainrot characters spawn at
	    the gate and stroll it; walkers are moved by CFrame steps on a server
	    loop, never by physics.
	  * Buy a walker with its ProximityPrompt, carry it home over your head,
	    and step onto your own base plot to bank it on a pad. Banked
	    brainrots pay their owner cash every second, with a floating "+$".
	  * Other players can steal banked brainrots (1.5s hold prompt). A NPC
	    BANDIT raids a random base every minute or so — body-check him (get
	    close) on his escape run and he drops the loot as a loose carryable.
	  * Every ~3 minutes a TSUNAMI washes down the lane: anything standing
	    on the lane — walker, loose or carried — is washed away. Banked
	    brainrots are safe.
	  * Rebirth (HUD button -> BrainrotRebirth remote) resets cash and
	    collection for a permanent +50% income multiplier per rebirth.

	No DataStore: a session is a fresh heist. Cash and rebirths live in
	leaderstats; the client HUD reads those plus the Carrying / IncomePerSec
	values this script maintains on each player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))

--====================================================================--
-- Remotes (created here; the client waits for them)
--====================================================================--

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "BrainrotNotify" -- server -> client banners: (text, kind)
notifyEvent.Parent = ReplicatedStorage

local rebirthEvent = Instance.new("RemoteEvent")
rebirthEvent.Name = "BrainrotRebirth" -- client -> server: "rebirth, please"
rebirthEvent.Parent = ReplicatedStorage

local function notify(player, text, kind)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function notifyAll(text, kind)
	notifyEvent:FireAllClients(text, kind or "info")
end

--====================================================================--
-- Look of the day: bright noon, soft shadows.
--====================================================================--

Lighting.ClockTime = 13.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(165, 175, 195)
Lighting.OutdoorAmbient = Color3.fromRGB(165, 175, 195)
Lighting.GlobalShadows = true

--====================================================================--
-- Small building helpers
--====================================================================--

local world = Instance.new("Folder")
world.Name = "BrainrotWorld"
world.Parent = Workspace

local actors = Instance.new("Folder")
actors.Name = "BrainrotActors"
actors.Parent = Workspace

--====================================================================--
-- Self-healing place setup: make any fresh starter place host the game
-- correctly — characters auto-load on join, and the starter ground
-- (Baseplate, SpawnLocation, terrain) is cleared so it cannot sit above
-- the procedural world's ground plane and bury it. Runs before any
-- world building, so no manual place settings are ever needed.
--====================================================================--

Players.CharacterAutoLoads = true
Workspace.Terrain:Clear()
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("BasePart") then
		child:Destroy()
	end
end

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
	l.TextStrokeTransparency = 0.6
	l.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	l.Parent = parent
	return l
end

-- A SurfaceGui sign face on an existing part. Returns (titleLabel, subLabel).
local function attachSign(part, face, titleText, subText, titleColor, titleSize)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local title = makeLabel(gui, "Title", titleText,
		UDim2.fromScale(1, subText and 0.6 or 1), UDim2.fromScale(0, 0),
		Enum.Font.FredokaOne, titleSize or 44, titleColor)
	local sub = nil
	if subText then
		sub = makeLabel(gui, "Sub", subText,
			UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.6),
			Enum.Font.GothamBold, 25, Color3.fromRGB(255, 255, 255))
	end
	return title, sub
end

-- A free-standing sign board facing a target point. Returns (board, title, sub).
local function makeSign(parent, name, size, position, faceTarget, bgColor, titleText, subText, titleColor, titleSize)
	local board = makePart(parent, name, size,
		CFrame.lookAt(position, Vector3.new(faceTarget.X, position.Y, faceTarget.Z)), bgColor)
	local title, sub = attachSign(board, Enum.NormalId.Front, titleText, subText, titleColor, titleSize)
	return board, title, sub
end

--====================================================================--
-- The lane: an S-curve of waypoints across the meadow.
--====================================================================--

local LANE_POINTS = {
	Vector3.new(-84, 0, 84),
	Vector3.new(-46, 0, 42),
	Vector3.new(-72, 0, -2),
	Vector3.new(-24, 0, -44),
	Vector3.new(28, 0, -62),
	Vector3.new(72, 0, -22),
	Vector3.new(48, 0, 30),
	Vector3.new(86, 0, 76),
}

local laneSegs = {}
local LANE_LENGTH = 0
for i = 1, #LANE_POINTS - 1 do
	local a, b = LANE_POINTS[i], LANE_POINTS[i + 1]
	local len = (b - a).Magnitude
	table.insert(laneSegs, { a = a, b = b, len = len })
	LANE_LENGTH += len
end

-- Point and direction at distance s along the lane (the tsunami rides this).
local function sampleLane(s)
	if s <= 0 then
		return LANE_POINTS[1], (LANE_POINTS[2] - LANE_POINTS[1]).Unit
	end
	for _, seg in ipairs(laneSegs) do
		if s <= seg.len then
			local dir = (seg.b - seg.a).Unit
			return seg.a + dir * s, dir
		end
		s -= seg.len
	end
	local last = laneSegs[#laneSegs]
	return last.b, (last.b - last.a).Unit
end

-- 2D distance from a point to the lane's polyline (flowers and trees keep off).
local function distToLane(x, z)
	local best = math.huge
	for _, seg in ipairs(laneSegs) do
		local ax, az = seg.a.X, seg.a.Z
		local dx, dz = seg.b.X - ax, seg.b.Z - az
		local lenSq = dx * dx + dz * dz
		local t = 0
		if lenSq > 0 then
			t = math.clamp(((x - ax) * dx + (z - az) * dz) / lenSq, 0, 1)
		end
		local px, pz = ax + dx * t, az + dz * t
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then
			best = d
		end
	end
	return best
end

--====================================================================--
-- World building
--====================================================================--

-- The meadow slab (its top, y = 0.02, is the ground everything stands on).
makePart(world, "Meadow", Vector3.new(440, 2, 440), CFrame.new(0, -0.98, 0),
	Color3.fromRGB(106, 190, 74), Enum.Material.Grass)

-- The lane itself: one sandy slab per segment, overlapping at the joints.
for i, seg in ipairs(laneSegs) do
	local mid = (seg.a + seg.b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, 0.05, mid.Z), Vector3.new(seg.b.X, 0.05, seg.b.Z))
	makePart(world, "Lane" .. i, Vector3.new(11, 0.06, seg.len + 10), cf,
		Color3.fromRGB(232, 205, 150), Enum.Material.Sand)
end

-- Gates at both ends of the lane.
local function buildGate(pos, outward, title, sub, color)
	local g = Instance.new("Folder")
	g.Name = title
	g.Parent = world
	local side = Vector3.new(-outward.Z, 0, outward.X) -- perpendicular, flat
	for _, s in ipairs({ -1, 1 }) do
		local pp = pos + side * (7 * s)
		makePart(g, "Pillar", Vector3.new(2.2, 11, 2.2), CFrame.new(pp.X, 5.5, pp.Z), color)
	end
	local topPos = pos + Vector3.new(0, 11.6, 0)
	makeSign(g, "GateSign", Vector3.new(19, 4.2, 1), topPos, pos + outward * 10,
		color, title, sub, Color3.fromRGB(255, 255, 255), 40)
end

buildGate(LANE_POINTS[1], Vector3.new(-0.707, 0, 0.707), "BRAINROTS ENTER",
	"Buy one and carry it HOME!", Color3.fromRGB(46, 160, 80))
buildGate(LANE_POINTS[#LANE_POINTS], Vector3.new(0.707, 0, 0.707), "LANE EXIT",
	"Mind the BANDIT past here...", Color3.fromRGB(90, 90, 100))

-- The great arch over the middle, signed on both faces, brain on top.
do
	local arch = Instance.new("Folder")
	arch.Name = "Arch"
	arch.Parent = world
	makePart(arch, "PillarL", Vector3.new(3.5, 12, 3.5), CFrame.new(-11, 6, 0), Color3.fromRGB(255, 120, 160))
	makePart(arch, "PillarR", Vector3.new(3.5, 12, 3.5), CFrame.new(11, 6, 0), Color3.fromRGB(255, 120, 160))
	local beam = makePart(arch, "Beam", Vector3.new(27, 4.5, 3.5), CFrame.new(0, 13.75, 0), Color3.fromRGB(255, 170, 60))
	attachSign(beam, Enum.NormalId.Front, "BRAINROT HEIST", nil, Color3.fromRGB(255, 255, 255), 64)
	attachSign(beam, Enum.NormalId.Back, "BRAINROT HEIST", nil, Color3.fromRGB(255, 255, 255), 64)
	local brain = makePart(arch, "Brain", Vector3.new(6.5, 5.5, 6.5), CFrame.new(0, 18.8, 0), Color3.fromRGB(255, 150, 190))
	brain.Shape = Enum.PartType.Ball
	brain.CanCollide = false
	local bump = makePart(arch, "BrainBump", Vector3.new(3.6, 3.2, 3.6), CFrame.new(2.8, 20.2, 0.8), Color3.fromRGB(255, 170, 205))
	bump.Shape = Enum.PartType.Ball
	bump.CanCollide = false
end

-- Spawn pad, just south of the arch, looking straight at it.
do
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HeistSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.52, 34)
	spawn.Color = Color3.fromRGB(90, 170, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world
end

-- The richest-collectors board, north of the arch, facing spawn.
local boardLines = {}
do
	local board = Instance.new("Folder")
	board.Name = "RichestBoard"
	board.Parent = world
	makePart(board, "PostL", Vector3.new(1.2, 6, 1.2), CFrame.new(-9, 3, -27), Color3.fromRGB(120, 85, 50))
	makePart(board, "PostR", Vector3.new(1.2, 6, 1.2), CFrame.new(9, 3, -27), Color3.fromRGB(120, 85, 50))
	local panel = makePart(board, "Panel", Vector3.new(23, 11.5, 1),
		CFrame.lookAt(Vector3.new(0, 8.5, -27), Vector3.new(0, 8.5, 0)), Color3.fromRGB(30, 34, 52))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = panel
	makeLabel(gui, "Title", "★ RICHEST COLLECTORS ★",
		UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.01),
		Enum.Font.FredokaOne, 40, Color3.fromRGB(255, 205, 60))
	for i = 1, 5 do
		boardLines[i] = makeLabel(gui, "Line" .. i, "—",
			UDim2.fromScale(1, 0.15), UDim2.fromScale(0, 0.22 + (i - 1) * 0.155),
			Enum.Font.GothamBold, 30, Color3.fromRGB(235, 240, 255))
	end
end

--====================================================================--
-- The 8 base plots in a ring. Each: floor, flat border, 6 pads, a sign.
--====================================================================--

local PLOT_RADIUS = 122
local PLOT_HALF = 19 -- half the floor's width; also the banking bounds
local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 80),
	Color3.fromRGB(255, 230, 100), Color3.fromRGB(130, 220, 110),
	Color3.fromRGB(90, 200, 220), Color3.fromRGB(110, 140, 255),
	Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 120, 200),
}
local PAD_IDLE = Color3.fromRGB(203, 213, 225)

local plots = {}
for i = 1, 8 do
	local angle = math.rad(22.5 + (i - 1) * 45)
	local cx = math.cos(angle) * PLOT_RADIUS
	local cz = math.sin(angle) * PLOT_RADIUS
	local center = Vector3.new(cx, 0, cz)
	local toCenter = Vector3.new(-cx, 0, -cz).Unit
	local color = PLOT_COLORS[i]

	local folder = Instance.new("Folder")
	folder.Name = "Base" .. i
	folder.Parent = world

	makePart(folder, "Floor", Vector3.new(38, 1, 38), CFrame.new(cx, 0.05, cz), color)
	local borderColor = color:Lerp(Color3.fromRGB(30, 30, 40), 0.3)
	makePart(folder, "BorderN", Vector3.new(38, 0.15, 1.4), CFrame.new(cx, 0.62, cz - 18.3), borderColor)
	makePart(folder, "BorderS", Vector3.new(38, 0.15, 1.4), CFrame.new(cx, 0.62, cz + 18.3), borderColor)
	makePart(folder, "BorderE", Vector3.new(1.4, 0.15, 38), CFrame.new(cx + 18.3, 0.62, cz), borderColor)
	makePart(folder, "BorderW", Vector3.new(1.4, 0.15, 38), CFrame.new(cx - 18.3, 0.62, cz), borderColor)

	local pads = {}
	for _, dx in ipairs({ -11.5, 0, 11.5 }) do
		for _, dz in ipairs({ -8.5, 8.5 }) do
			local padPart = makePart(folder, "Pad", Vector3.new(6.5, 0.5, 6.5),
				CFrame.new(cx + dx, 0.8, cz + dz), PAD_IDLE)
			table.insert(pads, {
				part = padPart,
				pos = Vector3.new(cx + dx, 1.05, cz + dz), -- top centre of the pad
				ent = nil,
			})
		end
	end

	-- Sign on two posts at the plot's inner edge, facing the meadow centre.
	local signPos = center + toCenter * 21.5 + Vector3.new(0, 5.2, 0)
	makePart(folder, "SignPost", Vector3.new(0.9, 5.2, 0.9), CFrame.new(signPos.X, 2.6, signPos.Z),
		Color3.fromRGB(120, 85, 50))
	local _, signTitle, signSub = makeSign(folder, "Sign", Vector3.new(19, 6.5, 0.8),
		signPos, Vector3.new(0, 5.2, 0), color, "EMPTY BASE", "Waiting for a collector...", Color3.fromRGB(255, 255, 255), 42)

	table.insert(plots, {
		index = i,
		center = center,
		color = color,
		pads = pads,
		owner = nil,
		signTitle = signTitle,
		signSub = signSub,
		spawnPos = center + toCenter * 27,
	})
end

local function plotAt(x, z)
	for _, plot in ipairs(plots) do
		if math.abs(x - plot.center.X) <= PLOT_HALF and math.abs(z - plot.center.Z) <= PLOT_HALF then
			return plot
		end
	end
	return nil
end

--====================================================================--
-- Rebirth shrine and the bandit's hideout: landmarks with jobs to do.
--====================================================================--

do
	local shrine = Instance.new("Folder")
	shrine.Name = "RebirthShrine"
	shrine.Parent = world
	local base = makePart(shrine, "Base", Vector3.new(2, 9, 9),
		CFrame.new(34, 1, 34) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(88, 60, 160))
	base.Shape = Enum.PartType.Cylinder
	local crystal = makePart(shrine, "Crystal", Vector3.new(2.6, 3.8, 2.6),
		CFrame.new(34, 4.8, 34), Color3.fromRGB(190, 110, 255), Enum.Material.Neon)
	crystal.Shape = Enum.PartType.Ball
	crystal.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 110, 255)
	light.Range = 20
	light.Brightness = 2
	light.Parent = crystal
	makePart(shrine, "SignPost", Vector3.new(0.8, 3.6, 0.8), CFrame.new(34, 1.8, 24.6), Color3.fromRGB(120, 85, 50))
	makeSign(shrine, "Sign", Vector3.new(16, 5, 0.8), Vector3.new(34, 4.6, 24.6),
		Vector3.new(0, 4.6, 0), Color3.fromRGB(88, 60, 160),
		"REBIRTH SHRINE", "+50% income per rebirth — use the HUD button!", Color3.fromRGB(255, 255, 255), 38)
end

local BANDIT_HOME = Vector3.new(110, 0, 100)
do
	local hideout = Instance.new("Folder")
	hideout.Name = "BanditHideout"
	hideout.Parent = world
	local dark = Color3.fromRGB(70, 66, 78)
	makePart(hideout, "Floor", Vector3.new(16, 1, 16), CFrame.new(110, 0.05, 100), dark)
	makePart(hideout, "WallN", Vector3.new(16, 5.5, 1), CFrame.new(110, 2.75, 92.5), dark)
	makePart(hideout, "WallE", Vector3.new(1, 5.5, 16), CFrame.new(117.5, 2.75, 100), dark)
	makePart(hideout, "WallS", Vector3.new(16, 5.5, 1), CFrame.new(110, 2.75, 107.5), dark)
	makePart(hideout, "Roof", Vector3.new(17.5, 1, 17.5), CFrame.new(110, 6, 100), Color3.fromRGB(52, 50, 60))
	makeSign(hideout, "Sign", Vector3.new(14, 3.6, 0.8), Vector3.new(102.5, 4.4, 92.8),
		Vector3.new(86, 4.4, 76), Color3.fromRGB(52, 50, 60),
		"BANDIT HIDEOUT", "Keep out. Seriously.", Color3.fromRGB(255, 120, 120), 36)
end

--====================================================================--
-- Set dressing: trees on the ring, flowers off the lane, lazy clouds.
--====================================================================--

do
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = world

	local trunkColor = Color3.fromRGB(121, 85, 58)
	local leafColors = { Color3.fromRGB(64, 160, 70), Color3.fromRGB(84, 180, 80), Color3.fromRGB(52, 140, 64) }
	for k = 0, 13 do
		local a = math.rad(12 + k * (360 / 14))
		local tx, tz = math.cos(a) * 96, math.sin(a) * 96
		if distToLane(tx, tz) > 11 and not plotAt(tx, tz) then
			local trunk = makePart(decor, "Trunk", Vector3.new(5, 1.7, 1.7),
				CFrame.new(tx, 2.5, tz) * CFrame.Angles(0, 0, math.rad(90)), trunkColor)
			trunk.Shape = Enum.PartType.Cylinder
			local leafColor = leafColors[(k % #leafColors) + 1]
			local crown = makePart(decor, "Crown", Vector3.new(7.5, 6.5, 7.5), CFrame.new(tx, 7.6, tz), leafColor)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
			local top = makePart(decor, "CrownTop", Vector3.new(5, 4.4, 5), CFrame.new(tx + 1.2, 10.2, tz), leafColor)
			top.Shape = Enum.PartType.Ball
			top.CanCollide = false
		end
	end

	local flowerColors = {
		Color3.fromRGB(255, 120, 180), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 150, 80),
	}
	local placed = 0
	local tries = 0
	while placed < 80 and tries < 300 do
		tries += 1
		local a = math.random() * math.pi * 2
		local r = 16 + math.random() * 158
		local fx, fz = math.cos(a) * r, math.sin(a) * r
		local nearSpawn = math.sqrt(fx ^ 2 + (fz - 34) ^ 2) < 9
		if distToLane(fx, fz) > 8 and not plotAt(fx, fz) and not nearSpawn then
			local f = makePart(decor, "Flower", Vector3.new(0.75, 0.75, 0.75),
				CFrame.new(fx, 0.35, fz), flowerColors[math.random(1, #flowerColors)])
			f.Shape = Enum.PartType.Ball
			f.CanCollide = false
			placed += 1
		end
	end

	for i = 1, 6 do
		local cx = -140 + i * 44 + math.random(-8, 8)
		local cz = -120 + math.random(0, 240)
		local cy = 56 + math.random(0, 14)
		for j = 1, 3 do
			local c = makePart(decor, "Cloud", Vector3.new(16 + j * 5, 3.5, 10 + j * 2),
				CFrame.new(cx + (j - 2) * 9, cy + (j % 2), cz), Color3.fromRGB(255, 255, 255))
			c.Shape = Enum.PartType.Ball
			c.CanCollide = false
		end
	end
end

--====================================================================--
-- Game state
--====================================================================--

local ROOT_Y = 0.27 -- root-part centre height when standing on the meadow

local entities = {} -- every brainrot in the world (walkers, carried, banked, loose, stolen)
local playerData = {} -- [Player] = { plot, carrying, cashFrac, incomeBase, lastFullAt }

-- Forward declarations for the mutually recursive entity actions.
local setPrompt, destroyEntity, startCarry, onPrompt

local function getCash(player)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function setCash(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash then
		cash.Value = math.max(0, math.floor(amount))
	end
end

local function getRebirths(player)
	local ls = player:FindFirstChild("leaderstats")
	local rb = ls and ls:FindFirstChild("Rebirths")
	return rb and rb.Value or 0
end

local function hrpOf(player)
	local char = player and player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

local function flatDist(a, b)
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end

-- A player's current income rate, recomputed from what they have banked.
local function updateIncome(player)
	local pd = playerData[player]
	if not pd then
		return
	end
	local sum = 0
	for _, ent in ipairs(entities) do
		if ent.owner == player and ent.state == "banked" then
			sum += Brainrots.EffectiveIncome(ent.def, ent.mutation)
		end
	end
	pd.incomeBase = sum
	local iv = player:FindFirstChild("IncomePerSec")
	if iv then
		iv.Value = math.floor(sum * Brainrots.RebirthMult(getRebirths(player)) + 0.5)
	end
end

--====================================================================--
-- Movement: everything glides by SetPrimaryPartCFrame, no physics.
-- An "ent" (brainrot or bandit) carries .model, .pos (root centre) and
-- .baseY (the pos.Y it returns to when not bobbing).
--====================================================================--

local function faceToward(ent, target)
	local pos = ent.pos
	local dx, dz = target.X - pos.X, target.Z - pos.Z
	if math.abs(dx) < 0.001 and math.abs(dz) < 0.001 then
		return
	end
	ent.model:SetPrimaryPartCFrame(CFrame.lookAt(
		Vector3.new(pos.X, pos.Y, pos.Z),
		Vector3.new(pos.X + dx, pos.Y, pos.Z + dz)))
end

-- Glide toward a ground target; returns true on arrival.
local function moveToward(ent, target, speed, dt, bobAmp)
	local pos = ent.pos
	local dx, dz = target.X - pos.X, target.Z - pos.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	local step = speed * dt
	if dist <= math.max(step, 0.05) then
		ent.pos = Vector3.new(target.X, ent.baseY, target.Z)
		faceToward(ent, target)
		return true
	end
	local bob = 0
	if bobAmp then
		bob = math.abs(math.sin(os.clock() * 9 + ent.bobPhase)) * bobAmp
	end
	ent.pos = Vector3.new(pos.X + dx / dist * step, ent.baseY + bob, pos.Z + dz / dist * step)
	faceToward(ent, target)
	return false
end

-- Ride a brainrot over a holder's head (player HRP or the bandit's root).
local function carryPosition(ent, holderRoot, height)
	local bob = math.sin(os.clock() * 3 + ent.bobPhase) * 0.15
	local pos = holderRoot.Position + Vector3.new(0, height + bob, 0)
	ent.model:SetPrimaryPartCFrame(CFrame.new(pos) * holderRoot.CFrame.Rotation)
	ent.pos = ent.root.Position
end

--====================================================================--
-- The character factory: one blocky brainrot, built from its definition.
-- Model space: origin at the ground point, front is -Z, root at y 0.25.
--====================================================================--

local function buildCharacterModel(def, mutation)
	local s = def.scale or 1
	local tier = Brainrots.Tiers[def.tier]
	local bodyColor = def.body
	if mutation then
		bodyColor = bodyColor:Lerp(mutation.color, 0.45)
	end
	local headColor = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.12)
	if def.accessory == "ToiletTank" then
		headColor = def.accent -- the goblin's own green head pops out of the bowl
	end

	local model = Instance.new("Model")
	model.Name = Brainrots.DisplayName(def, mutation)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.2, 0.5, 1.2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, 0.25, 0)
	root.Parent = model
	model.PrimaryPart = root

	local function v3(x, y, z)
		return Vector3.new(x * s, y * s, z * s)
	end
	local function at(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end
	local function add(name, size, cf, color, shape, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = model
		return p
	end

	-- Feet, body, belly, head, face.
	add("FootL", v3(0.7, 0.5, 0.95), at(-0.55, 0.25, 0.05), def.accent:Lerp(Color3.fromRGB(0, 0, 0), 0.25))
	add("FootR", v3(0.7, 0.5, 0.95), at(0.55, 0.25, 0.05), def.accent:Lerp(Color3.fromRGB(0, 0, 0), 0.25))
	local bodyPart = add("Body", v3(2.3, 2.5, 1.5), at(0, 1.5, 0), bodyColor)
	add("Belly", v3(1.7, 1.7, 0.2), at(0, 1.45, -0.78), bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.35))
	add("Head", v3(1.75, 1.65, 1.65), at(0, 3.35, 0), headColor, Enum.PartType.Ball)
	add("EyeL", v3(0.34, 0.34, 0.34), at(-0.4, 3.5, -0.72), Color3.fromRGB(25, 25, 30), Enum.PartType.Ball)
	add("EyeR", v3(0.34, 0.34, 0.34), at(0.4, 3.5, -0.72), Color3.fromRGB(25, 25, 30), Enum.PartType.Ball)
	add("Mouth", v3(0.65, 0.16, 0.1), at(0, 3.08, -0.8), Color3.fromRGB(60, 35, 35))

	-- The accessory that makes each brainrot itself.
	local acc = def.accessory
	if acc == "Tail" then -- Noodle Newt: a long tail, noodle strands for hair
		add("Tail", v3(0.4, 0.4, 2.4), at(0, 1.15, 1.55) * CFrame.Angles(math.rad(30), 0, 0), bodyColor)
		for _, x in ipairs({ -0.4, 0, 0.4 }) do
			add("Noodle", v3(0.18, 0.9, 0.18), at(x, 4.35, 0), def.accent)
		end
	elseif acc == "Headphones" then -- DJ Banana: cups, band, and a banana stem
		add("CupL", v3(0.45, 1.05, 1.05), at(-1.0, 3.35, 0), Color3.fromRGB(40, 40, 48), Enum.PartType.Cylinder)
		add("CupR", v3(0.45, 1.05, 1.05), at(1.0, 3.35, 0), Color3.fromRGB(40, 40, 48), Enum.PartType.Cylinder)
		add("Band", v3(2.0, 0.28, 0.45), at(0, 4.25, 0), Color3.fromRGB(40, 40, 48))
		add("Stem", v3(0.8, 0.32, 0.32), at(0, 4.45, 0) * CFrame.Angles(0, 0, math.rad(90)), def.accent, Enum.PartType.Cylinder)
	elseif acc == "CroissantHat" then -- Captain Croissant wears his namesake
		add("Croissant", v3(2.3, 0.95, 1.5), at(0, 4.15, 0), def.accent, Enum.PartType.Ball)
		add("CroissantTip", v3(1.5, 0.7, 1.1), at(0.5, 4.45, 0), def.accent:Lerp(Color3.fromRGB(0, 0, 0), 0.1), Enum.PartType.Ball)
	elseif acc == "Tie" then -- Pigeon CEO: tie, collar, briefcase, tiny beak
		add("Tie", v3(0.5, 1.5, 0.18), at(0, 1.8, -0.82), def.accent)
		add("Collar", v3(1.6, 0.3, 1.6), at(0, 2.68, 0), Color3.fromRGB(250, 250, 250))
		add("Briefcase", v3(1.15, 0.95, 0.4), at(1.65, 0.95, 0), Color3.fromRGB(60, 45, 35))
		add("Beak", v3(0.4, 0.35, 0.5), at(0, 3.3, -0.9), Color3.fromRGB(249, 115, 22))
	elseif acc == "CowboyHat" then -- Cactus Cowboy: brim, crown, cactus arms
		add("Brim", v3(0.3, 3.3, 3.3), at(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(90)), def.accent, Enum.PartType.Cylinder)
		add("HatTop", v3(1.15, 1.7, 1.7), at(0, 4.6, 0) * CFrame.Angles(0, 0, math.rad(90)), def.accent, Enum.PartType.Cylinder)
		add("ArmL", v3(1.7, 0.42, 0.42), at(-1.45, 2.35, 0) * CFrame.Angles(0, 0, math.rad(90)), bodyColor, Enum.PartType.Cylinder)
		add("ArmR", v3(1.7, 0.42, 0.42), at(1.45, 2.35, 0) * CFrame.Angles(0, 0, math.rad(90)), bodyColor, Enum.PartType.Cylinder)
	elseif acc == "Straw" then -- Sir Boba: a lid, a great pink straw, tapioca pearls
		add("Lid", v3(0.25, 2.0, 2.0), at(0, 4.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 245, 235), Enum.PartType.Cylinder)
		add("Straw", v3(2.3, 0.36, 0.36), at(0.35, 4.7, 0) * CFrame.Angles(0, 0, math.rad(65)), def.accent, Enum.PartType.Cylinder)
		for _, x in ipairs({ -0.5, 0, 0.5 }) do
			add("Pearl", v3(0.42, 0.42, 0.42), at(x, 0.62, -0.68), Color3.fromRGB(30, 25, 25), Enum.PartType.Ball)
		end
	elseif acc == "ToiletTank" then -- Toilet Goblin: the tank behind, the seat ring below the head
		add("Tank", v3(1.9, 1.7, 0.65), at(0, 3.2, 1.0), bodyColor)
		add("Seat", v3(0.35, 2.5, 2.5), at(0, 2.62, 0) * CFrame.Angles(0, 0, math.rad(90)), bodyColor, Enum.PartType.Cylinder)
	elseif acc == "DiscoBall" then -- Disco Potato: a mirror ball on a pole, potato spots
		add("Pole", v3(1.1, 0.18, 0.18), at(0, 4.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 120, 130), Enum.PartType.Cylinder)
		local ball = add("MirrorBall", v3(1.35, 1.35, 1.35), at(0, 5.5, 0), def.accent, Enum.PartType.Ball)
		ball.Reflectance = 0.55
		add("Spot1", v3(0.3, 0.3, 0.3), at(0.5, 1.9, -0.72), bodyColor:Lerp(Color3.fromRGB(0, 0, 0), 0.3), Enum.PartType.Ball)
		add("Spot2", v3(0.3, 0.3, 0.3), at(-0.45, 1.2, -0.74), bodyColor:Lerp(Color3.fromRGB(0, 0, 0), 0.3), Enum.PartType.Ball)
	elseif acc == "Shell" then -- Turbo Turtle: a big shell and a racing stripe
		add("Shell", v3(2.7, 2.0, 2.3), at(0, 2.15, 0.72), def.accent, Enum.PartType.Ball)
		add("Stripe", v3(0.5, 2.2, 0.15), at(0, 1.55, -0.8), Color3.fromRGB(220, 50, 50))
	elseif acc == "WizardHat" then -- Waffle Wizard: syrup grid, brim, pyramid hat
		add("GridH", v3(1.9, 0.18, 0.12), at(0, 1.5, -0.79), bodyColor:Lerp(Color3.fromRGB(0, 0, 0), 0.18))
		add("GridV", v3(0.18, 2.2, 0.12), at(0, 1.5, -0.79), bodyColor:Lerp(Color3.fromRGB(0, 0, 0), 0.18))
		add("Brim", v3(0.28, 2.7, 2.7), at(0, 4.05, 0) * CFrame.Angles(0, 0, math.rad(90)), def.accent, Enum.PartType.Cylinder)
		local cone = add("Hat", v3(2.0, 2.1, 2.0), at(0, 5.0, 0), def.accent)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = cone
	elseif acc == "Crown" then -- Golden Goose: a long neck, a beak, and the crown
		add("Neck", v3(1.9, 0.5, 0.5), at(0, 2.95, -0.15) * CFrame.Angles(0, 0, math.rad(90)), bodyColor, Enum.PartType.Cylinder)
		local beak = add("Beak", v3(0.55, 0.5, 0.9), at(0, 3.3, -0.95) * CFrame.Angles(math.rad(-90), 0, 0), def.accent)
		local beakMesh = Instance.new("SpecialMesh")
		beakMesh.MeshType = Enum.MeshType.Pyramid
		beakMesh.Parent = beak
		add("Crown", v3(0.85, 1.15, 1.15), at(0, 4.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 160, 20), Enum.PartType.Cylinder)
		for _, x in ipairs({ -0.4, 0, 0.4 }) do
			add("CrownPoint", v3(0.3, 0.3, 0.3), at(x, 4.95, 0), Color3.fromRGB(230, 160, 20), Enum.PartType.Ball)
		end
	elseif acc == "CupOrbit" then -- Cosmic Cappuccino: a saucer, and stars in orbit
		add("Saucer", v3(0.3, 3.6, 3.6), at(0, 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(248, 246, 240), Enum.PartType.Cylinder)
		local starColors = { Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 110, 199), Color3.fromRGB(110, 220, 255) }
		for k = 1, 3 do
			local a = math.rad((k - 1) * 120)
			add("Star", v3(0.5, 0.5, 0.5), at(math.cos(a) * 2.3, 2.7, math.sin(a) * 2.3),
				starColors[k], Enum.PartType.Ball, Enum.Material.Neon)
		end
	end

	-- Rare and above wear a pillar of light in their tier colour.
	if tier.order >= 3 then
		local beamHeight = 9 + tier.order
		local beam = add("Beam", v3(0.55, beamHeight, 0.55), at(0, beamHeight / 2 + 2, 0), tier.beam, nil, Enum.Material.Neon)
		beam.Transparency = 0.5
	end

	-- Sparkles for the shiny ones: Gold, Diamond, and the God.
	if (mutation and (mutation.name == "Gold" or mutation.name == "Diamond")) or def.tier == "Brainrot God" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mutation and mutation.color or tier.beam
		sparkles.Parent = bodyPart
	end

	-- Nameplate: who it is, what it earns, what tier it wears.
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(230, 58)
	plate.StudsOffset = Vector3.new(0, 5.5 * s, 0)
	plate.MaxDistance = 170
	plate.Parent = root
	local nameLabel = makeLabel(plate, "Name", Brainrots.DisplayName(def, mutation),
		UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0), Enum.Font.FredokaOne, 21,
		mutation and mutation.color or tier.color)
	nameLabel.TextStrokeTransparency = 0.3
	local subLabel = makeLabel(plate, "Sub",
		"+" .. Brainrots.FormatMoney(Brainrots.EffectiveIncome(def, mutation)) .. "/s • " .. def.tier,
		UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.58), Enum.Font.GothamBold, 14,
		Color3.fromRGB(255, 255, 255))
	subLabel.TextStrokeTransparency = 0.3

	return model
end

--====================================================================--
-- Entity lifecycle
--====================================================================--

local function spawnWalker(atPoint)
	local def, mutation = Brainrots.Roll()
	local model = buildCharacterModel(def, mutation)
	model.Parent = actors
	local startPos = LANE_POINTS[atPoint or 1]
	local ent = {
		def = def, mutation = mutation, model = model, root = model.PrimaryPart,
		state = "lane", owner = nil, carrier = nil, stolenFrom = nil,
		pad = nil, prompt = nil, floaterGui = nil, floaterLabel = nil, floatT = 0,
		wp = math.min((atPoint or 1) + 1, #LANE_POINTS),
		pos = Vector3.new(startPos.X, ROOT_Y, startPos.Z),
		baseY = ROOT_Y, bobPhase = math.random() * 6.28, stealGuardUntil = 0,
	}
	table.insert(entities, ent)
	faceToward(ent, LANE_POINTS[ent.wp])
	setPrompt(ent, "buy")
	return ent
end

setPrompt = function(ent, kind)
	if ent.prompt then
		ent.prompt:Destroy()
		ent.prompt = nil
	end
	if not kind then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 11
	prompt.ObjectText = Brainrots.DisplayName(ent.def, ent.mutation)
	if kind == "buy" then
		prompt.ActionText = "Buy " .. Brainrots.FormatMoney(ent.def.cost)
		prompt.HoldDuration = 0
	elseif kind == "steal" then
		prompt.ActionText = "STEAL!"
		prompt.HoldDuration = 1.5
	elseif kind == "pickup" then
		prompt.ActionText = "Pick Up"
		prompt.HoldDuration = 0
	end
	prompt.Parent = ent.root
	prompt.Triggered:Connect(function(player)
		onPrompt(ent, player)
	end)
	ent.prompt = prompt
end

destroyEntity = function(ent)
	for i, e in ipairs(entities) do
		if e == ent then
			table.remove(entities, i)
			break
		end
	end
	if ent.pad then
		ent.pad.ent = nil
		ent.pad.part.Color = PAD_IDLE
		ent.pad = nil
	end
	if ent.carrier then
		local pd = playerData[ent.carrier]
		if pd and pd.carrying == ent then
			pd.carrying = nil
			local cv = ent.carrier:FindFirstChild("Carrying")
			if cv then
				cv.Value = ""
			end
		end
		ent.carrier = nil
	end
	if ent.model then
		ent.model:Destroy()
	end
end

startCarry = function(ent, player)
	local pd = playerData[player]
	ent.state = "carried"
	ent.carrier = player
	ent.owner = player
	ent.stolenFrom = nil
	setPrompt(ent, nil)
	if pd then
		pd.carrying = ent
		local cv = player:FindFirstChild("Carrying")
		if cv then
			cv.Value = Brainrots.DisplayName(ent.def, ent.mutation)
				.. " (+" .. Brainrots.FormatMoney(Brainrots.EffectiveIncome(ent.def, ent.mutation)) .. "/s)"
		end
	end
end

-- The floating "+$" that rises over a banked brainrot each income tick.
local function attachFloater(ent)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Floater"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 6.4, 0)
	gui.MaxDistance = 120
	gui.Parent = ent.root
	local label = makeLabel(gui, "Amount", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0),
		Enum.Font.FredokaOne, 22, Color3.fromRGB(140, 255, 150))
	label.TextStrokeTransparency = 0.25
	ent.floaterGui = gui
	ent.floaterLabel = label
	ent.floatT = 1
end

local function detachFloater(ent)
	if ent.floaterGui then
		ent.floaterGui:Destroy()
	end
	ent.floaterGui = nil
	ent.floaterLabel = nil
end

-- Bank a carried brainrot onto a free pad of the carrier's base.
local function bankEntity(ent, player, pd)
	local freePad = nil
	for _, pad in ipairs(pd.plot.pads) do
		if not pad.ent then
			freePad = pad
			break
		end
	end
	if not freePad then
		local t = os.clock()
		if t - pd.lastFullAt > 3 then
			pd.lastFullAt = t
			notify(player, "Your base is FULL — six pads, no more!", "warn")
		end
		return false
	end
	freePad.ent = ent
	ent.pad = freePad
	ent.state = "banked"
	ent.carrier = nil
	ent.baseY = freePad.pos.Y + 0.25
	ent.pos = Vector3.new(freePad.pos.X, ent.baseY, freePad.pos.Z)
	faceToward(ent, Vector3.new(0, ent.baseY, 0))
	freePad.part.Color = Brainrots.Tiers[ent.def.tier].color
	pd.carrying = nil
	local cv = player:FindFirstChild("Carrying")
	if cv then
		cv.Value = ""
	end
	setPrompt(ent, "steal")
	attachFloater(ent)
	updateIncome(player)
	notify(player, "Banked! " .. Brainrots.DisplayName(ent.def, ent.mutation) .. " now earns for you.", "good")
	return true
end

-- One prompt handler for buying, stealing and picking up: all validated here.
onPrompt = function(ent, player)
	local pd = playerData[player]
	if not pd then
		return
	end
	local display = Brainrots.DisplayName(ent.def, ent.mutation)
	if ent.state == "lane" then
		if pd.carrying then
			notify(player, "You are already carrying a brainrot — bank it first!", "warn")
			return
		end
		local cash = getCash(player)
		if cash < ent.def.cost then
			notify(player, "Not enough cash! " .. display .. " costs " .. Brainrots.FormatMoney(ent.def.cost) .. ".", "warn")
			return
		end
		setCash(player, cash - ent.def.cost)
		startCarry(ent, player)
		notify(player, "Got " .. display .. "! Carry it HOME to your base!", "good")
	elseif ent.state == "banked" then
		if ent.owner == player then
			notify(player, "This one is yours — it is earning for you.", "info")
			return
		end
		if os.clock() < ent.stealGuardUntil then
			notify(player, "It just changed hands — give it a few seconds!", "warn")
			return
		end
		if pd.carrying then
			notify(player, "You are already carrying a brainrot — bank it first!", "warn")
			return
		end
		local victim = ent.owner
		if ent.pad then
			ent.pad.ent = nil
			ent.pad.part.Color = PAD_IDLE
			ent.pad = nil
		end
		detachFloater(ent)
		ent.stealGuardUntil = os.clock() + 5
		startCarry(ent, player)
		if victim then
			updateIncome(victim)
			notify(victim, player.Name .. " STOLE your " .. display .. "!", "danger")
		end
		notify(player, "STOLEN! Run it home before they take it back!", "good")
	elseif ent.state == "loose" then
		if pd.carrying then
			notify(player, "You are already carrying a brainrot — bank it first!", "warn")
			return
		end
		startCarry(ent, player)
		notify(player, "Picked up " .. display .. " — bank it at your base!", "good")
	end
end

--====================================================================--
-- Per-frame-ish steps (the main loop ticks at 10 Hz)
--====================================================================--

local function stepWalkers(dt)
	local arrived = {}
	for _, ent in ipairs(entities) do
		if ent.state == "lane" then
			if moveToward(ent, LANE_POINTS[ent.wp], ent.def.speed, dt, 0.18) then
				if ent.wp >= #LANE_POINTS then
					table.insert(arrived, ent) -- strolled off the exit, unpurchased
				else
					ent.wp += 1
				end
			end
		end
	end
	for _, ent in ipairs(arrived) do
		destroyEntity(ent)
	end
end

local function stepCarried()
	for _, ent in ipairs(entities) do
		if ent.state == "carried" then
			local player = ent.carrier
			local hrp = hrpOf(player)
			if not hrp then
				-- The carrier's character is gone (resetting): drop it loose.
				ent.state = "loose"
				ent.carrier = nil
				local pd = playerData[player]
				if pd and pd.carrying == ent then
					pd.carrying = nil
					local cv = player:FindFirstChild("Carrying")
					if cv then
						cv.Value = ""
					end
				end
				ent.baseY = ROOT_Y
				ent.pos = Vector3.new(ent.pos.X, ROOT_Y, ent.pos.Z)
				ent.model:SetPrimaryPartCFrame(CFrame.new(ent.pos))
				setPrompt(ent, "pickup")
			else
				carryPosition(ent, hrp, 4.6)
				-- Banking: standing anywhere on your own plot does it.
				local pd = playerData[player]
				if pd and pd.plot and pd.plot.owner == player then
					if math.abs(hrp.Position.X - pd.plot.center.X) <= PLOT_HALF
						and math.abs(hrp.Position.Z - pd.plot.center.Z) <= PLOT_HALF then
						bankEntity(ent, player, pd)
					end
				end
			end
		end
	end
end

local function stepFloaters(dt)
	for _, ent in ipairs(entities) do
		if ent.state == "banked" and ent.floaterGui then
			ent.floatT = math.min(ent.floatT + dt, 1)
			ent.floaterGui.StudsOffset = Vector3.new(0, 6.3 + ent.floatT * 1.6, 0)
			if ent.floaterLabel then
				ent.floaterLabel.TextTransparency = ent.floatT
			end
		end
	end
end

--====================================================================--
-- The BANDIT: idles in his hideout, raids a random banked brainrot,
-- and drops it if its owner gets close on the escape run.
--====================================================================--

local function buildBanditModel()
	local model = Instance.new("Model")
	model.Name = "Bandit"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.2, 0.5, 1.2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, 0.25, 0)
	root.Parent = model
	model.PrimaryPart = root

	local function add(name, size, cf, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = model
		return p
	end

	add("Body", Vector3.new(2.4, 2.6, 1.6), CFrame.new(0, 1.55, 0), Color3.fromRGB(52, 52, 64))
	add("Sack", Vector3.new(2.2, 2.4, 2.2), CFrame.new(0, 2.2, 1.35), Color3.fromRGB(176, 144, 96), Enum.PartType.Ball)
	add("Head", Vector3.new(1.7, 1.6, 1.6), CFrame.new(0, 3.4, 0), Color3.fromRGB(196, 160, 130), Enum.PartType.Ball)
	add("Mask", Vector3.new(1.8, 0.5, 0.3), CFrame.new(0, 3.5, -0.72), Color3.fromRGB(15, 15, 20))
	add("EyeL", Vector3.new(0.22, 0.22, 0.22), CFrame.new(-0.38, 3.5, -0.88), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	add("EyeR", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0.38, 3.5, -0.88), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	add("Brim", Vector3.new(0.25, 3.0, 3.0), CFrame.new(0, 4.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 25, 32), Enum.PartType.Cylinder)
	add("HatTop", Vector3.new(1.0, 1.5, 1.5), CFrame.new(0, 4.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 25, 32), Enum.PartType.Cylinder)

	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(200, 54)
	plate.StudsOffset = Vector3.new(0, 5.6, 0)
	plate.MaxDistance = 170
	plate.Parent = root
	local nameLabel = makeLabel(plate, "Name", "BANDIT!", UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0),
		Enum.Font.FredokaOne, 22, Color3.fromRGB(255, 90, 90))
	nameLabel.TextStrokeTransparency = 0.3
	local subLabel = makeLabel(plate, "Sub", "get close to make him drop loot!", UDim2.fromScale(1, 0.42),
		UDim2.fromScale(0, 0.58), Enum.Font.GothamBold, 13, Color3.fromRGB(255, 255, 255))
	subLabel.TextStrokeTransparency = 0.3

	return model
end

local bandit = {
	model = nil, root = nil,
	pos = Vector3.new(BANDIT_HOME.X, ROOT_Y, BANDIT_HOME.Z), baseY = ROOT_Y,
	state = "idle", nextRaidAt = os.clock() + 55,
	target = nil, loot = nil, bobPhase = 1.7,
}
bandit.model = buildBanditModel()
bandit.root = bandit.model.PrimaryPart
bandit.model.Parent = actors
faceToward(bandit, LANE_POINTS[#LANE_POINTS])

local function stepBandit(dt, t)
	if bandit.state == "idle" then
		if t >= bandit.nextRaidAt then
			local banked = {}
			for _, ent in ipairs(entities) do
				if ent.state == "banked" then
					table.insert(banked, ent)
				end
			end
			if #banked > 0 then
				bandit.target = banked[math.random(1, #banked)]
				bandit.state = "hunting"
				notifyAll("The BANDIT is raiding " .. (bandit.target.owner and bandit.target.owner.Name or "a") .. "'s base!", "warn")
			else
				bandit.nextRaidAt = t + 20
			end
		end
	elseif bandit.state == "hunting" then
		local target = bandit.target
		if not target or target.state ~= "banked" or not target.model.Parent then
			bandit.target = nil
			bandit.state = "returning"
		elseif moveToward(bandit, target.pos, 10.5, dt, 0.15) then
			if target.pad then
				target.pad.ent = nil
				target.pad.part.Color = PAD_IDLE
				target.pad = nil
			end
			detachFloater(target)
			setPrompt(target, nil)
			target.state = "stolen"
			target.stolenFrom = target.owner
			bandit.loot = target
			bandit.target = nil
			bandit.state = "escaping"
			if target.stolenFrom then
				updateIncome(target.stolenFrom)
				notify(target.stolenFrom, "The BANDIT grabbed your "
					.. Brainrots.DisplayName(target.def, target.mutation) .. "! Chase him down!", "danger")
			end
		end
	elseif bandit.state == "escaping" then
		local loot = bandit.loot
		if loot then
			carryPosition(loot, bandit.root, 4.9)
			local victim = loot.stolenFrom
			local vhrp = hrpOf(victim)
			if vhrp and flatDist(vhrp.Position, bandit.pos) < 6.5 then
				loot.state = "loose"
				loot.baseY = ROOT_Y
				loot.pos = Vector3.new(bandit.pos.X, ROOT_Y, bandit.pos.Z)
				loot.model:SetPrimaryPartCFrame(CFrame.new(loot.pos))
				setPrompt(loot, "pickup")
				bandit.loot = nil
				bandit.state = "fleeing"
				notify(victim, "You scared the BANDIT off — he dropped your brainrot!", "good")
				notifyAll("The BANDIT dropped the loot and ran!", "info")
			end
		end
		if bandit.state == "escaping" then
			if moveToward(bandit, BANDIT_HOME, 9, dt, 0.15) then
				if bandit.loot then
					local gone = bandit.loot
					local victim = gone.stolenFrom
					bandit.loot = nil
					destroyEntity(gone)
					if victim then
						notify(victim, "The BANDIT got away with your brainrot!", "danger")
					end
				end
				bandit.state = "idle"
				bandit.nextRaidAt = t + math.random(45, 75)
			end
		end
	elseif bandit.state == "fleeing" or bandit.state == "returning" then
		if moveToward(bandit, BANDIT_HOME, 11, dt, 0.15) then
			bandit.state = "idle"
			bandit.nextRaidAt = t + math.random(45, 75)
		end
	end
end

--====================================================================--
-- The TSUNAMI: a wall of water that rides the lane and washes away
-- anything standing on it. Banked brainrots are safe on their pads.
--====================================================================--

local waveModel = Instance.new("Model")
waveModel.Name = "TsunamiWall"
do
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, -80, 0)
	root.Parent = waveModel
	waveModel.PrimaryPart = root
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = Vector3.new(36, 26, 3)
	wall.CFrame = CFrame.new(0, -67, 0)
	wall.Color = Color3.fromRGB(56, 150, 255)
	wall.Material = Enum.Material.Glass
	wall.Transparency = 0.35
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.Parent = waveModel
	local foam = Instance.new("Part")
	foam.Name = "Foam"
	foam.Size = Vector3.new(36, 3.5, 3.6)
	foam.CFrame = CFrame.new(0, -54.5, 0)
	foam.Color = Color3.fromRGB(240, 250, 255)
	foam.Material = Enum.Material.SmoothPlastic
	foam.Transparency = 0.15
	foam.Anchored = true
	foam.CanCollide = false
	foam.CanQuery = false
	foam.Parent = waveModel
	waveModel.Parent = world
end

local wave = { state = "idle", nextAt = os.clock() + 150, warnEnd = 0, s = 0 }

local function stepWave(dt, t)
	if wave.state == "idle" then
		if t >= wave.nextAt then
			wave.state = "warning"
			wave.warnEnd = t + 10
			notifyAll("TSUNAMI in 10 seconds! Bank your brainrots — anything on the lane washes away!", "danger")
		end
	elseif wave.state == "warning" then
		if t >= wave.warnEnd then
			wave.state = "sweeping"
			wave.s = 0
		end
	elseif wave.state == "sweeping" then
		wave.s += 16 * dt
		local pos, dir = sampleLane(math.min(wave.s, LANE_LENGTH))
		local center = Vector3.new(pos.X, 0, pos.Z)
		waveModel:SetPrimaryPartCFrame(CFrame.lookAt(center, center + dir))
		local doomed = {}
		for _, ent in ipairs(entities) do
			if ent.state == "lane" or ent.state == "loose" then
				if flatDist(ent.pos, center) < 13 then
					table.insert(doomed, ent)
				end
			elseif ent.state == "carried" then
				local hrp = hrpOf(ent.carrier)
				if hrp and flatDist(hrp.Position, center) < 13 then
					table.insert(doomed, ent)
				end
			end
		end
		for _, ent in ipairs(doomed) do
			local display = Brainrots.DisplayName(ent.def, ent.mutation)
			local owner = ent.carrier or ent.owner
			destroyEntity(ent)
			if owner then
				notify(owner, "The tsunami washed away your " .. display .. "!", "danger")
			end
		end
		if wave.s >= LANE_LENGTH then
			waveModel:SetPrimaryPartCFrame(CFrame.new(0, -80, 0))
			wave.state = "idle"
			wave.nextAt = t + 180
			notifyAll("The tsunami passed... the lane is safe, for now.", "info")
		end
	end
end

--====================================================================--
-- Income, signs, players, rebirth
--====================================================================--

local function payIncome()
	for player, pd in pairs(playerData) do
		if pd.incomeBase and pd.incomeBase > 0 then
			local gain = pd.incomeBase * Brainrots.RebirthMult(getRebirths(player))
			pd.cashFrac += gain
			local whole = math.floor(pd.cashFrac)
			if whole > 0 then
				pd.cashFrac -= whole
				setCash(player, getCash(player) + whole)
			end
		end
	end
	for _, ent in ipairs(entities) do
		if ent.state == "banked" and ent.floaterLabel then
			local amt = Brainrots.EffectiveIncome(ent.def, ent.mutation)
				* Brainrots.RebirthMult(getRebirths(ent.owner))
			ent.floaterLabel.Text = "+" .. Brainrots.FormatMoney(amt)
			ent.floatT = 0
		end
	end
end

local function refreshSigns()
	for _, plot in ipairs(plots) do
		if plot.owner then
			plot.signTitle.Text = plot.owner.Name .. "'s Base"
			local pd = playerData[plot.owner]
			local count = 0
			for _, ent in ipairs(entities) do
				if ent.owner == plot.owner and ent.state == "banked" then
					count += 1
				end
			end
			local income = pd and pd.incomeBase or 0
			plot.signSub.Text = "+" .. Brainrots.FormatMoney(income * Brainrots.RebirthMult(getRebirths(plot.owner)))
				.. "/s • " .. count .. " brainrots"
		else
			plot.signTitle.Text = "EMPTY BASE"
			plot.signSub.Text = "Waiting for a collector..."
		end
	end
	local ranked = {}
	for player in pairs(playerData) do
		table.insert(ranked, player)
	end
	table.sort(ranked, function(a, b)
		return getCash(a) > getCash(b)
	end)
	for i = 1, 5 do
		local p = ranked[i]
		if p then
			boardLines[i].Text = i .. ". " .. p.Name .. " — " .. Brainrots.FormatMoney(getCash(p))
		else
			boardLines[i].Text = "—"
		end
	end
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = Brainrots.StartingCash
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	local carrying = Instance.new("StringValue")
	carrying.Name = "Carrying"
	carrying.Value = ""
	carrying.Parent = player
	local incomeVal = Instance.new("IntValue")
	incomeVal.Name = "IncomePerSec"
	incomeVal.Value = 0
	incomeVal.Parent = player

	local plot = nil
	for _, p in ipairs(plots) do
		if not p.owner then
			plot = p
			break
		end
	end
	if plot then
		plot.owner = player
	end
	playerData[player] = { plot = plot, carrying = nil, cashFrac = 0, incomeBase = 0, lastFullAt = 0 }

	local function placeCharacter(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if hrp and plot then
			local sp = plot.spawnPos
			hrp.CFrame = CFrame.lookAt(Vector3.new(sp.X, 2.5, sp.Z), Vector3.new(0, 2.5, 0))
		end
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(placeCharacter, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player.Character)
	end

	task.delay(4, function()
		if player.Parent then
			notify(player, "Welcome to BRAINROT HEIST! Buy a brainrot on the lane and carry it home!", "good")
		end
	end)
end

local function onPlayerRemoving(player)
	local pd = playerData[player]
	if pd and pd.plot then
		pd.plot.owner = nil
	end
	local mine = {}
	for _, ent in ipairs(entities) do
		if ent.owner == player or ent.carrier == player or ent.stolenFrom == player then
			table.insert(mine, ent)
		end
	end
	for _, ent in ipairs(mine) do
		if ent.state == "banked" or ent.state == "carried" then
			destroyEntity(ent)
		elseif ent.state == "loose" then
			ent.owner = nil
			ent.stolenFrom = nil
		elseif ent.state == "stolen" then
			if bandit.loot == ent then
				bandit.loot = nil
				bandit.state = "fleeing"
			end
			destroyEntity(ent)
		end
	end
	if bandit.target and bandit.target.owner == player then
		bandit.target = nil
	end
	playerData[player] = nil
end

rebirthEvent.OnServerEvent:Connect(function(player)
	local pd = playerData[player]
	if not pd then
		return
	end
	local rebirths = getRebirths(player)
	local cost = Brainrots.RebirthCost(rebirths)
	if getCash(player) < cost then
		notify(player, "Rebirth costs " .. Brainrots.FormatMoney(cost) .. " — keep heisting!", "warn")
		return
	end
	local mine = {}
	for _, ent in ipairs(entities) do
		if ent.owner == player and (ent.state == "banked" or ent.state == "carried" or ent.state == "loose") then
			table.insert(mine, ent)
		end
	end
	for _, ent in ipairs(mine) do
		destroyEntity(ent)
	end
	setCash(player, Brainrots.StartingCash)
	pd.cashFrac = 0
	local ls = player:FindFirstChild("leaderstats")
	local rb = ls and ls:FindFirstChild("Rebirths")
	if rb then
		rb.Value = rebirths + 1
	end
	updateIncome(player)
	notify(player, "REBIRTH! Your income is now x" .. Brainrots.RebirthMult(rebirths + 1) .. " — forever!", "good")
	notifyAll(player.Name .. " rebirthed! Income x" .. Brainrots.RebirthMult(rebirths + 1) .. "!", "info")
end)

--====================================================================--
-- Startup and the main loop
--====================================================================--

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Opening population: five walkers already spread along the lane.
for k = 1, 5 do
	spawnWalker(k)
end

local spawnAcc, incomeAcc, signAcc = 0, 0, 0
task.spawn(function()
	while true do
		local dt = task.wait(0.1)
		local t = os.clock()
		stepWalkers(dt)
		stepCarried()
		stepBandit(dt, t)
		stepWave(dt, t)
		stepFloaters(dt)

		spawnAcc += dt
		if spawnAcc >= 3.2 then
			spawnAcc = 0
			local laneCount = 0
			for _, ent in ipairs(entities) do
				if ent.state == "lane" then
					laneCount += 1
				end
			end
			if laneCount < 12 then
				spawnWalker(1)
			end
		end

		incomeAcc += dt
		if incomeAcc >= 1 then
			incomeAcc -= 1
			payIncome()
		end

		signAcc += dt
		if signAcc >= 2 then
			signAcc = 0
			refreshSigns()
		end
	end
end)

print("[Brainrot Heist] world built: 8 bases, a " .. math.floor(LANE_LENGTH) .. "-stud lane, one bandit, weather incoming")
