--!strict
-- Lucky block types. Contents: unlockTier - 1 .. unlockTier + 2 at 60 / 30 / 9 / 1 percent.
-- Chests follow the player's progress (user decision 2026-10-04, replaces "random,
-- not tied to progress"):
--   * a type only spawns when it can still give the buy tier or more
--     (unlockTier + 2 >= buy tier) and the player already owns its lowest tier
--     (unlockTier - 1 <= highest tier); among those, the weights below apply;
--   * a result below the buy tier is raised to the buy tier (rollsFor), so a
--     chest never gives less than what the pads sell. At buy tier 13 an Emerald
--     chest gives 13 / 14 / 15 at 90 / 9 / 1 percent.
-- Near the top of the ladder, weight past MAX_TIER folds into the last valid tier
-- (so Cosmic rolls 18 / 19 / 20 at 60 / 30 / 10).

local Tiers = require(script.Parent.Tiers)
local Economy = require(script.Parent.Economy)

export type Roll = { tier: number, weight: number }

export type Block = {
	name: string,
	unlockTier: number,
	weight: number, -- chance of spawning, relative to the other types
	price: number,
	rolls: { Roll },
}

local BLOCKS: { { name: string, unlockTier: number, weight: number } } = {
	{ name = "Wood", unlockTier = 3, weight = 30 },
	{ name = "Stone", unlockTier = 5, weight = 22 },
	{ name = "Iron", unlockTier = 7, weight = 16 },
	{ name = "Gold", unlockTier = 9, weight = 11 },
	{ name = "Diamond", unlockTier = 11, weight = 8 },
	{ name = "Emerald", unlockTier = 13, weight = 6 },
	{ name = "Ruby", unlockTier = 15, weight = 4 },
	{ name = "Rainbow", unlockTier = 17, weight = 2 },
	{ name = "Cosmic", unlockTier = 19, weight = 1 },
}

-- Offset from unlockTier -> percent weight
local ODDS: { { offset: number, weight: number } } = {
	{ offset = -1, weight = 60 },
	{ offset = 0, weight = 30 },
	{ offset = 1, weight = 9 },
	{ offset = 2, weight = 1 },
}

local function buildRolls(unlockTier: number): { Roll }
	local rolls: { Roll } = {}
	for _, odd in ODDS do
		local tier = math.min(unlockTier + odd.offset, Tiers.MAX_TIER)
		local last = rolls[#rolls]
		if last and last.tier == tier then
			last.weight += odd.weight
		else
			table.insert(rolls, { tier = tier, weight = odd.weight })
		end
	end
	return rolls
end

local list: { Block } = {}
for _, def in BLOCKS do
	table.insert(list, {
		name = def.name,
		unlockTier = def.unlockTier,
		weight = def.weight,
		price = Tiers.get(def.unlockTier).aura
			* Economy.LUCKY_BLOCK_PRICE_MULTIPLIER
			* Economy.BUY_TIER_UPGRADE_GROWTH ^ Economy.tierGrowthSteps(def.unlockTier), -- base; players pay priceFor
		rolls = buildRolls(def.unlockTier),
	})
end

local LuckyBlocks = {}

LuckyBlocks.list = list

-- Whether this type may spawn for a player at `buyTier` whose best is `highestTier`.
function LuckyBlocks.allowed(block: Block, buyTier: number, highestTier: number): boolean
	return block.unlockTier + 2 >= buyTier and block.unlockTier - 1 <= highestTier
end

-- A random block type among the allowed ones, weighted by `weight`; nil when none
-- is allowed yet (before the first tier 2). `random` is injectable for tests.
function LuckyBlocks.randomBlock(buyTier: number, highestTier: number, random: Random?): Block?
	local rng = random or Random.new()
	local total = 0
	for _, block in list do
		if LuckyBlocks.allowed(block, buyTier, highestTier) then
			total += block.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local pick = rng:NextNumber() * total
	local last: Block? = nil
	for _, block in list do
		if LuckyBlocks.allowed(block, buyTier, highestTier) then
			last = block
			pick -= block.weight
			if pick < 0 then
				return block
			end
		end
	end
	return last
end

-- The block's odds for a player at `buyTier`: results below the buy tier are
-- raised to it (their weight folds into the buy tier). The odds panel shows these.
function LuckyBlocks.rollsFor(block: Block, buyTier: number): { Roll }
	local rolls: { Roll } = {}
	for _, r in block.rolls do
		local tier = math.max(r.tier, math.min(buyTier, Tiers.MAX_TIER))
		local last = rolls[#rolls]
		if last and last.tier == tier then
			last.weight += r.weight
		else
			table.insert(rolls, { tier = tier, weight = r.weight })
		end
	end
	return rolls
end

-- What the block costs a player at `buyTier`: priced as the tier it really gives (its
-- lowest result raised to the buy tier), on the Upgrade Buy Tier growth curve. An old,
-- cheap type raised to the buy tier is priced as a chest that starts at the buy tier,
-- so it is never a cheap source of top brainrots.
function LuckyBlocks.priceFor(block: Block, buyTier: number): number
	local tier = math.clamp(math.max(block.unlockTier, buyTier + 1), 1, Tiers.MAX_TIER)
	return Tiers.get(tier).aura
		* Economy.LUCKY_BLOCK_PRICE_MULTIPLIER
		* Economy.BUY_TIER_UPGRADE_GROWTH ^ Economy.tierGrowthSteps(tier)
end

-- Pick a tier from a block for a player at `buyTier`. `random` is injectable for tests.
function LuckyBlocks.roll(block: Block, buyTier: number, random: Random?): number
	local rng = random or Random.new()
	local rolls = LuckyBlocks.rollsFor(block, buyTier)
	local total = 0
	for _, r in rolls do
		total += r.weight
	end
	local pick = rng:NextNumber() * total
	for _, r in rolls do
		pick -= r.weight
		if pick < 0 then
			return r.tier
		end
	end
	return rolls[#rolls].tier
end

return LuckyBlocks
