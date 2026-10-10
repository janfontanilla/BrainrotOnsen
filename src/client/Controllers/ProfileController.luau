--!strict
-- The Profile page (2026-10-09, user's Capybara Onsen reference): a small button with
-- the player's headshot left of Home opens a window with a cyan studded header (the
-- headshot, "Profile", a red X) and the player's stats: Net Worth (lifetime Cash
-- earned), Brainrots (total obtained), Best Brainrot and Time Played. Values come
-- from player attributes (DataService / LeaderboardService keep them current).

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Tiers = require(Shared.Config.Tiers)
local Visuals = require(Shared.Visuals)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

local HEADER = Color3.fromRGB(40, 200, 230)
local HEADER_BORDER = Color3.fromRGB(16, 80, 110)
local BODY = Color3.fromRGB(34, 34, 40)
local ROW = Color3.fromRGB(46, 46, 54)
local INK = Color3.fromRGB(20, 20, 26)

local ProfileController = {}

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function timeText(seconds: number): string
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h {minutes}m`
	end
	return if hours > 0 then `{hours}h {minutes}m` else `{minutes}m`
end

function ProfileController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Profile"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- children draw over their parent (the X on its button)
	Style.autoScale(gui)

	local headshot = ""
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok then
			headshot = image
		end
	end)

	-- The button: a small square left of Home showing just the player's face.
	local open, openLabel =
		Style.button(gui, "ProfileButton", Color3.fromRGB(230, 230, 236), Color3.fromRGB(60, 60, 70))
	openLabel:Destroy() -- just the player's face, no text (user)
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(0.5, -196, 0, 8)
	open.Size = UDim2.fromOffset(58, 58)
	local openFace = Instance.new("ImageLabel")
	openFace.BackgroundTransparency = 1
	openFace.AnchorPoint = Vector2.new(0.5, 0.5)
	openFace.Position = UDim2.fromScale(0.5, 0.5)
	openFace.Size = UDim2.fromScale(1, 1)
	openFace.ZIndex = 5
	openFace.Parent = open

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromOffset(620, 470)
	window.BackgroundColor3 = BODY
	window.Visible = false
	window.Parent = gui
	local windowStroke = Instance.new("UIStroke")
	windowStroke.Color = INK
	windowStroke.Thickness = 4
	windowStroke.Parent = window

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 84)
	header.BackgroundColor3 = HEADER
	header.Parent = window
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = HEADER_BORDER
	headerStroke.Thickness = 3
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = header
	local studs = Instance.new("ImageLabel")
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.Image = Style.STUDS_IMAGE
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(40, 40)
	studs.ImageTransparency = 0.5
	studs.Parent = header

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0, 0.5)
	face.Position = UDim2.new(0, 14, 0.5, 0)
	face.Size = UDim2.fromOffset(64, 64)
	face.BackgroundColor3 = Color3.fromRGB(200, 90, 80)
	face.ZIndex = 2
	face.Parent = header
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(1, 0)
	faceCorner.Parent = face
	local faceStroke = Instance.new("UIStroke")
	faceStroke.Color = INK
	faceStroke.Thickness = 3
	faceStroke.Parent = face

	local title = Style.outlined(header, "Title", Color3.new(1, 1, 1), INK, 3)
	title.Text = "Profile"
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.new(0, 92, 0.5, 0)
	title.Size = UDim2.fromOffset(260, 56)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2

	local close, closeLabel = Style.button(header, "Close", Color3.fromRGB(220, 50, 50), Color3.fromRGB(110, 14, 14))
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, 0)
	close.Size = UDim2.fromOffset(62, 58)
	close.ZIndex = 3
	closeLabel.Text = "X"

	local statsTitle = Style.outlined(window, "Stats", Color3.new(1, 1, 1), INK, 3)
	statsTitle.Text = "Stats"
	statsTitle.Position = UDim2.fromOffset(0, 96)
	statsTitle.Size = UDim2.new(1, 0, 0, 46)

	local rows: { [string]: TextLabel } = {}
	local function row(name: string, color: Color3, order: number)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Position = UDim2.fromOffset(22, 152 + (order - 1) * 76)
		frame.Size = UDim2.new(1, -44, 0, 66)
		frame.BackgroundColor3 = ROW
		frame.Parent = window
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 3
		stroke.Parent = frame
		local key = Style.outlined(frame, "Key", color, INK, 3)
		key.Text = name
		key.Position = UDim2.fromOffset(16, 8)
		key.Size = UDim2.new(0.55, -16, 1, -16)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local value = Style.outlined(frame, "Value", Color3.new(1, 1, 1), INK, 3)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -16, 0, 8)
		value.Size = UDim2.new(0.45, -16, 1, -16)
		value.TextXAlignment = Enum.TextXAlignment.Right
		rows[name] = value
	end
	row("Net Worth", Color3.fromRGB(60, 240, 60), 1)
	row("Brainrots", Color3.fromRGB(255, 186, 90), 2)
	row("Best Brainrot", Color3.fromRGB(110, 200, 255), 3)
	row("Time Played", Color3.fromRGB(200, 90, 255), 4)

	local function refresh()
		if headshot ~= "" then
			face.Image = headshot
			openFace.Image = headshot
		end
		rows["Net Worth"].Text = "$" .. Format.short(number("NetWorth"))
		rows["Brainrots"].Text = Format.commas(number("TotalBrainrots"))
		local best = number("HighestTier")
		rows["Best Brainrot"].Text = if best > 0 then Tiers.get(best).name else "-"
		rows["Best Brainrot"].TextColor3 = if best > 0 then Visuals.tierColor(best) else Color3.new(1, 1, 1)
		rows["Time Played"].Text = timeText(number("Playtime"))
	end

	open.Activated:Connect(function()
		window.Visible = not window.Visible
		refresh()
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
	for _, name in { "NetWorth", "TotalBrainrots", "HighestTier", "Playtime" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if window.Visible then
				refresh()
			end
		end)
	end
	task.delay(3, refresh) -- the button's headshot once the thumbnail is in
	gui.Parent = player:WaitForChild("PlayerGui")
end

return ProfileController
