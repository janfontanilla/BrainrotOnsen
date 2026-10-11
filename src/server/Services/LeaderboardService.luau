--!strict
-- Leaderboards: three roofed pavilions on the island in the middle of the map
-- (like Capybara Onsen's Total / Net Worth / Playtime boards), each showing the
-- top players from its own OrderedDataStore, refreshed every minute:
--   * Top Brainrots: lifetime brainrots obtained (bought or unlocked; merges don't count)
--   * Net Worth: lifetime Cash earned
--   * Playtime: time played
-- Plus the in-server leaderstat "Total Brainrots" (the Roblox player list).
--
-- OrderedDataStores hold integers, so Net Worth is stored as log10 x 1e6 (Cash can
-- pass 2^63) and decoded for display. Global data needs a published place with
-- "Enable Studio Access to API Services" on; without it the boards say so in Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local Plaza = require(script.Parent.Parent.Plaza)

type Data = DataService.Data

type BoardDef = {
	title: string,
	storeName: string,
	roof: Color3,
	x: number, -- along the island (world x)
	score: (Data) -> number, -- integer stored in the DataStore
	show: (number) -> string, -- stored integer -> display text
}

type Board = {
	def: BoardDef,
	store: OrderedDataStore,
	rows: { TextLabel },
	status: TextLabel,
}

local LeaderboardService = {}

local TOP_COUNT = 10
local LEADERSTAT_INTERVAL = 2 -- seconds between leaderstat / playtime updates
local BOARD_INTERVAL = 60 -- seconds between DataStore saves / board refreshes
local NET_WORTH_SCALE = 1e6 -- stored = floor(log10(cash + 1) x this)

local BOARD_SIZE = Vector3.new(16, 14, 0.8)
local BOARD_LIFT = 3 -- studs from the island to the bottom of a board
local WOOD = Color3.fromRGB(110, 74, 46)

local function playtimeText(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	return if hours > 0 then `{hours}h {minutes}m` else `{minutes}m`
end

local DEFS: { BoardDef } = {
	{
		title = "Top Brainrots",
		storeName = "TotalBrainrots_v1",
		roof = Color3.fromRGB(240, 150, 40),
		x = -34,
		score = function(data)
			return math.floor(data.totalBrainrots)
		end,
		show = Format.commas,
	},
	{
		title = "Net Worth",
		storeName = "NetWorth_v1",
		roof = Color3.fromRGB(96, 196, 70),
		x = 0,
		score = function(data)
			return math.floor(math.log10(data.totalCashEarned + 1) * NET_WORTH_SCALE)
		end,
		show = function(stored)
			return `{Format.short(10 ^ (stored / NET_WORTH_SCALE) - 1)} Cash`
		end,
	},
	{
		title = "Playtime",
		storeName = "Playtime_v1",
		roof = Color3.fromRGB(150, 96, 220),
		x = 34,
		score = function(data)
			return math.floor(data.playtime)
		end,
		show = playtimeText,
	},
}

local boards: { Board } = {}
local stats: { [Player]: { best: IntValue, cash: StringValue, total: IntValue } } = {}
local nameCache: { [number]: string } = {}
local warned = false

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(parent: Instance, size: UDim2, position: UDim2, align: Enum.TextXAlignment): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = align
	l.Size = size
	l.Position = position
	l.Parent = parent
	return l
end

-- A pavilion: stone plinth, two posts, the board (readable from both sides) and a
-- stepped roof in the board's colour.
local function buildBoard(folder: Folder, def: BoardDef): Board
	local base = Plaza.ISLAND_TOP
	local x = def.x
	local model = Instance.new("Model")
	model.Name = def.title
	model.Parent = folder
	part(model, "Plinth", Vector3.new(19, 1, 4), Vector3.new(x, base + 0.5, 0), Color3.fromRGB(150, 155, 168))
	local postHeight = BOARD_LIFT + BOARD_SIZE.Y + 1.5
	for _, dx in { -1, 1 } do
		part(
			model,
			"Post",
			Vector3.new(1.4, postHeight, 1.4),
			Vector3.new(x + dx * (BOARD_SIZE.X / 2 + 0.7), base + 1 + postHeight / 2, 0),
			WOOD
		)
	end
	local roofY = base + 1 + postHeight
	part(model, "Roof", Vector3.new(22, 1, 6), Vector3.new(x, roofY + 0.5, 0), def.roof)
	part(model, "Roof", Vector3.new(18, 1, 4.6), Vector3.new(x, roofY + 1.5, 0), def.roof)
	part(model, "RoofRidge", Vector3.new(8, 1, 2.4), Vector3.new(x, roofY + 2.5, 0), def.roof)
	local board = part(
		model,
		"Board",
		BOARD_SIZE,
		Vector3.new(x, base + 1 + BOARD_LIFT + BOARD_SIZE.Y / 2, 0),
		Color3.fromRGB(250, 238, 205)
	)
	local rows: { TextLabel } = {}
	local status: TextLabel? = nil
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(500, 440)
		gui.LightInfluence = 0.2
		gui.Parent = board
		local title = label(gui, UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.03), Enum.TextXAlignment.Center)
		title.Text = def.title
		title.TextColor3 = def.roof
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 40, 25)
		stroke.Thickness = 2
		stroke.Parent = title
		for i = 1, TOP_COUNT do
			-- Rows centred on the board (left-aligned rows bunched in the corner).
			local row = label(
				gui,
				UDim2.fromScale(0.86, 0.068),
				UDim2.fromScale(0.07, 0.19 + (i - 1) * 0.073),
				Enum.TextXAlignment.Center
			)
			row.RichText = true
			row.TextColor3 = Color3.fromRGB(70, 48, 30)
			table.insert(rows, row)
		end
		if face == Enum.NormalId.Front then
			local s = label(gui, UDim2.fromScale(0.9, 0.05), UDim2.fromScale(0.05, 0.93), Enum.TextXAlignment.Center)
			s.TextColor3 = Color3.fromRGB(140, 120, 100)
			status = s
		end
	end
	assert(status, "board has a status label")
	return {
		def = def,
		store = DataStoreService:GetOrderedDataStore(def.storeName),
		rows = rows,
		status = status,
	}
end

local function displayName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else `Player {userId}`
	nameCache[userId] = result
	return result
end

local function setRows(board: Board, all: { { key: string, value: number } })
	-- Studio test players (Player1, Player2: negative user ids) never show (2026-10-11,
	-- user); older saves of them are skipped here, new ones are never written.
	local entries = {}
	for _, entry in all do
		if (tonumber(entry.key) or 0) > 0 then
			table.insert(entries, entry)
		end
	end
	for i, row in board.rows do
		-- The rows list holds each face's rows in order: front rows, then back rows.
		local rank = (i - 1) % TOP_COUNT + 1
		local entry = entries[rank]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.Text = `{rank}. {displayName(userId)}  <font color="#2a8f3a">{board.def.show(entry.value)}</font>`
		else
			row.Text = ""
		end
	end
end

local function fail(board: Board, message: string)
	if not warned then
		warned = true
		if RunService:IsStudio() then
			warn(`[Leaderboard] {message}. Publish the place and enable Studio API access to use the global boards.`)
		end
	end
	board.status.Text = if RunService:IsStudio() then "Global data unavailable" else ""
end

local function save(player: Player, data: Data)
	if player.UserId <= 0 then
		return -- a Studio test player
	end
	for _, board in boards do
		local ok, err = pcall(function()
			board.store:SetAsync(tostring(player.UserId), board.def.score(data))
		end)
		if not ok then
			fail(board, tostring(err))
			return
		end
	end
end

local function refreshBoards()
	for player in stats do
		local data = DataService.get(player)
		if data then
			save(player, data)
		end
	end
	for _, board in boards do
		local ok, result = pcall(function()
			-- A few extra in case some are test players (skipped in setRows).
			local pages = board.store:GetSortedAsync(false, TOP_COUNT + 5)
			return pages:GetCurrentPage()
		end)
		if ok then
			board.status.Text = ""
			setRows(board, result :: { { key: string, value: number } })
		else
			fail(board, tostring(result))
		end
	end
end

-- The player list (top right): who is in the server with their best tier (first
-- column, so the list sorts by it), Cash and Total Brainrots.
local function onPlayerAdded(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local best = Instance.new("IntValue")
	best.Name = "Best Tier"
	best.Parent = folder
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "0"
	cash.Parent = folder
	local total = Instance.new("IntValue")
	total.Name = "Total Brainrots"
	total.Parent = folder
	folder.Parent = player
	stats[player] = { best = best, cash = cash, total = total }
end

local function onPlayerRemoving(player: Player)
	local data = DataService.get(player)
	stats[player] = nil
	if data then
		save(player, data)
	end
end

function LeaderboardService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
	for _, def in DEFS do
		table.insert(boards, buildBoard(folder, def))
	end
end

function LeaderboardService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(LEADERSTAT_INTERVAL)
			for player, stat in stats do
				local data = DataService.get(player)
				if data then
					stat.best.Value = data.highestTier
					stat.cash.Value = Format.short(data.cash)
					stat.total.Value = math.floor(data.totalBrainrots)
					data.playtime += LEADERSTAT_INTERVAL
					player:SetAttribute("Playtime", data.playtime) -- the Profile page
					player:SetAttribute("NetWorth", data.totalCashEarned)
				end
			end
		end
	end)

	while true do
		task.wait(5) -- first refresh shortly after start, then every BOARD_INTERVAL
		refreshBoards()
		task.wait(BOARD_INTERVAL - 5)
	end
end

return LeaderboardService
