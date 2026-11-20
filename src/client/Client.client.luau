-- Client.client.luau — MAGMA MAYHEM: Brainrot Volcano
-- LocalScript: StarterPlayer → StarterPlayerScripts.
--
-- The hands and eyes of the game. Interface.luau (required below) draws every
-- pixel of GUI; this script owns everything that is not GUI:
--   * wiring the MagmaRemotes folder into Interface,
--   * the carried brainrot riding on the player's back, with its name tag,
--   * the RUN HOME! decision (carrying + eruption warning or a fresh goblin
--     chase toast => danger) — Interface only draws the banner,
--   * the mallet swing hook (the tool is server-given; its Activated event is
--     hooked here to play a swing animation),
--   * parade buying: ProximityPrompts tagged with a BrainrotId fire BuyBrainrot,
--   * local feedback for the server Fx remote: particle bursts, light flashes
--     and sounds (buy cha-ching, collect sparkle, catch, quest, eruption),
--   * eruption camera shake and FOV kick,
--   * desktop conveniences: F = collect, L = lock, 1/2/3/4 = panels, Esc = close.
--
-- Ash and lava ambience in the world itself is built by the server; everything
-- here is local-only decoration and never decides game state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

--====================================================================--
-- Remotes (folder "MagmaRemotes" in ReplicatedStorage)
--====================================================================--

local remotesFolder = ReplicatedStorage:WaitForChild("MagmaRemotes", 20)

local function grabRemote(name)
	if not remotesFolder then
		return nil
	end
	return remotesFolder:WaitForChild(name, 10)
end

local remotes = {
	BuyBrainrot = grabRemote("BuyBrainrot"),
	CollectCash = grabRemote("CollectCash"),
	BuyUpgrade = grabRemote("BuyUpgrade"),
	DoRekindle = grabRemote("DoRekindle"),
	ToggleLock = grabRemote("ToggleLock"),
	ClaimQuest = grabRemote("ClaimQuest"),
	RerollMutation = grabRemote("RerollMutation"),
	SetSprint = grabRemote("SetSprint"),
	HudUpdate = grabRemote("HudUpdate"),
	Toast = grabRemote("Toast"),
	Fx = grabRemote("Fx"),
	GetIndexState = grabRemote("GetIndexState"),
}

local Interface = require(script.Parent:WaitForChild("Interface"))
Interface.init(remotes)

--====================================================================--
-- Local sounds (built-in Roblox sounds only; pitch carries the variety)
--====================================================================--

local SOUND_RECIPES = {
	collect = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.5, volume = 0.55 },
	buy = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.85, volume = 0.7 },
	catch = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.9, volume = 0.7 },
	quest = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.2, volume = 0.7 },
	warn = { id = "rbxasset://sounds/click.wav", speed = 0.7, volume = 0.8 },
	eruption = { id = "rbxasset://sounds/click.wav", speed = 0.45, volume = 1.0 },
	swing = { id = "rbxasset://sounds/click.wav", speed = 1.6, volume = 0.35 },
}

local function playSound(kind)
	local recipe = SOUND_RECIPES[kind]
	if not recipe then
		return
	end
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = recipe.id
		s.PlaybackSpeed = recipe.speed
		s.Volume = recipe.volume
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 2)
	end)
end

--====================================================================--
-- Fx remote: particle bursts + light flashes at a position
--====================================================================--

local FX_COLORS = {
	collect = Color3.fromRGB(255, 215, 90),
	buy = Color3.fromRGB(96, 220, 110),
	catch = Color3.fromRGB(255, 170, 40),
	quest = Color3.fromRGB(92, 225, 255),
	eruption = Color3.fromRGB(255, 80, 40),
}

local cameraShake = 0

local function spawnBurst(position, kind)
	if typeof(position) ~= "Vector3" then
		return
	end
	local color = FX_COLORS[kind] or FX_COLORS.collect
	pcall(function()
		local anchor = Instance.new("Part")
		anchor.Name = "MagmaFx"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.4, 0.4, 0.4)
		anchor.Position = position + Vector3.new(0, 1.2, 0)
		anchor.Parent = workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Lifetime = NumberRange.new(0.35, 0.7)
		emitter.Speed = NumberRange.new(5, 10)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Rate = 0
		emitter.Parent = anchor
		emitter:Emit(kind == "eruption" and 60 or 26)

		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 3
		light.Range = 14
		light.Parent = anchor
		TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()

		Debris:AddItem(anchor, 1.4)
	end)
end

if remotes.Fx then
	remotes.Fx.OnClientEvent:Connect(function(kind, position)
		kind = tostring(kind or "collect"):lower()
		spawnBurst(position, kind)
		playSound(kind)
		if kind == "eruption" then
			cameraShake = 1
		end
	end)
end

--====================================================================--
-- The carried brainrot on the player's back
--====================================================================--

local MAGMA = Color3.fromRGB(255, 110, 40)
local carriedNameNow = ""
local carriedModel = nil
local carriedMotor = nil

local function clearCarriedVisual()
	if carriedModel then
		carriedModel:Destroy()
		carriedModel = nil
		carriedMotor = nil
	end
end

local function buildCarriedVisual(character, name)
	clearCarriedVisual()
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then
		return
	end
	local entry = Interface.findCastByName(name)
	local color = entry and entry.color or MAGMA

	local model = Instance.new("Model")
	model.Name = "CarriedBrainrot"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.7, 1.7, 1.7)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Massless = true
	body.CFrame = hrp.CFrame * CFrame.new(0, 1.7, 1.6)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(0.95, 0.95, 0.95)
	head.Color = color:Lerp(Color3.new(1, 1, 1), 0.25)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Massless = true
	head.CFrame = body.CFrame * CFrame.new(0, 0.95, 0)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head

	local motor = Instance.new("Motor6D")
	motor.Name = "CarryMotor"
	motor.Part0 = hrp
	motor.Part1 = body
	motor.C0 = CFrame.new(0, 1.6, 1.1)
	motor.C1 = CFrame.new()
	motor.Parent = body

	local tag = Instance.new("BillboardGui")
	tag.Name = "CarryTag"
	tag.Adornee = body
	tag.Size = UDim2.new(0, 210, 0, 52)
	tag.StudsOffset = Vector3.new(0, 1.9, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model
	local tagLabel = Instance.new("TextLabel")
	tagLabel.BackgroundTransparency = 1
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.Text = "🎒 " .. name
	tagLabel.TextSize = 20
	tagLabel.Font = Enum.Font.GothamBlack
	tagLabel.TextColor3 = Color3.new(1, 1, 1)
	tagLabel.TextStrokeTransparency = 0.4
	tagLabel.Parent = tag

	model.Parent = character
	carriedModel = model
	carriedMotor = motor
end

--====================================================================--
-- Mallet swing hook
--====================================================================--

local hookedTools = {}

local function proceduralSwing(character)
	local shoulder = nil
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == "RightShoulder" then
			shoulder = d
			break
		end
	end
	if not shoulder then
		return
	end
	pcall(function()
		local down = TweenService:Create(shoulder, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transform = CFrame.Angles(-1.9, 0, 0),
		})
		local up = TweenService:Create(shoulder, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Transform = CFrame.new(),
		})
		down:Play()
		down.Completed:Connect(function()
			up:Play()
		end)
	end)
end

local function playSwing(tool)
	playSound("swing")
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local anim = tool:FindFirstChild("Swing") or tool:FindFirstChildOfClass("Animation")
	if humanoid and anim and anim:IsA("Animation") then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			pcall(function()
				animator:LoadAnimation(anim):Play(0.05)
			end)
			return
		end
	end
	proceduralSwing(character)
end

local function hookTool(tool)
	if not tool or not tool:IsA("Tool") or hookedTools[tool] then
		return
	end
	local lname = tool.Name:lower()
	if not (lname:find("mallet") or lname:find("hammer") or tool:GetAttribute("MagmaTool")) then
		return
	end
	hookedTools[tool] = true
	tool.Activated:Connect(function()
		playSwing(tool)
	end)
end

local function hookBackpackAndCharacter()
	local backpack = player:FindFirstChildOfClass("PlayerBackpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			hookTool(child)
		end
		backpack.ChildAdded:Connect(hookTool)
	end
	if player.Character then
		for _, child in ipairs(player.Character:GetChildren()) do
			hookTool(child)
		end
		player.Character.ChildAdded:Connect(hookTool)
	end
end

--====================================================================--
-- Parade buying: tagged ProximityPrompts fire BuyBrainrot
--====================================================================--

local hookedPrompts = {}

local function promptBrainrotId(prompt)
	local id = prompt:GetAttribute("BrainrotId") or prompt:GetAttribute("BrainrotID") or prompt:GetAttribute("Id")
	if id ~= nil then
		return id
	end
	local v = prompt:FindFirstChild("BrainrotId")
	if v and v:IsA("ValueBase") then
		return v.Value
	end
	return nil
end

local function hookPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") or hookedPrompts[prompt] then
		return
	end
	local id = promptBrainrotId(prompt)
	if id == nil then
		return
	end
	hookedPrompts[prompt] = true
	prompt.Triggered:Connect(function(plr)
		if plr == player and remotes.BuyBrainrot then
			remotes.BuyBrainrot:FireServer(id)
			playSound("buy")
		end
	end)
end

for _, d in ipairs(workspace:GetDescendants()) do
	hookPrompt(d)
end
workspace.DescendantAdded:Connect(hookPrompt)

--====================================================================--
-- Eruption camera: shake while erupting + FOV kick
--====================================================================--

local function eruptionKindOf(state)
	local phase = tostring(state.eruptionPhase or "none"):lower()
	if phase:find("warn") then
		return "warning"
	elseif phase:find("erupt") then
		return "erupting"
	end
	return "none"
end

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local kind = eruptionKindOf(Interface.getState())
	local targetFov = (kind == "erupting") and 75 or 70
	camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * math.min(1, dt * 3)
	if kind == "erupting" then
		cameraShake = math.max(cameraShake, 0.35)
	end
	if cameraShake > 0.01 then
		local m = cameraShake * 0.02
		camera.CFrame = camera.CFrame * CFrame.Angles(
			(math.random() - 0.5) * 2 * m,
			(math.random() - 0.5) * 2 * m,
			(math.random() - 0.5) * 1.4 * m
		)
		cameraShake = math.max(0, cameraShake - dt * 1.3)
	end
	-- Gentle bob for the carried brainrot.
	if carriedMotor then
		local t = tick()
		carriedMotor.Transform = CFrame.new(0, math.sin(t * 3.1) * 0.07, 0)
			* CFrame.Angles(0, math.sin(t * 1.6) * 0.18, math.sin(t * 2.3) * 0.06)
	end
end)

--====================================================================--
-- State watcher: carried visual, RUN HOME!, phase-change stingers
--====================================================================--

local runHomeOn = false
local lastPhase = "none"

task.spawn(function()
	while true do
		task.wait(0.15)
		local st = Interface.getState()
		local want = (type(st.carriedName) == "string") and st.carriedName or ""
		if want ~= carriedNameNow then
			carriedNameNow = want
			if want ~= "" and player.Character then
				buildCarriedVisual(player.Character, want)
			else
				clearCarriedVisual()
			end
		end

		local phase = eruptionKindOf(st)
		if phase ~= lastPhase then
			if phase == "warning" then
				playSound("warn")
			elseif phase == "erupting" then
				playSound("eruption")
				cameraShake = 1
			end
			lastPhase = phase
		end

		local carrying = want ~= ""
		local chased = (tick() - (st.lastChaseAt or -math.huge)) < 6
		local danger = carrying and (phase == "warning" or phase == "erupting" or chased)
		if danger ~= runHomeOn then
			runHomeOn = danger
			if danger then
				playSound("warn")
			end
		end
		Interface.setRunHomeVisible(danger)
	end
end)

player.CharacterAdded:Connect(function(character)
	hookBackpackAndCharacter()
	if carriedNameNow ~= "" then
		task.wait(0.4)
		buildCarriedVisual(character, carriedNameNow)
	end
end)
hookBackpackAndCharacter()

--====================================================================--
-- Desktop conveniences: F = collect, L = lock, 1-4 = panels, Esc = close
--====================================================================--

local PANEL_KEYS = {
	[Enum.KeyCode.One] = "index",
	[Enum.KeyCode.Two] = "upgrades",
	[Enum.KeyCode.Three] = "rekindle",
	[Enum.KeyCode.Four] = "quest",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		Interface.pulseCollect()
		if remotes.CollectCash then
			remotes.CollectCash:FireServer()
		end
	elseif input.KeyCode == Enum.KeyCode.L then
		if remotes.ToggleLock then
			remotes.ToggleLock:FireServer()
		end
	elseif PANEL_KEYS[input.KeyCode] then
		if Interface.togglePanel then
			Interface.togglePanel(PANEL_KEYS[input.KeyCode])
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if Interface.closePanels then
			Interface.closePanels()
		end
	end
end)

--====================================================================--
-- Sprint: hold Shift (left or right) to run. The server owns the
-- actual speed (Progression.ApplyMovement, x1.5); the client only
-- reports the flag, and only when it changes. InputBegan is
-- ignored while the game processed the key (typing in chat); the
-- release is always reported so sprint can never stick on.
--====================================================================--

local sprintHeld = false
local function setSprint(on)
	if sprintHeld == on then
		return
	end
	sprintHeld = on
	if remotes.SetSprint then
		remotes.SetSprint:FireServer(on)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprint(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprint(false)
	end
end)

--====================================================================--
-- Music: auto-discovery playlist. The server creates an empty
-- ReplicatedStorage > MusicTracks folder; Akmal drops free Studio
-- Toolbox Sound tracks into it himself. The client rotates through
-- every Sound found there (re-scanning when a track ends or a new
-- one appears); an empty folder simply means silence. Playback
-- volume is modest (0.35) and the HUD speaker button (Interface)
-- mutes for the session. Everything is pcall-wrapped: a music
-- error can never break the client.
--====================================================================--

local musicPlayer = nil
local musicMuted = false

local function collectTracks(folder)
	local tracks = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") and child.SoundId ~= "" then
			table.insert(tracks, child)
		end
	end
	table.sort(tracks, function(a, b)
		return a.Name < b.Name
	end)
	return tracks
end

local function startMusic()
	pcall(function()
		local folder = ReplicatedStorage:FindFirstChild("MusicTracks")
		if not folder or musicMuted then
			return
		end
		if musicPlayer and musicPlayer.IsPlaying then
			return
		end
		local tracks = collectTracks(folder)
		if #tracks == 0 then
			return
		end
		if not musicPlayer then
			musicPlayer = Instance.new("Sound")
			musicPlayer.Name = "MagmaMusicPlayer"
			musicPlayer.Volume = 0.35
			musicPlayer.Parent = SoundService
			musicPlayer.Ended:Connect(function()
				pcall(function()
					if musicMuted or not musicPlayer then
						return
					end
					local f2 = ReplicatedStorage:FindFirstChild("MusicTracks")
					if not f2 then
						return
					end
					local list = collectTracks(f2)
					if #list == 0 then
						return
					end
					-- Advance past the track that just ended; the
					-- list wraps, so a single track loops itself.
					local idx = 1
					for i, tr in ipairs(list) do
						if tr.SoundId == musicPlayer.SoundId then
							idx = i
							break
						end
					end
					musicPlayer.SoundId = list[(idx % #list) + 1].SoundId
					musicPlayer.TimePosition = 0
					musicPlayer:Play()
				end)
			end)
		end
		musicPlayer.SoundId = tracks[1].SoundId
		musicPlayer.TimePosition = 0
		musicPlayer:Play()
	end)
end

-- The HUD mute button (Interface) calls this; session-only state.
Interface.onMusicMuteToggled = function(muted)
	musicMuted = muted
	pcall(function()
		if muted then
			if musicPlayer then
				musicPlayer:Stop()
			end
		else
			startMusic()
		end
	end)
end

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("MusicTracks", 30)
	if folder then
		folder.ChildAdded:Connect(function()
			task.delay(0.5, startMusic)
		end)
		startMusic()
	end
end)
