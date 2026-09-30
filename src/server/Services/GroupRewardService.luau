--!strict
-- Group reward: the pink pad in front of the "Join the group + Like" sign on each
-- plot's curved front wall. Group members standing on it get Cash every
-- Economy.GROUP_REWARD_INTERVAL seconds; the amount grows with the buy tier
-- (Economy.GROUP_REWARD_*). Likes cannot be checked by the game, so membership is
-- the only condition. Products.GROUP_ID = 0 means the group is not set yet: Studio
-- treats everyone as a member so the pad can be tested; live servers say "soon".

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Plots = require(script.Parent.Parent.Plots)
local Billboard = require(script.Parent.Parent.Billboard)
local DataService = require(script.Parent.DataService)

type Plot = Plots.Plot

local GroupRewardService = {}

local notify: RemoteEvent

local function isMember(player: Player): boolean
	if Products.GROUP_ID == 0 then
		return RunService:IsStudio()
	end
	local ok, member = pcall(function()
		return player:IsInGroup(Products.GROUP_ID)
	end)
	return ok and member
end

-- Cash the next claim pays for this player's progress.
function GroupRewardService.amount(buyTier: number): number
	return math.max(Economy.GROUP_REWARD_MIN, Economy.basePrice(buyTier) * Economy.GROUP_REWARD_MULTIPLIER)
end

local function refresh(plot: Plot)
	local label = plot.stations.groupReward.label
	local owner = plot.owner
	local data = if owner then DataService.get(owner) else nil
	local text = "Group Reward"
	if data then
		local wait = data.groupRewardAt + Economy.GROUP_REWARD_INTERVAL - os.time()
		local status = if wait <= 0
			then Billboard.color(`{Format.short(GroupRewardService.amount(data.buyTier))} Cash`, Billboard.CASH)
			else string.format("%d:%02d", wait // 60, wait % 60)
		text = `Group Reward\n{status}`
	end
	if label.Text ~= text then
		label.Text = text
	end
end

local function claim(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	if Products.GROUP_ID == 0 and not RunService:IsStudio() then
		notify:FireClient(player, "Group reward coming soon!")
		return
	end
	if not isMember(player) then
		notify:FireClient(player, "Join the group to claim this reward!")
		return
	end
	local wait = data.groupRewardAt + Economy.GROUP_REWARD_INTERVAL - os.time()
	if wait > 0 then
		notify:FireClient(player, string.format("Next group reward in %d:%02d", wait // 60, wait % 60))
		return
	end
	local amount = GroupRewardService.amount(data.buyTier)
	data.cash += amount
	data.totalCashEarned += amount
	data.groupRewardAt = os.time()
	DataService.sync(player)
	notify:FireClient(player, `Collected {Format.short(amount)} Cash!`, "cash")
	refresh(plot)
end

function GroupRewardService:Init()
	notify = Remotes.event("Notify")
end

function GroupRewardService:Start()
	for _, plot in Plots.all() do
		Plots.onStep(plot, plot.stations.groupReward, function(player)
			claim(player, plot)
		end)
	end
	while true do
		for _, plot in Plots.all() do
			refresh(plot)
		end
		task.wait(1)
	end
end

return GroupRewardService
