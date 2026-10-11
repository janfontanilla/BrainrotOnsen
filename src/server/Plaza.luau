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

local LAKE_HALF_LENGTH = 200 -- along x; the plot rows span about +-225
local LAKE_HALF_WIDTH = 40 -- along z
local LANE_WIDTH = 10 -- each long stream; the island (60 wide, walkable) fills the rest
-- Island ground cover (prop, weight), how many, how far apart; the middle (|x| <
-- ISLAND_CLEAR_X, round the leaderboard pavilions) stays clear.
local ISLAND_COVER: { { any } } = {
	{ "GrassTuft", 10 },
	{ "Sprig", 3 },
	{ "BambooShoot", 2 },
	{ "Flower1", 2 },
	{ "Flower2", 2 },
	{ "Flower3", 1 },
	{ "Flower4", 2 },
}
local ISLAND_COVER_MAX = 320
local ISLAND_COVER_TRIES = 4000
local ISLAND_COVER_GAP = 3.5
local ISLAND_CLEAR_X = 50
-- Hot tubs on the island: x, z, the tier chilling in each.
local ISLAND_TUBS: { { number } } =
	{ { -140, -20, 5 }, { -60, -18, 9 }, { 60, 18, 12 }, { 130, 20, 16 }, { -100, 18, 20 } }
local END_WIDTH = 10 -- the turning streams at both ends
local FLOW_SPEED = 28 -- studs per second (walking is 16)
local GROUND_TOP = 0.5
-- The flowing lake stays shallow, on the ground (2026-10-09, user: not the lake that
-- carries players; the deep water is the plot moats, server/Plots). Players wade
-- across to the island (no bridges, user 2026-10-09).
local WATER_TOP = GROUND_TOP + 0.3
local BED_TOP = GROUND_TOP - 0.2 -- where kerbs, the island and the end cliffs start
local KERB_TOP = WATER_TOP + 0.4
-- The promenades stand above the water so the lake and the plot moats sit sunk
-- between walls (2026-10-09, user: "sink the lake so we're on a higher part").
local PROMENADE_TOP = GROUND_TOP + 1.7
local ISLAND_TOP = GROUND_TOP + 2.1 -- a raised walkway on a stone retaining wall
Plaza.ISLAND_TOP = ISLAND_TOP -- the leaderboard pavilions stand on it
local END_CLIFF_FRONT = 206 -- |x| where the cliffs at both ends of the lake start
local KERB_WIDTH = 1.4
local PROMENADE_WIDTH = 6

local WATER = Color3.fromRGB(70, 205, 240)
local CLIFF = Color3.fromRGB(172, 178, 186) -- light warm grey, as server/Decor (2026-10-06)
local GRASS = Color3.fromRGB(112, 190, 74)
-- End cliffs: { z centre, height, depth (x), set back from END_CLIFF_FRONT, width (z) }.
-- The first one is the tallest and carries the waterfall.
-- About half the old heights (2026-10-06, docs/visual-overhaul.md: they towered over
-- every view like flat walls).
local END_CLIFF_BLOCKS: { { number } } = {
	{ 0, 46, 30, 0, 36 },
	{ -38, 32, 28, 2, 40 },
	{ 38, 36, 28, 2, 40 },
	{ -78, 24, 26, 4, 40 },
	{ 78, 28, 26, 4, 40 },
	{ 0, 64, 30, 30, 70 },
	{ -60, 50, 30, 32, 60 },
	{ 60, 56, 30, 32, 60 },
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
	-- Studded plastic everywhere (2026-10-10, user: the pads' Lego studs on everything in the
	-- world except the brainrots); water, glow and skinned tiles override it after.
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = "Onsen_lego" -- round Lego studs on every face (MaterialService.Onsen_lego); ignored once the material changes
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
		Vector3.new(math.abs(x2 - x1), top - BED_TOP, math.abs(z2 - z1)),
		Vector3.new((x1 + x2) / 2, (top + BED_TOP) / 2, (z1 + z2) / 2),
		STONE
	)
	Skin.apply(k, "stone", STONE_TINT)
end

-- A grey-green cliff block from the ground up with a grass ledge on top.
local function cliffBlock(parent: Instance, center: Vector3, size: Vector3)
	local depthBelow = GROUND_TOP - BED_TOP -- down into the basin
	local rock = part(
		parent,
		"EndCliff",
		size + Vector3.new(0, depthBelow, 0),
		Vector3.new(center.X, GROUND_TOP + (size.Y - depthBelow) / 2, center.Z),
		CLIFF
	)
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
	Decor.waterfallDetail(fall, if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right)
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

-- How far the promenades reach from the middle of the road (|z|): the plot moats
-- (server/Plots) start here.
Plaza.OUTER_Z = LAKE_HALF_WIDTH + KERB_WIDTH + PROMENADE_WIDTH
Plaza.PROMENADE_TOP = PROMENADE_TOP

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
	local C = END_CLIFF_FRONT
	kerb(folder, -C, W, C, W + KERB_WIDTH, PROMENADE_TOP)
	kerb(folder, -C, -W - KERB_WIDTH, C, -W, PROMENADE_TOP)
	-- Still pools from the lake's ends to the cliffs, under the waterfalls.
	for _, side in { -1, 1 } do
		local pool = part(
			folder,
			"LakePool",
			Vector3.new(C - L, 0.4, 2 * W),
			Vector3.new(side * (L + C) / 2, WATER_TOP - 0.2, 0),
			WATER
		)
		pool.Material = Enum.Material.Glass
		pool.Transparency = 0.1
		Skin.tile(pool, "water")
	end

	-- The island: raised grass inside a stone kerb, with trees, bamboo and lanterns.
	local islandHalf = inner - KERB_WIDTH
	local grass = part(
		folder,
		"Island",
		Vector3.new(2 * islandHalf, ISLAND_TOP - BED_TOP, 2 * (island - KERB_WIDTH)),
		Vector3.new(0, (ISLAND_TOP + BED_TOP) / 2, 0),
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
		Props.place("Bush", CFrame.new(x, islandTop, z), folder, 0.8)
	end

	-- Stepping stones down the middle of the island, around the leaderboard pavilions.
	for x = -184, 184, 3.5 do
		if math.abs(x) > ISLAND_CLEAR_X then
			local stone = part(
				folder,
				"SteppingStone",
				Vector3.new(2.4, 0.25, 2.8),
				Vector3.new(x, islandTop + 0.1, rng:NextNumber(-0.4, 0.4)),
				STONE
			)
			stone.CFrame *= CFrame.Angles(0, math.rad(rng:NextNumber(-12, 12)), 0)
			Skin.apply(stone, "stone", STONE_TINT)
		end
	end

	-- Ground cover over the island's grass (2026-10-09, user: "make the middle place
	-- more grassy and detailed"): tufts, sprigs, flowers and bamboo shoots, clear of
	-- the pavilions, the path, the trees and the lanterns.
	local keepOut: { Vector3 } = {} -- (x, z, radius)
	for i, x in { -160, -120, -80, -40, 40, 80, 120, 160 } do
		table.insert(keepOut, Vector3.new(x, if i % 2 == 0 then 16 else -16, 5))
	end
	for x = -180, 180, 80 do
		table.insert(keepOut, Vector3.new(x, -25, 2.5))
		table.insert(keepOut, Vector3.new(x, 25, 2.5))
	end
	for i, x in { -140, -100, -60, 60, 100, 140 } do
		table.insert(keepOut, Vector3.new(x, if i % 2 == 0 then -12 else 12, 4))
	end
	table.insert(keepOut, Vector3.new(-178, 0, 5))
	for _, tub in ISLAND_TUBS do
		Decor.hotTub(folder, CFrame.new(tub[1], islandTop, tub[2]) * CFrame.Angles(0, math.rad(tub[1]), 0), tub[3])
		table.insert(keepOut, Vector3.new(tub[1], tub[2], 5))
	end
	table.insert(keepOut, Vector3.new(178, 0, 5))
	local placed: { Vector2 } = {}
	local total = 0
	for _, entry in ISLAND_COVER do
		total += entry[2]
	end
	local zHalf = island - KERB_WIDTH - 1.2
	for _ = 1, ISLAND_COVER_TRIES do
		if #placed >= ISLAND_COVER_MAX then
			break
		end
		local x = rng:NextNumber(-islandHalf + 1.5, islandHalf - 1.5)
		local z = rng:NextNumber(-zHalf, zHalf)
		local ok = math.abs(z) > 2.5 and not (math.abs(x) < ISLAND_CLEAR_X and math.abs(z) < 6)
		for _, k in keepOut do
			if ok and (Vector2.new(k.X - x, k.Y - z)).Magnitude < k.Z then
				ok = false
			end
		end
		for _, other in placed do
			if ok and (other - Vector2.new(x, z)).Magnitude < ISLAND_COVER_GAP then
				ok = false
			end
		end
		if ok then
			local pick = rng:NextNumber(0, total)
			local name = ISLAND_COVER[1][1]
			for _, entry in ISLAND_COVER do
				pick -= entry[2]
				if pick <= 0 then
					name = entry[1]
					break
				end
			end
			Props.place(
				name,
				CFrame.new(x, islandTop, z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0),
				folder,
				rng:NextNumber(1, 1.45)
			)
			table.insert(placed, Vector2.new(x, z))
		end
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
			Vector3.new(2 * (L + KERB_WIDTH), PROMENADE_TOP - GROUND_TOP + 0.2, PROMENADE_WIDTH),
			Vector3.new(0, (PROMENADE_TOP + GROUND_TOP - 0.2) / 2, z),
			STONE
		)
		Skin.apply(walk, "stone")
	end
end

return Plaza
