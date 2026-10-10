--!strict
-- Map geometry for the player plots, built in code so it syncs through Rojo.
-- Placeholder parts until Phase 6. Holds which player owns which plot.
--
-- Plot-local coordinates: x runs across the plot (-WIDTH/2 .. WIDTH/2), z runs
-- from the front edge on the road (0) to the back (DEPTH). Two rows of three
-- plots face each other across a road.
--
-- Plot layout, seen from above (road at the bottom), modeled on Capybara Onsen
-- (reference/capybara-onsen-*.webp):
--
--   back   [==bath==]    ||    [==bath==]    Economy.ROWS rows (8). Each row is a low
--          ~~river~~~>   ||   <~~river~~~    river with a raised, stone-rimmed bath
--          [==bath==]    ||    [==bath==]    behind it, on both sides of the center
--          ~~river~~~>   ||   <~~river~~~    channel. Each bath holds
--             ...        ||      ...        Economy.SPOTS_PER_LANE brainrots (5)
--          [==bath==]    ||    [==bath==]    single file; wooden slides run from its
--          ~~river~~~>   ||   <~~river~~~    rim down into its river between them.
--                       [  ]                 Rivers flow into the channel, the channel
--          [1][5][25]   [  ]                 into the narrow pool; walk in to collect.
--
--                     spawn
--   [info][tank][deposit][market]           station row facing the pool, pads on
--                                           the pool side (Collect Cash, upgrade,
--                                           Deposit Aura); left to right as seen
--                                           from the pool looking at the road
--   road   ------- sign -------            board in front

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Textures = require(Shared.Config.Textures)
local Sounds = require(Shared.Config.Sounds)
local Models = require(Shared.Models)
local Props = require(Shared.Props)
local Billboard = require(script.Parent.Billboard)
local Decor = require(script.Parent.Decor)
local Plaza = require(script.Parent.Plaza)
local Skin = require(script.Parent.Skin)

export type Pad = {
	amount: number, -- buy amount for buy pads, 0 for station pads
	part: BasePart,
	label: TextLabel,
}

export type Stations = {
	deposit: Pad,
	collectCash: Pad,
	upgradeProcessor: Pad,
	merge: Pad,
	upgradeBuyTier: Pad,
	-- Robux pads, each beside the station it boosts (labels set by MonetizationService)
	finishNow: Pad,
	autoCollect: Pad,
	doubleAura: Pad,
	cashPass: Pad,
	groupReward: Pad, -- step-on pad in front of the group sign (GroupRewardService)
	processorLabel: TextLabel, -- the processor info board's text
}

export type Plot = {
	index: number,
	folder: Folder,
	origin: CFrame, -- plot-local frame (see the layout above)
	spawn: CFrame,
	spots: { CFrame }, -- Economy.MAX_SPOTS spot CFrames at the water surface, front row first
	spotRiverZ: { number }, -- plot-local z of the river each spot's slide ends in
	pads: { Pad }, -- buy pads
	stations: Stations,
	signLabels: { TextLabel },
	brainrotFolder: Folder,
	dropFolder: Folder,
	owner: Player?,
}

-- Layout (studs). Visual geometry only; balance numbers live in Config/Economy.
local WIDTH = 130
local DEPTH = 220
-- The middle area between the two rows holds the flowing lake (server/Plaza).
local ROAD_WIDTH = 140
local COLUMN_GAP = 30 -- between plots (2026-10-09, user: further apart; was 12), a moat runs down it
-- Moats round the plots (2026-10-09, user: "I like how the plots are surrounded by
-- water" in Capybara Onsen): shallow water in the gaps between plots, along the outer
-- sides and in front of every plot (between the promenade and the front steps), with
-- stone kerbs, stone facing on the plot slab's sides, and a wooden bridge at each
-- entrance. Players can wade through; the bridges keep the way in dry.
-- Deep (2026-10-09, user: the water round the plots, not the flowing lake): the map
-- ground is cut away under the moats, stone walls run down to a dark bed, and each
-- plot's front steps carry on down into the water so players can climb out.
local MOAT_WATER_TOP = 0.5 - 2.5 -- 2.5 below the map ground
local MOAT_BED = 0.5 - 4
local MOAT_STEPS = 4 -- steps down from the map ground into the front moat
local MOAT_KERB_WIDTH = 1.4
local MOAT_OUTER_WIDTH = 18 -- the strip beyond the outer plots
local MOAT_BRIDGE_WIDTH = 10
local MOAT_BRIDGE_RISE = 0.8 -- the bridges arch up this much in the middle
local MOAT_COLOR = Color3.fromRGB(70, 205, 240)
-- The deposit stall's own little onsen (2026-10-09, user: "the market capybara has his
-- own little onsen"): a raised stone-rimmed pool the stall stands in.
local STALL_POOL_WIDTH = 3 -- water strip width, rims included
local STALL_POOL_RIM = 0.6
local STALL_POOL_RIM_TOP = 0.9 -- above the floor
local STALL_POOL_WATER_TOP = 0.7
-- The plot floor is a thick slab on the map ground so the bath field can be sunk
-- into it (Capybara Onsen style): the rivers, channel and pool are one sunken water
-- sheet below the grass, framed by a stone lip, and the baths are stone pedestals
-- standing up out of it.
local MAP_GROUND_TOP = 0.5 -- top of the map-wide Ground part
local GROUND_BOTTOM = -8 -- the ground is thick: the lake basin is cut into it (server/Plaza)
local GROUND_HALF_X, GROUND_HALF_Z = 600, 520
local FLOOR_TOP = 4.5
local WATER_TOP = FLOOR_TOP - 1.4 -- the sunken water sheet (rivers, channel)
local BASIN_BOTTOM = WATER_TOP - 0.8 -- the dark bed seen through the sunken water
-- The pool is the lowest water: the channel pours over a step down into it.
local POOL_WATER_TOP = WATER_TOP - 1.5
local POOL_BED_TOP = POOL_WATER_TOP - 0.8
local BASIN_LIP = 1.5 -- stone lip around the sunken basin
local LIP_TOP = FLOOR_TOP + 0.4
local STEP_COUNT = 4 -- steps up from the map ground at the plot's front edge (1 stud each)
local DROP_FLOAT = 1.2 -- drop height above the water
local LANE_WIDTH = 7 -- baths run along x; this is their size in z, rims included
local RIVER_WIDTH = 8 -- low river in front of each bath, flowing to the channel
local BATH_RIM = 1.25 -- rim of the platform's top layer around the bath water
-- Baths are raised, stepped stone platforms standing up out of the sunken rivers
-- (Capybara Onsen, docs/visual-overhaul.md; 2026-10-06, were thin rims on the water):
-- a wide base layer, a narrower top layer with the bath water sunk into it, the
-- brainrots on the water at the top, ramps from the top edge down into the river.
local PLATFORM_STEP = 0.75 -- the base sticks out this far past the top layer on the long sides
local PLATFORM_BASE_TOP = WATER_TOP + 1.1 -- top of the base layer
local BATH_RIM_TOP = FLOOR_TOP + 1.3 -- top of the platform (the rim)
local BATH_WATER_TOP = BATH_RIM_TOP - 0.5 -- the bath water; brainrots stand on it
local PLATFORM_TOP_WIDTH = LANE_WIDTH - 2 * PLATFORM_STEP -- top layer, in z
local BATH_EDGE = PLATFORM_TOP_WIDTH / 2 -- lane centre to the top layer's long edge (slides start here)
local SPOT_SPACING = 9 -- along the bath (x)
local SLIDE_OFFSET = SPOT_SPACING / 2 -- slides sit between brainrots
local LANES_FRONT_Z = 90
local CHANNEL_WIDTH = 8
-- Narrow pool right in front of the lanes; the open ground in front of it is
-- room for the Phase 2+ stations (deposit, processor, market).
local POOL_FRONT_Z = 64
local POOL_BACK_Z = LANES_FRONT_Z
local POOL_WIDTH = 14
local PAD_SIZE = 8
local BUY_PAD_SIZE = 6 -- the buy pads are smaller than the station pads
-- Beside Merge! (never on a pad), facing the baths.
local SPAWN_X, SPAWN_Z = 11, 46
-- Station row in front of the pool, facing it (+z), read left to right from the
-- spawn: market board, deposit stall, signpost, a cherry tree, processor info
-- board, with their pads on the pool side. The processor barrel stands by the -x
-- side wall beside the pool, facing into the plot, with Collect Cash in front.
local STATION_Z = 26 -- where the row's structures stand
local STATION_PAD_Z = 38 -- where their pads sit
-- The processor controls (info board, upgrade pad, Finish Now) stand together on the
-- +x side wall beside the pool, the board facing into the plot (-x).
local INFO_BOARD_X, INFO_BOARD_Z = 61, 70
local UPGRADE_X, UPGRADE_Z = 50, INFO_BOARD_Z -- processor upgrade pad, in front of the board
-- Robux pads sit in line beside the free pad they boost, on the "right" side of the
-- plot (-x, where Upgrade Buy Tier is). x2 Cash is the exception: the barrel is on
-- that side of Collect Cash, so it sits beside it toward the road instead.
local ROBUX_GAP = 9.5 -- centre to centre
local BARREL_X, BARREL_Z = -55, 66 -- the processor barrel by the -x wall
local COLLECT_CASH_X, COLLECT_CASH_Z = -41, BARREL_Z
local DEPOSIT_X = -24 -- right of the entrance gate (seen from the spawn), room around the gate
local STALL_SCALE = 1.25 -- the deposit stall is built bigger than the forge design
local SIGNPOST_X, SIGNPOST_Z = -60, 54 -- tall signpost by the -x wall, beside the barrel

local DEPOSIT_PAD_SIZE = 11
local ROBUX_PAD_SIZE = 6
local MARKET_X = 26 -- left of the entrance gate, clear of it
local STALL_KEEPER_TIER = 13 -- Tung Tung Tung Sahur behind the deposit counter
local STALL_KEEPER_SCALE = 1
local STALL_KEEPER_STEP = 5.2 -- stands up at counter-top height so all of him shows
-- The wooden stool he stands on (seat top = STALL_KEEPER_STEP).
local STOOL_SEAT = 4 -- seat width and depth
local STOOL_SEAT_THICK = 0.6
local STOOL_LEG = 0.6
local STOOL_COLOR = Color3.fromRGB(130, 84, 44)
-- Goods on the deposit counter (Capybara Onsen's stall has crates of yuzu): a crate at
-- each end of the counter, piled with drop items; the middle stays clear for the keeper.
local COUNTER_TOP = 9.5 -- measured in Studio (the DepositStall prop at STALL_SCALE)
local COUNTER_Z = 27.8 -- front half of the counter (its centre is 26.6, the front edge 29.1)
local CRATE_OFFSET_X = 4.6 -- from the stall centre: clear of the keeper and the lamp at the ends
local CRATE_SIZE = Vector3.new(3.4, 1.4, 2.8)
local CRATE_ITEMS = { { 1, 4, 2 }, { 5, 3, 6 } } -- drop item tiers piled in each crate
local CRATE_COLOR = Color3.fromRGB(150, 98, 52)
-- The barrel's chimney top relative to its base centre, in the barrel's own frame
-- (tools/voxel_forge.py processor_barrel).
local CHIMNEY_OFFSET = Vector3.new(2.5, 26.5, 3)
-- Merge! centred right in front of the pool. A row of pads runs along the front of
-- the first bath row, read left to right from the spawn (+x is the player's left):
-- Buy 1, Buy 5, Auto Collect left of the pool; Buy 25, Buy 100 and Upgrade Buy Tier
-- right of it.
local MERGE_X, MERGE_Z = 0, 56.5
local MERGE_PAD_SIZE = 10
local BUY_ROW_Z = 84 -- just in front of the first river (LANES_FRONT_Z)
local PAD_LAYOUT: { { amount: number, x: number, z: number } } = {
	{ amount = 1, x = 36, z = BUY_ROW_Z },
	{ amount = 5, x = 25, z = BUY_ROW_Z },
	{ amount = 25, x = -14.5, z = BUY_ROW_Z },
	{ amount = 100, x = -25.5, z = BUY_ROW_Z },
}
local AUTO_COLLECT_X, AUTO_COLLECT_Z = 14, BUY_ROW_Z
local UPGRADE_BUY_TIER_X, UPGRADE_BUY_TIER_Z = -37.5, BUY_ROW_Z
local UPGRADE_BUY_TIER_PAD_SIZE = 7.5
-- The step-on group reward pad in front of the group sign on the curved wall.
local GROUP_PAD_X, GROUP_PAD_Z = 50, 40 -- in front of the group sign on the curved wall

local FLOOR_COLOR = Color3.fromRGB(112, 190, 74)
-- Tint on the grass tile: a touch deeper and calmer than the tile as drawn (2026-10-06:
-- from above the yard read neon).
local GRASS_TINT = Color3.fromRGB(226, 232, 216)

-- Front yard (2026-10-06, docs/visual-overhaul.md): stone paths tie the stations
-- together, a raised koi pond with a bridge fills the empty lawn left of the pool,
-- planters furnish the stations. Plot-local studs.
local PATH_WIDTH = 5
local PATH_THICK = 0.12
local PATH_EDGE = 0.45 -- darker border strips along both sides
local PATH_TINT = Color3.fromRGB(236, 236, 240)
local PATH_EDGE_TINT = Color3.fromRGB(160, 160, 168)
-- Path segments { x1, z1, x2, z2 } along x or z (centre lines).
local PATHS: { { number } } = {
	{ 0, 20, 0, 51 }, -- gate to Merge!
	{ -48, 46, 43, 46 }, -- across the yard in front of the Deposit pad
	{ -48, 46, -48, 77 }, -- up past Collect Cash
	{ 43, 46, 43, 77 }, -- up past the processor controls
	{ -48, 77, -10, 77 }, -- in front of the buy row, right half
	{ 10, 77, 43, 77 }, -- left half
}
local POND_X, POND_Z = 27, 62 -- centre of the koi pond
-- Round pond (2026-10-09, user: "a circular one with fish floating around"; was a
-- square pond with a bridge): a stone disc, round water on top, lily pads, a rock in
-- the middle that the koi circle.
local POND_RADIUS = 6.5 -- water
local POND_RIM = 2 -- wide enough for the statues' pedestals
local POND_STEP = 0.9 -- a darker stone step round the foot of the rim
local POND_RIM_TOP = 1.1 -- above the floor
local LILY_PADS: { { number } } = { { 40, 4.2 }, { 165, 4.6 }, { 280, 3.8 } } -- angle (degrees), distance
local KOI_STATUES = { 90, 210, 330 } -- angles (degrees) of the fountain koi round the rim
local POND_BUSHES = { 30, 150, 270 } -- between the statues
local STATUE_RING = POND_RADIUS + POND_RIM / 2 -- they stand on the rim
local STATUE_SCALE = 1
local STATUE_MOUTH = Vector3.new(0, 3.5, -1.1) -- the KoiStatue prop's mouth, from its pivot (tools/voxel_forge.py)
local SPOUT_RISE = 0.9 -- the jet leaves the mouth this steeply (up per stud inward)
local SPOUT_SPEED = 7.5 -- studs per second; with SPOUT_GRAVITY the arc lands mid-pond
local SPOUT_GRAVITY = 14
local POND_WATER = Color3.fromRGB(80, 196, 220)
local KOI_COUNT = 5
local KOI_KINDS = 4 -- Koi1..Koi4 voxel props
local KOI_SINK = 0.3 -- studs of the fish below the water top
local KOI_SPEED = 1.3 -- studs per second
local KOI_TAG = "Koi" -- Controllers/KoiController swims these round the pond
-- Ground cover scattered over every open patch of lawn (2026-10-09, user: "more of
-- these little bamboo shoots and grass and flower things throughout the grass"):
-- props, their weights, and spacing. Placed on a 1-stud grid of the plot where
-- nothing else stands (paths, pads, props, walls, trees all count).
local SCATTER: { { any } } = {
	{ "GrassTuft", 10 },
	{ "Sprig", 3 },
	{ "BambooShoot", 2 },
	{ "Flower1", 2 },
	{ "Flower2", 2 },
	{ "Flower3", 1 },
	{ "Flower4", 2 },
}
local SCATTER_TRIES = 3000
local HOT_TUB_X, HOT_TUB_Z = 58.5, 49 -- a wooden hot tub in the lawn corner by the +x wall
local SCATTER_MAX = 260 -- per plot
local SCATTER_GAP = 3.5 -- studs between two scattered props
local SCATTER_CLEAR = 1.2 -- studs kept clear round anything already standing on the lawn
-- Planters beside the stations.
local PLANTERS: { { number } } = {
	{ -37, 28, 0 }, -- either side of the deposit stall
	{ -11, 28, 0 },
	{ -48, 59, 90 }, -- beside Collect Cash
	{ 57, 56, 90 }, -- by the processor board
	{ 18, 28, 0 }, -- by the market board
}
local LANE_COLOR = Color3.fromRGB(70, 205, 240)
-- Pad colours from the reference: yellow Buy 1 / 5, lime Buy 25, orange Buy 100.
local BUY_COLORS: { [number]: Color3 } = {
	[1] = Color3.fromRGB(250, 222, 70),
	[5] = Color3.fromRGB(250, 222, 70),
	[25] = Color3.fromRGB(170, 228, 60),
	[100] = Color3.fromRGB(255, 120, 40),
}
local MERGE_COLOR = Color3.fromRGB(150, 150, 160)
local UPGRADE_BUY_TIER_COLOR = Color3.fromRGB(60, 210, 255)
local DEPOSIT_COLOR = Color3.fromRGB(255, 220, 90)
local COLLECT_COLOR = Color3.fromRGB(60, 220, 90)
local UPGRADE_COLOR = Color3.fromRGB(70, 170, 255)
local ROBUX_COLOR = Color3.fromRGB(255, 180, 40)
local GROUP_COLOR = Color3.fromRGB(255, 120, 190)
local SIGN_COLOR = Color3.fromRGB(120, 80, 50)
local STONE_COLOR = Color3.fromRGB(140, 140, 150)
local BASIN_BED_COLOR = Color3.fromRGB(30, 110, 140) -- dark water depth under the sunken sheet
local WOOD_COLOR = Color3.fromRGB(150, 100, 60)
local BRIDGE_RED = Color3.fromRGB(196, 58, 48)
local FLOW_TAG = "FlowWater" -- Controllers/WaterController scrolls these textures
local WATER_FLOW_SPEED = 6 -- studs per second the river and channel textures drift
-- Tints for textured parts (Skin multiplies the tile by these; white = the tile as drawn).
local RIM_TINT = Color3.fromRGB(236, 238, 244) -- light grey rims (2026-10-06, was slate 200, 204, 216)
local LANTERN_SCALE = 1.2 -- bath lanterns, a bit bigger than the prop (Capybara Onsen)
local TOWEL_SCALE = 0.8 -- the towel stack, to fit the rim
local DUCK_EVERY = 3 -- a rubber duck floats in every this-many-th bath
local SLIDE_RAIL = 0.4 -- side rails on the slides (the water runs between them)
local SLIDE_POST = 0.5 -- posts at the top of each slide
local SLIDE_WATER_COLOR = Color3.fromRGB(170, 238, 255) -- the water running down each slide
local PAD_TRAY_COLOR = Color3.fromRGB(78, 80, 92)
local PAD_TRAY = 0.7 -- the dark studded tray shows this far around each pad
-- Floor arrows along the loop (x, z, direction x, direction z): pool > Deposit,
-- Deposit > Collect Cash, Collect Cash > the buy row.
local ARROWS: { { number } } = {
	{ -10, 57, -0.6, -0.8 },
	{ -13.5, 52, -0.6, -0.8 },
	{ -17, 47, -0.6, -0.8 },
	{ -27, 45, -0.55, 0.83 },
	{ -30.5, 50.5, -0.55, 0.83 },
	{ -34, 56, -0.55, 0.83 },
	{ -38, 74.5, 0.3, 1 },
}

local Plots = {}

-- Tag on every pad part; a pad has a Pressed attribute while someone stands on it.
Plots.PAD_TAG = "Pad"
-- Tag on each plot's market board part; clients draw the board on it.
Plots.MARKET_BOARD_TAG = "MarketBoard"

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeSignLabel(board: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(500, 100)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return label
end

-- Pad label sizes in studs (width, height) by the number of lines they show.
local LABEL_ONE_LINE = Vector2.new(9, 2.2)
local LABEL_TWO_LINES = Vector2.new(8, 3.2)
local LABEL_THREE_LINES = Vector2.new(10, 4.4)
local LABEL_ROBUX = Vector2.new(6.5, 2.8)

function Plots.setSign(plot: Plot, text: string)
	for _, label in plot.signLabels do
		label.Text = text
	end
end

local function originFor(index: number): CFrame
	local column = (index - 1) % 3 - 1 -- -1, 0, 1
	local frontRow = index <= 3
	local x = column * (WIDTH + COLUMN_GAP)
	if frontRow then
		return CFrame.new(x, 0, ROAD_WIDTH / 2)
	end
	return CFrame.new(x, 0, -ROAD_WIDTH / 2) * CFrame.Angles(0, math.pi, 0)
end

-- Scatters ground cover (SCATTER) over the plot's open lawn: rasterises every part
-- in `geometry` that stands on the lawn into a 1-stud grid (plot space), marks the
-- lawn ("Floor" pieces), then drops props on random free cells.
local function scatterGround(geometry: Instance, origin: CFrame, index: number)
	local blocked: { [number]: boolean } = {}
	local lawn: { [number]: boolean } = {}
	local function key(x: number, z: number): number
		return (x + 200) * 1000 + z + 200
	end
	local function mark(set: { [number]: boolean }, x1: number, z1: number, x2: number, z2: number)
		for x = math.floor(x1), math.ceil(x2) do
			for z = math.floor(z1), math.ceil(z2) do
				set[key(x, z)] = true
			end
		end
	end
	for _, part in geometry:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = origin:ToObjectSpace(part.CFrame)
			local r, size = cf, part.Size
			-- Axis-aligned half extents of the (possibly turned) part, in plot space.
			local hx = math.abs(r.XVector.X) * size.X + math.abs(r.YVector.X) * size.Y + math.abs(r.ZVector.X) * size.Z
			local hy = math.abs(r.XVector.Y) * size.X + math.abs(r.YVector.Y) * size.Y + math.abs(r.ZVector.Y) * size.Z
			local hz = math.abs(r.XVector.Z) * size.X + math.abs(r.YVector.Z) * size.Y + math.abs(r.ZVector.Z) * size.Z
			hx, hy, hz = hx / 2, hy / 2, hz / 2
			local p = cf.Position
			if part.Name == "Floor" then
				if math.abs(p.Y + hy - FLOOR_TOP) < 0.05 then
					mark(lawn, p.X - hx + 1, p.Z - hz + 1, p.X + hx - 1, p.Z + hz - 1)
				end
			elseif p.Y + hy > FLOOR_TOP + 0.05 and p.Y - hy < FLOOR_TOP + 8 then
				local c = SCATTER_CLEAR
				mark(blocked, p.X - hx - c, p.Z - hz - c, p.X + hx + c, p.Z + hz + c)
			end
		end
	end
	local total = 0
	for _, entry in SCATTER do
		total += entry[2]
	end
	local rng = Random.new(index * 7919)
	local placed = 0
	for _ = 1, SCATTER_TRIES do
		if placed >= SCATTER_MAX then
			break
		end
		local x = rng:NextInteger(-WIDTH // 2 + 2, WIDTH // 2 - 2)
		local z = rng:NextInteger(2, DEPTH - 2)
		local k = key(x, z)
		if lawn[k] and not blocked[k] then
			local pick = rng:NextNumber(0, total)
			local name = SCATTER[1][1]
			for _, entry in SCATTER do
				pick -= entry[2]
				if pick <= 0 then
					name = entry[1]
					break
				end
			end
			Props.place(
				name,
				origin
					* CFrame.new(x + rng:NextNumber(-0.4, 0.4), FLOOR_TOP, z + rng:NextNumber(-0.4, 0.4))
					* CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0),
				geometry,
				rng:NextNumber(1, 1.45)
			)
			local g = SCATTER_GAP / 2
			mark(blocked, x - g, z - g, x + g, z + g)
			placed += 1
		end
	end
end

local function buildPlot(root: Instance, index: number): Plot
	local origin = originFor(index)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local folder = Instance.new("Folder")
	folder.Name = `Plot{index}`
	folder.Parent = root

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = folder

	-- Floor: a slab from the map ground to FLOOR_TOP with the basin (the pool in
	-- front, the bath field behind it) cut out, plus steps up at the front edge.
	local fieldHalf = CHANNEL_WIDTH / 2 + 1 + Economy.SPOTS_PER_LANE * SPOT_SPACING + 2 + 2 * BATH_RIM
	local lanesBack = LANES_FRONT_Z + Economy.ROWS * (RIVER_WIDTH + LANE_WIDTH)
	local poolHalf = POOL_WIDTH / 2
	local L = BASIN_LIP
	local slab = FLOOR_TOP - MAP_GROUND_TOP
	local function floorPiece(x1: number, z1: number, x2: number, z2: number)
		local piece = makePart(
			geometry,
			"Floor",
			Vector3.new(x2 - x1, slab, z2 - z1),
			at((x1 + x2) / 2, MAP_GROUND_TOP + slab / 2, (z1 + z2) / 2),
			FLOOR_COLOR
		)
		Skin.apply(piece, "grass", GRASS_TINT)
	end
	floorPiece(-WIDTH / 2, 0, WIDTH / 2, POOL_FRONT_Z - L)
	floorPiece(-WIDTH / 2, lanesBack + L, WIDTH / 2, DEPTH)
	for _, side in { -1, 1 } do
		local function mirrored(x1: number, z1: number, x2: number, z2: number)
			floorPiece(math.min(side * x1, side * x2), z1, math.max(side * x1, side * x2), z2)
		end
		mirrored(poolHalf + L, POOL_FRONT_Z - L, WIDTH / 2, LANES_FRONT_Z - L)
		mirrored(fieldHalf + L, LANES_FRONT_Z - L, WIDTH / 2, lanesBack + L)
	end
	for i = 1, STEP_COUNT do
		local height = slab * i / STEP_COUNT
		local stepZ = -(STEP_COUNT - i + 0.5)
		local step = makePart(
			geometry,
			"FrontStep",
			Vector3.new(WIDTH, height, 1),
			at(0, MAP_GROUND_TOP + height / 2, stepZ),
			STONE_COLOR
		)
		Skin.apply(step, "stone", RIM_TINT)
	end
	Decor.build(
		geometry,
		{ at = at, width = WIDTH, depth = DEPTH, floorTop = FLOOR_TOP, seed = index, moatWaterTop = MOAT_WATER_TOP }
	)

	local function water(name: string, size: Vector3, cframe: CFrame): Part
		local part = makePart(geometry, name, size, cframe, LANE_COLOR)
		part.Transparency = 0.2
		part.Material = Enum.Material.Glass
		part.CastShadow = false
		Skin.tile(part, "water")
		return part
	end
	-- Marks water whose texture scrolls along plot-local (dx, dz); visual only, no current.
	local function flows(part: BasePart, dx: number, dz: number)
		part:SetAttribute("FlowX", dx)
		part:SetAttribute("FlowZ", dz)
		part:SetAttribute("FlowSpeed", WATER_FLOW_SPEED)
		CollectionService:AddTag(part, FLOW_TAG)
	end
	local function stone(name: string, size: Vector3, cframe: CFrame)
		local part = makePart(geometry, name, size, cframe, STONE_COLOR)
		Skin.apply(part, "stone", if name == "Bath" then nil else RIM_TINT)
	end

	-- Rows, front to back: a low river, then a raised bath behind it that drains
	-- forward into it. One bath and river on each side of the center channel.
	local rowDepth = RIVER_WIDTH + LANE_WIDTH
	local bathInnerLength = Economy.SPOTS_PER_LANE * SPOT_SPACING + 2
	local bathLength = bathInnerLength + 2 * BATH_RIM
	local bathNearX = CHANNEL_WIDTH / 2 + 1 -- bath edge nearest the channel
	local bathCenterX = bathNearX + bathLength / 2
	local bodyBottom = BATH_WATER_TOP - 0.4 -- the bath water's floor
	local rimHeight = BATH_RIM_TOP - bodyBottom
	local rimY = bodyBottom + rimHeight / 2

	local lanes: { { side: number, z: number, riverZ: number } } = {}
	for row = 0, Economy.ROWS - 1 do
		local rowFront = LANES_FRONT_Z + row * rowDepth
		local riverZ = rowFront + RIVER_WIDTH / 2
		local z = rowFront + RIVER_WIDTH + LANE_WIDTH / 2
		for side = -1, 1, 2 do
			table.insert(lanes, { side = side, z = z, riverZ = riverZ })
			local river = water(
				"River",
				Vector3.new(bathLength, 0.4, RIVER_WIDTH),
				at(side * bathCenterX, WATER_TOP - 0.2, riverZ)
			)
			flows(river, -side, 0) -- toward the channel

			-- Foam where the slides land (they end a stud past the river's middle).
			local foam = makePart(
				geometry,
				"SlideFoam",
				Vector3.new(bathLength - 2, 0.2, 2),
				at(side * bathCenterX, WATER_TOP + 0.1, riverZ + 1.5),
				Color3.new(1, 1, 1)
			)
			foam.Transparency = 1
			foam.CanCollide = false
			foam.CanQuery = false
			foam.CanTouch = false
			foam.CastShadow = false
			Decor.foam(foam)

			-- Raised platform: a wide base layer from the basin bed, a narrower top layer
			-- whose middle holds the shallow bath water, rims all round the water.
			stone(
				"BathBase",
				Vector3.new(bathLength, PLATFORM_BASE_TOP - BASIN_BOTTOM, LANE_WIDTH),
				at(side * bathCenterX, (PLATFORM_BASE_TOP + BASIN_BOTTOM) / 2, z)
			)
			stone(
				"Bath",
				Vector3.new(bathLength, bodyBottom - PLATFORM_BASE_TOP, PLATFORM_TOP_WIDTH),
				at(side * bathCenterX, (bodyBottom + PLATFORM_BASE_TOP) / 2, z)
			)
			Decor.steam(
				water(
					"BathWater",
					Vector3.new(bathInnerLength, 0.4, PLATFORM_TOP_WIDTH - 2 * BATH_RIM),
					at(side * bathCenterX, BATH_WATER_TOP - 0.2, z)
				)
			)
			for _, dz in { -1, 1 } do
				stone(
					"BathRim",
					Vector3.new(bathLength, rimHeight, BATH_RIM),
					at(side * bathCenterX, rimY, z + dz * (PLATFORM_TOP_WIDTH - BATH_RIM) / 2)
				)
			end
			for _, dx in { -1, 1 } do
				stone(
					"BathRim",
					Vector3.new(BATH_RIM, rimHeight, PLATFORM_TOP_WIDTH - 2 * BATH_RIM),
					at(side * bathCenterX + dx * (bathLength - BATH_RIM) / 2, rimY, z)
				)
			end

			-- Two lanterns per bath, on opposite top corners: the channel end on the river
			-- side and the far end on the back side (four were too many, 2026-10-06).
			for _, corner in { { bathNearX + BATH_RIM / 2, -1 }, { bathNearX + bathLength - BATH_RIM / 2, 1 } } do
				Props.place(
					"RimLantern",
					at(side * corner[1], BATH_RIM_TOP, z + corner[2] * (PLATFORM_TOP_WIDTH - BATH_RIM) / 2),
					geometry,
					LANTERN_SCALE
				)
			end
			-- Onsen things on the two free corners: a wash bucket at the far end on the river
			-- side, a stack of towels at the channel end on the back side; and a rubber duck
			-- floating in every third bath.
			local rimZ = (PLATFORM_TOP_WIDTH - BATH_RIM) / 2
			Props.place(
				"WashBucket",
				at(side * (bathNearX + bathLength - BATH_RIM / 2), BATH_RIM_TOP, z - rimZ)
					* CFrame.Angles(0, math.rad(15), 0),
				geometry
			)
			Props.place(
				"TowelStack",
				at(side * (bathNearX + BATH_RIM + 1.2), BATH_RIM_TOP, z + rimZ),
				geometry,
				TOWEL_SCALE
			)
			if (row * 2 + (side + 1) / 2) % DUCK_EVERY == 0 then
				Props.place(
					"RubberDuck",
					at(side * (bathNearX + BATH_RIM + 1.4), BATH_WATER_TOP - 0.25, z)
						* CFrame.Angles(0, math.rad(-side * 70), 0),
					geometry
				)
			end
		end
	end

	-- A little red bridge over the channel joining the two front baths' rims.
	local bridgeZ = LANES_FRONT_Z + RIVER_WIDTH + LANE_WIDTH / 2
	local bridgeSpan = 2 * bathNearX + 2
	local deck = makePart(
		geometry,
		"ChannelBridge",
		Vector3.new(bridgeSpan, 0.4, 4),
		at(0, BATH_RIM_TOP + 0.2, bridgeZ),
		WOOD_COLOR
	)
	Skin.apply(deck, "planks")
	for _, dz in { -1.8, 1.8 } do
		makePart(
			geometry,
			"ChannelBridgeRail",
			Vector3.new(bridgeSpan, 0.35, 0.35),
			at(0, BATH_RIM_TOP + 1.6, bridgeZ + dz),
			BRIDGE_RED
		)
		for _, dx in { -bridgeSpan / 2 + 0.3, 0, bridgeSpan / 2 - 0.3 } do
			makePart(
				geometry,
				"ChannelBridgePost",
				Vector3.new(0.4, 1.4, 0.4),
				at(dx, BATH_RIM_TOP + 1.1, bridgeZ + dz),
				BRIDGE_RED
			)
		end
	end
	local lanesBackZ = LANES_FRONT_Z + Economy.ROWS * rowDepth

	-- Center channel from the back row down to the pool.
	-- (The channel water also fills the strip between it and the baths' near ends.)
	-- The part is turned 90 degrees so the water texture's streaks (drawn along the
	-- texture's U, the part's x) run down the channel; its +x points at the pool.
	local channel = water(
		"Channel",
		Vector3.new(lanesBackZ - POOL_BACK_Z, 0.4, 2 * bathNearX),
		at(0, WATER_TOP - 0.2, (POOL_BACK_Z + lanesBackZ) / 2) * CFrame.Angles(0, math.pi / 2, 0)
	)
	flows(channel, 1, 0) -- toward the pool

	-- Where the channel pours over the step into the lower pool: a short sheet of
	-- falling water with foam at its foot.
	local pour = makePart(
		geometry,
		"PoolFall",
		Vector3.new(2 * bathNearX, WATER_TOP - POOL_WATER_TOP, 0.4),
		at(0, (WATER_TOP + POOL_WATER_TOP) / 2, POOL_BACK_Z - 0.2),
		LANE_COLOR
	)
	pour.Material = Enum.Material.Glass
	pour.Transparency = 0.2
	pour.CanCollide = false
	pour.CastShadow = false
	Skin.tile(pour, "water", { Enum.NormalId.Front })
	local pourFoam = makePart(
		geometry,
		"PoolFallFoam",
		Vector3.new(2 * bathNearX, 0.2, 2),
		at(0, POOL_WATER_TOP + 0.1, POOL_BACK_Z - 1.2),
		Color3.new(1, 1, 1)
	)
	pourFoam.Transparency = 1
	pourFoam.CanCollide = false
	pourFoam.CanQuery = false
	pourFoam.CanTouch = false
	Decor.foam(pourFoam)
	-- Collection pool: the front of the sunken water, jutting out toward the spawn.
	local poolDepth = POOL_BACK_Z - POOL_FRONT_Z
	local poolCenterZ = (POOL_FRONT_Z + POOL_BACK_Z) / 2
	local pool = water("Pool", Vector3.new(POOL_WIDTH, 0.4, poolDepth), at(0, POOL_WATER_TOP - 0.2, poolCenterZ))
	Decor.steam(pool)
	Decor.ambient(pool, Sounds.STREAM, Sounds.STREAM_VOLUME, 60)

	-- The basin: a dark bed under the water and a stone lip all round, from the map
	-- ground up to just above the grass.
	local function bed(x: number, z: number, sizeX: number, sizeZ: number, top: number)
		local p = makePart(
			geometry,
			"BasinBed",
			Vector3.new(sizeX, top - MAP_GROUND_TOP, sizeZ),
			at(x, (top + MAP_GROUND_TOP) / 2, z),
			BASIN_BED_COLOR
		)
		p.CastShadow = false
	end
	bed(0, poolCenterZ, POOL_WIDTH, poolDepth, POOL_BED_TOP)
	bed(0, (LANES_FRONT_Z + lanesBackZ) / 2, 2 * fieldHalf, lanesBackZ - LANES_FRONT_Z, BASIN_BOTTOM)
	local lipHeight = LIP_TOP - MAP_GROUND_TOP
	local function lip(x1: number, z1: number, x2: number, z2: number)
		stone(
			"BasinLip",
			Vector3.new(math.abs(x2 - x1), lipHeight, math.abs(z2 - z1)),
			at((x1 + x2) / 2, MAP_GROUND_TOP + lipHeight / 2, (z1 + z2) / 2)
		)
	end
	lip(-(poolHalf + L), POOL_FRONT_Z - L, poolHalf + L, POOL_FRONT_Z)
	lip(-(fieldHalf + L), lanesBackZ, fieldHalf + L, lanesBackZ + L)
	for _, side in { -1, 1 } do
		lip(side * poolHalf, POOL_FRONT_Z, side * (poolHalf + L), LANES_FRONT_Z)
		lip(side * (poolHalf + L), LANES_FRONT_Z - L, side * (fieldHalf + L), LANES_FRONT_Z)
		lip(side * fieldHalf, LANES_FRONT_Z, side * (fieldHalf + L), lanesBackZ)
	end

	-- Spots in fill order: the front row first, left to right as seen from the
	-- spawn facing the baths (+x is the player's left), then the next row back.
	-- Each spot gets a wooden slide beside it, from the bath rim down into the river.
	local spots: { CFrame } = {}
	local spotRiverZ: { number } = {}
	local fillOrder: { { lane: { side: number, z: number, riverZ: number }, position: number } } = {}
	for row = 0, Economy.ROWS - 1 do
		local left = lanes[row * 2 + 2] -- side +1
		local right = lanes[row * 2 + 1] -- side -1
		for position = Economy.SPOTS_PER_LANE, 1, -1 do
			table.insert(fillOrder, { lane = left, position = position })
		end
		for position = 1, Economy.SPOTS_PER_LANE do
			table.insert(fillOrder, { lane = right, position = position })
		end
	end
	for _, entry in fillOrder do
		local lane = entry.lane
		local x = bathNearX + BATH_RIM + 1 + SPOT_SPACING / 2 + (entry.position - 1) * SPOT_SPACING
		table.insert(spots, at(lane.side * x, BATH_WATER_TOP, lane.z))
		table.insert(spotRiverZ, lane.riverZ)

		local toward = if lane.riverZ > lane.z then 1 else -1
		local slideX = lane.side * (x + SLIDE_OFFSET)
		local top = at(slideX, BATH_RIM_TOP + 0.1, lane.z + toward * BATH_EDGE).Position
		local bottom = at(slideX, WATER_TOP, lane.riverZ - toward).Position
		local slide = makePart(
			geometry,
			"Slide",
			Vector3.new(1.6, 0.3, (bottom - top).Magnitude),
			CFrame.lookAt((top + bottom) / 2, bottom),
			WOOD_COLOR
		)
		Skin.apply(slide, "planks")
		slide.CanCollide = false
		slide.CastShadow = false
		for _, edge in { -1, 1 } do
			local rail = makePart(
				geometry,
				"SlideRail",
				Vector3.new(SLIDE_RAIL, 0.8, slide.Size.Z),
				slide.CFrame * CFrame.new(edge * (slide.Size.X / 2 - SLIDE_RAIL / 2), 0.5, 0),
				WOOD_COLOR
			)
			Skin.apply(rail, "planks", Color3.fromRGB(200, 170, 140))
			rail.CanCollide = false
			rail.CastShadow = false
			local post = makePart(
				geometry,
				"SlidePost",
				Vector3.new(SLIDE_POST, 1.2, SLIDE_POST),
				at(slideX + edge * (slide.Size.X / 2), BATH_RIM_TOP + 0.6, lane.z + toward * (BATH_EDGE - 0.3)),
				WOOD_COLOR
			)
			Skin.apply(post, "planks")
			post.CanCollide = false
		end
		-- Water running down the slide between the rails, its texture scrolling
		-- downhill (the slide's front, -z in its own frame, faces the river).
		local runoff = water(
			"SlideWater",
			Vector3.new(slide.Size.X - 2 * SLIDE_RAIL, 0.12, slide.Size.Z),
			slide.CFrame * CFrame.new(0, 0.2, 0)
		)
		runoff.CanCollide = false
		runoff.CanQuery = false
		runoff.CanTouch = false
		-- Solid, brighter water: Glass refracts the river behind it and the strip vanishes.
		runoff.Material = Enum.Material.SmoothPlastic
		runoff.Color = SLIDE_WATER_COLOR
		runoff.Transparency = 0
		flows(runoff, 0, -1)
	end

	-- A thick studded pad in a dark studded tray (reference: capybara-onsen-plot-layout.webp),
	-- with a label floating just above it. Pressing sinks it level with the tray.
	local function makePad(
		name: string,
		x: number,
		z: number,
		color: Color3,
		amount: number,
		size: number?,
		labelSize: Vector2?
	): Pad
		local width = size or PAD_SIZE
		local tray = makePart(
			geometry,
			`{name}Tray`,
			Vector3.new(width + 2 * PAD_TRAY, 0.6, width + 2 * PAD_TRAY),
			at(x, FLOOR_TOP + 0.3, z),
			PAD_TRAY_COLOR
		)
		tray.Material = Enum.Material.Plastic
		tray.TopSurface = Enum.SurfaceType.Studs
		tray.CastShadow = false
		local part = makePart(geometry, name, Vector3.new(width, 0.6, width), at(x, FLOOR_TOP + 0.55, z), color)
		part.Material = Enum.Material.Plastic
		part.TopSurface = Enum.SurfaceType.Studs
		part.CastShadow = false
		CollectionService:AddTag(part, Plots.PAD_TAG)
		local labelDims = labelSize or LABEL_TWO_LINES
		local label = Billboard.new(part, { width = labelDims.X, height = labelDims.Y, offsetY = 1.2 })
		return { amount = amount, part = part, label = label }
	end

	-- Buy pads.
	local pads: { Pad } = {}
	for _, def in PAD_LAYOUT do
		local color = BUY_COLORS[def.amount] or BUY_COLORS[1]
		table.insert(pads, makePad(`Buy{def.amount}Pad`, def.x, def.z, color, def.amount, BUY_PAD_SIZE))
	end

	-- Everything in the station row faces the pool: rotate by pi so a part's
	-- Front face (and SurfaceGuis on it) points to +z.
	local function facingPool(x: number, y: number, z: number): CFrame
		return at(x, y, z) * CFrame.Angles(0, math.pi, 0)
	end

	-- Station props (voxel forge, tools/voxel_forge.py) face the pool. The boards,
	-- labels and pads that the services drive stay separate parts inside them.
	local function stationProp(name: string, x: number, scale: number?): Model
		return Props.place(name, facingPool(x, FLOOR_TOP, STATION_Z), geometry, scale)
	end

	-- Processor info board: framed sign under a curved roof on the +x side wall,
	-- facing into the plot, showing the queue and the rate.
	local facingIn = CFrame.Angles(0, math.pi / 2, 0) -- front (-z) turned to face -x
	Props.place("InfoBoardFrame", at(INFO_BOARD_X, FLOOR_TOP, INFO_BOARD_Z) * facingIn, geometry)
	local infoBoard = makePart(
		geometry,
		"ProcessorInfo",
		Vector3.new(14, 9, 0.6),
		at(INFO_BOARD_X, FLOOR_TOP + 8.5, INFO_BOARD_Z) * facingIn,
		Color3.fromRGB(235, 215, 170)
	)
	local infoGui = Instance.new("SurfaceGui")
	infoGui.Face = Enum.NormalId.Front
	infoGui.CanvasSize = Vector2.new(560, 360)
	infoGui.LightInfluence = 0
	infoGui.Parent = infoBoard
	local processorLabel = Instance.new("TextLabel")
	processorLabel.Size = UDim2.new(1, -40, 1, -40)
	processorLabel.Position = UDim2.fromOffset(20, 20)
	processorLabel.BackgroundTransparency = 1
	processorLabel.Font = Enum.Font.FredokaOne
	processorLabel.TextScaled = true
	processorLabel.RichText = true
	processorLabel.TextColor3 = Color3.fromRGB(90, 60, 30)
	processorLabel.Text = "Processor"
	processorLabel.Parent = infoGui

	-- Processor: the orange barrel by the -x wall, facing into the plot (+x), with
	-- smoke from its chimney.
	local barrelCf = at(BARREL_X, FLOOR_TOP, BARREL_Z) * CFrame.Angles(0, -math.pi / 2, 0)
	Props.place("ProcessorBarrel", barrelCf, geometry)
	local chimney = makePart(
		geometry,
		"ChimneySmoke",
		Vector3.new(2, 0.5, 2),
		barrelCf * CFrame.new(CHIMNEY_OFFSET),
		Color3.new(1, 1, 1)
	)
	chimney.Transparency = 1
	chimney.CanCollide = false
	chimney.CanQuery = false
	chimney.CanTouch = false
	Decor.smoke(chimney)

	-- Deposit stall with Tung Tung Tung Sahur (tier 13) keeping it, behind the counter.
	local stall = stationProp("DepositStall", DEPOSIT_X, STALL_SCALE)
	do
		-- The stall's own little onsen: a stone-rimmed pool the stall stands in,
		-- steaming, with a rubber duck.
		local box, size = stall:GetBoundingBox()
		local centre = origin:PointToObjectSpace(box.Position)
		local halfX, halfZ = size.X / 2, size.Z / 2
		local front = math.min(centre.Z + halfZ + STALL_POOL_WIDTH, STATION_PAD_Z - DEPOSIT_PAD_SIZE / 2 - 0.6)
		local left, right = centre.X - halfX - STALL_POOL_WIDTH, centre.X + halfX + STALL_POOL_WIDTH
		local back = Decor.FRONT_WALL_Z + 1.2
		-- One pool under and round the whole stall: it stands in the water (user: no
		-- grass inside the ring).
		local strips = { { left, back, right, front } }
		local rimTop = FLOOR_TOP + STALL_POOL_RIM_TOP
		local function stoneBox(
			name: string,
			x1: number,
			z1: number,
			x2: number,
			z2: number,
			y1: number,
			y2: number
		): Part
			local slabPart = makePart(
				geometry,
				name,
				Vector3.new(x2 - x1, y2 - y1, z2 - z1),
				at((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
				STONE_COLOR
			)
			return slabPart
		end
		for _, r in strips do
			local x1, z1, x2, z2 = r[1], r[2], r[3], r[4]
			Skin.apply(stoneBox("StallPoolBed", x1, z1, x2, z2, FLOOR_TOP, FLOOR_TOP + 0.3), "stone", RIM_TINT)
			local w = STALL_POOL_RIM
			for _, rim in
				{ { x1, z1, x2, z1 + w }, { x1, z2 - w, x2, z2 }, { x1, z1, x1 + w, z2 }, { x2 - w, z1, x2, z2 } }
			do
				Skin.apply(
					stoneBox("StallPoolRim", rim[1], rim[2], rim[3], rim[4], FLOOR_TOP, rimTop),
					"stone",
					RIM_TINT
				)
			end
			local stallPool = makePart(
				geometry,
				"StallPool",
				Vector3.new(x2 - x1 - 2 * w, STALL_POOL_WATER_TOP - 0.3, z2 - z1 - 2 * w),
				at((x1 + x2) / 2, FLOOR_TOP + (0.3 + STALL_POOL_WATER_TOP) / 2, (z1 + z2) / 2),
				LANE_COLOR
			)
			stallPool.Material = Enum.Material.Glass
			stallPool.Transparency = 0.15
			stallPool.CanCollide = false
			stallPool.CastShadow = false
			Skin.tile(pool, "water")
			Decor.steam(stallPool)
		end
		Props.place(
			"RubberDuck",
			at(left + 1.5, FLOOR_TOP + STALL_POOL_WATER_TOP - 0.2, front - 1.5) * CFrame.Angles(0, math.rad(200), 0),
			geometry,
			0.9
		)
	end
	local keeper = Models.makeBrainrot(STALL_KEEPER_TIER)
	keeper.Name = "StallKeeper"
	-- Bigger than in a bath and standing on a step, so it shows above the counter.
	keeper:ScaleTo(keeper:GetScale() * STALL_KEEPER_SCALE)
	keeper:PivotTo(facingPool(DEPOSIT_X, FLOOR_TOP + STALL_KEEPER_STEP, STATION_Z - 3.5))
	keeper.Parent = geometry
	-- A tall wooden stool under him, so he doesn't float: a seat on four legs
	-- with a footrest ring halfway up.
	local stool = Instance.new("Model")
	stool.Name = "KeeperStool"
	stool.Parent = geometry
	local stoolAt = facingPool(DEPOSIT_X, FLOOR_TOP, STATION_Z - 3.5)
	local seatHeight = STALL_KEEPER_STEP
	local function stoolPart(name: string, size: Vector3, offset: Vector3)
		local part = makePart(stool, name, size, stoolAt * CFrame.new(offset), STOOL_COLOR)
		part.Material = Enum.Material.Wood
		return part
	end
	stoolPart(
		"Seat",
		Vector3.new(STOOL_SEAT, STOOL_SEAT_THICK, STOOL_SEAT),
		Vector3.new(0, seatHeight - STOOL_SEAT_THICK / 2, 0)
	)
	local legHeight = seatHeight - STOOL_SEAT_THICK
	local inset = STOOL_SEAT / 2 - STOOL_LEG / 2 - 0.2
	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		stoolPart(
			"Leg",
			Vector3.new(STOOL_LEG, legHeight, STOOL_LEG),
			Vector3.new(corner.X * inset, legHeight / 2, corner.Y * inset)
		)
	end
	local ringY = legHeight * 0.45
	local ringLength = inset * 2
	for _, side in { 1, -1 } do
		stoolPart("Rung", Vector3.new(ringLength, 0.35, 0.35), Vector3.new(0, ringY, side * inset))
		stoolPart("Rung", Vector3.new(0.35, 0.35, ringLength), Vector3.new(side * inset, ringY, 0))
	end

	-- Crates of drop items on the counter.
	for i, dx in { -CRATE_OFFSET_X, CRATE_OFFSET_X } do
		local crateAt = facingPool(DEPOSIT_X + dx, COUNTER_TOP + CRATE_SIZE.Y / 2, COUNTER_Z)
		local crate = makePart(geometry, "StallCrate", CRATE_SIZE, crateAt, CRATE_COLOR)
		Skin.apply(crate, "planks")
		for _, dz in { -1, 1 } do
			-- darker slats along the front and back
			makePart(
				geometry,
				"StallCrateSlat",
				Vector3.new(CRATE_SIZE.X + 0.1, 0.35, 0.2),
				crateAt * CFrame.new(0, 0.1, dz * (CRATE_SIZE.Z / 2)),
				STOOL_COLOR
			)
		end
		for j, tier in CRATE_ITEMS[i] do
			local item = Models.makeDropItem(tier)
			local spread = (j - 2) * 1.05
			item:PivotTo(
				crateAt
					* CFrame.new(spread, CRATE_SIZE.Y / 2 + 0.6 + (if j == 2 then 0.35 else 0), (j % 2) * 0.3)
					* CFrame.Angles(0, math.rad(j * 37), 0)
			)
			item:ScaleTo(item:GetScale() * 1.1)
			item.Parent = geometry
		end
	end

	-- Market board in a wooden frame.
	stationProp("MarketBoardFrame", MARKET_X)

	-- Tall signpost with "BATHS" down it, beside the barrel.
	Decor.signpost(geometry, at(SIGNPOST_X, FLOOR_TOP, SIGNPOST_Z) * CFrame.Angles(0, math.pi / 2, 0), "BATHS")
	local marketBoard = makePart(
		geometry,
		"MarketBoard",
		Vector3.new(14, 9, 0.6),
		facingPool(MARKET_X, FLOOR_TOP + 8.5, STATION_Z),
		Color3.fromRGB(30, 30, 40)
	)
	CollectionService:AddTag(marketBoard, Plots.MARKET_BOARD_TAG)

	local stations: Stations = {
		deposit = makePad(
			"DepositPad",
			DEPOSIT_X,
			STATION_PAD_Z,
			DEPOSIT_COLOR,
			0,
			DEPOSIT_PAD_SIZE,
			Vector2.new(14, 3)
		),
		collectCash = makePad("CollectCashPad", COLLECT_CASH_X, COLLECT_CASH_Z, COLLECT_COLOR, 0),
		groupReward = makePad("GroupRewardPad", GROUP_PAD_X, GROUP_PAD_Z, GROUP_COLOR, 0),
		upgradeProcessor = makePad(
			"UpgradeProcessorPad",
			UPGRADE_X,
			UPGRADE_Z,
			UPGRADE_COLOR,
			0,
			nil,
			LABEL_THREE_LINES
		),
		merge = makePad("MergePad", MERGE_X, MERGE_Z, MERGE_COLOR, 0, MERGE_PAD_SIZE, LABEL_ONE_LINE),
		upgradeBuyTier = makePad(
			"UpgradeBuyTierPad",
			UPGRADE_BUY_TIER_X,
			UPGRADE_BUY_TIER_Z,
			UPGRADE_BUY_TIER_COLOR,
			0,
			UPGRADE_BUY_TIER_PAD_SIZE,
			LABEL_THREE_LINES
		),
		-- Robux pads on the pool side of the row, each near what it boosts.
		finishNow = makePad(
			"FinishNowPad",
			UPGRADE_X,
			UPGRADE_Z - ROBUX_GAP - 1, -- beside the upgrade pad, toward the road
			ROBUX_COLOR,
			0,
			ROBUX_PAD_SIZE,
			LABEL_ROBUX
		),
		cashPass = makePad(
			"CashPassPad",
			COLLECT_CASH_X,
			COLLECT_CASH_Z - ROBUX_GAP - 0.5,
			ROBUX_COLOR,
			0,
			ROBUX_PAD_SIZE,
			LABEL_ROBUX
		),
		autoCollect = makePad(
			"AutoCollectPad",
			AUTO_COLLECT_X,
			AUTO_COLLECT_Z,
			ROBUX_COLOR,
			0,
			ROBUX_PAD_SIZE,
			LABEL_ROBUX
		),
		doubleAura = makePad(
			"DoubleAuraPad",
			DEPOSIT_X - ROBUX_GAP - 2,
			STATION_PAD_Z,
			ROBUX_COLOR,
			0,
			ROBUX_PAD_SIZE,
			LABEL_ROBUX
		),
		processorLabel = processorLabel,
	}

	-- The Merge! pad has the hot-spring mark engraved on it (a dark decal).
	if Textures.onsen.id ~= 0 then
		local mark = Instance.new("Decal")
		mark.Name = "Engraving"
		mark.Texture = `rbxassetid://{Textures.onsen.id}`
		mark.Face = Enum.NormalId.Top
		mark.Color3 = Color3.fromRGB(70, 70, 82)
		mark.Transparency = 0.35
		mark.Parent = stations.merge.part
	end

	-- Floor arrows along the loop (reference/capybara-onsen-plot-overview.webp). The
	-- arrow image points along +z at no rotation.
	if Textures.arrow.id ~= 0 then
		for _, def in ARROWS do
			local arrow = makePart(
				geometry,
				"FloorArrow",
				Vector3.new(3.4, 0.05, 3.4),
				at(def[1], FLOOR_TOP + PATH_THICK + 0.03, def[2]) * CFrame.Angles(0, math.atan2(def[3], def[4]), 0),
				Color3.new(1, 1, 1)
			)
			arrow.Transparency = 1
			arrow.CanCollide = false
			arrow.CanQuery = false
			arrow.CanTouch = false
			arrow.CastShadow = false
			local decal = Instance.new("Decal")
			decal.Texture = `rbxassetid://{Textures.arrow.id}`
			decal.Face = Enum.NormalId.Top
			decal.Parent = arrow
		end
	end

	-- Stone paths with darker edges.
	for _, seg in PATHS do
		local x1, z1, x2, z2 = seg[1], seg[2], seg[3], seg[4]
		local alongX = z1 == z2
		local length = (if alongX then math.abs(x2 - x1) else math.abs(z2 - z1)) + PATH_WIDTH
		local size = if alongX
			then Vector3.new(length, PATH_THICK, PATH_WIDTH)
			else Vector3.new(PATH_WIDTH, PATH_THICK, length)
		local centre = at((x1 + x2) / 2, FLOOR_TOP + PATH_THICK / 2, (z1 + z2) / 2)
		local path = makePart(geometry, "YardPath", size, centre, PATH_TINT)
		Skin.apply(path, "stone", PATH_TINT)
		path.CastShadow = false
		for _, edge in { -1, 1 } do
			local offset = (PATH_WIDTH / 2 - PATH_EDGE / 2) * edge
			local strip = makePart(
				geometry,
				"YardPathEdge",
				if alongX
					then Vector3.new(length, PATH_THICK + 0.04, PATH_EDGE)
					else Vector3.new(PATH_EDGE, PATH_THICK + 0.04, length),
				centre * CFrame.new(if alongX then 0 else offset, 0.02, if alongX then offset else 0),
				PATH_EDGE_TINT
			)
			strip.CastShadow = false
		end
	end

	-- Round koi pond; the koi swim round it (client side, KoiController).
	local function disc(name: string, radius: number, height: number, centreY: number, color: Color3): Part
		-- A cylinder part stands on its side by default: turn its axis upright.
		local d = makePart(
			geometry,
			name,
			Vector3.new(height, radius * 2, radius * 2),
			at(POND_X, centreY, POND_Z) * CFrame.Angles(0, 0, math.pi / 2),
			color
		)
		d.Shape = Enum.PartType.Cylinder
		d.CastShadow = false
		return d
	end
	local step = disc("PondStep", POND_RADIUS + POND_RIM + POND_STEP, 0.35, FLOOR_TOP + 0.175, STONE_COLOR)
	Skin.apply(step, "stone", Color3.fromRGB(176, 176, 184))
	local rim = disc("PondRim", POND_RADIUS + POND_RIM, POND_RIM_TOP, FLOOR_TOP + POND_RIM_TOP / 2, STONE_COLOR)
	Skin.apply(rim, "stone", RIM_TINT)
	-- Flower bushes on the step between the statues.
	for _, angle in POND_BUSHES do
		local a = math.rad(angle)
		local r = POND_RADIUS + POND_RIM + POND_STEP * 0.5
		Props.place(
			"Bush",
			at(POND_X + math.cos(a) * r, FLOOR_TOP + 0.35, POND_Z + math.sin(a) * r) * CFrame.Angles(0, a, 0),
			geometry,
			0.28
		)
	end
	local waterTop = FLOOR_TOP + POND_RIM_TOP + 0.04
	local pondWater = disc("KoiPond", POND_RADIUS, 0.2, waterTop - 0.1, POND_WATER)
	pondWater.Material = Enum.Material.SmoothPlastic
	pondWater.Reflectance = 0.08
	Decor.ambient(pondWater, Sounds.FOUNTAIN, Sounds.FOUNTAIN_VOLUME, 45)
	for _, pad in LILY_PADS do
		local a = math.rad(pad[1])
		local lily = makePart(
			geometry,
			"LilyPad",
			Vector3.new(0.08, 1.8, 1.8),
			at(POND_X + math.cos(a) * pad[2], waterTop + 0.03, POND_Z + math.sin(a) * pad[2])
				* CFrame.Angles(0, a, math.pi / 2),
			Color3.fromRGB(90, 176, 70)
		)
		lily.Shape = Enum.PartType.Cylinder
		lily.CastShadow = false
	end
	-- Koi fountain statues on the rim facing the middle, each spitting an arc of water
	-- into the pond (2026-10-09, user reference; replaced a rock in the middle).
	local pondCentre = at(POND_X, waterTop, POND_Z).Position
	for _, angle in KOI_STATUES do
		local a = math.rad(angle)
		local spot =
			at(POND_X + math.cos(a) * STATUE_RING, FLOOR_TOP + POND_RIM_TOP, POND_Z + math.sin(a) * STATUE_RING)
		local facing = CFrame.lookAt(spot.Position, Vector3.new(pondCentre.X, spot.Position.Y, pondCentre.Z))
		Props.place("KoiStatue", facing, geometry, STATUE_SCALE)
		local mouth = facing * CFrame.new(STATUE_MOUTH * STATUE_SCALE)
		local inward = (Vector3.new(pondCentre.X, 0, pondCentre.Z) - Vector3.new(mouth.X, 0, mouth.Z)).Unit
		local nozzle = makePart(
			geometry,
			"FountainSpout",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.lookAt(mouth.Position, mouth.Position + inward + Vector3.new(0, SPOUT_RISE, 0)),
			Color3.new(1, 1, 1)
		)
		nozzle.Transparency = 1
		nozzle.CanCollide = false
		nozzle.CanQuery = false
		nozzle.CanTouch = false
		local jet = Instance.new("ParticleEmitter")
		jet.Name = "Spout"
		jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		jet.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
		jet.LightEmission = 0.4
		jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.25) })
		jet.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.5) })
		jet.EmissionDirection = Enum.NormalId.Front
		jet.Speed = NumberRange.new(SPOUT_SPEED, SPOUT_SPEED + 0.6)
		jet.SpreadAngle = Vector2.new(3, 3)
		jet.Acceleration = Vector3.new(0, -SPOUT_GRAVITY, 0)
		jet.Lifetime = NumberRange.new(0.9, 1)
		jet.Rate = 45
		jet.Parent = nozzle
	end
	for i = 1, KOI_COUNT do
		-- Voxel koi (tools/voxel_forge.py Koi1..Koi4), their backs just above the water.
		local y = waterTop - KOI_SINK
		local koi = Props.place(`Koi{(i - 1) % KOI_KINDS + 1}`, at(POND_X, y, POND_Z), geometry)
		koi.Name = "Koi"
		-- Stream each fish whole: a part arriving after KoiController has moved the model
		-- would land at the server's spot and leave the fish in pieces.
		koi.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for _, part in koi:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
			end
		end
		koi:SetAttribute("Centre", at(POND_X, y, POND_Z).Position)
		-- One school circling the same way: two rings, spread round the circle.
		local swim = POND_RADIUS - 1.5 - (i % 2) * 1.6
		koi:SetAttribute("RadiusX", swim)
		koi:SetAttribute("RadiusZ", swim)
		koi:SetAttribute("Phase", i * (2 * math.pi / KOI_COUNT))
		koi:SetAttribute("Speed", KOI_SPEED / swim) -- the same pace in studs per second on both rings
		CollectionService:AddTag(koi, KOI_TAG)
		koi.Parent = geometry
	end

	-- Planters beside the stations.
	for _, def in PLANTERS do
		Props.place("Planter", at(def[1], FLOOR_TOP, def[2]) * CFrame.Angles(0, math.rad(def[3]), 0), geometry)
	end

	-- "<Name>'s Bathhouse": a plaque in the entrance torii (both faces), and the name
	-- floating high over the entrance like the reference's plot names.
	local board = makePart(
		geometry,
		"Sign",
		Vector3.new(Decor.PLAQUE_WIDTH, 3.4, 2.8),
		at(0, FLOOR_TOP + Decor.PLAQUE_Y, Decor.ENTRANCE_Z),
		SIGN_COLOR
	)
	board.Material = Enum.Material.WoodPlanks
	local signLabels = {
		makeSignLabel(board, Enum.NormalId.Front),
		makeSignLabel(board, Enum.NormalId.Back),
		Billboard.new(board, { width = 34, height = 5, offsetY = 12, maxDistance = 400, outline = 3 }),
	}

	Decor.hotTub(
		geometry,
		at(HOT_TUB_X, FLOOR_TOP, HOT_TUB_Z) * CFrame.Angles(0, math.rad(index * 50), 0),
		(index * 3) % 10 + 1
	)
	scatterGround(geometry, origin, index)

	local brainrotFolder = Instance.new("Folder")
	brainrotFolder.Name = "Brainrots"
	brainrotFolder.Parent = folder

	local dropFolder = Instance.new("Folder")
	dropFolder.Name = "Drops"
	dropFolder.Parent = folder

	local plot: Plot = {
		index = index,
		folder = folder,
		origin = origin,
		spawn = at(SPAWN_X, FLOOR_TOP + 3, SPAWN_Z) * CFrame.Angles(0, math.pi, 0),
		spots = spots,
		spotRiverZ = spotRiverZ,
		pads = pads,
		stations = stations,
		signLabels = signLabels,
		brainrotFolder = brainrotFolder,
		dropFolder = dropFolder,
		owner = nil,
	}
	Plots.setSign(plot, "Empty Bathhouse")
	return plot
end

-- Water round the plots (MOAT_*), in world space: a front moat between each row's
-- promenade and the plots' front steps, moats down the gaps between plots and
-- along the outer sides, stone kerbs on the open edges, stone facing on the plot
-- slabs' sides, and a wooden bridge to each entrance.
type Rect = { number } -- x1, z1, x2, z2 (min, min, max, max)

-- The map ground: thick (down to GROUND_BOTTOM) and wide (past the horizon hills),
-- with `holes` (the moats) cut out. Rectangle subtraction on a grid of every hole
-- edge, each z band merged into the fewest x strips.
local function buildGround(root: Instance, holes: { Rect })
	local gx, gz = GROUND_HALF_X, GROUND_HALF_Z
	local xs, zs = { -gx, gx }, { -gz, gz }
	for _, r in holes do
		table.insert(xs, r[1])
		table.insert(xs, r[3])
		table.insert(zs, r[2])
		table.insert(zs, r[4])
	end
	table.sort(xs)
	table.sort(zs)
	local function inHole(x: number, z: number): boolean
		for _, r in holes do
			if x > r[1] and x < r[3] and z > r[2] and z < r[4] then
				return true
			end
		end
		return false
	end
	local thick = MAP_GROUND_TOP - GROUND_BOTTOM
	local function piece(x1: number, z1: number, x2: number, z2: number)
		local ground = makePart(
			root,
			"Ground",
			Vector3.new(x2 - x1, thick, z2 - z1),
			CFrame.new((x1 + x2) / 2, GROUND_BOTTOM + thick / 2, (z1 + z2) / 2),
			Color3.fromRGB(110, 170, 90)
		)
		ground.Material = Enum.Material.Grass
		Skin.apply(ground, "grass")
	end
	for k = 1, #zs - 1 do
		local z1, z2 = zs[k], zs[k + 1]
		if z2 - z1 > 0.01 then
			local zm = (z1 + z2) / 2
			local start: number? = nil
			for i = 1, #xs - 1 do
				local x1, x2 = xs[i], xs[i + 1]
				local solid = x2 - x1 > 0.01 and not inHole((x1 + x2) / 2, zm)
				if x2 - x1 <= 0.01 then
					continue
				end
				if solid and not start then
					start = x1
				elseif not solid and start then
					piece(start, z1, x1, z2)
					start = nil
				end
			end
			if start then
				piece(start, z1, gx, z2)
			end
		end
	end
end

local function buildMoats(root: Instance): { Rect }
	local holes: { Rect } = {} -- where the map ground is cut away
	local function hole(x1: number, z1: number, x2: number, z2: number)
		table.insert(holes, { math.min(x1, x2), math.min(z1, z2), math.max(x1, x2), math.max(z1, z2) })
	end
	local folder = Instance.new("Folder")
	folder.Name = "Moats"
	folder.Parent = root
	local plotHalf = WIDTH / 2
	local span = WIDTH + COLUMN_GAP
	local outer = span + plotHalf -- outer edge of the outer plots
	local outerEdge = outer + MOAT_OUTER_WIDTH
	local slab = FLOOR_TOP - MAP_GROUND_TOP
	local function box(
		name: string,
		x1: number,
		z1: number,
		x2: number,
		z2: number,
		y1: number,
		y2: number,
		color: Color3
	): Part
		return makePart(
			folder,
			name,
			Vector3.new(math.abs(x2 - x1), y2 - y1, math.abs(z2 - z1)),
			CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
			color
		)
	end
	local function water(x1: number, z1: number, x2: number, z2: number)
		hole(x1, z1, x2, z2)
		local bed = box("MoatBed", x1, z1, x2, z2, MOAT_BED - 0.5, MOAT_BED, Color3.fromRGB(40, 92, 116))
		bed.Material = Enum.Material.Slate
		local w = box("MoatWater", x1, z1, x2, z2, MOAT_WATER_TOP - 0.4, MOAT_WATER_TOP, MOAT_COLOR)
		w.Material = Enum.Material.Glass
		w.Transparency = 0.1
		w.CanCollide = false
		w.CastShadow = false
		Skin.tile(w, "water")
	end
	local function kerb(x1: number, z1: number, x2: number, z2: number)
		-- From the bed up to the promenade: the moats sit sunk between walls.
		hole(x1, z1, x2, z2)
		Skin.apply(box("MoatKerb", x1, z1, x2, z2, MOAT_BED - 0.5, Plaza.PROMENADE_TOP, STONE_COLOR), "stone", RIM_TINT)
	end
	for _, sign in { 1, -1 } do
		local near = Plaza.OUTER_Z -- the promenade's outer edge
		local plotFront = ROAD_WIDTH / 2 - STEP_COUNT -- the first step
		local back = ROAD_WIDTH / 2 + DEPTH + 1
		local function z(v: number): number
			return sign * v
		end
		-- Front moat, kerbed on the promenade side.
		kerb(-outerEdge - MOAT_KERB_WIDTH, z(near), outerEdge + MOAT_KERB_WIDTH, z(near + MOAT_KERB_WIDTH))
		water(-outerEdge, z(near + MOAT_KERB_WIDTH), outerEdge, z(plotFront))
		-- Gaps between the plots and the outer strips, from the front moat to the cliffs.
		for _, gap in
			{
				{ -span - plotHalf - COLUMN_GAP, -span - plotHalf },
				{ -plotHalf - COLUMN_GAP, -plotHalf },
				{ plotHalf, plotHalf + COLUMN_GAP },
				{ span + plotHalf, span + plotHalf + COLUMN_GAP },
			}
		do
			water(gap[1], z(plotFront), gap[2], z(back))
		end
		-- (the two gaps beyond the outer plots are part of the outer strips)
		water(-outerEdge, z(plotFront), -outer - COLUMN_GAP, z(back))
		water(outer + COLUMN_GAP, z(plotFront), outerEdge, z(back))
		kerb(-outerEdge - MOAT_KERB_WIDTH, z(near), -outerEdge, z(back))
		kerb(outerEdge, z(near), outerEdge + MOAT_KERB_WIDTH, z(back))
		-- Stone ends where the gaps and outer strips meet the cliffs.
		for _, gap in
			{
				{ -outerEdge, -outer },
				{ -plotHalf - COLUMN_GAP, -plotHalf },
				{ plotHalf, plotHalf + COLUMN_GAP },
				{ outer, outerEdge },
			}
		do
			Skin.apply(
				box("MoatEnd", gap[1], z(back), gap[2], z(back + 1), MOAT_BED - 0.5, MAP_GROUND_TOP, STONE_COLOR),
				"stone",
				RIM_TINT
			)
		end
		-- Stone facing on the plot slabs' sides (they rise out of the water) and a
		-- bridge to every entrance.
		for column = -1, 1 do
			local cx = column * span
			for _, side in { -1, 1 } do
				local x = cx + side * (plotHalf + 0.15)
				Skin.apply(
					box(
						"PlotFacing",
						x - 0.15,
						z(plotFront),
						x + 0.15,
						z(back - 1),
						MOAT_BED - 0.5,
						MAP_GROUND_TOP + slab,
						STONE_COLOR
					),
					"stone",
					RIM_TINT
				)
			end
			-- The front steps carry on down into the moat (the way out of the water).
			for k = 1, MOAT_STEPS do
				local top = MAP_GROUND_TOP - (k - 1) * (MAP_GROUND_TOP - MOAT_WATER_TOP + 0.5) / (MOAT_STEPS - 1)
				Skin.apply(
					box(
						"MoatSteps",
						cx - plotHalf,
						z(plotFront - k + 1),
						cx + plotHalf,
						z(plotFront - k),
						MOAT_BED - 0.5,
						top,
						STONE_COLOR
					),
					"stone",
					RIM_TINT
				)
			end
			-- A bridge from the promenade to the second front step.
			Decor.bridge(
				folder,
				Vector3.new(cx, Plaza.PROMENADE_TOP, z(near + 0.6)),
				Vector3.new(cx, MAP_GROUND_TOP + slab * 2 / STEP_COUNT, z(plotFront + 1.5)),
				MOAT_BRIDGE_WIDTH,
				MOAT_BRIDGE_RISE
			)
		end
	end
	return holes
end

function Plots.build()
	assert(#plots == 0, "Plots already built")
	local root = Instance.new("Folder")
	root.Name = "Plots"

	-- Ground under the plots and the road. Top sits at y = 0.5 so it never
	-- z-fights a default Baseplate (top at y = 0).
	Plaza.build(root)
	Decor.horizon(root)

	for index = 1, Economy.PLAYERS_PER_SERVER do
		table.insert(plots, buildPlot(root, index))
	end
	buildGround(root, buildMoats(root))
	root.Parent = workspace
end

-- A random point floating in the pool (world space).
function Plots.poolPoint(plot: Plot, random: Random): Vector3
	local x = random:NextNumber(-(POOL_WIDTH / 2 - 2), POOL_WIDTH / 2 - 2)
	local z = random:NextNumber(POOL_FRONT_Z + 2, POOL_BACK_Z - 2)
	return plot.origin:PointToWorldSpace(Vector3.new(x, POOL_WATER_TOP + DROP_FLOAT, z))
end

-- The path a new drop floats along, in world space: off the brainrot in spot
-- `spotIndex`, over the rim and down the slide into the river, along the river
-- to the channel, down the channel into the pool, to a random resting point.
function Plots.dropPath(plot: Plot, spotIndex: number, random: Random): { Vector3 }
	local spot = plot.origin:PointToObjectSpace(plot.spots[spotIndex].Position)
	local x, z = spot.X, spot.Z
	local riverZ = plot.spotRiverZ[spotIndex]
	local toward = if riverZ > z then 1 else -1
	local side = if x < 0 then -1 else 1
	local slideX = x + side * SLIDE_OFFSET
	local floatY = WATER_TOP + DROP_FLOAT
	local floatZ = riverZ + random:NextNumber(-RIVER_WIDTH / 4, RIVER_WIDTH / 4)
	local rest = plot.origin:PointToObjectSpace(Plots.poolPoint(plot, random))
	local points = {
		Vector3.new(x, BATH_WATER_TOP + DROP_FLOAT, z),
		Vector3.new(slideX, BATH_RIM_TOP + DROP_FLOAT, z + toward * BATH_EDGE),
		Vector3.new(slideX, floatY, floatZ),
		Vector3.new(0, floatY, floatZ),
		Vector3.new(0, floatY, POOL_BACK_Z),
		Vector3.new(0, POOL_WATER_TOP + DROP_FLOAT, POOL_BACK_Z - 2), -- over the step into the pool
		Vector3.new(rest.X, rest.Y, rest.Z),
	}
	for i, point in points do
		points[i] = plot.origin:PointToWorldSpace(point)
	end
	return points
end

function Plots.all(): { Plot }
	return plots
end

function Plots.get(player: Player): Plot?
	return byPlayer[player]
end

function Plots.assign(player: Player): Plot?
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			plot.folder:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotIndex", plot.index)
			Plots.setSign(plot, `{player.DisplayName}'s Bathhouse`)
			return plot
		end
	end
	return nil
end

function Plots.release(player: Player): Plot?
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	byPlayer[player] = nil
	plot.owner = nil
	plot.folder:SetAttribute("OwnerUserId", nil)
	Plots.setSign(plot, "Empty Bathhouse")
	return plot
end

-- Calls `onStep(player)` when the plot's owner steps onto `pad`: once per step,
-- not once per Touched event. While they stand on it the pad has Pressed = true
-- (clients animate it).
function Plots.onStep(plot: Plot, pad: Pad, onStep: (Player) -> ())
	local occupied = false
	local limit = pad.part.Size.X / 2 + 1.5
	pad.part.Touched:Connect(function(hit: BasePart)
		local player = Plots.playerFromHit(hit)
		if occupied or not player or player ~= plot.owner then
			return
		end
		occupied = true
		pad.part:SetAttribute("Pressed", true)
		task.spawn(function()
			local center = pad.part.Position
			while true do
				task.wait(0.15)
				local root = Plots.rootPart(player)
				if not root or player.Parent == nil then
					break
				end
				local offset = root.Position - center
				if math.abs(offset.X) > limit or math.abs(offset.Z) > limit or math.abs(offset.Y) > 8 then
					break
				end
			end
			occupied = false
			pad.part:SetAttribute("Pressed", false)
		end)
		onStep(player)
	end)
end

-- The player whose character touched `hit`, if any.
function Plots.playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model or not model:IsA("Model") then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

function Plots.rootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

return Plots
