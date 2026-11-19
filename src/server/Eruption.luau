--[[
	Eruption.luau — the volcano's moods for MAGMA MAYHEM.

	ServerScriptService ModuleScript. Owns:
	  * The eruption cycle (~5 minutes): calm, a 30-second warning
	    with the countdown broadcast in the HUD state, then 20 seconds
	    of rising lava over the lowlands. Lava drains health and
	    knocks a carried brainrot loose; bases and the high zones are
	    safe. Surviving an eruption is a quest stat.
	  * The rotating events scheduler: Golden Hour (x2 income,
	    3 min), Mutation Storm (mutation odds x3, 2 min) and Goblin
	    Rush (a thief wave, 90 s), one at a time, announced by toast.

	Everything the HUD needs — phase, timings, active event — is
	published into Game.EruptionState / Game.EventState, which
	Economy's PushHud reads. This module never touches money.
]]

local Eruption = {}
local G = nil -- the Game context, set by Init

local CALM_SECONDS = 240 -- quiet between eruptions
local WARNING_SECONDS = 30 -- "get to high ground" time
local ERUPTING_SECONDS = 20 -- lava over the lowlands
local EVENT_GAP_SECONDS = 110 -- quiet between rotating events
local EVENT_FIRST_DELAY = 75 -- grace before the first event

local EVENT_ROTATION = {
	{ name = "Golden Hour", seconds = 180, incomeMult = 2, mutationOddsMult = 1,
		blurb = "All income DOUBLED for 3 minutes. Collect everything!" },
	{ name = "Mutation Storm", seconds = 120, incomeMult = 1, mutationOddsMult = 3,
		blurb = "Mutation odds TRIPLED for 2 minutes. Watch the parade!" },
	{ name = "Goblin Rush", seconds = 90, incomeMult = 1, mutationOddsMult = 1, rush = true,
		blurb = "Ash Goblins are swarming for 90 seconds. Guard your base!" },
}

local droppedThisEruption = {} -- [player] = true once lava took their load

local function playerRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--====================================================================--
-- The flood sheet: raise / lower the lava over the lowlands.
--====================================================================--

local function SetFloodLevel(targetY, seconds)
	local floodPart = G.Flood.part
	if not floodPart then
		return
	end
	task.spawn(function()
		local startY = floodPart.CFrame.Position.Y
		local started = os.clock()
		while true do
			local t = math.min(1, (os.clock() - started) / seconds)
			local y = startY + (targetY - startY) * t
			floodPart.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
			if t >= 1 then
				break
			end
			task.wait(0.05)
		end
	end)
end

--====================================================================--
-- Eruption cycle
--====================================================================--

local function RunEruptionCycle()
	while true do
		-- CALM: publish when the next eruption will start.
		G.EruptionState.phase = "calm"
		G.EruptionState.at = os.time() + CALM_SECONDS + WARNING_SECONDS
		G.Modules.Economy.PushHudAll()
		task.wait(CALM_SECONDS)

		-- WARNING: 30 seconds of dread, counted down in the HUD.
		G.EruptionState.phase = "warning"
		G.EruptionState.at = os.time() + WARNING_SECONDS
		G.ToastAll("ERUPTION INCOMING", "The volcano blows in 30 seconds — get to high ground!", "danger")
		G.Modules.Economy.PushHudAll()
		task.wait(WARNING_SECONDS)

		-- ERUPTING: the lowlands drown for 20 seconds.
		G.EruptionState.phase = "erupting"
		G.EruptionState.at = os.time() + ERUPTING_SECONDS
		droppedThisEruption = {}
		G.Flood.active = true
		SetFloodLevel(G.Flood.floodY, 2.5)
		G.ToastAll("ERUPTION!", "Lava over the lowlands! Bases and high zones are safe!", "danger")
		G.Modules.Economy.PushHudAll()
		task.wait(ERUPTING_SECONDS)

		-- RECOVERY: waters fall, survivors earn their quest credit.
		G.Flood.active = false
		SetFloodLevel(G.Flood.baseY, 3)
		G.EruptionState.phase = "calm"
		for player, st in pairs(G.State) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				st.stats.eruptionsSurvived += 1
			end
		end
		G.ToastAll("The eruption passes", "The lava sinks back. The island provides.", "success")
		G.Modules.Economy.PushHudAll()
	end
end

-- While the flood is up, standing in the lowlands burns: health
-- drains, and the first touch knocks a carried brainrot loose.
local function RunLavaDamageLoop()
	while true do
		task.wait(0.5)
		if G.Flood.active then
			for player, st in pairs(G.State) do
				local root = playerRoot(player)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < G.Flood.safeY then
					humanoid:TakeDamage(7)
					if st.carried and not droppedThisEruption[player] then
						droppedThisEruption[player] = true
						local lostName = st.carried.defName
						G.Modules.Economy.DropCarried(player,
							root.Position + Vector3.new(2.5, 1, 0))
						G.Toast(player, "The lava took it!", "Your " .. lostName
							.. " slipped into the flood — grab it back when it sinks!", "danger")
					end
				end
			end
		end
	end
end

--====================================================================--
-- Rotating events
--====================================================================--

local function RunEventScheduler()
	task.wait(EVENT_FIRST_DELAY)
	local index = 0
	while true do
		index = (index % #EVENT_ROTATION) + 1
		local event = EVENT_ROTATION[index]
		G.EventState.name = event.name
		G.EventState.endsAt = os.time() + event.seconds
		G.EventState.incomeMult = event.incomeMult
		G.EventState.mutationOddsMult = event.mutationOddsMult
		if event.rush then
			G.Modules.Thieves.TriggerGoblinRush(event.seconds)
		end
		G.ToastAll("EVENT: " .. string.upper(event.name), event.blurb, "event")
		G.Modules.Economy.PushHudAll()
		task.wait(event.seconds)

		G.EventState.name = "None"
		G.EventState.endsAt = 0
		G.EventState.incomeMult = 1
		G.EventState.mutationOddsMult = 1
		G.Modules.Economy.PushHudAll()
		task.wait(EVENT_GAP_SECONDS)
	end
end

function Eruption.Init(game)
	G = game
	task.spawn(RunEruptionCycle)
	task.spawn(RunLavaDamageLoop)
	task.spawn(RunEventScheduler)
end

return Eruption
