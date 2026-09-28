--!strict
-- Lucky blocks. After every Economy.LUCKY_BLOCK_SPAWN_INTERVAL seconds of
-- production (the owner online, owning brainrots, drops under the cap) the next
-- drop from one of their brainrots is a lucky block instead of Aura: it slides
-- out of the bath and floats down the river and channel into the pool like any
-- drop. Only one block at a time. The type is the best one unlocked by the
-- highest tier ever owned (Config/LuckyBlocks).
--
-- Walking over it (anywhere on its way or in the pool) picks it up: the player's
-- LuckyBlock attribute is set, which makes every client draw the block swinging
-- above that player's head and opens the owner's panel (odds, price, Unlock /
-- Discard). Unlock costs the block's Cash price and adds the rolled brainrot to
-- a free spot; it only merges if the onsen is full, and if nothing can merge to
-- make room the block keeps waiting. Unlocking fires LuckyBlockOpened to all
-- clients for the open-up reveal. Discard throws it away.
--
-- data.luckyBlock saves the block's name; after a rejoin it rests in the pool.

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

type Plot = Plots.Plot

local LuckyBlockService = {}

local TICK = 0.25
local BLOCK_SIZE = 3

type State = {
	model: Model?, -- the block floating down to / resting in the pool
	path: { Vector3 }, -- its flow path (last point = resting point in the pool)
	flowAt: number, -- server time it started floating
	held: boolean,
	debugReason: string?, -- Studio-only: last "why no block" message printed
}

local states: { [Player]: State } = {}
local random = Random.new()
local notify: RemoteEvent
local opened: RemoteEvent

local function interval(): number
	if RunService:IsStudio() and Economy.STUDIO_LUCKY_BLOCK_INTERVAL > 0 then
		return Economy.STUDIO_LUCKY_BLOCK_INTERVAL
	end
	return Economy.LUCKY_BLOCK_SPAWN_INTERVAL
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
	gui.Size = UDim2.fromOffset(180, 40)
	gui.StudsOffset = Vector3.new(0, BLOCK_SIZE / 2 + 1.2, 0)
	gui.MaxDistance = 80
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

local function clearPart(state: State)
	if state.model then
		state.model:Destroy()
		state.model = nil
	end
end

-- Floats the block along `path` (a drop's path, or just a resting point) into
-- the plot's Drops folder, where clients animate it like a drop.
local function floatDown(player: Player, plot: Plot, name: string, path: { Vector3 }, flowAt: number)
	local state = states[player]
	if not state then
		return
	end
	clearPart(state)
	state.held = false
	player:SetAttribute("LuckyBlock", "")
	local model = makeBlock(name)
	model:PivotTo(CFrame.new(path[#path]))
	model:SetAttribute("Lucky", true)
	DropPath.write(model, path, flowAt)
	model.Parent = plot.dropFolder
	state.model = model
	state.path = path
	state.flowAt = flowAt
end

local function pickUp(player: Player, name: string)
	local state = states[player]
	if not state then
		return
	end
	clearPart(state)
	state.held = true
	player:SetAttribute("LuckyBlock", name)
end

local function finish(player: Player)
	local state = states[player]
	local data = DataService.get(player)
	if state then
		clearPart(state)
		state.held = false
	end
	if data then
		data.luckyBlock = ""
		data.luckyProgress = 0
	end
	player:SetAttribute("LuckyBlock", "")
end

local function unlock(player: Player)
	local state = states[player]
	local data = DataService.get(player)
	local plot = Plots.get(player)
	if not state or not state.held or not data or not plot then
		return
	end
	local block = findBlock(data.luckyBlock)
	if not block then
		finish(player)
		return
	end
	local before = table.clone(data.counts)
	ShopService.makeRoom(data, 1)
	if DataService.brainrotCount(data) >= Economy.MAX_SPOTS then
		data.counts = before
		notify:FireClient(player, "Your onsen is full and nothing can merge")
		return
	end
	if not DataService.spendCash(player, block.price) then
		data.counts = before
		notify:FireClient(player, `Not enough Cash (need {Format.short(block.price)})`)
		return
	end
	local tier = LuckyBlocks.roll(block, random)
	data.counts[tier] += 1
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
	local state: State = { model = nil, path = {}, flowAt = 0, held = false, debugReason = nil }
	states[player] = state
	player:SetAttribute("LuckyBlock", "")
	local data = DataService.get(player)
	if data and data.luckyBlock ~= "" then
		floatDown(player, plot, data.luckyBlock, { Plots.poolPoint(plot, random) }, workspace:GetServerTimeNow())
	end
end

function LuckyBlockService.onRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	clearPart(state)
	states[player] = nil
end

local function update(player: Player, plot: Plot, dt: number)
	local state = states[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	if data.luckyBlock == "" then
		local hasBrainrots = DataService.brainrotCount(data) > 0
		local capped = DropService.dropCount(plot) >= Economy.DROP_CAP
		local producing = hasBrainrots and not capped
		if producing then
			data.luckyProgress = math.min(data.luckyProgress + dt, interval())
		end
		if RunService:IsStudio() then
			-- Studio-only: say in the Output why no block is spawning, when that changes.
			local first = LuckyBlocks.list[1]
			local reason = if data.highestTier < first.unlockTier
				then `no block unlocked yet: highest tier owned is {data.highestTier}, {first.name} unlocks at tier {first.unlockTier}`
				elseif not hasBrainrots then "paused: no brainrots"
				elseif capped then `paused: {Economy.DROP_CAP}-drop cap reached, collect drops`
				else "counting"
			if reason ~= state.debugReason then
				state.debugReason = reason
				print(`[LuckyBlock] {player.Name}: {reason}`)
			end
		end
		if data.luckyProgress >= interval() then
			local block = LuckyBlocks.forHighestTier(data.highestTier)
			if block then
				data.luckyBlock = block.name
				data.luckyProgress = 0
				-- The next drop from one of their brainrots is the block.
				DropService.replaceNextDrop(plot, function(path, flowAt)
					if states[player] == state and data.luckyBlock == block.name then
						floatDown(player, plot, block.name, path, flowAt)
					end
				end)
			end
		end
		return
	end
	-- A block is waiting in the pool: pick it up when the owner walks over it.
	local model = state.model
	local root = Plots.rootPart(player)
	if not state.held and model and root then
		local where = DropPath.at(state.path, state.flowAt, workspace:GetServerTimeNow())
		local offset = root.Position - where
		if
			Vector3.new(offset.X, 0, offset.Z).Magnitude <= Economy.LUCKY_BLOCK_PICKUP_RANGE
			and math.abs(offset.Y) < 8
		then
			pickUp(player, data.luckyBlock)
		end
	end
end

function LuckyBlockService:Init()
	notify = Remotes.event("Notify")
	Remotes.event("LuckyBlockAction").OnServerEvent:Connect(onAction)
	opened = Remotes.event("LuckyBlockOpened")
end

function LuckyBlockService:Start()
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
