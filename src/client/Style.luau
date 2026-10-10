--!strict
-- HUD building blocks in Capybara Onsen's style: blocky studded buttons with a
-- thick dark border, and big text with a thick dark outline and no background.
-- Image IDs are uploaded from assets/textures (ui_studs.png, aura_icon.png, friends_icon.png).

local Style = {}

Style.STUDS_IMAGE = "rbxassetid://116195014081230" -- translucent stud tile laid over buttons
Style.AURA_ICON = "rbxassetid://105037500567475"
Style.FRIENDS_ICON = "rbxassetid://85467253576318" -- friends_icon.png: two yellow heads (2026-10-09)
Style.FONT = Enum.Font.FredokaOne

-- Big text with a thick outline and no box.
function Style.outlined(parent: Instance, name: string, color: Color3, outline: Color3, thickness: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Style.FONT
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = color
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = outline
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end

-- A blocky studded button: `face` colour under a stud tile, a dark `border`, and
-- outlined white text (returned as the second value so callers can change it).
function Style.button(parent: Instance, name: string, face: Color3, border: Color3): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = face
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = border
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local studs = Instance.new("ImageLabel")
	studs.Name = "Studs"
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.Image = Style.STUDS_IMAGE
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(22, 22)
	studs.Parent = button
	local studCorner = Instance.new("UICorner")
	studCorner.CornerRadius = UDim.new(0, 6)
	studCorner.Parent = studs
	local label = Style.outlined(button, "Label", Color3.new(1, 1, 1), border, 3)
	label.Size = UDim2.new(1, -16, 1, -12)
	label.Position = UDim2.fromOffset(8, 6)
	label.ZIndex = 2
	return button, label
end

-- Scales everything in `gui` with the screen: the HUD is laid out in pixels for a
-- 1280 x 720 screen, so phones shrink it (never below MIN_SCALE) and it never grows.
local DESIGN_SIZE = Vector2.new(1280, 720)
local MIN_SCALE = 0.55

function Style.autoScale(gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function update()
		local view = camera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / DESIGN_SIZE.X, view.Y / DESIGN_SIZE.Y), MIN_SCALE, 1)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

return Style
