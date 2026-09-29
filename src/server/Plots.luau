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
local Decor = require(script.Parent.Decor)

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
local ROAD_WIDTH = 30
local COLUMN_GAP = 12
local FLOOR_TOP = 1
local WATER_TOP = FLOOR_TOP + 0.4
local DROP_FLOAT = 1.2 -- drop height above the water
local LANE_WIDTH = 7 -- baths run along x; this is their size in z, rims included
local RIVER_WIDTH = 8 -- low river in front of each bath, flowing to the channel
local BATH_RIM = 1
local BATH_WATER_TOP = FLOOR_TOP + 3 -- baths are raised well above the rivers
local BATH_RIM_TOP = BATH_WATER_TOP + 0.6
local SPOT_SPACING = 9 -- along the bath (x)
local SLIDE_OFFSET = SPOT_SPACING / 2 -- slides sit between brainrots
local LANES_FRONT_Z = 90
local CHANNEL_WIDTH = 8
-- Narrow pool right in front of the lanes; the open ground in front of it is
-- room for the Phase 2+ stations (deposit, processor, market).
local POOL_FRONT_Z = 60
local POOL_BACK_Z = LANES_FRONT_Z - 2
local POOL_WIDTH = 14
local RIM_HEIGHT = 0.8
local RIM_THICKNESS = 1.5
local PAD_Z = 72
local PAD_SIZE = 8
local SPAWN_Z = 52
-- Phase 2 station row, in front of the pool and facing it (+z). Seen from the
-- pool looking at the road it reads, left to right: processor info board, processor
-- tank, deposit stand, market board. Pads sit on the pool side of the row.
local STATION_Z = 26 -- where the row's structures stand
local STATION_PAD_Z = 38 -- where their pads sit
local INFO_BOARD_X = -52
local UPGRADE_X = -56
local COLLECT_CASH_X = -44
local PROCESSOR_X = -30
local DEPOSIT_X = -10
local DEPOSIT_PAD_SIZE = 11
local ROBUX_PAD_SIZE = 6
local MARKET_X = 12
-- Buy pads (amount -> plot-local x), on the player's left of the pool
-- (+x, seen from the spawn facing the baths).
local PAD_LAYOUT: { { amount: number, x: number } } = {
	{ amount = 1, x = 38 },
	{ amount = 5, x = 28 },
	{ amount = 25, x = 18 },
	{ amount = 100, x = 50 },
}
-- Merge! and Upgrade Buy Tier, in front of the buy pads beside the pool.
local MERGE_X, MERGE_Z = 18, 58
local MERGE_PAD_SIZE = 10
local UPGRADE_BUY_TIER_X, UPGRADE_BUY_TIER_Z = 36, 58
local UPGRADE_BUY_TIER_PAD_SIZE = 10

local FLOOR_COLOR = Color3.fromRGB(112, 190, 74)
local LANE_COLOR = Color3.fromRGB(96, 190, 220)
local PAD_COLOR = Color3.fromRGB(80, 200, 110)
local BUY_100_COLOR = Color3.fromRGB(255, 120, 40)
local MERGE_COLOR = Color3.fromRGB(150, 150, 160)
local UPGRADE_BUY_TIER_COLOR = Color3.fromRGB(60, 210, 255)
local DEPOSIT_COLOR = Color3.fromRGB(255, 220, 90)
local COLLECT_COLOR = Color3.fromRGB(60, 220, 90)
local UPGRADE_COLOR = Color3.fromRGB(70, 170, 255)
local PROCESSOR_COLOR = Color3.fromRGB(230, 150, 50)
local ROBUX_COLOR = Color3.fromRGB(255, 180, 40)
local SIGN_COLOR = Color3.fromRGB(120, 80, 50)
local STONE_COLOR = Color3.fromRGB(140, 140, 150)
local WOOD_COLOR = Color3.fromRGB(150, 100, 60)

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
	gui.CanvasSize = Vector2.new(680, 100)
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

local function makePadLabel(pad: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 80)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 90
	gui.Parent = pad
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return label
end

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

	makePart(geometry, "Floor", Vector3.new(WIDTH, 1, DEPTH), at(0, FLOOR_TOP - 0.5, DEPTH / 2), FLOOR_COLOR)
	Decor.build(geometry, { at = at, width = WIDTH, depth = DEPTH, floorTop = FLOOR_TOP, seed = index })

	local function water(name: string, size: Vector3, cframe: CFrame)
		local part = makePart(geometry, name, size, cframe, LANE_COLOR)
		part.Transparency = 0.2
		part.Material = Enum.Material.Glass
	end
	local function stone(name: string, size: Vector3, cframe: CFrame)
		local part = makePart(geometry, name, size, cframe, STONE_COLOR)
		part.Material = Enum.Material.Slate
	end

	-- Rows, front to back: a low river, then a raised bath behind it that drains
	-- forward into it. One bath and river on each side of the center channel.
	local rowDepth = RIVER_WIDTH + LANE_WIDTH
	local bathInnerLength = Economy.SPOTS_PER_LANE * SPOT_SPACING + 2
	local bathLength = bathInnerLength + 2 * BATH_RIM
	local bathNearX = CHANNEL_WIDTH / 2 + 1 -- bath edge nearest the channel
	local bathCenterX = bathNearX + bathLength / 2
	local riverLength = bathNearX + bathLength - CHANNEL_WIDTH / 2
	local baseHeight = BATH_WATER_TOP - 0.4 - FLOOR_TOP
	local rimHeight = BATH_RIM_TOP - (BATH_WATER_TOP - 0.4)
	local rimY = BATH_WATER_TOP - 0.4 + rimHeight / 2

	local lanes: { { side: number, z: number, riverZ: number } } = {}
	for row = 0, Economy.ROWS - 1 do
		local rowFront = LANES_FRONT_Z + row * rowDepth
		local riverZ = rowFront + RIVER_WIDTH / 2
		local z = rowFront + RIVER_WIDTH + LANE_WIDTH / 2
		for side = -1, 1, 2 do
			table.insert(lanes, { side = side, z = z, riverZ = riverZ })
			water(
				"River",
				Vector3.new(riverLength, 0.4, RIVER_WIDTH),
				at(side * (CHANNEL_WIDTH / 2 + riverLength / 2), WATER_TOP - 0.2, riverZ)
			)

			-- Raised bath: stone base, shallow water on top, rim around it.
			stone(
				"Bath",
				Vector3.new(bathLength, baseHeight, LANE_WIDTH),
				at(side * bathCenterX, FLOOR_TOP + baseHeight / 2, z)
			)
			water(
				"BathWater",
				Vector3.new(bathInnerLength, 0.4, LANE_WIDTH - 2 * BATH_RIM),
				at(side * bathCenterX, BATH_WATER_TOP - 0.2, z)
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

			-- Lantern on the rim at the channel end of each bath.
			local lantern = makePart(
				geometry,
				"Lantern",
				Vector3.new(1.4, 1.6, 1.4),
				at(side * (bathNearX + 0.7), BATH_RIM_TOP + 0.8, z),
				Color3.fromRGB(255, 214, 140)
			)
			lantern.Material = Enum.Material.Neon
		end
	end
	local lanesBackZ = LANES_FRONT_Z + Economy.ROWS * rowDepth

	-- Center channel from the back row down to the pool.
	water(
		"Channel",
		Vector3.new(CHANNEL_WIDTH, 0.4, lanesBackZ - POOL_BACK_Z),
		at(0, WATER_TOP - 0.2, (POOL_BACK_Z + lanesBackZ) / 2)
	)
	-- Collection pool with a low stone rim, open at the back where the channel enters.
	local poolDepth = POOL_BACK_Z - POOL_FRONT_Z
	local poolCenterZ = (POOL_FRONT_Z + POOL_BACK_Z) / 2
	water("Pool", Vector3.new(POOL_WIDTH, 0.4, poolDepth), at(0, WATER_TOP - 0.2, poolCenterZ))
	local poolRimY = FLOOR_TOP + RIM_HEIGHT / 2
	local outer = POOL_WIDTH + 2 * RIM_THICKNESS
	stone("PoolRim", Vector3.new(outer, RIM_HEIGHT, RIM_THICKNESS), at(0, poolRimY, POOL_FRONT_Z - RIM_THICKNESS / 2))
	for side = -1, 1, 2 do
		stone(
			"PoolRim",
			Vector3.new(RIM_THICKNESS, RIM_HEIGHT, poolDepth),
			at(side * (POOL_WIDTH + RIM_THICKNESS) / 2, poolRimY, poolCenterZ)
		)
		local backWidth = (outer - CHANNEL_WIDTH) / 2
		stone(
			"PoolRim",
			Vector3.new(backWidth, RIM_HEIGHT, RIM_THICKNESS),
			at(side * (CHANNEL_WIDTH + backWidth) / 2, poolRimY, POOL_BACK_Z + RIM_THICKNESS / 2)
		)
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
		slide.Material = Enum.Material.WoodPlanks
		slide.CanCollide = false
	end

	local function makePad(name: string, x: number, z: number, color: Color3, amount: number, size: number?): Pad
		local width = size or PAD_SIZE
		local part = makePart(geometry, name, Vector3.new(width, 0.4, width), at(x, FLOOR_TOP + 0.2, z), color)
		part.Material = Enum.Material.Neon
		CollectionService:AddTag(part, Plots.PAD_TAG)
		return { amount = amount, part = part, label = makePadLabel(part) }
	end

	-- Buy pads.
	local pads: { Pad } = {}
	for _, def in PAD_LAYOUT do
		local color = if def.amount == Economy.AUTO_MERGE_BUY_AMOUNT then BUY_100_COLOR else PAD_COLOR
		table.insert(pads, makePad(`Buy{def.amount}Pad`, def.x, PAD_Z, color, def.amount))
	end

	-- Everything in the station row faces the pool: rotate by pi so a part's
	-- Front face (and SurfaceGuis on it) points to +z.
	local function facingPool(x: number, y: number, z: number): CFrame
		return at(x, y, z) * CFrame.Angles(0, math.pi, 0)
	end

	-- Processor info board: framed wooden sign showing the queue and the rate.
	for _, dx in { -7.5, 7.5 } do
		makePart(
			geometry,
			"InfoPost",
			Vector3.new(1, 14, 1),
			at(INFO_BOARD_X + dx, FLOOR_TOP + 7, STATION_Z),
			SIGN_COLOR
		)
	end
	makePart(geometry, "InfoRoof", Vector3.new(18, 1, 3), at(INFO_BOARD_X, FLOOR_TOP + 14.5, STATION_Z), SIGN_COLOR)
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

	-- Processor tank.
	local processor = makePart(
		geometry,
		"Processor",
		Vector3.new(18, 14, 14),
		at(PROCESSOR_X, FLOOR_TOP + 9, STATION_Z) * CFrame.Angles(0, 0, math.pi / 2),
		PROCESSOR_COLOR
	)
	processor.Shape = Enum.PartType.Cylinder
	local cap = makePart(
		geometry,
		"ProcessorCap",
		Vector3.new(2, 10, 10),
		at(PROCESSOR_X, FLOOR_TOP + 19, STATION_Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(90, 90, 100)
	)
	cap.Shape = Enum.PartType.Cylinder

	-- Deposit stand: counter, posts and a red awning, pad in front on the pool side.
	makePart(geometry, "DepositCounter", Vector3.new(12, 3, 3), at(DEPOSIT_X, FLOOR_TOP + 1.5, STATION_Z), SIGN_COLOR)
	for _, dx in { -5.5, 5.5 } do
		makePart(
			geometry,
			"DepositPost",
			Vector3.new(0.8, 9, 0.8),
			at(DEPOSIT_X + dx, FLOOR_TOP + 4.5, STATION_Z - 1),
			SIGN_COLOR
		)
	end
	makePart(
		geometry,
		"DepositAwning",
		Vector3.new(13, 0.6, 5),
		at(DEPOSIT_X, FLOOR_TOP + 9.3, STATION_Z),
		Color3.fromRGB(220, 60, 60)
	)

	-- Market board on posts.
	for _, dx in { -6, 6 } do
		makePart(
			geometry,
			"MarketPost",
			Vector3.new(0.8, 12, 0.8),
			at(MARKET_X + dx, FLOOR_TOP + 6, STATION_Z - 0.6),
			SIGN_COLOR
		)
	end
	local marketBoard = makePart(
		geometry,
		"MarketBoard",
		Vector3.new(14, 9, 0.6),
		facingPool(MARKET_X, FLOOR_TOP + 8.5, STATION_Z),
		Color3.fromRGB(30, 30, 40)
	)
	CollectionService:AddTag(marketBoard, Plots.MARKET_BOARD_TAG)

	local stations: Stations = {
		deposit = makePad("DepositPad", DEPOSIT_X, STATION_PAD_Z, DEPOSIT_COLOR, 0, DEPOSIT_PAD_SIZE),
		collectCash = makePad("CollectCashPad", COLLECT_CASH_X, STATION_PAD_Z, COLLECT_COLOR, 0),
		upgradeProcessor = makePad("UpgradeProcessorPad", UPGRADE_X, STATION_PAD_Z - 4, UPGRADE_COLOR, 0),
		merge = makePad("MergePad", MERGE_X, MERGE_Z, MERGE_COLOR, 0, MERGE_PAD_SIZE),
		upgradeBuyTier = makePad(
			"UpgradeBuyTierPad",
			UPGRADE_BUY_TIER_X,
			UPGRADE_BUY_TIER_Z,
			UPGRADE_BUY_TIER_COLOR,
			0,
			UPGRADE_BUY_TIER_PAD_SIZE
		),
		-- Robux pads on the pool side of the row, each near what it boosts.
		finishNow = makePad("FinishNowPad", UPGRADE_X + 4, STATION_PAD_Z + 8, ROBUX_COLOR, 0, ROBUX_PAD_SIZE),
		cashPass = makePad("CashPassPad", COLLECT_CASH_X + 10, STATION_PAD_Z + 8, ROBUX_COLOR, 0, ROBUX_PAD_SIZE),
		autoCollect = makePad("AutoCollectPad", PROCESSOR_X + 10, STATION_PAD_Z + 8, ROBUX_COLOR, 0, ROBUX_PAD_SIZE),
		doubleAura = makePad("DoubleAuraPad", DEPOSIT_X + 12, STATION_PAD_Z + 8, ROBUX_COLOR, 0, ROBUX_PAD_SIZE),
		processorLabel = processorLabel,
	}

	-- "<Name>'s Onsen" sign over the entrance, readable from the road and the plot.
	for _, x in { -18, 18 } do
		makePart(geometry, "SignPost", Vector3.new(1, 14, 1), at(x, FLOOR_TOP + 7, 2), SIGN_COLOR)
	end
	local board = makePart(geometry, "Sign", Vector3.new(36, 5, 1), at(0, FLOOR_TOP + 12, 2), SIGN_COLOR)
	local signLabels = { makeSignLabel(board, Enum.NormalId.Front), makeSignLabel(board, Enum.NormalId.Back) }

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
		spawn = at(0, FLOOR_TOP + 3, SPAWN_Z) * CFrame.Angles(0, math.pi, 0),
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

	for index = 1, Economy.PLAYERS_PER_SERVER do
		table.insert(plots, buildPlot(root, index))
	end
	root.Parent = workspace
end

-- A random point floating in the pool (world space).
function Plots.poolPoint(plot: Plot, random: Random): Vector3
	local x = random:NextNumber(-(POOL_WIDTH / 2 - 2), POOL_WIDTH / 2 - 2)
	local z = random:NextNumber(POOL_FRONT_Z + 2, POOL_BACK_Z - 2)
	return plot.origin:PointToWorldSpace(Vector3.new(x, WATER_TOP + DROP_FLOAT, z))
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
		Vector3.new(rest.X, floatY, rest.Z),
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
	local limit = PAD_SIZE / 2 + 1.5
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
