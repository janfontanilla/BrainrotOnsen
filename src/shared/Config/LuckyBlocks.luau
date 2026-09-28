--!strict
-- Lucky block types. The block a player gets is the best one whose unlockTier
-- is <= the highest tier they have ever owned.
-- Contents: unlockTier - 1 .. unlockTier + 2 at 60 / 30 / 9 / 1 percent.
-- Near the top of the ladder, weight past MAX_TIER folds into the last valid tier
-- (so Cosmic rolls 18 / 19 / 20 at 60 / 30 / 10).

local Tiers = require(script.Parent.Tiers)
local Economy = require(script.Parent.Economy)

export type Roll = { tier: number, weight: number }

export type Block = {
	name: string,
	unlockTier: number,
	price: number,
	rolls: { Roll },
}

local BLOCKS: { { name: string, unlockTier: number } } = {
	{ name = "Wood", unlockTier = 3 },
	{ name = "Stone", unlockTier = 5 },
	{ name = "Iron", unlockTier = 7 },
	{ name = "Gold", unlockTier = 9 },
	{ name = "Diamond", unlockTier = 11 },
	{ name = "Emerald", unlockTier = 13 },
	{ name = "Ruby", unlockTier = 15 },
	{ name = "Rainbow", unlockTier = 17 },
	{ name = "Cosmic", unlockTier = 19 },
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
		price = Tiers.get(def.unlockTier).aura * Economy.LUCKY_BLOCK_PRICE_MULTIPLIER,
		rolls = buildRolls(def.unlockTier),
	})
end

local LuckyBlocks = {}

LuckyBlocks.list = list

-- Best block for a player whose highest tier ever owned is `highestTier`, or nil if none unlocked yet.
function LuckyBlocks.forHighestTier(highestTier: number): Block?
	local best: Block? = nil
	for _, block in list do
		if block.unlockTier <= highestTier then
			best = block
		end
	end
	return best
end

-- Pick a tier from a block. `random` is injectable for tests.
function LuckyBlocks.roll(block: Block, random: Random?): number
	local rng = random or Random.new()
	local total = 0
	for _, r in block.rolls do
		total += r.weight
	end
	local pick = rng:NextNumber() * total
	for _, r in block.rolls do
		pick -= r.weight
		if pick < 0 then
			return r.tier
		end
	end
	return block.rolls[#block.rolls].tier
end

return LuckyBlocks
