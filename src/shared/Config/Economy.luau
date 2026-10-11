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
Economy.STUDIO_STARTING_CASH = 0 -- user test 2026-10-04: real new-player start (1,000); was 500_000
-- Studio-only: appended to the profile key, so a new suffix plays as a brand-new player
-- without touching the real save. "" = the real profile.
Economy.STUDIO_PROFILE_SUFFIX = "_fresh6" -- user test 2026-10-04: a fresh profile; "" = the real save
-- Studio-only: a brand-new profile gets this many of every tier (model checks). 0 = off.
Economy.STUDIO_GIVE_EACH_TIER = 0
-- Studio-only: restart the new-player tutorial on every join (TutorialService). false = off.
Economy.STUDIO_FORCE_TUTORIAL = false

-- Buying
Economy.BUY_AMOUNTS = { 1, 5, 25, 100 }
Economy.AUTO_MERGE_BUY_AMOUNT = 100 -- only this buy size auto-merges
Economy.BASE_PRICE_MULTIPLIER = 20 -- base price = aura per drop x this
-- Standing on a buy pad keeps buying (2026-10-10, user): first repeat after this, then
-- one buy every BUY_REPEAT_INTERVAL seconds until the player steps off or can't buy.
Economy.BUY_REPEAT_DELAY = 0.6
Economy.BUY_REPEAT_INTERVAL = 0.35
Economy.PRICE_GROWTH = 1.08 -- unit price x this per brainrot bought at the current buy tier (2026-10-04: 1.005 -> 1.08, keeps the best brainrot ~3 tiers ahead of the pads)
-- Upgrade Buy Tier cost = next tier's base price x MULTIPLIER x GROWTH ^ tierGrowthSteps(buy tier).
-- An expanding curve (2026-10-04, tools/economy_sim.py): fast at the start, each step
-- ~2-3x longer from buy tier 4 to 15, then about the same length per step. Simulated:
-- first upgrade 3-9 min, free player buy tier 12 ~day 3 and a tier 20 ~day 48, x7 Cash
-- player a tier 20 ~day 8 (2 h play a day, offline the rest).
Economy.BUY_TIER_UPGRADE_MULTIPLIER = 15 -- (2026-10-04: 500 -> 15; the growth below does the rest)
Economy.BUY_TIER_UPGRADE_GROWTH = 2.9
Economy.TIER_GROWTH_FROM = 4 -- the growth starts after this buy tier...
Economy.TIER_GROWTH_TO = 15 -- ...and stops at this one

-- Merging
Economy.MERGE_COUNT = 3

-- Market (server-wide)
Economy.MARKET_MIN = 0.5
Economy.MARKET_MAX = 1.5
Economy.MARKET_INTERVAL = 30 -- seconds between rerolls
Economy.MARKET_HISTORY = 20 -- rolls shown on the board graph
-- A message to everyone when the market rolls above / below these (2026-10-09, user).
Economy.MARKET_ALERT_HIGH = 1.4
Economy.MARKET_ALERT_LOW = 0.6

-- Processor
Economy.PROCESSOR_BASE_RATE = 20 -- Aura per second at level 1 (2026-09-30: 10 -> 20)
Economy.PROCESSOR_RATE_GROWTH = 1.35
Economy.PROCESSOR_UPGRADE_BASE_COST = 100
Economy.PROCESSOR_COST_GROWTH = 1.45

-- Boosts
Economy.FRIEND_BOOST_PER_FRIEND = 0.10 -- applies to processor Cash output
Economy.FRIEND_BOOST_MAX = 0.50
Economy.PREMIUM_AURA_BOOST = 0.10 -- applies to Aura from drops
-- Studio-only: a game pass / dev product whose ID is still 0 is granted directly when its
-- Robux pad or button is used (session only, no receipt), so purchases can be tested for free.
Economy.STUDIO_SIMULATE_PURCHASES = true
-- Studio-only: treat the account's owned game passes as not owned (play as a free player). false = off.
Economy.STUDIO_IGNORE_OWNED_PASSES = false -- 2026-10-09 off: hiding owned passes made pass purchases look broken (Roblox answers "already owned")
-- Studio-only: act as if this player's country forbids paid random items (hides the
-- Robux chest unlock). false = off.
Economy.STUDIO_PAID_RANDOM_RESTRICTED = false

-- Lucky blocks
-- A block spawns after a random stretch of production between these (seconds), then
-- the next drop from a brainrot is the block. Several can wait in the pool at once.
Economy.LUCKY_BLOCK_SPAWN_MIN = 40
Economy.LUCKY_BLOCK_SPAWN_MAX = 100
Economy.LUCKY_BLOCK_MAX_WAITING = 5 -- blocks floating / in the pool before spawning pauses
-- price = aura of the tier the chest really gives (its unlock tier, or the buy tier + 1
-- when chests are raised to the buy tier) x MULTIPLIER x the Upgrade Buy Tier growth
-- (LuckyBlocks.priceFor). 2026-10-04: 800 -> 100 -> 10 with chests following progress;
-- simulated: a fun gamble that never speeds up reaching tier 20.
Economy.LUCKY_BLOCK_PRICE_MULTIPLIER = 10
Economy.LUCKY_BLOCK_PICKUP_RANGE = 5 -- studs, horizontal; walking this close picks the block up
-- Studio-only fixed spawn interval (seconds) so blocks can be tested quickly. 0 = off.
Economy.STUDIO_LUCKY_BLOCK_INTERVAL = 0

-- Cash packs (dev products): amount = a share of the player's next Upgrade Buy Tier
-- cost (at tier 20, of the last upgrade's), at least CASH_PACK_MIN. Grows only with the
-- buy tier, not with the brainrots owned (2026-10-09, user; was 1 / 6 / 24 hours of
-- brainrot income). Better value per Robux the bigger the pack (29 / 149 / 499 Robux).
Economy.CASH_PACK_SHARE = { S = 0.1, M = 0.5, L = 1.5 }
Economy.CASH_PACK_MIN = { S = 1_000, M = 5_000, L = 15_000 }

-- Group reward (the pad in front of the "Join the group + Like" sign): members can
-- claim Cash every GROUP_REWARD_INTERVAL seconds. A helper, not income: the amount
-- starts at GROUP_REWARD_MIN and grows with the buy tier (base price x multiplier).
Economy.GROUP_REWARD_INTERVAL = 600 -- (2026-10-04: 300 -> 600, user request)
Economy.GROUP_REWARD_MIN = 10_000
Economy.GROUP_REWARD_MULTIPLIER = 25

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

-- How many times BUY_TIER_UPGRADE_GROWTH applies at `tier` (0 up to TIER_GROWTH_FROM,
-- then +1 per tier, capped at TIER_GROWTH_TO).
function Economy.tierGrowthSteps(tier: number): number
	return math.max(0, math.min(tier, Economy.TIER_GROWTH_TO) - Economy.TIER_GROWTH_FROM)
end

function Economy.buyTierUpgradeCost(currentBuyTier: number): number?
	if currentBuyTier >= Tiers.MAX_TIER then
		return nil
	end
	return Economy.basePrice(currentBuyTier + 1)
		* Economy.BUY_TIER_UPGRADE_MULTIPLIER
		* Economy.BUY_TIER_UPGRADE_GROWTH ^ Economy.tierGrowthSteps(currentBuyTier)
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

-- `auraPerSecond` = what the player's brainrots make (DataService.auraPerSecond).
function Economy.cashPackAmount(buyTier: number, size: "S" | "M" | "L"): number
	local upgrade = Economy.buyTierUpgradeCost(math.min(buyTier, Tiers.MAX_TIER - 1)) or 0
	return math.floor(math.max(upgrade * Economy.CASH_PACK_SHARE[size], Economy.CASH_PACK_MIN[size]))
end

return Economy
