--!strict
-- The middle of the map between the two plot rows: a big rectangular lake laid out
-- as a loop around a long grass island (the global leaderboard stands on it). The
-- water flows round the loop and carries players standing in it, so it is the fast
-- way from plot to plot: toward +x on the front-row side, toward -x on the back-row
-- side, turning at both ends. Stone promenades run along both long edges.
--
-- The current is the conveyor trick: each water segment is an anchored part whose
-- AssemblyLinearVelocity moves whatever stands on it. The client scrolls the water
-- texture to show the flow (Controllers/WaterController, FLOW_TAG parts).
-- World coordinates; the map centre is the origin.

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Props = require(Shared.Props)
local Skin = require(script.Parent.Skin)
local Decor = require(script.Parent.Decor)
local Sounds = require(Shared.Config.Sounds)

local Plaza = {}

Plaza.FLOW_TAG = "FlowWater" -- matches Controllers/WaterController

local LAKE_HALF_LENGTH = 200 -- along x; the plot rows span about +-207
local LAKE_HALF_WIDTH = 40 -- along z
local LANE_WIDTH = 10 -- each long stream; the island (60 wide, walkable) fills the rest
local END_WIDTH = 10 -- the turning streams at both ends
local FLOW_SPEED = 28 -- studs per second (walking is 16)
local GROUND_TOP = 0.5
local WATER_TOP = GROUND_TOP + 0.3
local KERB_TOP = WATER_TOP + 0.4 -- low enough to step over
local ISLAND_TOP = WATER_TOP + 1.8 -- a raised walkway on a stone retaining wall
Plaza.ISLAND_TOP = ISLAND_TOP -- the leaderboard pavilions stand on it
local END_CLIFF_FRONT = 206 -- |x| where the cliffs at both ends of the lake start
local KERB_WIDTH = 1.4
local PROMENADE_WIDTH = 6

local WATER = Color3.fromRGB(70, 205, 240)
local CLIFF = Color3.fromRGB(150, 162, 156)
local GRASS = Color3.fromRGB(112, 190, 74)
-- End cliffs: { z centre, height, depth (x), set back from END_CLIFF_FRONT, width (z) }.
-- The first one is the tallest and carries the waterfall.
local END_CLIFF_BLOCKS: { { number } } = {
	{ 0, 86, 30, 0, 36 },
	{ -38, 58, 28, 2, 40 },
	{ 38, 64, 28, 2, 40 },
	{ -78, 44, 26, 4, 40 },
	{ 78, 50, 26, 4, 40 },
	{ 0, 118, 30, 30, 70 },
	{ -60, 92, 30, 32, 60 },
	{ 60, 100, 30, 32, 60 },
}
local STONE = Color3.fromRGB(150, 155, 168)
local STONE_TINT = Color3.fromRGB(200, 204, 216)

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Mist rising where a waterfall lands.
local function mist(foam: Part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(215, 240, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 18) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Rate = 6
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.3
	emitter.Parent = foam
end

-- A walkable water segment from (x1, z1) to (x2, z2) flowing along `direction`.
local function flowSegment(parent: Instance, x1: number, z1: number, x2: number, z2: number, direction: Vector3)
	local size = Vector3.new(math.abs(x2 - x1), 0.4, math.abs(z2 - z1))
	local water = part(parent, "LakeWater", size, Vector3.new((x1 + x2) / 2, WATER_TOP - 0.2, (z1 + z2) / 2), WATER)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.1
	water.AssemblyLinearVelocity = direction * FLOW_SPEED
	water:SetAttribute("FlowX", direction.X)
	water:SetAttribute("FlowZ", direction.Z)
	water:SetAttribute("FlowSpeed", FLOW_SPEED)
	CollectionService:AddTag(water, Plaza.FLOW_TAG)
	Skin.tile(water, "water")
end

-- A low stone kerb box (players can step over it).
local function kerb(parent: Instance, x1: number, z1: number, x2: number, z2: number, topY: number?)
	local top = topY or KERB_TOP
	local k = part(
		parent,
		"LakeKerb",
		Vector3.new(math.abs(x2 - x1), top - GROUND_TOP + 0.2, math.abs(z2 - z1)),
		Vector3.new((x1 + x2) / 2, (top + GROUND_TOP - 0.2) / 2, (z1 + z2) / 2),
		STONE
	)
	Skin.apply(k, "stone", STONE_TINT)
end

-- A grey-green cliff block from the ground up with a grass ledge on top.
local function cliffBlock(parent: Instance, center: Vector3, size: Vector3)
	local rock = part(parent, "EndCliff", size, Vector3.new(center.X, GROUND_TOP + size.Y / 2, center.Z), CLIFF)
	rock.CastShadow = true
	Skin.apply(rock, "cliff")
	local cap = part(
		parent,
		"EndCliffLedge",
		Vector3.new(size.X + 0.8, 1.6, size.Z + 0.8),
		Vector3.new(center.X, GROUND_TOP + size.Y + 0.8, center.Z),
		GRASS
	)
	Skin.apply(cap, "grass")
end

-- Stepped cliffs beyond one end of the lake (side = 1: +x) and a waterfall pouring
-- from the tallest one into the end of the lake.
local function endCliffs(parent: Instance, side: number)
	local front = END_CLIFF_FRONT
	for _, block in END_CLIFF_BLOCKS do
		local depth = block[3]
		cliffBlock(
			parent,
			Vector3.new(side * (front + block[4] + depth / 2), 0, block[1]),
			Vector3.new(depth, block[2], block[5])
		)
	end
	local fallTop = GROUND_TOP + END_CLIFF_BLOCKS[1][2]
	local fall = part(
		parent,
		"EndWaterfall",
		Vector3.new(0.9, fallTop - WATER_TOP, 16),
		Vector3.new(side * (front - 0.5), (fallTop + WATER_TOP) / 2, 0),
		Color3.fromRGB(170, 235, 255)
	)
	fall.Material = Enum.Material.Glass
	fall.Transparency = 0.15
	Skin.tile(fall, "water", { if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right })
	local foam = part(
		parent,
		"EndWaterfallFoam",
		Vector3.new(6, 1.4, 20),
		Vector3.new(side * (LAKE_HALF_LENGTH - 3), WATER_TOP + 0.4, 0),
		Color3.fromRGB(235, 248, 255)
	)
	foam.Transparency = 0.15
	mist(foam)
	Decor.ambient(foam, Sounds.WATERFALL, Sounds.WATERFALL_VOLUME, 160)
end

function Plaza.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = parent

	local L, W = LAKE_HALF_LENGTH, LAKE_HALF_WIDTH
	local inner = L - END_WIDTH -- where the long lanes end and the turning channels begin
	local island = W - LANE_WIDTH -- island half width

	-- The loop, clockwise seen from above: +x along z > 0, -z at the +x end,
	-- -x along z < 0, +z at the -x end. Corners hand over to the next segment.
	local X, Z = Vector3.xAxis, Vector3.zAxis
	flowSegment(folder, -inner, island, inner, W, X)
	flowSegment(folder, inner, island, L, W, -Z)
	flowSegment(folder, inner, -island, L, island, -Z)
	flowSegment(folder, inner, -W, L, -island, -X)
	flowSegment(folder, -inner, -W, inner, -island, -X)
	flowSegment(folder, -L, -W, -inner, -island, Z)
	flowSegment(folder, -L, -island, -inner, island, Z)
	flowSegment(folder, -L, island, -inner, W, X)

	-- Outer kerbs.
	kerb(folder, -L - KERB_WIDTH, W, L + KERB_WIDTH, W + KERB_WIDTH)
	kerb(folder, -L - KERB_WIDTH, -W - KERB_WIDTH, L + KERB_WIDTH, -W)
	kerb(folder, L, -W, L + KERB_WIDTH, W)
	kerb(folder, -L - KERB_WIDTH, -W, -L, W)

	-- The island: raised grass inside a stone kerb, with trees, bamboo and lanterns.
	local islandHalf = inner - KERB_WIDTH
	local grass = part(
		folder,
		"Island",
		Vector3.new(2 * islandHalf, ISLAND_TOP - GROUND_TOP + 0.2, 2 * (island - KERB_WIDTH)),
		Vector3.new(0, (ISLAND_TOP + GROUND_TOP - 0.2) / 2, 0),
		Color3.fromRGB(112, 190, 74)
	)
	grass.CastShadow = true
	Skin.apply(grass, "grass")
	kerb(folder, -inner, island - KERB_WIDTH, inner, island, ISLAND_TOP)
	kerb(folder, -inner, -island, inner, -island + KERB_WIDTH, ISLAND_TOP)
	kerb(folder, inner - KERB_WIDTH, -island + KERB_WIDTH, inner, island - KERB_WIDTH, ISLAND_TOP)
	kerb(folder, -inner, -island + KERB_WIDTH, -inner + KERB_WIDTH, island - KERB_WIDTH, ISLAND_TOP)
	local islandTop = ISLAND_TOP
	local rng = Random.new(7)
	-- Trees staggered in two loose rows, lanterns along both edges, bamboo at the
	-- ends; the middle of the island stays open grass to walk on.
	for i, x in { -160, -120, -80, -40, 40, 80, 120, 160 } do -- no tree by the leaderboard
		local z = if i % 2 == 0 then 16 else -16
		local turn = CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0)
		Props.place("CherryTree", CFrame.new(x, islandTop, z) * turn, folder, 0.85)
	end
	for x = -180, 180, 80 do -- 10 lanterns: each is 23 boxes
		for _, z in { -25, 25 } do
			Props.place("StoneLantern", CFrame.new(x, islandTop, z), folder, 0.6)
		end
	end
	for _, x in { -178, 178 } do
		Props.place("Bamboo", CFrame.new(x, islandTop, 0), folder, 1.2)
	end
	for i, x in { -140, -100, -60, 60, 100, 140 } do -- bushes between the trees
		local z = if i % 2 == 0 then -12 else 12
		Props.place("Sprig", CFrame.new(x, islandTop, z), folder, 1.4)
	end

	-- Cliffs with a waterfall at both ends of the lake, like the end of Capybara
	-- Onsen's middle area.
	for _, side in { -1, 1 } do
		endCliffs(folder, side)
	end

	-- Stone promenades along both long edges, between the lake and the plots.
	for _, side in { -1, 1 } do
		local z = side * (W + KERB_WIDTH + PROMENADE_WIDTH / 2)
		local walk = part(
			folder,
			"Promenade",
			Vector3.new(2 * (L + KERB_WIDTH), 0.2, PROMENADE_WIDTH),
			Vector3.new(0, GROUND_TOP + 0.1, z),
			STONE
		)
		Skin.apply(walk, "stone")
	end
end

return Plaza
