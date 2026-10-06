--!strict
-- Lucky blocks. After a random stretch of production (Economy.LUCKY_BLOCK_SPAWN_MIN
-- to _MAX seconds, the owner online, owning brainrots, drops under the cap) the
-- next drop from one of their brainrots is a lucky block instead of Aura: it slides
-- out of the bath and floats down the river and channel into the pool like any
-- drop. Its type is a weighted random roll (Config/LuckyBlocks). Several blocks can
-- float at once (up to Economy.LUCKY_BLOCK_MAX_WAITING); a player holds one.
--
-- Walking over one (anywhere on its way or in the pool) while holding none picks it up: the player's
-- LuckyBlock attribute is set, which makes every client draw the block swinging
-- above that player's head and opens the owner's panel (odds, price, Unlock /
-- Discard). Unlock costs the block's Cash price and adds the rolled brainrot to
-- a free spot; it only merges if the onsen is full, and if nothing can merge to
-- make room the block keeps waiting. Unlocking fires LuckyBlockOpened to all
-- clients for the open-up reveal. Discard throws it away.
--
-- data.luckyBlock saves the held block, data.luckyWaiting the floating ones; after a
-- rejoin the floating ones rest in the pool again.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Economy = require(Shared.Config.Economy)
local LuckyBlocks = require(Shared.Config.LuckyBlocks)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Visuals = require(Shared.Visuals)
local DropPath = require(Shared.DropPath)
local Plots = require(script.Parent.Parent.Plots)
local DataService = require(script.Parent.DataService)
local PoolService = require(script.Parent.PoolService)
local DropService = require(script.Parent.DropService)
local ShopService = require(script.Parent.ShopService)
local Analytics = require(script.Parent.Parent.Analytics)
local MonetizationService = require(script.Parent.MonetizationService)

type Plot = Plots.Plot

local LuckyBlockService = {}

local TICK = 0.25
local BLOCK_SIZE = 3

type Floating = {
	name: string,
	model: Model,
	path: { Vector3 }, -- its flow path (last point = resting point in the pool)
	flowAt: number, -- server time it started floating
}

type State = {
	floating: { Floating }, -- blocks floating down to / resting in the pool
	held: boolean,
	nextAt: number, -- seconds of production at which the next block spawns
	pending: boolean, -- a block is waiting for the next drop to replace
	debugReason: string?, -- Studio-only: last "why no block" message printed
}

local states: { [Player]: State } = {}
local random = Random.new()
local notify: RemoteEvent
local opened: RemoteEvent

-- Seconds of production until the next block: random, or the Studio test override.
local function nextInterval(): number
	if RunService:IsStudio() and Economy.STUDIO_LUCKY_BLOCK_INTERVAL > 0 then
		return Economy.STUDIO_LUCKY_BLOCK_INTERVAL
	end
	return random:NextNumber(Economy.LUCKY_BLOCK_SPAWN_MIN, Economy.LUCKY_BLOCK_SPAWN_MAX)
end

local function saveWaiting(state: State, data: DataService.Data)
	local names: { string } = {}
	for _, entry in state.floating do
		table.insert(names, entry.name)
	end
	data.luckyWaiting = names
end

local function findBlock(name: string): LuckyBlocks.Block?
	for _, block in LuckyBlocks.list do
		if block.name == name then
			return block
		end
	end
	return nil
end

local function makeBlock(name: string): Model
	local model = Visuals.makeLuckyBlock(name, BLOCK_SIZE)
	local gui = Instance.new("BillboardGui")
	-- Small, and only up close: several chests can float at once and their labels
	-- would otherwise stack into a wall of text over the pool.
	gui.Size = UDim2.fromScale(6, 1.1) -- studs, so it shrinks with distance
	gui.StudsOffset = Vector3.new(0, BLOCK_SIZE / 2 + 0.8, 0)
	gui.MaxDistance = 25
	gui.Parent = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Visuals.blockColor(name)
	label.TextStrokeTransparency = 0.2
	label.Text = `{name} Lucky Box`
	label.Parent = gui
	return model
end

-- Floats a block along `path` (a drop's path, or just a resting point) into the
-- plot's Drops folder, where clients animate it like a drop.
local function floatDown(player: Player, plot: Plot, name: string, path: { Vector3 }, flowAt: number)
	local state = states[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	local model = makeBlock(name)
	model:PivotTo(CFrame.new(path[#path]))
	model:SetAttribute("Lucky", true)
	DropPath.write(model, path, flowAt)
	model.Parent = plot.dropFolder
	table.insert(state.floating, { name = name, model = model, path = path, flowAt = flowAt })
	saveWaiting(state, data)
end

local function pickUp(player: Player, index: number)
	local state = states[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	local entry = table.remove(state.floating, index)
	if not entry then
		return
	end
	entry.model:Destroy()
	state.held = true
	data.luckyBlock = entry.name
	saveWaiting(state, data)
	player:SetAttribute("LuckyBlock", entry.name)
end

-- Ends the held block (unlocked or discarded).
local function finish(player: Player)
	local state = states[player]
	local data = DataService.get(player)
	if state then
		state.held = false
	end
	if data then
		data.luckyBlock = ""
	end
	player:SetAttribute("LuckyBlock", "")
end

-- Opens the held block. `paid` = bought with Robux (no Cash spent). Returns whether
-- a block was opened.
local function unlock(player: Player, paid: boolean?): boolean
	local state = states[player]
	local data = DataService.get(player)
	local plot = Plots.get(player)
	if not state or not state.held or not data or not plot then
		return false
	end
	local block = findBlock(data.luckyBlock)
	if not block then
		finish(player)
		return false
	end
	local before = table.clone(data.counts)
	ShopService.makeRoom(data, 1)
	if DataService.brainrotCount(data) >= Economy.MAX_SPOTS then
		data.counts = before
		notify:FireClient(player, "Your bathhouse is full and nothing can merge")
		return false
	end
	if not paid then
		local price = LuckyBlocks.priceFor(block, data.buyTier)
		if not DataService.spendCash(player, price) then
			data.counts = before
			notify:FireClient(player, `Not enough Cash (need {Format.short(price)})`)
			return false
		end
		Analytics.cash(player, "sink", price, data.cash, "Shop", `LuckyBlock{block.name}`)
	end
	local tier = LuckyBlocks.roll(block, data.buyTier, random)
	data.counts[tier] += 1
	data.totalBrainrots += 1
	ShopService.mergeIfFull(data)
	local discovered = DataService.markOwned(data)
	DataService.sync(player)
	PoolService.render(plot, data)
	ShopService.refreshPads(plot)
	opened:FireAllClients(player, block.name, tier)
	finish(player)
	local name = Tiers.get(tier).name
	if #discovered > 0 then
		notify:FireClient(player, `New brainrot! {name}`, "newBrainrot")
	else
		notify:FireClient(player, `Unlocked {name}!`, "lucky")
	end
	return true
end

local function onAction(player: Player, action: unknown)
	if action == "unlock" then
		unlock(player)
	elseif action == "discard" then
		local state = states[player]
		if state and state.held then
			finish(player)
		end
	end
end

-- Called by PlotService once the player has a plot and data.
function LuckyBlockService.onAssigned(player: Player, plot: Plot)
	local state: State = { floating = {}, held = false, nextAt = nextInterval(), pending = false, debugReason = nil }
	states[player] = state
	player:SetAttribute("LuckyBlock", "")
	local data = DataService.get(player)
	if not data then
		return
	end
	-- Blocks that were floating (and one that was held) rest in the pool again.
	local waiting = table.clone(data.luckyWaiting)
	if data.luckyBlock ~= "" then
		table.insert(waiting, data.luckyBlock)
		data.luckyBlock = ""
	end
	data.luckyWaiting = {}
	for _, name in waiting do
		if findBlock(name) then
			floatDown(player, plot, name, { Plots.poolPoint(plot, random) }, workspace:GetServerTimeNow())
		end
	end
end

function LuckyBlockService.onRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, entry in state.floating do
		entry.model:Destroy()
	end
	states[player] = nil
end

local function update(player: Player, plot: Plot, dt: number)
	local state = states[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end

	-- Spawning: count production time; when it reaches the random target, the next
	-- drop from one of their brainrots becomes a random block.
	local hasBrainrots = DataService.brainrotCount(data) > 0
	local capped = DropService.dropCount(plot) >= Economy.DROP_CAP
	local full = #state.floating >= Economy.LUCKY_BLOCK_MAX_WAITING
	if hasBrainrots and not capped and not full and not state.pending then
		data.luckyProgress += dt
	end
	if RunService:IsStudio() then
		-- Studio-only: say in the Output why no block is spawning, when that changes.
		local reason = if not hasBrainrots
			then "paused: no brainrots"
			elseif capped then `paused: {Economy.DROP_CAP}-drop cap reached, collect drops`
			elseif full then `paused: {Economy.LUCKY_BLOCK_MAX_WAITING} blocks already waiting`
			else "counting"
		if reason ~= state.debugReason then
			state.debugReason = reason
			print(`[LuckyBlock] {player.Name}: {reason}`)
		end
	end
	if data.luckyProgress >= state.nextAt and not state.pending then
		data.luckyProgress = 0
		state.nextAt = nextInterval()
		state.pending = true
		local block = LuckyBlocks.randomBlock(data.buyTier, data.highestTier, random)
		if block then
			local name = block.name
			DropService.replaceNextDrop(plot, function(path, flowAt)
				if states[player] == state then
					state.pending = false
					floatDown(player, plot, name, path, flowAt)
				end
			end)
		else
			state.pending = false -- nothing allowed yet (no tier 2 owned): try again next time
		end
	end

	-- Pick up the nearest floating block when the owner walks over it, holding none.
	local root = Plots.rootPart(player)
	if state.held or not root or #state.floating == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	for index, entry in state.floating do
		local where = DropPath.at(entry.path, entry.flowAt, now)
		local offset = root.Position - where
		if
			Vector3.new(offset.X, 0, offset.Z).Magnitude <= Economy.LUCKY_BLOCK_PICKUP_RANGE
			and math.abs(offset.Y) < 8
		then
			pickUp(player, index)
			return
		end
	end
end

function LuckyBlockService:Init()
	notify = Remotes.event("Notify")
	Remotes.event("LuckyBlockAction").OnServerEvent:Connect(onAction)
	opened = Remotes.event("LuckyBlockOpened")
end

function LuckyBlockService:Start()
	-- The 89 Robux "Unlock Lucky Chest" product opens the held chest without Cash.
	MonetizationService.setLuckyUnlockHandler(function(player: Player): boolean
		return unlock(player, true)
	end)
	local last = os.clock()
	while true do
		task.wait(TICK)
		local now = os.clock()
		local dt = now - last
		last = now
		for _, player in Players:GetPlayers() do
			local plot = Plots.get(player)
			if plot then
				update(player, plot, dt)
			end
		end
	end
end

return LuckyBlockService
