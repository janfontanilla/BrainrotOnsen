--!strict
-- Checks config invariants at server start. A broken config should stop the
-- server loudly instead of producing a bad economy quietly.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Tiers = require(Config.Tiers)
local Economy = require(Config.Economy)
local LuckyBlocks = require(Config.LuckyBlocks)
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

	assert(Economy.MAX_SPOTS == 48, `Expected 48 spots, got {Economy.MAX_SPOTS}`)
	assert(Economy.MARKET_MIN < Economy.MARKET_MAX, "Market min must be below max")

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
