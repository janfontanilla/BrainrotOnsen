--!strict
-- Builds the voxel props designed in tools/voxel_forge.py (data in PropData.luau)
-- as Models of merged coloured boxes, and places copies of them. Each prop's
-- origin is its bottom centre and it faces -Z. Templates are built once and cloned.

local PropData = require(script.Parent.PropData)

local Props = {}

local SHADOW_MIN_SIZE = 3 -- studs: boxes smaller than this in every direction cast no shadow

local templates: { [string]: Model } = {}

local function build(name: string): Model
	local data = PropData[name]
	assert(data, `Unknown prop {name}`)
	local glow: { [number]: boolean } = {}
	for _, index in data.glow do
		glow[index] = true
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, box in data.boxes do
		local part = Instance.new("Part")
		part.Name = "Voxel"
		part.Anchored = true
		part.CanCollide = data.solid
		part.CanQuery = data.solid
		part.CanTouch = false
		part.CastShadow = math.max(box[4], box[5], box[6]) >= SHADOW_MIN_SIZE -- small boxes: no shadow (cheaper)
		-- Studded tops like the pads (2026-10-10, user: Lego studs on everything but
		-- the brainrots); glowing boxes stay smooth Neon.
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = Vector3.new(box[4], box[5], box[6])
		part.CFrame = CFrame.new(box[1], box[2], box[3])
		local color = data.colors[box[7]]
		part.Color = Color3.fromRGB(color[1], color[2], color[3])
		part.Material = if glow[box[7]] then Enum.Material.Neon else Enum.Material.Plastic
		if not glow[box[7]] then
			part.MaterialVariant = "Onsen_lego" -- round Lego studs on every face (MaterialService)
		end
		part.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Whether prop `name` exists (tools/voxel_forge.py wrote it).
function Props.has(name: string): boolean
	return PropData[name] ~= nil
end

-- A fresh copy of prop `name`, unparented, bottom centre at the origin.
function Props.clone(name: string): Model
	local template = templates[name]
	if not template then
		template = build(name)
		templates[name] = template
	end
	return template:Clone()
end

-- Places a copy of prop `name` with its bottom centre at `cf`. `scale` multiplies its size.
function Props.place(name: string, cf: CFrame, parent: Instance, scale: number?): Model
	local model = Props.clone(name)
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

return Props
