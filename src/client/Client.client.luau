--[[
	Client.client.luau — BRAINROT HEIST heads-up display.

	Paste target: a LocalScript named "Client" in
	StarterPlayer > StarterPlayerScripts.

	Everything here is display and one button. The server owns the truth:
	cash and rebirths live in leaderstats, and the server maintains two
	values on the player — Carrying (what is over your head right now) and
	IncomePerSec (what your banked brainrots pay you). This script reads
	those, draws the HUD, shows the server's banner messages
	(BrainrotNotify), and asks for a rebirth (BrainrotRebirth) when the
	button is pressed — the server validates and applies it.

	Layout note: the top-LEFT corner stays empty on purpose — Roblox's own
	menu buttons live there. Stats sit top-right, banners top-centre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Brainrots = require(ReplicatedStorage:WaitForChild("Brainrots"))
local notifyEvent = ReplicatedStorage:WaitForChild("BrainrotNotify")
local rebirthEvent = ReplicatedStorage:WaitForChild("BrainrotRebirth")

local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash")
local rebirthsValue = leaderstats:WaitForChild("Rebirths")
local carryingValue = player:WaitForChild("Carrying")
local incomeValue = player:WaitForChild("IncomePerSec")

--====================================================================--
-- Small GUI helpers
--====================================================================--

local function makeFrame(parent, name, size, position, anchor, color, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.new(0, 0)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	return f
end

local function makeLabel(parent, name, text, size, position, font, textSize, color, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextStrokeTransparency = 0.7
	l.Parent = parent
	return l
end

--====================================================================--
-- The HUD
--====================================================================--

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5

-- Stats panel, top-right: cash, income rate, rebirth multiplier.
local panel = makeFrame(gui, "StatsPanel",
	UDim2.fromOffset(258, 100), UDim2.new(1, -14, 0, 14), Vector2.new(1, 0),
	Color3.fromRGB(18, 22, 36), 0.22)
local cashLabel = makeLabel(panel, "Cash", "$0",
	UDim2.new(1, -20, 0, 36), UDim2.fromOffset(12, 4),
	Enum.Font.FredokaOne, 27, Color3.fromRGB(255, 205, 60))
local incomeLabel = makeLabel(panel, "Income", "+$0/s",
	UDim2.new(1, -20, 0, 26), UDim2.fromOffset(12, 42),
	Enum.Font.GothamBold, 18, Color3.fromRGB(140, 255, 150))
local multLabel = makeLabel(panel, "Mult", "",
	UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 70),
	Enum.Font.GothamBold, 14, Color3.fromRGB(170, 200, 255))

-- Carried line, top-centre: what is over your head and what to do with it.
local carryLabel = makeLabel(gui, "Carrying", "",
	UDim2.fromOffset(560, 34), UDim2.new(0.5, 0, 0, 14), Enum.Font.FredokaOne, 19,
	Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Center)
carryLabel.AnchorPoint = Vector2.new(0.5, 0)
carryLabel.BackgroundTransparency = 0.45
carryLabel.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
carryLabel.Visible = false
local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 10)
carryCorner.Parent = carryLabel

-- Banner, upper-centre: wave warnings, steal alerts, bandit news.
local banner = makeLabel(gui, "Banner", "",
	UDim2.fromOffset(820, 56), UDim2.new(0.5, 0, 0.3, 0), Enum.Font.FredokaOne, 30,
	Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Center)
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.TextStrokeTransparency = 0.25
banner.Visible = false

-- Rebirth button, bottom-right: price and current multiplier on its face.
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Size = UDim2.fromOffset(238, 66)
rebirthButton.Position = UDim2.new(1, -14, 1, -14)
rebirthButton.AnchorPoint = Vector2.new(1, 1)
rebirthButton.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
rebirthButton.BorderSizePixel = 0
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextSize = 16
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.Text = "REBIRTH"
rebirthButton.Parent = gui
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 12)
buttonCorner.Parent = rebirthButton
rebirthButton.MouseButton1Click:Connect(function()
	rebirthEvent:FireServer()
end)

-- One-line how-to, bottom-left (the top-left stays clear for Roblox).
local helpLabel = makeLabel(gui, "Help",
	"Buy on the lane -> carry it HOME -> bank it. Steal rivals' brainrots — and beware the BANDIT and the TSUNAMI!",
	UDim2.fromOffset(560, 24), UDim2.new(0, 14, 1, -14),
	Enum.Font.GothamBold, 14, Color3.fromRGB(255, 255, 255))
helpLabel.AnchorPoint = Vector2.new(0, 1)
helpLabel.TextTransparency = 0.25

gui.Parent = player:WaitForChild("PlayerGui")

--====================================================================--
-- Refresh from the server's values
--====================================================================--

local function refresh()
	cashLabel.Text = Brainrots.FormatMoney(cashValue.Value)
	incomeLabel.Text = "+" .. Brainrots.FormatMoney(incomeValue.Value) .. "/s"
	local rebirths = rebirthsValue.Value
	local mult = Brainrots.RebirthMult(rebirths)
	multLabel.Text = "Rebirth x" .. mult .. " (" .. rebirths .. " rebirths)"
	rebirthButton.Text = "REBIRTH — " .. Brainrots.FormatMoney(Brainrots.RebirthCost(rebirths))
		.. "\n+50% income forever (now x" .. mult .. ")"
	local carrying = carryingValue.Value
	if carrying ~= "" then
		carryLabel.Text = "Carrying: " .. carrying .. " — bank it at YOUR base!"
		carryLabel.Visible = true
	else
		carryLabel.Visible = false
	end
end

cashValue.Changed:Connect(refresh)
rebirthsValue.Changed:Connect(refresh)
carryingValue.Changed:Connect(refresh)
incomeValue.Changed:Connect(refresh)
refresh()

--====================================================================--
-- Banners from the server
--====================================================================--

local KIND_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	good = Color3.fromRGB(140, 255, 150),
	warn = Color3.fromRGB(255, 210, 80),
	danger = Color3.fromRGB(255, 95, 95),
}

local bannerSeq = 0
notifyEvent.OnClientEvent:Connect(function(text, kind)
	bannerSeq += 1
	local seq = bannerSeq
	banner.Text = text
	banner.TextColor3 = KIND_COLORS[kind] or KIND_COLORS.info
	banner.Visible = true
	task.delay(4, function()
		if bannerSeq == seq then
			banner.Visible = false
		end
	end)
end)
