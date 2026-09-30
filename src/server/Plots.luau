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
local COLUMN_GAP = 12
-- The plot floor is a thick slab on the map ground so the bath field can be sunk
-- into it (Capybara Onsen style): the rivers, channel and pool are one sunken water
-- sheet below the grass, framed by a stone lip, and the baths are stone pedestals
-- standing up out of it.
local MAP_GROUND_TOP = 0.5 -- top of the map-wide Ground part
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
local BATH_RIM = 1
-- Baths are thin stone rings standing in the sunken water (Capybara Onsen): their
-- water sits just below the grass and the rim tops just above it, so no tall box.
local BATH_WATER_TOP = FLOOR_TOP - 0.3
local BATH_RIM_TOP = FLOOR_TOP + 0.5
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
local INFO_BOARD_X = -48 -- processor info board at the -x end of the station row
local UPGRADE_X = INFO_BOARD_X -- processor upgrade pad, in front of the board
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
local RIM_TINT = Color3.fromRGB(200, 204, 216) -- rims a shade darker than the bath body
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
		Skin.apply(piece, "grass")
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
	Decor.build(geometry, { at = at, width = WIDTH, depth = DEPTH, floorTop = FLOOR_TOP, seed = index })

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
	local baseHeight = BATH_WATER_TOP - 0.4 - BASIN_BOTTOM
	local rimHeight = BATH_RIM_TOP - (BATH_WATER_TOP - 0.4)
	local rimY = BATH_WATER_TOP - 0.4 + rimHeight / 2

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

			-- Raised bath: stone base, shallow water on top, rim around it.
			stone(
				"Bath",
				Vector3.new(bathLength, baseHeight, LANE_WIDTH),
				at(side * bathCenterX, BASIN_BOTTOM + baseHeight / 2, z)
			)
			Decor.steam(
				water(
					"BathWater",
					Vector3.new(bathInnerLength, 0.4, LANE_WIDTH - 2 * BATH_RIM),
					at(side * bathCenterX, BATH_WATER_TOP - 0.2, z)
				)
			)
			for _, dz in { -1, 1 } do
				stone(
					"BathRim",
					Vector3.new(bathLength, rimHeight, BATH_RIM),
					at(side * bathCenterX, rimY, z + dz * (LANE_WIDTH - BATH_RIM) / 2)
				)
			end
			for _, dx in { -1, 1 } do
				stone(
					"BathRim",
					Vector3.new(BATH_RIM, rimHeight, LANE_WIDTH - 2 * BATH_RIM),
					at(side * bathCenterX + dx * (bathLength - BATH_RIM) / 2, rimY, z)
				)
			end

			-- A step down at the channel end of the rim.
			stone(
				"BathStep",
				Vector3.new(1, BATH_WATER_TOP - BASIN_BOTTOM, LANE_WIDTH),
				at(side * (bathNearX - 0.5), (BATH_WATER_TOP + BASIN_BOTTOM) / 2, z)
			)

			-- Lantern on the rim at the channel end of each bath.
			Props.place("RimLantern", at(side * (bathNearX + 0.7), BATH_RIM_TOP, z), geometry)
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
		local top = at(slideX, BATH_RIM_TOP + 0.2, lane.z + toward * (LANE_WIDTH / 2 - BATH_RIM)).Position
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

	-- Processor info board: framed sign under a curved roof beside the barrel,
	-- showing the queue and the rate.
	stationProp("InfoBoardFrame", INFO_BOARD_X)
	local infoBoard = makePart(
		geometry,
		"ProcessorInfo",
		Vector3.new(14, 9, 0.6),
		facingPool(INFO_BOARD_X, FLOOR_TOP + 8.5, STATION_Z),
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
	stationProp("DepositStall", DEPOSIT_X, STALL_SCALE)
	local keeper = Models.makeBrainrot(STALL_KEEPER_TIER)
	keeper.Name = "StallKeeper"
	-- Bigger than in a bath and standing on a step, so it shows above the counter.
	keeper:ScaleTo(keeper:GetScale() * STALL_KEEPER_SCALE)
	keeper:PivotTo(facingPool(DEPOSIT_X, FLOOR_TOP + STALL_KEEPER_STEP, STATION_Z - 3.5))
	keeper.Parent = geometry

	-- Market board in a wooden frame.
	stationProp("MarketBoardFrame", MARKET_X)

	-- Tall signpost with "ONSEN" down it, between the stall and the barrel.
	Decor.signpost(geometry, at(SIGNPOST_X, FLOOR_TOP, SIGNPOST_Z) * CFrame.Angles(0, math.pi / 2, 0), "ONSEN")
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
			STATION_PAD_Z,
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
			UPGRADE_X - ROBUX_GAP,
			STATION_PAD_Z,
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
				at(def[1], FLOOR_TOP + 0.03, def[2]) * CFrame.Angles(0, math.atan2(def[3], def[4]), 0),
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

	-- "<Name>'s Onsen": a plaque in the entrance torii (both faces), and the name
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
	Plots.setSign(plot, "Empty Onsen")
	return plot
end

function Plots.build()
	assert(#plots == 0, "Plots already built")
	local root = Instance.new("Folder")
	root.Name = "Plots"

	-- Ground under the plots and the road. Top sits at y = 0.5 so it never
	-- z-fights a default Baseplate (top at y = 0).
	local groundSize = Vector3.new(3 * WIDTH + 2 * COLUMN_GAP + 60, 1, 2 * DEPTH + ROAD_WIDTH + 60)
	local ground = makePart(root, "Ground", groundSize, CFrame.new(0, 0, 0), Color3.fromRGB(110, 170, 90))
	ground.Material = Enum.Material.Grass
	Skin.apply(ground, "grass")

	Plaza.build(root)
	Decor.horizon(root)

	for index = 1, Economy.PLAYERS_PER_SERVER do
		table.insert(plots, buildPlot(root, index))
	end
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
		Vector3.new(slideX, BATH_RIM_TOP + DROP_FLOAT, z + toward * (LANE_WIDTH / 2 - BATH_RIM)),
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
			Plots.setSign(plot, `{player.DisplayName}'s Onsen`)
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
	Plots.setSign(plot, "Empty Onsen")
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
