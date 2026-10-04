--!strict
-- Checks config invariants at server start. A broken config should stop the
-- server loudly instead of producing a bad economy quietly.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Tiers = require(Config.Tiers)
local Economy = require(Config.Economy)
local LuckyBlocks = require(Config.LuckyBlocks)
local Products = require(Config.Products)
local Format = require(Shared.Format)

local ConfigCheck = {}

function ConfigCheck.run()
	assert(Tiers.MAX_TIER == 20, `Expected 20 tiers, got {Tiers.MAX_TIER}`)

	for i, t in Tiers.list do
		assert(t.tier == i, `Tier at index {i} says tier {t.tier}`)
		assert(t.aura > 0, `Tier {i} has no aura value`)
		if i > 1 then
			-- Merging 3 into 1 must always pay off.
			local ratio = t.aura / Tiers.list[i - 1].aura
			assert(
				ratio > Economy.MERGE_COUNT,
				`Tier {i} is only {ratio}x tier {i - 1}; must be > {Economy.MERGE_COUNT}x`
			)
		end
	end

	local lastMultiplier = math.huge
	for _, name in Products.CASH_MULTIPLIER_PASSES do
		local pass = Products.GamePasses[name]
		assert(pass and pass.multiplier, `Cash pass {name} is missing from GamePasses or has no multiplier`)
		assert(pass.multiplier < lastMultiplier, "CASH_MULTIPLIER_PASSES must go from highest to lowest multiplier")
		lastMultiplier = pass.multiplier
	end
	for name, product in Products.DevProducts do
		assert(name == "FinishNow" or product.size, `Dev product {name} needs a pack size`)
	end

	assert(Economy.MAX_SPOTS == 80, `Expected 80 spots, got {Economy.MAX_SPOTS}`)
	assert(Economy.MARKET_MIN < Economy.MARKET_MAX, "Market min must be below max")
	assert(
		Economy.DROP_TOUCH_RANGE < Economy.DROP_PICKUP_RANGE,
		"Client touch range must be inside server pickup range"
	)
	assert(Economy.STARTING_CASH >= Economy.basePrice(1), "Starting Cash must buy at least one tier 1 brainrot")
	assert(Economy.BUY_TIER_UPGRADE_GROWTH >= 1, "Upgrade cost growth must not shrink costs")
	assert(Economy.TIER_GROWTH_FROM < Economy.TIER_GROWTH_TO, "TIER_GROWTH_FROM must be below TIER_GROWTH_TO")
	local lastCost = 0
	for tier = 1, Tiers.MAX_TIER - 1 do
		local cost = Economy.buyTierUpgradeCost(tier) :: number
		assert(cost > lastCost, `Upgrade Buy Tier cost must rise every tier (tier {tier})`)
		lastCost = cost
	end
	assert(
		Economy.CASH_PACK_HOURS.S < Economy.CASH_PACK_HOURS.M and Economy.CASH_PACK_HOURS.M < Economy.CASH_PACK_HOURS.L,
		"Cash packs must grow S < M < L"
	)

	for _, block in LuckyBlocks.list do
		local total = 0
		for _, r in block.rolls do
			total += r.weight
			assert(r.tier >= 1 and r.tier <= Tiers.MAX_TIER, `{block.name} rolls invalid tier {r.tier}`)
		end
		assert(total == 100, `{block.name} odds add to {total}, not 100`)
	end

	assert(Format.short(16_260_000_000) == "16.26B", `Format.short broke: {Format.short(16_260_000_000)}`)
	assert(Format.short(7e12) == "7.00T", `Format.short broke: {Format.short(7e12)}`)
	assert(Format.short(999) == "999", `Format.short broke: {Format.short(999)}`)
	assert(Format.commas(11919393) == "11,919,393", `Format.commas broke: {Format.commas(11919393)}`)

	print(`[ConfigCheck] OK: {Tiers.MAX_TIER} tiers, {#LuckyBlocks.list} lucky blocks, {Economy.MAX_SPOTS} spots`)
end

return ConfigCheck
