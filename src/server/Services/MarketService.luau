--!strict
-- The server-wide market multiplier. Rerolled every Economy.MARKET_INTERVAL
-- seconds, uniformly from Economy.MARKET_MIN to Economy.MARKET_MAX in 0.01 steps.
-- Replicated to clients as attributes on ReplicatedStorage.Market:
--   Multiplier  current value
--   NextRollAt  server time of the next reroll (workspace:GetServerTimeNow())
--   History     last Economy.MARKET_HISTORY values, oldest first, comma-separated
-- Above Economy.MARKET_ALERT_HIGH / below MARKET_ALERT_LOW everyone gets a Notify.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local MarketService = {}

local folder: Folder
local random = Random.new()
local current = 1
local history: { number } = {}

local function roll()
	current = random:NextInteger(math.round(Economy.MARKET_MIN * 100), math.round(Economy.MARKET_MAX * 100)) / 100
	table.insert(history, current)
	while #history > Economy.MARKET_HISTORY do
		table.remove(history, 1)
	end
	local parts: { string } = {}
	for i, value in history do
		parts[i] = string.format("%.2f", value)
	end
	folder:SetAttribute("Multiplier", current)
	folder:SetAttribute("History", table.concat(parts, ","))
	folder:SetAttribute("NextRollAt", workspace:GetServerTimeNow() + Economy.MARKET_INTERVAL)
	-- Tell everyone when the market is unusually good or bad.
	local shown = string.format("%.2f", current)
	if current > Economy.MARKET_ALERT_HIGH then
		Remotes.event("Notify"):FireAllClients(`Aura Market is high: x{shown}`, "good")
	elseif current < Economy.MARKET_ALERT_LOW then
		Remotes.event("Notify"):FireAllClients(`Aura Market is low: x{shown}`, "warn")
	end
end

function MarketService.multiplier(): number
	return current
end

function MarketService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Market"
	folder.Parent = ReplicatedStorage
	roll()
end

function MarketService:Start()
	while true do
		task.wait(Economy.MARKET_INTERVAL)
		roll()
	end
end

return MarketService
