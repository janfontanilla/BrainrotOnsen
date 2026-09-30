--!strict
-- The Index: an "Index" button at the top center (right of Home) opens a grid
-- of all tiers. Discovered tiers show the brainrot's model, name and Aura per
-- drop; undiscovered ones are its dark silhouette with "???". Reads the Discovered
-- attribute the server sets ("0101...", one char per tier).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Models = require(Shared.Models)
local Format = require(Shared.Format)
local Visuals = require(Shared.Visuals)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

local COLUMNS = 4
local CELL = Vector2.new(150, 150)
local SILHOUETTE = Color3.fromRGB(25, 25, 30)

local IndexController = {}

-- A picture of the tier's brainrot in a ViewportFrame; a flat dark silhouette
-- when it has not been discovered yet.
local function makeIcon(parent: Instance, tier: number, known: boolean): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.new(0.5, 0, 0.5, -4)
	view.Size = UDim2.fromOffset(112, 104)
	view.BackgroundTransparency = 1
	view.Parent = parent

	local model = Models.makeBrainrot(tier)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
			descendant:Destroy()
		elseif not known then
			if descendant:IsA("SurfaceAppearance") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Color = SILHOUETTE
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant:IsA("MeshPart") then
					descendant.TextureID = ""
				end
			end
		end
	end
	local label = model:FindFirstChild("Label")
	if label then
		label:Destroy()
	end
	local size = model:GetExtentsSize()
	local biggest = math.max(size.Y, size.X, size.Z)
	-- Three-quarter view: turn the model a little and look at its middle.
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = view

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.55 + 0.5, -biggest * 1.9), Vector3.new(0, size.Y * 0.5, 0))
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

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

	-- The Index button: tan and studded, right of Home (HudController).
	local open, openLabel = Style.button(gui, "IndexButton", Color3.fromRGB(216, 152, 98), Color3.fromRGB(96, 54, 22))
	open.AnchorPoint = Vector2.new(0, 0)
	open.Position = UDim2.new(0.5, 8, 0, 8)
	open.Size = UDim2.fromOffset(180, 58)
	openLabel.Text = "Index"

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

			makeIcon(cell, def.tier, known)

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
