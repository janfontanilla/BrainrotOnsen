--!strict
-- Lucky block types. Which type spawns is a weighted random roll (weight below;
-- user decision 2026-09-30: rarity is random, not tied to progress).
-- Contents: unlockTier - 1 .. unlockTier + 2 at 60 / 30 / 9 / 1 percent.
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
			* Economy.BUY_TIER_UPGRADE_GROWTH ^ Economy.tierGrowthSteps(def.unlockTier),
		rolls = buildRolls(def.unlockTier),
	})
end

local LuckyBlocks = {}

LuckyBlocks.list = list

-- A random block type, weighted by `weight`. `random` is injectable for tests.
function LuckyBlocks.randomBlock(random: Random?): Block
	local rng = random or Random.new()
	local total = 0
	for _, block in list do
		total += block.weight
	end
	local pick = rng:NextNumber() * total
	for _, block in list do
		pick -= block.weight
		if pick < 0 then
			return block
		end
	end
	return list[#list]
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
