--!strict
-- Floating text labels in the Capybara Onsen style (reference/capybara-onsen-plot-layout.webp):
-- bold rounded text with a thick dark outline, sized in studs so a label shrinks
-- with distance like the world around it (pixel-sized labels piled up on screen).
-- Rich text: callers colour parts of the text with <font color="...">.

local Billboard = {}

-- Colours used across labels (hex for rich text).
Billboard.CASH = "#7dff8a"
Billboard.GOLD = "#ffd84a"
Billboard.CYAN = "#5ee3ff"
Billboard.ROBUX = "#ffd966"

local OUTLINE = Color3.fromRGB(28, 28, 38)

export type Options = {
	width: number, -- studs
	height: number, -- studs
	offsetY: number?, -- studs from the adornee's centre to the label's bottom (default 1.5)
	maxDistance: number?,
	outline: number?, -- outline thickness in pixels (default 2.5)
}

-- A label floating above `adornee`, bottom edge `offsetY` studs above its centre.
function Billboard.new(adornee: BasePart, options: Options): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(options.width, options.height) -- scale = studs for a BillboardGui
	gui.StudsOffset = Vector3.new(0, (options.offsetY or 1.5) + options.height / 2, 0)
	gui.MaxDistance = options.maxDistance or 120
	gui.LightInfluence = 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 1
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = options.outline or 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end

-- Wraps `text` in a rich-text colour.
function Billboard.color(text: string, hex: string): string
	return `<font color="{hex}">{text}</font>`
end

return Billboard
