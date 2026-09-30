--!strict
-- Placeholder blocky models built in code (Phase 6 art, approach 1). Used by the
-- server (baths, drops) and the client (unlock reveal). Real models can replace
-- these later without touching the callers: keep the same two functions.
--
--   Models.makeBrainrot(tier)   a brainrot. Origin = bottom centre (WorldPivot; models
--                               have no PrimaryPart, which would override it), front
--                               faces -Z, plus an invisible "Label" part above its head
--                               for the name / tier billboard. Uses the third-party pack
--                               model ReplicatedStorage.Assets.Brainrots.Tier<N> when it
--                               is there (tools/extract_brainrot_pack.py), else the
--                               code-built design below.
--   Models.makeDropItem(tier)   the tier's drop item (cheese, shrimp, tire...),
--                               about 2 studs, origin = centre: the voxel design
--                               Drop<tier> from tools/voxel_forge.py when present.
--
-- Everything is anchored, non-colliding and non-queryable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Visuals = require(script.Parent.Visuals)
local Props = require(script.Parent.Props)

type Shape = "Block" | "Ball" | "Cylinder"
type Add = (
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Shape?,
	material: Enum.Material?
) -> Part

local Models = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local BLACK = rgb(25, 25, 30)
local WHITE = rgb(245, 245, 250)

-- Makes a model builder. Sizes and positions passed to `add` are multiplied by
-- `scale`; rotations are kept. Cylinders run along X (rotate to stand them up).
local function newBuilder(name: string, scale: number): (Model, Add)
	local model = Instance.new("Model")
	model.Name = name
	local function add(
		partName: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		shape: Shape?,
		material: Enum.Material?
	): Part
		local part = Instance.new("Part")
		part.Name = partName
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Size = size * scale
		part.CFrame = CFrame.new(cf.Position * scale) * cf.Rotation
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Parent = model
		return part
	end
	return model, add
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Two eyes on a front face (-Z): black cubes with a white glint.
local function eyes(add: Add, y: number, z: number, spread: number, size: number)
	for _, side in { -1, 1 } do
		add("Eye", Vector3.new(size, size, size * 0.5), at(side * spread, y, z), BLACK)
		add(
			"Glint",
			Vector3.new(size * 0.35, size * 0.35, size * 0.3),
			at(side * spread + size * 0.15, y + size * 0.2, z - size * 0.25),
			WHITE
		)
	end
end

-- Finishes a brainrot: pivot at the bottom centre, and a Label anchor above the head.
local function finishBrainrot(model: Model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2
	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(0, top + 0.6, 0)
	anchor.Parent = model
	model.WorldPivot = CFrame.new()
end

-- ---------- Brainrot designs (tiers 1-5; the rest use the generic body) ----------

local designs: { [number]: (add: Add) -> () } = {}

-- 1. Tim Cheese: a cheese block with holes, a face and little feet.
designs[1] = function(add)
	local cheese = rgb(255, 212, 60)
	local hole = rgb(225, 165, 30)
	add("Body", Vector3.new(3.2, 2.6, 3), at(0, 1.5, 0), cheese)
	add("Hole", Vector3.new(0.9, 0.9, 0.3), at(-0.9, 2.2, -1.5), hole)
	add("Hole", Vector3.new(0.6, 0.6, 0.3), at(1, 1.0, -1.5), hole)
	add("Hole", Vector3.new(0.3, 0.9, 0.9), at(1.6, 1.8, 0.4), hole)
	add("Hole", Vector3.new(0.3, 0.6, 0.6), at(-1.6, 1.1, -0.2), hole)
	eyes(add, 1.9, -1.55, 0.65, 0.5)
	add("Mouth", Vector3.new(0.9, 0.2, 0.2), at(0, 1.1, -1.55), BLACK)
	add("Foot", Vector3.new(0.9, 0.4, 1.1), at(-0.9, 0.2, -0.4), rgb(230, 130, 40))
	add("Foot", Vector3.new(0.9, 0.4, 1.1), at(0.9, 0.2, -0.4), rgb(230, 130, 40))
end

-- 2. Trippi Troppi: a cat with a shrimp tail.
designs[2] = function(add)
	local pink = rgb(255, 140, 120)
	local light = rgb(255, 205, 185)
	add("Body", Vector3.new(2, 1.8, 3), at(0, 1.1, 0.3), pink)
	add("Belly", Vector3.new(1.5, 0.5, 3.05), at(0, 0.45, 0.3), light)
	add("Head", Vector3.new(1.9, 1.6, 1.6), at(0, 2.1, -1.4), pink)
	add("Ear", Vector3.new(0.5, 0.7, 0.5), at(-0.6, 3.1, -1.4), pink)
	add("Ear", Vector3.new(0.5, 0.7, 0.5), at(0.6, 3.1, -1.4), pink)
	eyes(add, 2.25, -2.2, 0.45, 0.35)
	add("Nose", Vector3.new(0.3, 0.2, 0.2), at(0, 1.85, -2.25), rgb(200, 80, 90))
	add("Whisker", Vector3.new(0.9, 0.08, 0.08), at(-1.2, 1.9, -2.15), BLACK)
	add("Whisker", Vector3.new(0.9, 0.08, 0.08), at(1.2, 1.9, -2.15), BLACK)
	add("Tail", Vector3.new(1.4, 1.2, 1.2), at(0, 1.7, 2.1), pink)
	add("Tail", Vector3.new(1.0, 1.0, 1.0), at(0, 2.4, 2.6), rgb(255, 120, 100))
	add("Tail", Vector3.new(0.7, 0.7, 0.7), at(0, 3.1, 2.8), rgb(255, 100, 80))
	add("Fin", Vector3.new(1.0, 0.2, 0.5), at(0, 3.55, 2.8), rgb(255, 90, 70))
end

-- 3. Boneca Ambalabu: a frog riding a tyre.
designs[3] = function(add)
	add("Body", Vector3.new(1.7, 2.8, 2.8), at(0, 1.4, 0), rgb(35, 35, 40), "Cylinder")
	add("Hub", Vector3.new(1.9, 1.3, 1.3), at(0, 1.4, 0), rgb(150, 150, 160), "Cylinder")
	local green = rgb(110, 190, 70)
	add("Torso", Vector3.new(1.8, 1.5, 1.4), at(0, 3.5, 0), green)
	add("Head", Vector3.new(2.2, 1.3, 1.5), at(0, 4.5, -0.2), green)
	for _, side in { -1, 1 } do
		add("EyeWhite", Vector3.new(0.7, 0.7, 0.7), at(side * 0.65, 5.3, -0.4), WHITE, "Ball")
		add("Pupil", Vector3.new(0.35, 0.35, 0.3), at(side * 0.65, 5.3, -0.75), BLACK)
		add("Arm", Vector3.new(0.5, 1.2, 0.5), at(side * 1.25, 3.5, -0.2), green)
	end
	add("Mouth", Vector3.new(1.4, 0.15, 0.2), at(0, 4.25, -0.96), rgb(60, 110, 40))
end

-- 4. Frigo Camelo: a fridge with a camel's head and humps.
designs[4] = function(add)
	local tan = rgb(205, 155, 95)
	add("Body", Vector3.new(2.4, 3.6, 2.2), at(0, 1.8, 0.3), rgb(235, 240, 245))
	add("DoorLine", Vector3.new(2.42, 0.1, 0.06), at(0, 2.5, -0.82), rgb(150, 155, 165))
	add("Handle", Vector3.new(0.15, 0.9, 0.2), at(0.9, 3.0, -0.92), rgb(150, 155, 165))
	add("Handle", Vector3.new(0.15, 0.7, 0.2), at(0.9, 1.4, -0.92), rgb(150, 155, 165))
	add("Hump", Vector3.new(0.9, 0.7, 0.9), at(-0.55, 3.95, 0.9), tan)
	add("Hump", Vector3.new(0.9, 0.7, 0.9), at(0.55, 3.95, 0.9), tan)
	add("Neck", Vector3.new(0.9, 1.4, 0.9), at(0, 4.3, -0.3), tan)
	add("Head", Vector3.new(1.1, 0.9, 1.5), at(0, 5.1, -0.8), tan)
	add("Snout", Vector3.new(0.7, 0.6, 0.5), at(0, 4.95, -1.7), rgb(225, 185, 130))
	add("Ear", Vector3.new(0.25, 0.35, 0.25), at(-0.45, 5.65, -0.6), tan)
	add("Ear", Vector3.new(0.25, 0.35, 0.25), at(0.45, 5.65, -0.6), tan)
	eyes(add, 5.25, -1.52, 0.35, 0.25)
end

-- 5. Lirili Larila: an elephant on a cactus with a clock.
designs[5] = function(add)
	local grey = rgb(150, 160, 178)
	local cactus = rgb(85, 170, 80)
	add("Body", Vector3.new(2.6, 2.0, 3.0), at(0, 2.2, 0.2), grey)
	add("Cactus", Vector3.new(2.4, 1.2, 2.4), at(0, 0.6, 0.2), cactus)
	for _, x in { -0.8, 0, 0.8 } do
		add("Spike", Vector3.new(0.15, 0.4, 0.15), at(x, 1.35, -0.85), rgb(240, 240, 200))
	end
	add("Head", Vector3.new(2.0, 1.8, 1.6), at(0, 3.0, -1.6), grey)
	add("Ear", Vector3.new(0.3, 1.6, 1.4), at(-1.2, 3.1, -1.3), rgb(175, 185, 200))
	add("Ear", Vector3.new(0.3, 1.6, 1.4), at(1.2, 3.1, -1.3), rgb(175, 185, 200))
	add("Trunk", Vector3.new(0.6, 0.6, 0.6), at(0, 2.7, -2.6), grey)
	add("Trunk", Vector3.new(0.55, 0.55, 0.55), at(0, 2.2, -2.8), grey)
	add("Trunk", Vector3.new(0.5, 0.5, 0.5), at(0, 1.75, -2.75), grey)
	eyes(add, 3.4, -2.42, 0.55, 0.3)
	add(
		"ClockFace",
		Vector3.new(0.2, 0.9, 0.9),
		at(0, 1.7, -1.33) * CFrame.Angles(0, math.pi / 2, 0),
		WHITE,
		"Cylinder"
	)
	add("Hand", Vector3.new(0.06, 0.4, 0.1), at(0, 1.85, -1.45), BLACK)
	add("Hand", Vector3.new(0.3, 0.06, 0.1), at(0.12, 1.7, -1.45), BLACK)
end

-- Generic body for tiers without their own design: a tier-coloured animal with a
-- hat that cycles by tier.
local HATS = { "crown", "horns", "antenna", "leaf", "halo", "tophat" }

local function generic(tier: number): (add: Add) -> ()
	return function(add)
		local color = Visuals.tierColor(tier)
		local dark = Color3.fromHSV(color:ToHSV())
		add("Body", Vector3.new(2.8, 2.2, 3.2), at(0, 1.3, 0.2), color)
		add("Head", Vector3.new(2.2, 1.8, 1.8), at(0, 2.7, -1.4), color)
		add("Snout", Vector3.new(1.2, 0.8, 0.6), at(0, 2.4, -2.5), dark:Lerp(WHITE, 0.45))
		eyes(add, 3.0, -2.32, 0.6, 0.4)
		add("Foot", Vector3.new(0.9, 0.5, 1.0), at(-0.9, 0.25, -0.8), color:Lerp(BLACK, 0.3))
		add("Foot", Vector3.new(0.9, 0.5, 1.0), at(0.9, 0.25, -0.8), color:Lerp(BLACK, 0.3))
		local hat = HATS[(tier - 1) % #HATS + 1]
		local gold = rgb(255, 205, 50)
		if hat == "crown" then
			add("Crown", Vector3.new(1.6, 0.5, 1.4), at(0, 3.85, -1.4), gold)
			for _, x in { -0.6, 0, 0.6 } do
				add("Point", Vector3.new(0.3, 0.4, 0.3), at(x, 4.3, -1.4), gold)
			end
		elseif hat == "horns" then
			add("Horn", Vector3.new(0.4, 0.9, 0.4), at(-0.7, 4.0, -1.4), WHITE)
			add("Horn", Vector3.new(0.4, 0.9, 0.4), at(0.7, 4.0, -1.4), WHITE)
		elseif hat == "antenna" then
			add("Stick", Vector3.new(0.12, 1.0, 0.12), at(0, 4.3, -1.4), BLACK)
			add("Bulb", Vector3.new(0.5, 0.5, 0.5), at(0, 4.95, -1.4), rgb(255, 80, 80), "Ball")
		elseif hat == "leaf" then
			add(
				"Leaf",
				Vector3.new(0.4, 1.3, 0.8),
				at(0, 4.25, -1.4) * CFrame.Angles(0, 0, math.rad(20)),
				rgb(80, 190, 80)
			)
		elseif hat == "halo" then
			add(
				"Halo",
				Vector3.new(0.15, 1.6, 1.6),
				at(0, 4.5, -1.4) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(255, 240, 120),
				"Cylinder",
				Enum.Material.Neon
			)
		else
			add(
				"Brim",
				Vector3.new(0.2, 1.9, 1.9),
				at(0, 3.7, -1.4) * CFrame.Angles(0, 0, math.pi / 2),
				BLACK,
				"Cylinder"
			)
			add(
				"Top",
				Vector3.new(1.1, 1.3, 1.3),
				at(0, 4.3, -1.4) * CFrame.Angles(0, 0, math.pi / 2),
				BLACK,
				"Cylinder"
			)
		end
	end
end

-- A brainrot from the pack in ReplicatedStorage.Assets.Brainrots, scaled to fit a
-- bath, standing on the origin. nil if the pack model is not there.
local PACK_MAX_FOOTPRINT = 6 -- studs: widest horizontal size (they overhang the bath rims, like Capybara Onsen's)
local PACK_MAX_HEIGHT = 8

local function fromPack(tier: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Brainrots")
	local source = folder and folder:FindFirstChild(`Tier{tier}`)
	if not source or not source:IsA("Model") then
		return nil
	end
	local model = source:Clone()
	model.Name = `Brainrot{tier}`
	model.PrimaryPart = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	-- Fit the bath, then stand the model on the origin (bottom centre).
	local size = model:GetExtentsSize()
	local fit = math.min(PACK_MAX_FOOTPRINT / math.max(size.X, size.Z, 0.1), PACK_MAX_HEIGHT / math.max(size.Y, 0.1))
	model:ScaleTo(model:GetScale() * fit)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = Vector3.new(boxCFrame.Position.X, boxCFrame.Position.Y - boxSize.Y / 2, boxCFrame.Position.Z)
	model:PivotTo(model:GetPivot() - bottom)
	model.WorldPivot = CFrame.new()
	local top = boxSize.Y
	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(0, top + 0.6, 0)
	anchor.Parent = model
	return model
end

function Models.makeBrainrot(tier: number): Model
	local packed = fromPack(tier)
	if packed then
		return packed
	end
	local scale = 0.85 + tier * 0.02
	local model, add = newBuilder(`Brainrot{tier}`, scale)
	local design = designs[tier] or generic(tier)
	design(add)
	finishBrainrot(model)
	return model
end

-- ---------- Drop items, one per tier (Config/Tiers item names) ----------

local items: { [number]: (add: Add) -> () } = {}

items[1] = function(add) -- Cheese
	local y = rgb(255, 212, 60)
	add("Body", Vector3.new(1.6, 0.9, 1.4), at(0, 0, 0), y)
	add("Wedge", Vector3.new(1.6, 0.5, 0.7), at(0, 0.6, 0.35), y)
	add("Hole", Vector3.new(0.4, 0.4, 0.2), at(-0.4, 0, -0.72), rgb(225, 165, 30))
	add("Hole", Vector3.new(0.3, 0.3, 0.2), at(0.4, 0.15, -0.72), rgb(225, 165, 30))
end
items[2] = function(add) -- Shrimp
	local c = rgb(255, 130, 100)
	add("Body", Vector3.new(0.8, 0.7, 1.0), at(0, -0.3, -0.3), c)
	add("Mid", Vector3.new(0.7, 0.6, 0.8), at(0, 0.1, 0.2), c)
	add("Tail", Vector3.new(0.6, 0.5, 0.6), at(0, 0.5, 0.6), rgb(255, 100, 70))
end
items[3] = function(add) -- Tire
	add("Body", Vector3.new(0.7, 1.6, 1.6), at(0, 0, 0), rgb(35, 35, 40), "Cylinder")
	add("Hub", Vector3.new(0.8, 0.7, 0.7), at(0, 0, 0), rgb(160, 160, 170), "Cylinder")
end
items[4] = function(add) -- Ice cube
	add("Body", Vector3.new(1.3, 1.3, 1.3), at(0, 0, 0), rgb(170, 230, 255), "Block", Enum.Material.Glass).Transparency =
		0.25
end
items[5] = function(add) -- Clock
	add("Body", Vector3.new(0.4, 1.5, 1.5), at(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), WHITE, "Cylinder")
	add(
		"Rim",
		Vector3.new(0.3, 1.7, 1.7),
		at(0, 0, 0.05) * CFrame.Angles(0, math.pi / 2, 0),
		rgb(200, 60, 60),
		"Cylinder"
	)
	add("Hand", Vector3.new(0.06, 0.6, 0.1), at(0, 0.25, -0.22), BLACK)
	add("Hand", Vector3.new(0.4, 0.06, 0.1), at(0.15, 0, -0.22), BLACK)
end
items[6] = function(add) -- Banana
	local y = rgb(255, 225, 60)
	add("Body", Vector3.new(0.5, 0.8, 0.5), at(0, -0.5, 0), y)
	add("Mid", Vector3.new(0.5, 0.8, 0.5), at(0.25, 0.1, 0), y)
	add("Tip", Vector3.new(0.4, 0.6, 0.4), at(0.55, 0.65, 0), rgb(90, 70, 30))
end
items[7] = function(add) -- Leaf
	add("Body", Vector3.new(1.4, 0.15, 0.9), at(0, 0, 0) * CFrame.Angles(0, 0, math.rad(20)), rgb(80, 190, 80))
	add("Stem", Vector3.new(0.6, 0.1, 0.1), at(-0.85, -0.25, 0), rgb(60, 130, 50))
end
items[8] = function(add) -- Feather
	add("Body", Vector3.new(0.3, 1.6, 0.1), at(0, 0, 0) * CFrame.Angles(0, 0, math.rad(15)), WHITE)
	add("Stripe", Vector3.new(0.12, 1.2, 0.12), at(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(15)), rgb(90, 160, 255))
end
items[9] = function(add) -- Coffee bean
	add("Body", Vector3.new(0.9, 0.9, 0.9), at(0, 0, 0), rgb(110, 70, 40), "Ball")
	add("Groove", Vector3.new(0.08, 0.9, 0.5), at(0, 0, -0.42), rgb(60, 35, 20))
end
items[10] = function(add) -- Coffee cup
	add("Body", Vector3.new(1.0, 1.1, 1.1), at(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), WHITE, "Cylinder")
	add(
		"Coffee",
		Vector3.new(0.1, 0.95, 0.95),
		at(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(120, 75, 40),
		"Cylinder"
	)
	add("Handle", Vector3.new(0.3, 0.5, 0.15), at(0.65, 0, 0), WHITE)
end
items[11] = function(add) -- Bomb
	add("Body", Vector3.new(1.3, 1.3, 1.3), at(0, -0.1, 0), rgb(40, 40, 50), "Ball")
	add("Cap", Vector3.new(0.4, 0.3, 0.4), at(0, 0.6, 0), rgb(150, 150, 160))
	add("Fuse", Vector3.new(0.08, 0.4, 0.08), at(0.1, 0.9, 0), rgb(200, 150, 80))
	add("Spark", Vector3.new(0.25, 0.25, 0.25), at(0.15, 1.15, 0), rgb(255, 200, 40), "Ball", Enum.Material.Neon)
end
items[12] = function(add) -- Shoe
	add("Body", Vector3.new(0.8, 0.25, 1.6), at(0, -0.4, 0), WHITE)
	add("Upper", Vector3.new(0.7, 0.6, 0.9), at(0, 0, 0.3), rgb(230, 60, 60))
	add("Toe", Vector3.new(0.7, 0.4, 0.6), at(0, -0.15, -0.5), rgb(240, 240, 245))
end
items[13] = function(add) -- Stick
	add("Body", Vector3.new(0.35, 1.7, 0.35), at(0, 0, 0) * CFrame.Angles(0, 0, math.rad(20)), rgb(150, 100, 55))
	add("Knot", Vector3.new(0.3, 0.3, 0.3), at(0.15, 0.1, -0.2), rgb(110, 70, 35))
end
items[14] = function(add) -- Milk
	add("Body", Vector3.new(0.9, 1.1, 0.9), at(0, -0.1, 0), WHITE)
	add("Top", Vector3.new(0.9, 0.4, 0.5), at(0, 0.65, 0), rgb(90, 150, 255))
	add("Label", Vector3.new(0.5, 0.4, 0.05), at(0, -0.1, -0.47), rgb(90, 150, 255))
end
items[15] = function(add) -- Fruit
	add("Body", Vector3.new(1.2, 1.2, 1.2), at(0, -0.1, 0), rgb(255, 150, 40), "Ball")
	add("Leaf", Vector3.new(0.6, 0.12, 0.35), at(0.2, 0.6, 0), rgb(80, 190, 80))
end
items[16] = function(add) -- Coconut
	add("Body", Vector3.new(1.2, 1.2, 1.2), at(0, 0, 0), rgb(120, 80, 45), "Ball")
	for _, p in { Vector3.new(-0.2, 0.2, -0.55), Vector3.new(0.2, 0.2, -0.55), Vector3.new(0, -0.05, -0.58) } do
		add("Dot", Vector3.new(0.18, 0.18, 0.1), at(p.X, p.Y, p.Z), rgb(60, 35, 20))
	end
end
items[17] = function(add) -- Bell
	local gold = rgb(255, 205, 50)
	add("Body", Vector3.new(0.9, 1.3, 1.3), at(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), gold, "Cylinder")
	add("Rim", Vector3.new(0.25, 1.7, 1.7), at(0, -0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), gold, "Cylinder")
	add("Clapper", Vector3.new(0.4, 0.4, 0.4), at(0, -0.85, 0), rgb(150, 100, 30), "Ball")
end
items[18] = function(add) -- Star
	local y = rgb(255, 235, 90)
	add("Body", Vector3.new(1.4, 0.4, 0.4), at(0, 0, 0), y, "Block", Enum.Material.Neon)
	add("Body", Vector3.new(0.4, 1.4, 0.4), at(0, 0, 0), y, "Block", Enum.Material.Neon)
	add(
		"Body",
		Vector3.new(1.1, 0.35, 0.35),
		at(0, 0, 0) * CFrame.Angles(0, 0, math.rad(45)),
		y,
		"Block",
		Enum.Material.Neon
	)
	add(
		"Body",
		Vector3.new(1.1, 0.35, 0.35),
		at(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-45)),
		y,
		"Block",
		Enum.Material.Neon
	)
end
items[19] = function(add) -- Watermelon
	add("Body", Vector3.new(1.5, 1.5, 1.5), at(0, 0, 0), rgb(60, 160, 70), "Ball")
	add("Stripe", Vector3.new(0.1, 1.5, 0.5), at(0, 0, -0.5), rgb(30, 100, 40))
	add("Slice", Vector3.new(0.9, 0.9, 0.1), at(0, 0, -0.76), rgb(240, 70, 90))
end
items[20] = function(add) -- Golden shoe
	local gold = rgb(255, 205, 50)
	add("Body", Vector3.new(0.8, 0.25, 1.6), at(0, -0.4, 0), rgb(255, 235, 140), "Block", Enum.Material.Neon)
	add("Upper", Vector3.new(0.7, 0.6, 0.9), at(0, 0, 0.3), gold, "Block", Enum.Material.Neon)
	add("Toe", Vector3.new(0.7, 0.4, 0.6), at(0, -0.15, -0.5), gold, "Block", Enum.Material.Neon)
end

function Models.makeDropItem(tier: number): Model
	-- The voxel item from tools/voxel_forge.py (Drop<tier>), centred on its middle.
	local voxelName = `Drop{tier}`
	if Props.has(voxelName) then
		local item = Props.clone(voxelName)
		item.Name = `Item{tier}`
		local centre = item:GetBoundingBox()
		item.WorldPivot = CFrame.new(centre.Position)
		item:PivotTo(CFrame.new())
		for _, part in item:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
			end
		end
		return item
	end
	-- Fallback: the older code-built design.
	local model, add = newBuilder(`Item{tier}`, 1)
	local build = items[tier]
	if build then
		build(add)
	else
		add("Body", Vector3.new(1.2, 1.2, 1.2), at(0, 0, 0), Visuals.tierColor(tier), "Ball", Enum.Material.Neon)
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Models
