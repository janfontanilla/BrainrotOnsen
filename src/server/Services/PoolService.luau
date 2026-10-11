--!strict
-- The brainrot spots of each plot (Economy.MAX_SPOTS). Brainrots are stored as counts per tier;
-- this service lays them out as placeholder blocks (highest tier at the front)
-- and remembers which tier sits in which spot so drops can float next to them.
-- Rendering only rebuilds spots whose tier changed. Only brainrots that are really new
-- (a tier's count went up) get a SpawnedAt attribute, so clients play the rise-out-
-- of-the-bath animation for them; lower tiers that just move back a spot when higher
-- ones arrive appear in place (2026-10-11, user: buying Frigo Camelo made the shifted
-- Tim Cheese rise, so it looked like Tim Cheese was bought).
-- Merging and Buy 100 live in ShopService; this only lays out the result.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local Models = require(Shared.Models)
local Visuals = require(Shared.Visuals)
local Plots = require(script.Parent.Parent.Plots)
local Billboard = require(script.Parent.Parent.Billboard)
local DataService = require(script.Parent.DataService)

type Plot = Plots.Plot
type Data = DataService.Data

local SIT_HEIGHT = 0.8 -- studs above the water surface the models stand (pack models reach a bit below their pivot)

local PoolService = {}

-- plot index -> tier in each used spot, in spot order
local spotTiers: { [number]: { number } } = {}
-- plot index -> spot index -> the brainrot model
local spotParts: { [number]: { [number]: Model } } = {}
-- plot index -> spot index -> os.clock() when that spot's brainrot was placed
local spotSince: { [number]: { [number]: number } } = {}

local function makeBrainrot(parent: Instance, spot: CFrame, tier: number, rise: boolean): Model
	local def = Tiers.get(tier)
	local model = Models.makeBrainrot(tier)
	-- Sit up on the bath's water, above the rims (the model's origin is its bottom centre).
	model:PivotTo(spot * CFrame.new(0, SIT_HEIGHT, 0))
	model:SetAttribute("Tier", tier)
	if rise then
		model:SetAttribute("SpawnedAt", workspace:GetServerTimeNow())
	end

	local anchor = model:FindFirstChild("Label")
	if anchor and anchor:IsA("BasePart") then
		local label = Billboard.new(anchor, { width = 9, height = 2.8, offsetY = 0, maxDistance = 90 })
		label.Text = `{Billboard.color(def.name, "#" .. Visuals.tierColor(tier):ToHex())}\nTier {tier}`
	end

	model.Parent = parent
	return model
end

function PoolService.render(plot: Plot, data: Data)
	local tiers: { number } = {}
	for tier = #data.counts, 1, -1 do
		for _ = 1, data.counts[tier] do
			table.insert(tiers, tier)
		end
	end
	assert(#tiers <= #plot.spots, `Plot {plot.index} holds {#tiers} brainrots but has {#plot.spots} spots`)
	local old = spotTiers[plot.index] or {}
	local parts = spotParts[plot.index] or {}
	local since = spotSince[plot.index] or {}
	local now = os.clock()
	-- How many of each tier are new since the last render: only those rise.
	local fresh: { [number]: number } = {}
	for _, tier in tiers do
		fresh[tier] = (fresh[tier] or 0) + 1
	end
	for _, tier in old do
		fresh[tier] = (fresh[tier] or 0) - 1
	end
	for i = 1, math.max(#tiers, #old) do
		if tiers[i] ~= old[i] then
			local existing = parts[i]
			if existing then
				existing:Destroy()
				parts[i] = nil
			end
			since[i] = nil
			if tiers[i] then
				local tier = tiers[i]
				local rise = (fresh[tier] or 0) > 0
				if rise then
					fresh[tier] -= 1
				end
				parts[i] = makeBrainrot(plot.brainrotFolder, plot.spots[i], tier, rise)
				since[i] = now
			end
		end
	end
	spotTiers[plot.index] = tiers
	spotParts[plot.index] = parts
	spotSince[plot.index] = since
end

function PoolService.clear(plot: Plot)
	plot.brainrotFolder:ClearAllChildren()
	spotTiers[plot.index] = nil
	spotParts[plot.index] = nil
	spotSince[plot.index] = nil
end

-- Tier in each occupied spot (in spot order) and os.clock() when each spot's
-- brainrot was placed. Read-only views; do not modify.
function PoolService.spots(plot: Plot): ({ number }, { [number]: number })
	return spotTiers[plot.index] or {}, spotSince[plot.index] or {}
end

return PoolService
