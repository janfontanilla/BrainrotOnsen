--!strict
-- The Index: an "Index" button at the top center (right of Home) opens a grid
-- of all tiers. Discovered tiers show their color, name and Aura per drop;
-- undiscovered ones are dark silhouettes with "???". Reads the Discovered
-- attribute the server sets ("0101...", one char per tier).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Format = require(Shared.Format)
local Visuals = require(Shared.Visuals)

local player = Players.LocalPlayer

local COLUMNS = 4
local CELL = Vector2.new(150, 150)
local SILHOUETTE = Color3.fromRGB(25, 25, 30)

local IndexController = {}

local function label(parent: Instance, value: string, color: Color3, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = value
	l.Size = size
	l.Position = position
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = l
	return l
end

function IndexController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Index"
	gui.ResetOnSpawn = false

	local open = Instance.new("TextButton")
	open.Name = "IndexButton"
	open.AnchorPoint = Vector2.new(0, 0)
	open.Position = UDim2.new(0.5, 6, 0, 8)
	open.Size = UDim2.fromOffset(160, 48)
	open.BackgroundColor3 = Color3.fromRGB(215, 150, 90)
	open.Font = Enum.Font.FredokaOne
	open.TextScaled = true
	open.TextColor3 = Color3.new(1, 1, 1)
	open.Text = "Index"
	open.Parent = gui
	local openCorner = Instance.new("UICorner")
	openCorner.CornerRadius = UDim.new(0, 10)
	openCorner.Parent = open
	local openStroke = Instance.new("UIStroke")
	openStroke.Thickness = 3
	openStroke.Color = Color3.fromRGB(90, 50, 20)
	openStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	openStroke.Parent = open
	local openPadding = Instance.new("UIPadding")
	openPadding.PaddingTop = UDim.new(0, 6)
	openPadding.PaddingBottom = UDim.new(0, 6)
	openPadding.Parent = open

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(COLUMNS * (CELL.X + 10) + 40, 520)
	window.BackgroundColor3 = Color3.fromRGB(240, 150, 50)
	window.Visible = false
	window.Parent = gui
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 14)
	windowCorner.Parent = window
	label(window, "Index", Color3.new(1, 1, 1), UDim2.fromOffset(200, 44), UDim2.fromOffset(16, 8)).TextXAlignment =
		Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = window
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close

	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(16, 60)
	grid.Size = UDim2.new(1, -32, 1, -76)
	grid.BackgroundColor3 = Color3.fromRGB(50, 35, 20)
	grid.ScrollBarThickness = 8
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 8)
	gridPadding.PaddingLeft = UDim.new(0, 8)
	gridPadding.Parent = grid

	local function refresh()
		local discovered = player:GetAttribute("Discovered")
		local flags = if typeof(discovered) == "string" then discovered else ""
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, def in Tiers.list do
			local known = string.sub(flags, def.tier, def.tier) == "1"
			local cell = Instance.new("Frame")
			cell.LayoutOrder = def.tier
			cell.BackgroundColor3 = Color3.fromRGB(35, 50, 30)
			cell.Parent = grid
			local cellCorner = Instance.new("UICorner")
			cellCorner.CornerRadius = UDim.new(0, 8)
			cellCorner.Parent = cell

			local swatch = Instance.new("Frame")
			swatch.AnchorPoint = Vector2.new(0.5, 0.5)
			swatch.Position = UDim2.fromScale(0.5, 0.5)
			swatch.Size = UDim2.fromOffset(64, 64)
			swatch.BackgroundColor3 = if known then Visuals.tierColor(def.tier) else SILHOUETTE
			swatch.Parent = cell
			local swatchCorner = Instance.new("UICorner")
			swatchCorner.CornerRadius = UDim.new(0, 6)
			swatchCorner.Parent = swatch

			label(
				cell,
				if known then Format.short(def.aura) else "?",
				Color3.fromRGB(255, 226, 90),
				UDim2.new(1, -12, 0, 26),
				UDim2.fromOffset(6, 4)
			).TextXAlignment =
				Enum.TextXAlignment.Right
			label(
				cell,
				if known then def.name else "???",
				if known then Visuals.tierColor(def.tier) else Color3.fromRGB(150, 150, 150),
				UDim2.new(1, -12, 0, 30),
				UDim2.new(0, 6, 1, -34)
			)
		end
	end

	open.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh()
		end
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
	player:GetAttributeChangedSignal("Discovered"):Connect(function()
		if window.Visible then
			refresh()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return IndexController
