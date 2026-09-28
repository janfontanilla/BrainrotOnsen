--!strict
-- Draws the market board on every plot's MarketBoard part: the current
-- multiplier, a line graph of the recent rolls, and "Updating in Xs".
-- Reads ReplicatedStorage.Market (set by the server's MarketService).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)

local BOARD_TAG = "MarketBoard" -- matches Plots.MARKET_BOARD_TAG on the server
local CANVAS = Vector2.new(560, 360)
local GRAPH_POS = Vector2.new(30, 130)
local GRAPH_SIZE = Vector2.new(500, 180)
local GOOD_COLOR = Color3.fromRGB(120, 255, 140)
local BAD_COLOR = Color3.fromRGB(255, 120, 120)

type Board = {
	value: TextLabel,
	countdown: TextLabel,
	graph: Frame,
}

local MarketBoardController = {}

local boards: { [BasePart]: Board } = {}

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Position = position
	l.Size = size
	l.Parent = parent
	return l
end

local function build(part: Instance)
	if not part:IsA("BasePart") or boards[part] then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = CANVAS
	gui.LightInfluence = 0
	gui.Parent = part

	label(gui, "Aura Market", UDim2.fromOffset(0, 8), UDim2.fromOffset(CANVAS.X, 44), Color3.fromRGB(255, 220, 90))
	local value = label(gui, "", UDim2.fromOffset(0, 56), UDim2.fromOffset(CANVAS.X, 64), Color3.new(1, 1, 1))

	local graph = Instance.new("Frame")
	graph.Position = UDim2.fromOffset(GRAPH_POS.X, GRAPH_POS.Y)
	graph.Size = UDim2.fromOffset(GRAPH_SIZE.X, GRAPH_SIZE.Y)
	graph.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	graph.BorderSizePixel = 0
	graph.ClipsDescendants = true
	graph.Parent = gui

	local countdown = label(
		gui,
		"",
		UDim2.fromOffset(0, CANVAS.Y - 44),
		UDim2.fromOffset(CANVAS.X, 36),
		Color3.fromRGB(180, 180, 200)
	)

	boards[part] = { value = value, countdown = countdown, graph = graph }
end

local function yFor(v: number): number
	local t = (v - Economy.MARKET_MIN) / (Economy.MARKET_MAX - Economy.MARKET_MIN)
	return GRAPH_SIZE.Y - 8 - t * (GRAPH_SIZE.Y - 16)
end

local function segment(parent: Instance, a: Vector2, b: Vector2, color: Color3, thickness: number)
	local delta = b - a
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	line.Size = UDim2.fromOffset(delta.Magnitude + thickness / 2, thickness)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.Parent = parent
end

local function drawGraph(board: Board, values: { number })
	board.graph:ClearAllChildren()
	-- 1.00x baseline.
	local baseY = yFor(1)
	segment(board.graph, Vector2.new(0, baseY), Vector2.new(GRAPH_SIZE.X, baseY), Color3.fromRGB(70, 70, 90), 2)
	if #values < 2 then
		return
	end
	local step = GRAPH_SIZE.X / (Economy.MARKET_HISTORY - 1)
	local offset = (Economy.MARKET_HISTORY - #values) * step
	for i = 1, #values - 1 do
		local a = Vector2.new(offset + (i - 1) * step, yFor(values[i]))
		local b = Vector2.new(offset + i * step, yFor(values[i + 1]))
		segment(board.graph, a, b, if values[i + 1] >= 1 then GOOD_COLOR else BAD_COLOR, 4)
	end
end

function MarketBoardController:Start()
	local market = ReplicatedStorage:WaitForChild("Market")

	for _, part in CollectionService:GetTagged(BOARD_TAG) do
		build(part)
	end
	CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(function(part)
		build(part)
		local history = market:GetAttribute("History")
		local board = boards[part :: BasePart]
		if board and typeof(history) == "string" then
			local values: { number } = {}
			for _, s in string.split(history, ",") do
				table.insert(values, tonumber(s) or 1)
			end
			drawGraph(board, values)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(BOARD_TAG):Connect(function(part)
		boards[part :: BasePart] = nil
	end)

	local function redrawGraphs()
		local history = market:GetAttribute("History")
		local values: { number } = {}
		if typeof(history) == "string" then
			for _, s in string.split(history, ",") do
				table.insert(values, tonumber(s) or 1)
			end
		end
		for _, board in boards do
			drawGraph(board, values)
		end
	end
	market:GetAttributeChangedSignal("History"):Connect(redrawGraphs)
	redrawGraphs()

	local lastText = ""
	RunService.Heartbeat:Connect(function()
		local multiplier = market:GetAttribute("Multiplier")
		local nextRollAt = market:GetAttribute("NextRollAt")
		if typeof(multiplier) ~= "number" or typeof(nextRollAt) ~= "number" then
			return
		end
		local seconds = math.max(0, math.ceil(nextRollAt - workspace:GetServerTimeNow()))
		local text = `{Format.multiplier(multiplier)}|{seconds}`
		if text == lastText then
			return
		end
		lastText = text
		for _, board in boards do
			board.value.Text = `Multiplier: {Format.multiplier(multiplier)}`
			board.value.TextColor3 = if multiplier >= 1 then GOOD_COLOR else BAD_COLOR
			board.countdown.Text = `Updating in {seconds}s`
		end
	end)
end

return MarketBoardController
