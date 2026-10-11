--!strict
-- The Welcome Back window (2026-10-11, user, after Capybara Onsen's): when a player
-- returns after a while, a window shows what their brainrots earned while they were
-- away: a green studded header with a clock, "Welcome Back" and an X, then "Offline
-- Aura" with the gem and the amount, the time away, any Cash the processor made, and a
-- Claim button. The server already credited it all (PlotService, OfflineEarnings);
-- Claim just closes the window with the cash sound.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Config.Sounds)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

local INK = Color3.fromRGB(20, 20, 26)
local GREEN = Color3.fromRGB(110, 210, 50)
local GREEN_DARK = Color3.fromRGB(30, 90, 14)
local BODY = Color3.fromRGB(34, 34, 40)
local GOLD = Color3.fromRGB(255, 214, 90)

local WelcomeBackController = {}

local function timeText(seconds: number): string
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	end
	return if hours > 0 then `{hours}h {minutes}m` else `{math.max(1, minutes)}m`
end

function WelcomeBackController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	Style.autoScale(gui)

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(460, 380)
	window.BackgroundColor3 = BODY
	window.BackgroundTransparency = 0.08
	window.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = window
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 4
	stroke.Parent = window
	local scale = Instance.new("UIScale")
	scale.Parent = window

	-- Header.
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 74)
	header.BackgroundColor3 = GREEN
	header.Parent = window
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = GREEN_DARK
	headerStroke.Thickness = 3
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = header
	local studs = Instance.new("ImageLabel")
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.Image = Style.STUDS_IMAGE
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(32, 32)
	studs.ImageTransparency = 0.45
	studs.Parent = header
	local clock = Style.outlined(header, "Clock", Color3.new(1, 1, 1), INK, 2)
	clock.Text = "⏰"
	clock.AnchorPoint = Vector2.new(0, 0.5)
	clock.Position = UDim2.new(0, 10, 0.5, -6)
	clock.Size = UDim2.fromOffset(70, 70)
	clock.ZIndex = 2
	local title = Style.outlined(header, "Title", Color3.new(1, 1, 1), INK, 3)
	title.Text = "Welcome Back"
	title.Position = UDim2.fromOffset(84, 10)
	title.Size = UDim2.new(1, -170, 0, 54)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2
	local close, closeLabel = Style.button(header, "Close", Color3.fromRGB(220, 50, 50), Color3.fromRGB(110, 14, 14))
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, 0)
	close.Size = UDim2.fromOffset(58, 54)
	close.ZIndex = 3
	closeLabel.Text = "X"

	-- Body.
	local caption = Style.outlined(window, "Caption", Color3.new(1, 1, 1), INK, 2)
	caption.Text = "Offline Aura"
	caption.Position = UDim2.fromOffset(0, 84)
	caption.Size = UDim2.new(1, 0, 0, 34)
	local gem = Instance.new("ImageLabel")
	gem.BackgroundTransparency = 1
	gem.Image = Style.AURA_ICON
	gem.AnchorPoint = Vector2.new(0.5, 0)
	gem.Position = UDim2.new(0.5, 0, 0, 122)
	gem.Size = UDim2.fromOffset(84, 84)
	gem.Parent = window
	local amount = Style.outlined(window, "Amount", GOLD, INK, 3)
	amount.Position = UDim2.fromOffset(10, 210)
	amount.Size = UDim2.new(1, -20, 0, 50)
	local details = Style.outlined(window, "Details", Color3.fromRGB(220, 220, 230), INK, 2)
	details.Position = UDim2.fromOffset(10, 262)
	details.Size = UDim2.new(1, -20, 0, 24)

	local claim, claimLabel = Style.button(window, "Claim", GREEN, GREEN_DARK)
	claim.AnchorPoint = Vector2.new(0.5, 0)
	claim.Position = UDim2.new(0.5, 0, 0, 298)
	claim.Size = UDim2.fromOffset(200, 62)
	claimLabel.Text = "Claim"

	local function hide(withSound: boolean)
		if withSound and Sounds.CASH ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = Sounds.CASH
			sound.Volume = Sounds.CUE_VOLUME
			sound.PlayOnRemove = true
			sound.Parent = SoundService
			sound:Destroy()
		end
		local shrink = TweenService:Create(
			scale,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		)
		shrink:Play()
		shrink.Completed:Wait()
		gui.Enabled = false
	end
	claim.Activated:Connect(function()
		hide(true)
	end)
	close.Activated:Connect(function()
		hide(false)
	end)

	Remotes.event("OfflineEarnings").OnClientEvent:Connect(function(aura: unknown, cash: unknown, seconds: unknown)
		if typeof(aura) ~= "number" or typeof(cash) ~= "number" or typeof(seconds) ~= "number" then
			return
		end
		amount.Text = `+{Format.short(aura)} Aura`
		details.Text = if cash > 0
			then `Away {timeText(seconds)}  •  the processor made +${Format.short(cash)}`
			else `Away {timeText(seconds)}`
		scale.Scale = 0
		gui.Enabled = true
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return WelcomeBackController
