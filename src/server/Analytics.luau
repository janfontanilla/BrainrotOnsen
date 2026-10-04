--!strict
-- Roblox Analytics (Creator Dashboard > Analytics): the onboarding funnel (tutorial
-- steps), the progression funnel (buy tiers) and Cash sources / sinks. Live only:
-- Studio just warns. Every call is wrapped so analytics can never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local CURRENCY = "Cash"

local function try(call: () -> ())
	if RunService:IsStudio() then
		return
	end
	local ok, err = pcall(call)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

-- Tutorial step `step` (1-based, in order) was finished.
function Analytics.onboarding(player: Player, step: number, name: string)
	try(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

-- The player reached buy tier `tier` (a one-time funnel: tier 2 = step 1).
function Analytics.buyTier(player: Player, tier: number)
	try(function()
		AnalyticsService:LogFunnelStepEvent(player, "BuyTier", nil, tier - 1, `Buy tier {tier}`)
	end)
end

-- Cash gained (`source`) or spent (`sink`). `kind` is an
-- Enum.AnalyticsEconomyTransactionType name ("Gameplay", "Shop", "IAP", "TimedReward", ...).
function Analytics.cash(
	player: Player,
	flow: "source" | "sink",
	amount: number,
	balance: number,
	kind: string,
	sku: string
)
	if amount <= 0 then
		return
	end
	try(function()
		local flowType = if flow == "source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flowType, CURRENCY, amount, balance, kind, sku)
	end)
end

return Analytics
