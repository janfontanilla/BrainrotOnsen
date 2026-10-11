--!strict
-- Buying and merging. Stepping on a pad is the intent; the server decides
-- everything else.
--   Buy 1 / 5 / 25   sell the player's buy tier, buy as many as fit in the free
--                    spots and charge only for those. They only merge when the
--                    onsen is full (see ShopService.makeRoom / mergeIfFull)
--   Buy 100          buys 100 and merges them together with what the player
--                    already owns, instantly; refused only if the result won't fit
--   Merge!           merges every triple, cascading upward, silently. The pad is
--                    lit when something can merge and grey when nothing can.
--   Upgrade Buy Tier raises the tier the buy pads sell and resets price scaling;
--                    then merges what can merge and promotes every leftover below
--                    the new buy tier to it (no popup)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Plots = require(script.Parent.Parent.Plots)
local Billboard = require(script.Parent.Parent.Billboard)
local DataService = require(script.Parent.DataService)
local PoolService = require(script.Parent.PoolService)
local TutorialService = require(script.Parent.TutorialService)
local Analytics = require(script.Parent.Parent.Analytics)

type Plot = Plots.Plot
type Data = DataService.Data

local ShopService = {}

local notify: RemoteEvent

-- Merges every triple in `counts` in place, cascading upward. Tier MAX_TIER never
-- merges. Returns how many merges happened.
function ShopService.mergeCounts(counts: { number }): number
	local merges = 0
	for tier = 1, Tiers.MAX_TIER - 1 do
		local made = counts[tier] // Economy.MERGE_COUNT
		if made > 0 then
			counts[tier] -= made * Economy.MERGE_COUNT
			counts[tier + 1] += made
			merges += made
		end
	end
	return merges
end

local MERGE_READY_COLOR = Color3.fromRGB(255, 200, 60)
local MERGE_IDLE_COLOR = Color3.fromRGB(150, 150, 160)

-- Whether any tier below MAX_TIER has enough to merge.
local function canMerge(counts: { number }): boolean
	for tier = 1, Tiers.MAX_TIER - 1 do
		if counts[tier] >= Economy.MERGE_COUNT then
			return true
		end
	end
	return false
end

-- When the onsen maxes out it merges by itself. Call before adding `needed`
-- brainrots: merges if they wouldn't all fit.
function ShopService.makeRoom(data: Data, needed: number)
	if Economy.MAX_SPOTS - DataService.brainrotCount(data) < needed then
		ShopService.mergeCounts(data.counts)
	end
end

-- Call after adding brainrots: merges if the onsen is now full.
function ShopService.mergeIfFull(data: Data)
	if DataService.brainrotCount(data) >= Economy.MAX_SPOTS then
		ShopService.mergeCounts(data.counts)
	end
end

local function total(counts: { number }): number
	local sum = 0
	for _, count in counts do
		sum += count
	end
	return sum
end

function ShopService.refreshPads(plot: Plot)
	local owner = plot.owner
	local data = if owner then DataService.get(owner) else nil
	for _, pad in plot.pads do
		if data then
			local price = Economy.bulkPrice(data.buyTier, data.boughtAtBuyTier, pad.amount)
			pad.label.Text = `Buy {pad.amount} {Tiers.get(data.buyTier).name}\n`
				.. Billboard.color(`{Format.short(price)} Cash`, Billboard.CASH)
		else
			pad.label.Text = `Buy {pad.amount}`
		end
	end

	local mergePad = plot.stations.merge
	mergePad.label.Text = Billboard.color("Merge!", Billboard.GOLD)
	mergePad.part.Color = if data and canMerge(data.counts) then MERGE_READY_COLOR else MERGE_IDLE_COLOR
	local upgradeLabel = plot.stations.upgradeBuyTier.label
	if not data then
		upgradeLabel.Text = Billboard.color("Upgrade Buy Tier", Billboard.CYAN)
		return
	end
	local cost = Economy.buyTierUpgradeCost(data.buyTier)
	if cost then
		upgradeLabel.Text = `{Billboard.color("Upgrade Buy Tier", Billboard.CYAN)}\n`
			.. `{Tiers.get(data.buyTier).name} {Billboard.color("&gt;&gt;", Billboard.CASH)} {Tiers.get(
				data.buyTier + 1
			).name}\n`
			.. Billboard.color(`{Format.short(cost)} Cash`, Billboard.CASH)
	else
		upgradeLabel.Text = `{Billboard.color("Upgrade Buy Tier", Billboard.CYAN)}\n{Tiers.get(data.buyTier).name}\n`
			.. Billboard.color("Max tier", Billboard.GOLD)
	end
end

local function afterChange(player: Player, plot: Plot, data: Data)
	local discovered = DataService.markOwned(data)
	DataService.sync(player)
	PoolService.render(plot, data)
	ShopService.refreshPads(plot)
	if #discovered > 0 then
		notify:FireClient(player, `New brainrot! {Tiers.get(discovered[#discovered]).name}`, "newBrainrot")
	end
end

local function buyAndMerge(player: Player, plot: Plot, data: Data, amount: number): boolean
	local after = table.clone(data.counts)
	after[data.buyTier] += amount
	ShopService.mergeCounts(after)
	if total(after) > Economy.MAX_SPOTS then
		notify:FireClient(player, `Not enough room, even after merging ({Economy.MAX_SPOTS} spots)`)
		return false
	end
	local cost = Economy.bulkPrice(data.buyTier, data.boughtAtBuyTier, amount)
	if not DataService.spendCash(player, cost) then
		notify:FireClient(player, `Not enough Cash (need {Format.short(cost)})`)
		return false
	end
	data.boughtAtBuyTier += amount
	data.totalBrainrots += amount
	local merged = total(after) < total(data.counts) + amount
	data.counts = after
	afterChange(player, plot, data)
	Analytics.cash(player, "sink", cost, data.cash, "Shop", "Brainrot")
	TutorialService.record(player, "buy")
	if merged then
		TutorialService.record(player, "merge")
	end
	notify:FireClient(player, `Bought {amount} {Tiers.get(data.buyTier).name}!`, "good")
	return true
end

-- Returns whether something was bought (a held buy pad keeps going while it is true).
local function buy(player: Player, plot: Plot, amount: number): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	if amount == Economy.AUTO_MERGE_BUY_AMOUNT then
		return buyAndMerge(player, plot, data, amount)
	end
	local before = table.clone(data.counts)
	ShopService.makeRoom(data, amount)
	local free = Economy.MAX_SPOTS - DataService.brainrotCount(data)
	local count = math.min(amount, free)
	if count <= 0 then
		data.counts = before
		notify:FireClient(
			player,
			`Your bathhouse is full ({Economy.MAX_SPOTS}/{Economy.MAX_SPOTS}) and nothing can merge`
		)
		return false
	end
	local cost = Economy.bulkPrice(data.buyTier, data.boughtAtBuyTier, count)
	if not DataService.spendCash(player, cost) then
		data.counts = before
		notify:FireClient(player, `Not enough Cash (need {Format.short(cost)})`)
		return false
	end
	data.boughtAtBuyTier += count
	data.counts[data.buyTier] += count
	data.totalBrainrots += count
	ShopService.mergeIfFull(data)
	afterChange(player, plot, data)
	Analytics.cash(player, "sink", cost, data.cash, "Shop", "Brainrot")
	TutorialService.record(player, "buy")
	if count < amount then
		notify:FireClient(player, `Only room for {count}: bought {count}`)
		return false -- full now: stop repeating
	end
	return true
end

local function merge(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	if ShopService.mergeCounts(data.counts) > 0 then
		afterChange(player, plot, data)
		TutorialService.record(player, "merge")
	end
end

local function upgradeBuyTier(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.buyTierUpgradeCost(data.buyTier)
	if not cost then
		notify:FireClient(player, "Already at the highest buy tier")
		return
	end
	if not DataService.spendCash(player, cost) then
		notify:FireClient(player, `Not enough Cash (need {Format.short(cost)})`)
		return
	end
	data.buyTier += 1
	data.boughtAtBuyTier = 0
	-- Leftovers below the new buy tier can never be completed (the pads don't sell
	-- them any more): merge what can merge, then promote the rest to the buy tier,
	-- silently (2026-10-11, user).
	ShopService.mergeCounts(data.counts)
	for tier = 1, data.buyTier - 1 do
		data.counts[data.buyTier] += data.counts[tier]
		data.counts[tier] = 0
	end
	ShopService.mergeIfFull(data)
	DataService.markOwned(data)
	DataService.sync(player)
	PoolService.render(plot, data)
	ShopService.refreshPads(plot)
	Analytics.cash(player, "sink", cost, data.cash, "Gameplay", "UpgradeBuyTier")
	Analytics.buyTier(player, data.buyTier)
	TutorialService.record(player, "upgradeBuyTier")
	notify:FireClient(player, `Buy pads now sell {Tiers.get(data.buyTier).name}!`, "good")
end

function ShopService:Init()
	notify = Remotes.event("Notify")
end

function ShopService:Start()
	for _, plot in Plots.all() do
		for _, pad in plot.pads do
			Plots.onStep(plot, pad, function(player)
				return buy(player, plot, pad.amount)
			end, Economy.BUY_REPEAT_INTERVAL, Economy.BUY_REPEAT_DELAY)
		end
		Plots.onStep(plot, plot.stations.merge, function(player)
			merge(player, plot)
		end)
		Plots.onStep(plot, plot.stations.upgradeBuyTier, function(player)
			upgradeBuyTier(player, plot)
		end)
		ShopService.refreshPads(plot)
	end
end

return ShopService
