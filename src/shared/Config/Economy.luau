--!strict
-- Every tunable balance number lives here. Services read from this module;
-- never hard-code a balance number anywhere else.

local Tiers = require(script.Parent.Tiers)

local Economy = {}

-- Plots
Economy.PLAYERS_PER_SERVER = 6
Economy.ROWS = 8 -- rows of baths, front to back
Economy.LANES = Economy.ROWS * 2 -- one bath on each side of the center channel per row
Economy.SPOTS_PER_LANE = 5
Economy.MAX_SPOTS = Economy.LANES * Economy.SPOTS_PER_LANE -- 80

-- Drops
Economy.DROP_INTERVAL = 7 -- seconds between drops
Economy.DROP_CAP = 50 -- uncollected drops per plot before production stops
Economy.DROP_PICKUP_RANGE = 12 -- studs; server-side distance check (lenient for latency)
Economy.DROP_TOUCH_RANGE = 4 -- studs, horizontal; how close the client must walk before it asks to collect
Economy.DROP_FLOW_SECONDS = 10 -- time a drop takes to float from its brainrot to its resting point in the pool
-- Studio-only override for DROP_INTERVAL so the drop cap can be tested quickly. 0 = off.
-- Ignored in live servers.
Economy.STUDIO_DROP_INTERVAL = 0

-- New players start with this much Cash to buy their first brainrots.
-- (Until saving exists in Phase 3, every join is a new player.)
Economy.STARTING_CASH = 1_000
-- Studio-only: a brand-new profile in Studio starts with this much Cash instead,
-- for testing. 0 = off. Ignored in live servers.
Economy.STUDIO_STARTING_CASH = 500_000

-- Buying
Economy.BUY_AMOUNTS = { 1, 5, 25, 100 }
Economy.AUTO_MERGE_BUY_AMOUNT = 100 -- only this buy size auto-merges
Economy.BASE_PRICE_MULTIPLIER = 20 -- base price = aura per drop x this
Economy.PRICE_GROWTH = 1.005 -- unit price x this per brainrot bought at the current buy tier
Economy.BUY_TIER_UPGRADE_MULTIPLIER = 2_500 -- upgrade cost = next tier's base price x this

-- Merging
Economy.MERGE_COUNT = 3

-- Market (server-wide)
Economy.MARKET_MIN = 0.5
Economy.MARKET_MAX = 1.5
Economy.MARKET_INTERVAL = 30 -- seconds between rerolls
Economy.MARKET_HISTORY = 20 -- rolls shown on the board graph

-- Processor
Economy.PROCESSOR_BASE_RATE = 10 -- Aura per second at level 1
Economy.PROCESSOR_RATE_GROWTH = 1.35
Economy.PROCESSOR_UPGRADE_BASE_COST = 100
Economy.PROCESSOR_COST_GROWTH = 1.45

-- Boosts
Economy.FRIEND_BOOST_PER_FRIEND = 0.10 -- applies to processor Cash output
Economy.FRIEND_BOOST_MAX = 0.50
Economy.PREMIUM_AURA_BOOST = 0.10 -- applies to Aura from drops

-- Lucky blocks
Economy.LUCKY_BLOCK_SPAWN_INTERVAL = 180 -- seconds of production per block
Economy.LUCKY_BLOCK_PRICE_MULTIPLIER = 800 -- price = unlock tier's aura x this
Economy.LUCKY_BLOCK_PICKUP_RANGE = 5 -- studs, horizontal; walking this close picks the block up
-- Studio-only override for LUCKY_BLOCK_SPAWN_INTERVAL so blocks can be tested quickly. 0 = off.
Economy.STUDIO_LUCKY_BLOCK_INTERVAL = 0

-- Cash packs (dev products): amount = base price of highest tier x multiplier
Economy.CASH_PACK_MULTIPLIERS = { S = 50, M = 2_500, L = 125_000 }

-- Offline
Economy.OFFLINE_RATE = 1.0 -- 100%, no time cap, straight into Aura
Economy.OFFLINE_POPUP_MIN_SECONDS = 60 -- show "While you were away" only after this long offline

function Economy.basePrice(tier: number): number
	return Tiers.get(tier).aura * Economy.BASE_PRICE_MULTIPLIER
end

-- Unit price after `boughtAtBuyTier` brainrots were already bought at this buy tier.
function Economy.unitPrice(buyTier: number, boughtAtBuyTier: number): number
	return Economy.basePrice(buyTier) * Economy.PRICE_GROWTH ^ boughtAtBuyTier
end

-- Bulk costs exactly n x the current unit price (no bulk discount).
function Economy.bulkPrice(buyTier: number, boughtAtBuyTier: number, amount: number): number
	return Economy.unitPrice(buyTier, boughtAtBuyTier) * amount
end

function Economy.buyTierUpgradeCost(currentBuyTier: number): number?
	if currentBuyTier >= Tiers.MAX_TIER then
		return nil
	end
	return Economy.basePrice(currentBuyTier + 1) * Economy.BUY_TIER_UPGRADE_MULTIPLIER
end

function Economy.processorRate(level: number): number
	return Economy.PROCESSOR_BASE_RATE * Economy.PROCESSOR_RATE_GROWTH ^ (level - 1)
end

function Economy.processorUpgradeCost(level: number): number
	return Economy.PROCESSOR_UPGRADE_BASE_COST * Economy.PROCESSOR_COST_GROWTH ^ (level - 1)
end

function Economy.friendBoost(friendsInServer: number): number
	return math.min(friendsInServer * Economy.FRIEND_BOOST_PER_FRIEND, Economy.FRIEND_BOOST_MAX)
end

function Economy.cashPackAmount(highestTier: number, size: "S" | "M" | "L"): number
	return Economy.basePrice(highestTier) * Economy.CASH_PACK_MULTIPLIERS[size]
end

return Economy
