--!strict
-- Map decoration for one plot, built in code (Phase 6 art, modeled on the
-- Capybara Onsen screenshots in reference/): a tall pegboard-style wooden wall
-- with hanging paper scrolls around the sides and back, huge stepped cliffs with
-- a waterfall behind the plot, big cherry blossom trees, tall bamboo, stone
-- lanterns and scattered daisies, plus steam / blossom / mist particles.
-- Plot-local coordinates like Plots.luau: x across (-width/2 .. width/2), z from
-- the road (0) to the back (depth).
--
-- Static and anchored. Only the wall, cliffs and tree trunks collide.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Props = require(Shared.Props)
local Skin = require(script.Parent.Skin)

local Decor = {}

export type Options = {
	at: (x: number, y: number, z: number) -> CFrame, -- plot-local -> world
	width: number,
	depth: number,
	floorTop: number,
	seed: number,
}

local WALL = Color3.fromRGB(190, 142, 88)
local WALL_DARK = Color3.fromRGB(104, 70, 44)
local BLOSSOM_A = Color3.fromRGB(255, 170, 200)
local CLIFF = Color3.fromRGB(118, 132, 148)
local CLIFF_DARK = Color3.fromRGB(96, 110, 128)
local CLIFF_CAP = Color3.fromRGB(92, 172, 72)
local PAPER = Color3.fromRGB(245, 240, 225)

local WALL_HEIGHT = 11
local POST_SPACING = 12
local SCROLL_SPACING = 30

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	collide: boolean?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ---------- Particles (Roblox built-in textures) ----------

-- Steam rising off a bath's water.
function Decor.steam(water: Part): Part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.Rate = 3
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.25
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Parent = water
	return water
end

local function blossomPetals(canopy: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Petals"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 215))
	emitter.Size = NumberSequence.new(0.7)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Acceleration = Vector3.new(1.5, -3, 0.5)
	emitter.Rate = 2
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 0.4
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = canopy
end

local function waterfallMist(foam: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(215, 240, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 16) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Rate = 6
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.3
	emitter.Parent = foam
end

-- ---------- Wall ----------

-- A tall wooden wall between two plot-local points: a plank panel, a dark top
-- and bottom trim, and posts with caps every POST_SPACING studs.
local function wallRun(folder: Folder, o: Options, x1: number, z1: number, x2: number, z2: number)
	local dx, dz = x2 - x1, z2 - z1
	local length = math.sqrt(dx * dx + dz * dz)
	local rotation = CFrame.lookAt(Vector3.zero, Vector3.new(dx, 0, dz))
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	local top = o.floorTop
	local panel = part(
		folder,
		"WallPanel",
		Vector3.new(0.9, WALL_HEIGHT - 1.4, length),
		o.at(mx, top + 0.5 + (WALL_HEIGHT - 1.4) / 2, mz) * rotation,
		WALL,
		true,
		Enum.Material.WoodPlanks
	)
	Skin.tile(panel, "pegboard", { Enum.NormalId.Left, Enum.NormalId.Right })
	part(
		folder,
		"WallBase",
		Vector3.new(1.6, 1.0, length),
		o.at(mx, top + 0.5, mz) * rotation,
		WALL_DARK,
		true,
		Enum.Material.WoodPlanks
	)
	part(
		folder,
		"WallTop",
		Vector3.new(2, 0.9, length),
		o.at(mx, top + WALL_HEIGHT - 0.45, mz) * rotation,
		WALL_DARK,
		true,
		Enum.Material.WoodPlanks
	)
	local posts = math.max(1, math.floor(length / POST_SPACING))
	for i = 0, posts do
		local t = i / posts
		local px, pz = x1 + dx * t, z1 + dz * t
		part(
			folder,
			"WallPost",
			Vector3.new(1.7, WALL_HEIGHT + 0.6, 1.7),
			o.at(px, top + (WALL_HEIGHT + 0.6) / 2, pz),
			WALL_DARK,
			true,
			Enum.Material.WoodPlanks
		)
		part(folder, "WallPostCap", Vector3.new(2.4, 0.7, 2.4), o.at(px, top + WALL_HEIGHT + 0.95, pz), WALL_DARK, true)
	end
	-- Paper scrolls hanging on the inside face, facing into the plot.
	local scrolls = math.floor(length / SCROLL_SPACING)
	for i = 1, scrolls do
		local t = (i - 0.5) / scrolls
		local sx, sz = x1 + dx * t, z1 + dz * t
		-- Inside = towards the plot's middle line (x = 0 for side walls, smaller z for the back wall).
		local inward = if math.abs(dx) > math.abs(dz) then Vector3.new(0, 0, -1) else Vector3.new(-math.sign(x1), 0, 0)
		local px, pz = sx + inward.X * 0.7, sz + inward.Z * 0.7
		local face = CFrame.lookAt(Vector3.zero, inward)
		local cy = top + WALL_HEIGHT - 5.3
		part(folder, "Scroll", Vector3.new(4, 5.6, 0.2), o.at(px, cy, pz) * face, PAPER)
		part(folder, "ScrollRod", Vector3.new(4.6, 0.4, 0.5), o.at(px, cy + 2.9, pz) * face, WALL_DARK)
		part(folder, "ScrollRod", Vector3.new(4.6, 0.4, 0.5), o.at(px, cy - 2.9, pz) * face, WALL_DARK)
		part(folder, "ScrollStripe", Vector3.new(0.9, 3.6, 0.25), o.at(px, cy, pz) * face, Color3.fromRGB(70, 110, 170))
	end
end

-- ---------- Cliffs ----------

local function cliffs(folder: Folder, o: Options)
	local depth = 44
	local heights = { 62, 92, 74 }
	local segment = o.width / 3
	local zCenter = o.depth + 1 + depth / 2
	for i, height in heights do
		local x = (i - 2) * segment
		local rock = part(
			folder,
			"Cliff",
			Vector3.new(segment + 6, height, depth),
			o.at(x, 0.5 + height / 2, zCenter),
			CLIFF,
			true,
			Enum.Material.Slate
		)
		Skin.tile(rock, "cliff", Skin.ALL_SIDES)
		-- A second, narrower tier set back on top, with its own grass cap.
		local tier = height * 0.45
		part(
			folder,
			"CliffTier",
			Vector3.new(segment * 0.65, tier, depth * 0.6),
			o.at(x, 0.5 + height + tier / 2, zCenter + depth * 0.18),
			CLIFF_DARK,
			true,
			Enum.Material.Slate
		)
		part(
			folder,
			"CliffCap",
			Vector3.new(segment * 0.65 + 0.8, 1.6, depth * 0.6 + 0.8),
			o.at(x, 0.5 + height + tier + 0.8, zCenter + depth * 0.18),
			CLIFF_CAP,
			true
		)
		part(
			folder,
			"CliffLedge",
			Vector3.new(segment + 6.8, 1.6, depth + 0.8),
			o.at(x, 0.5 + height + 0.8, zCenter),
			CLIFF_CAP,
			true
		)
	end
	local height = heights[2]
	local fall = part(
		folder,
		"Waterfall",
		Vector3.new(12, height - 1, 0.9),
		o.at(0, 1 + (height - 1) / 2, o.depth + 0.6),
		Color3.fromRGB(120, 215, 255),
		false,
		Enum.Material.Neon
	)
	fall.Transparency = 0.3
	local foam = part(
		folder,
		"WaterfallFoam",
		Vector3.new(16, 1.4, 6),
		o.at(0, 1.2, o.depth + 3),
		Color3.fromRGB(235, 248, 255),
		false,
		Enum.Material.Neon
	)
	foam.Transparency = 0.3
	waterfallMist(foam)
end

-- ---------- Props ----------

-- ---------- Props (voxel models from tools/voxel_forge.py) ----------

-- A cherry tree; petals fall from an invisible emitter part above its canopy.
local function cherryTree(folder: Folder, o: Options, rng: Random, x: number, z: number, scale: number)
	local turn = math.rad(90 * rng:NextInteger(0, 3))
	Props.place("CherryTree", o.at(x, o.floorTop, z) * CFrame.Angles(0, turn, 0), folder, scale)
	local canopy = part(
		folder,
		"PetalEmitter",
		Vector3.new(14 * scale, 0.5, 14 * scale),
		o.at(x, o.floorTop + 15 * scale, z),
		BLOSSOM_A
	)
	canopy.Transparency = 1
	blossomPetals(canopy)
end

local function bambooCluster(folder: Folder, o: Options, rng: Random, x: number, z: number, scale: number)
	local turn = math.rad(90 * rng:NextInteger(0, 3))
	Props.place("Bamboo", o.at(x, o.floorTop, z) * CFrame.Angles(0, turn, 0), folder, scale)
end

local function stoneLantern(folder: Folder, o: Options, x: number, z: number, scale: number)
	Props.place("StoneLantern", o.at(x, o.floorTop, z), folder, scale)
end

local function daisy(folder: Folder, o: Options, rng: Random, x: number, z: number)
	local y = o.floorTop + 0.1
	local turn = math.rad(rng:NextInteger(0, 90))
	local white = Color3.fromRGB(250, 250, 255)
	part(folder, "Daisy", Vector3.new(1.4, 0.12, 0.45), o.at(x, y, z) * CFrame.Angles(0, turn, 0), white)
	part(folder, "Daisy", Vector3.new(1.4, 0.12, 0.45), o.at(x, y, z) * CFrame.Angles(0, turn + math.rad(90), 0), white)
	part(folder, "DaisyCore", Vector3.new(0.55, 0.2, 0.55), o.at(x, y + 0.06, z), Color3.fromRGB(255, 215, 60))
end

function Decor.build(parent: Instance, o: Options)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent
	local rng = Random.new(o.seed)
	local half = o.width / 2 - 1

	-- Wall: both sides (leaving the road end open) and the back.
	wallRun(folder, o, -half, 6, -half, o.depth - 1)
	wallRun(folder, o, half, 6, half, o.depth - 1)
	wallRun(folder, o, -half, o.depth - 1, half, o.depth - 1)

	cliffs(folder, o)

	-- Trees and bamboo in the strip between the baths and the side walls.
	for _, side in { -1, 1 } do
		cherryTree(folder, o, rng, side * (half - 3), 68, 0.9)
		cherryTree(folder, o, rng, side * (half - 3), 148, 1.05)
		cherryTree(folder, o, rng, side * (half - 3), 206, 0.85)
		bambooCluster(folder, o, rng, side * (half - 4), 14, 1.2)
		bambooCluster(folder, o, rng, side * (half - 4), 108, 1.3)
		bambooCluster(folder, o, rng, side * (half - 4), 184, 1.3)
		-- Lanterns: entrance, and either side of the pool.
		stoneLantern(folder, o, side * 26, 6, 0.8)
		stoneLantern(folder, o, side * 12, 62, 0.75)
		stoneLantern(folder, o, side * 12, 84, 0.75)
	end

	-- The entrance gate: a torii over the path from the road.
	Props.place("Torii", o.at(0, o.floorTop, 14), folder, 1)

	-- Daisies near the entrance and along the walls.
	for _ = 1, 14 do
		daisy(folder, o, rng, rng:NextNumber(-half + 4, half - 4), rng:NextNumber(3, 17))
	end
	for _ = 1, 24 do
		local side = if rng:NextInteger(0, 1) == 0 then -1 else 1
		daisy(folder, o, rng, side * rng:NextNumber(half - 8, half - 2), rng:NextNumber(20, o.depth - 12))
	end
end

return Decor
