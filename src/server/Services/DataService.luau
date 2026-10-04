--!strict
-- Per-player data, saved with ProfileStore (session locking: a player can't be
-- loaded on two servers at once). Profile.Data is the live table; services
-- mutate it and call DataService.sync so balances reach the client.
--
-- Balances replicate to the owning client as read-only player attributes
-- (Aura, Cash, Brainrots, TotalBrainrots, HighestTier, BuyTier, AuraPerSecond, MergeReady,
-- Discovered = "0101..." one char per tier). Attributes a client sets never reach the server.
--
-- In Studio, saving only persists when the place is published and "Enable
-- Studio Access to API Services" is on; otherwise ProfileStore runs in mock
-- mode and every join starts fresh.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Economy = require(Shared.Config.Economy)
local ProfileStore = require(ServerStorage:WaitForChild("ServerPackages"):WaitForChild("ProfileStore")) :: any

export type Data = {
	cash: number,
	aura: number,
	buyTier: number,
	boughtAtBuyTier: number, -- brainrots bought since the buy tier last changed (price scaling)
	counts: { number }, -- brainrots owned, indexed by tier
	highestTier: number, -- highest tier ever owned (0 = none yet)
	discovered: { boolean }, -- tiers ever owned, indexed by tier (the Index, Phase 4)
	processorLevel: number,
	processorQueue: number, -- deposited Aura (already x market) waiting to become Cash
	pendingCash: number, -- processed Cash waiting on the Collect Cash pad
	lastOnline: number, -- os.time() while online, for offline earnings
	luckyBlock: string, -- name of the lucky block held ("" = none)
	luckyWaiting: { string }, -- names of the lucky blocks floating / waiting in the pool
	luckyProgress: number, -- seconds of production toward the next lucky block
	totalBrainrots: number, -- lifetime brainrots obtained (bought or unlocked; leaderboard)
	receipts: { [string]: boolean }, -- processed dev product PurchaseIds
	groupRewardAt: number, -- os.time() of the last group reward claim
	totalCashEarned: number, -- lifetime Cash earned (the Net Worth board)
	playtime: number, -- seconds played (the Playtime board)
	tutorialStep: number, -- TutorialService: 0 = not decided, then the step, Tutorial.DONE = finished
}

local STORE_NAME = "PlayerData_v1"
local LAST_ONLINE_INTERVAL = 10 -- seconds between lastOnline stamps

local TEMPLATE: Data = {
	cash = Economy.STARTING_CASH,
	aura = 0,
	buyTier = 1,
	boughtAtBuyTier = 0,
	counts = table.create(Tiers.MAX_TIER, 0),
	highestTier = 0,
	discovered = table.create(Tiers.MAX_TIER, false),
	processorLevel = 1,
	processorQueue = 0,
	pendingCash = 0,
	lastOnline = 0,
	luckyBlock = "",
	luckyWaiting = {},
	luckyProgress = 0,
	totalBrainrots = 0,
	receipts = {},
	groupRewardAt = 0,
	totalCashEarned = 0,
	playtime = 0,
	tutorialStep = 0,
}

local DataService = {}

local store = ProfileStore.New(STORE_NAME, TEMPLATE)
local profiles: { [Player]: any } = {}
local loaded: { [Player]: Data } = {}

-- Loads (or creates) the player's profile. Yields. Returns nil if the player
-- left or the profile could not be loaded (the player is kicked).
function DataService.load(player: Player): Data?
	-- Studio-only: a suffix loads a separate test profile (a fresh new player) and
	-- leaves the real save alone.
	local suffix = if RunService:IsStudio() then Economy.STUDIO_PROFILE_SUFFIX else ""
	local profile = store:StartSessionAsync(`Player_{player.UserId}{suffix}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return nil
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		loaded[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was loaded on another server. Please rejoin.")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	profiles[player] = profile
	local data = profile.Data :: Data
	if data.lastOnline == 0 and RunService:IsStudio() and Economy.STUDIO_STARTING_CASH > 0 then
		-- Brand-new profile in Studio: testing Cash (Economy.STUDIO_STARTING_CASH).
		data.cash = Economy.STUDIO_STARTING_CASH
	end
	if data.lastOnline == 0 and RunService:IsStudio() and Economy.STUDIO_GIVE_EACH_TIER > 0 then
		-- Brand-new profile in Studio: n of every tier, to check every model in a bath.
		for tier = 1, Tiers.MAX_TIER do
			data.counts[tier] = Economy.STUDIO_GIVE_EACH_TIER
		end
		DataService.markOwned(data)
	end
	loaded[player] = data
	DataService.sync(player)
	return data
end

function DataService.get(player: Player): Data?
	return loaded[player]
end

function DataService.release(player: Player)
	local data = loaded[player]
	if data then
		data.lastOnline = os.time()
	end
	local profile = profiles[player]
	profiles[player] = nil
	loaded[player] = nil
	if profile then
		profile:EndSession()
	end
end

-- Saves the profile now (used after granting a purchase).
function DataService.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

function DataService.brainrotCount(data: Data): number
	local total = 0
	for _, count in data.counts do
		total += count
	end
	return total
end

-- Aura per second from every brainrot, for offline earnings.
function DataService.auraPerSecond(data: Data): number
	local total = 0
	for tier, count in data.counts do
		total += count * Tiers.get(tier).aura
	end
	return total / Economy.DROP_INTERVAL
end

-- Updates highestTier and discovered from what the player owns now. Returns
-- the tiers discovered for the first time.
function DataService.markOwned(data: Data): { number }
	local new: { number } = {}
	for tier, count in data.counts do
		if count > 0 then
			if not data.discovered[tier] then
				data.discovered[tier] = true
				table.insert(new, tier)
			end
			data.highestTier = math.max(data.highestTier, tier)
		end
	end
	return new
end

-- Applies earnings since lastOnline: brainrots at Economy.OFFLINE_RATE straight
-- into Aura (ignores the drop cap), and the processor keeps processing.
-- Returns the Aura and Cash gained.
function DataService.applyOffline(data: Data): (number, number)
	if data.lastOnline <= 0 then
		return 0, 0
	end
	local elapsed = math.max(0, os.time() - data.lastOnline)
	local aura = DataService.auraPerSecond(data) * elapsed * Economy.OFFLINE_RATE
	local cash = math.min(data.processorQueue, Economy.processorRate(data.processorLevel) * elapsed)
	data.aura += aura
	data.processorQueue -= cash
	data.pendingCash += cash
	data.lastOnline = os.time()
	return aura, cash
end

function DataService.sync(player: Player)
	local data = loaded[player]
	if not data then
		return
	end
	player:SetAttribute("Aura", data.aura)
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Brainrots", DataService.brainrotCount(data))
	local discovered = table.create(Tiers.MAX_TIER, "0")
	for tier = 1, Tiers.MAX_TIER do
		if data.discovered[tier] then
			discovered[tier] = "1"
		end
	end
	player:SetAttribute("Discovered", table.concat(discovered))
	player:SetAttribute("TotalBrainrots", data.totalBrainrots)
	player:SetAttribute("HighestTier", data.highestTier)
	player:SetAttribute("BuyTier", data.buyTier)
	player:SetAttribute("AuraPerSecond", DataService.auraPerSecond(data))
	local mergeReady = false
	for tier = 1, Tiers.MAX_TIER - 1 do
		if data.counts[tier] >= Economy.MERGE_COUNT then
			mergeReady = true
			break
		end
	end
	player:SetAttribute("MergeReady", mergeReady)
end

function DataService.addAura(player: Player, amount: number)
	local data = loaded[player]
	if not data or amount <= 0 then
		return
	end
	data.aura += amount
	DataService.sync(player)
end

-- Takes `amount` Cash if the player has it. Returns whether it was spent.
function DataService.spendCash(player: Player, amount: number): boolean
	local data = loaded[player]
	if not data or amount < 0 or data.cash < amount then
		return false
	end
	data.cash -= amount
	DataService.sync(player)
	return true
end

function DataService.addBrainrots(player: Player, tier: number, amount: number)
	local data = loaded[player]
	if not data or amount <= 0 then
		return
	end
	data.counts[tier] += amount
	DataService.markOwned(data)
	DataService.sync(player)
end

function DataService:Start()
	while true do
		task.wait(LAST_ONLINE_INTERVAL)
		local now = os.time()
		for _, data in loaded do
			data.lastOnline = now
		end
	end
end

return DataService
