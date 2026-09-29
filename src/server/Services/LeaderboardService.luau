--!strict
-- Total Brainrots: lifetime brainrots obtained (bought or unlocked from lucky
-- blocks; merging does not count).
--   * In-server leaderstat "Total Brainrots" (the Roblox player list).
--   * A global board in the middle of the map (the road between the plot rows)
--     showing the top players, from an OrderedDataStore refreshed every minute.
--
-- Global data needs a published place with "Enable Studio Access to API
-- Services" on; without it the board says so in Studio and stays empty.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local STORE_NAME = "TotalBrainrots_v1"
local TOP_COUNT = 10
local LEADERSTAT_INTERVAL = 5 -- seconds between leaderstat updates
local BOARD_INTERVAL = 60 -- seconds between DataStore saves / board refreshes

local BOARD_SIZE = Vector3.new(30, 20, 1)
local BOARD_POSITION = Vector3.new(0, 12, 0) -- middle of the map (the road between the plot rows)
local ROW_HEIGHT = 0.075 -- fraction of the board per row

local store = DataStoreService:GetOrderedDataStore(STORE_NAME)
local stats: { [Player]: IntValue } = {}
local nameCache: { [number]: string } = {}
local rows: { TextLabel } = {}
local status: TextLabel
local warned = false

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

local function buildBoard()
	local model = Instance.new("Model")
	model.Name = "Leaderboard"

	for _, dx in { -13, 13 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(1.2, 14, 1.2)
		post.Position = Vector3.new(dx, 7, 0)
		post.Color = Color3.fromRGB(120, 80, 50)
		post.Parent = model
	end

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Size = BOARD_SIZE
	board.Position = BOARD_POSITION
	board.Color = Color3.fromRGB(35, 30, 40)
	board.Parent = model

	-- The same list on both faces, so it reads from either side of the road.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(900, 600)
		gui.LightInfluence = 0
		gui.Parent = board
		label(gui, UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0.01), Enum.TextXAlignment.Center).Text =
			"Top Brainrot Collectors"
		for i = 1, TOP_COUNT do
			local row = label(
				gui,
				UDim2.fromScale(0.9, ROW_HEIGHT),
				UDim2.fromScale(0.05, 0.14 + (i - 1) * 0.082),
				Enum.TextXAlignment.Left
			)
			row.RichText = true
			table.insert(rows, row)
		end
		if face == Enum.NormalId.Front then
			status = label(gui, UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.94), Enum.TextXAlignment.Center)
			status.TextColor3 = Color3.fromRGB(180, 180, 200)
		end
	end
	model.Parent = workspace
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

local function setRows(entries: { { key: string, value: number } })
	for i, row in rows do
		-- The rows list holds each face's rows in order: front rows, then back rows.
		local rank = (i - 1) % TOP_COUNT + 1
		local entry = entries[rank]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.Text = `{rank}. {displayName(userId)}  <font color="#ffd966">{Format.commas(entry.value)}</font>`
		else
			row.Text = ""
		end
	end
end

local function fail(message: string)
	if not warned then
		warned = true
		if RunService:IsStudio() then
			warn(`[Leaderboard] {message}. Publish the place and enable Studio API access to use the global board.`)
		end
	end
	status.Text = if RunService:IsStudio() then "Global data unavailable" else ""
end

local function saveTotal(player: Player, total: number)
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), total)
	end)
	if not ok then
		fail(tostring(err))
	end
end

local function refreshBoard()
	for player in stats do
		local data = DataService.get(player)
		if data then
			saveTotal(player, math.floor(data.totalBrainrots))
		end
	end
	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, TOP_COUNT)
		return pages:GetCurrentPage()
	end)
	if not ok then
		fail(tostring(result))
		return
	end
	status.Text = ""
	setRows(result :: { { key: string, value: number } })
end

local function onPlayerAdded(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local stat = Instance.new("IntValue")
	stat.Name = "Total Brainrots"
	stat.Value = 0
	stat.Parent = folder
	folder.Parent = player
	stats[player] = stat
end

local function onPlayerRemoving(player: Player)
	local data = DataService.get(player)
	stats[player] = nil
	if data then
		saveTotal(player, math.floor(data.totalBrainrots))
	end
end

function LeaderboardService:Init()
	buildBoard()
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
					stat.Value = math.floor(data.totalBrainrots)
				end
			end
		end
	end)

	while true do
		task.wait(5) -- first refresh shortly after start, then every BOARD_INTERVAL
		refreshBoard()
		task.wait(BOARD_INTERVAL - 5)
	end
end

return LeaderboardService
