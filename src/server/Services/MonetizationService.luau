--!strict
-- Game passes, dev products and boosts.
--
-- Passes (Config/Products): 2x Aura, Auto Collect, and Cash x2 / x4 / x7 / x12 (only
-- the highest Cash pass applies). Ownership is read from Roblox at join and
-- updated when a purchase finishes. Dev products (Finish Now, Cash packs) go
-- through ProcessReceipt with a receipt log in the profile, so a purchase is
-- never granted twice or lost.
--
-- Boosts multiply each other: Aura = (2x pass) x (1 + Premium 10%); processor
-- Cash = (highest Cash pass) x (1 + friend boost). Friend boost is 10% per friend
-- in the server, max 50%.
--
-- The Robux pads (next to the station each one boosts) and the HUD Cash pack
-- buttons only send intents; this service prompts the purchase. Product IDs are
-- 0 until created on the Creator Dashboard. In Studio, with
-- Economy.STUDIO_SIMULATE_PURCHASES on, an ID of 0 grants the purchase directly
-- (session only, no receipt) so the flow can be tested for free.
--
-- Replicated to the client as player attributes: CashPass, FriendBoost, Premium,
-- AuraMultiplier, AutoCollect.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Plots = require(script.Parent.Parent.Plots)
local Billboard = require(script.Parent.Parent.Billboard)
local DataService = require(script.Parent.DataService)

type Plot = Plots.Plot

local MonetizationService = {}

local BUY_PRODUCT_COOLDOWN = 1 -- seconds between BuyProduct intents per player
local CASH_PASS_ORDER = { "Cash2x", "Cash4x", "Cash7x", "Cash12x" } -- ascending
local PRODUCT_INTENTS: { [string]: boolean } =
	{ FinishNow = true, CashPackS = true, CashPackM = true, CashPackL = true }

local notify: RemoteEvent
local owned: { [Player]: { [string]: boolean } } = {}
local friendPairs: { [Player]: { [Player]: boolean } } = {}
local lastBuy: { [Player]: number } = {}
local finishNowHandler: ((Player) -> ())? = nil

-- ProcessorService registers what Finish Now does (avoids a require cycle).
function MonetizationService.setFinishNowHandler(handler: (Player) -> ())
	finishNowHandler = handler
end

local function hasPass(player: Player, name: string): boolean
	local set = owned[player]
	return set ~= nil and set[name] == true
end

local function simulating(): boolean
	return RunService:IsStudio() and Economy.STUDIO_SIMULATE_PURCHASES
end

function MonetizationService.hasAutoCollect(player: Player?): boolean
	return player ~= nil and hasPass(player, "AutoCollect")
end

-- The highest owned Cash pass multiplier, or 1.
function MonetizationService.cashPassMultiplier(player: Player): number
	local best = 1
	for _, name in Products.CASH_MULTIPLIER_PASSES do
		if hasPass(player, name) then
			best = math.max(best, Products.GamePasses[name].multiplier or 1)
		end
	end
	return best
end

function MonetizationService.friendCount(player: Player): number
	local count = 0
	for other in friendPairs[player] or {} do
		if other.Parent == Players then
			count += 1
		end
	end
	return count
end

function MonetizationService.isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Multiplier on the Aura from drops.
function MonetizationService.auraMultiplier(player: Player): number
	local multiplier = if hasPass(player, "DoubleAura") then 2 else 1
	if MonetizationService.isPremium(player) then
		multiplier *= 1 + Economy.PREMIUM_AURA_BOOST
	end
	return multiplier
end

-- Multiplier on the processor's Cash output.
function MonetizationService.cashMultiplier(player: Player): number
	local friends = Economy.friendBoost(MonetizationService.friendCount(player))
	return MonetizationService.cashPassMultiplier(player) * (1 + friends)
end

local function nextCashPass(player: Player): string?
	local current = MonetizationService.cashPassMultiplier(player)
	for _, name in CASH_PASS_ORDER do
		if (Products.GamePasses[name].multiplier or 1) > current then
			return name
		end
	end
	return nil
end

function MonetizationService.refreshPads(plot: Plot)
	local stations = plot.stations
	local owner = plot.owner
	local function set(pad: Plots.Pad, title: string, price: number, isOwned: boolean)
		pad.label.Text = if isOwned
			then `{title}\n{Billboard.color("Owned", Billboard.CASH)}`
			else `{title}\n` .. Billboard.color(`R$ {price}`, Billboard.ROBUX)
	end
	local auto = Products.GamePasses.AutoCollect
	local aura = Products.GamePasses.DoubleAura
	set(stations.finishNow, "Finish Now", Products.DevProducts.FinishNow.robux, false)
	set(stations.autoCollect, "Auto Collect", auto.robux, owner ~= nil and hasPass(owner, "AutoCollect"))
	set(stations.doubleAura, "2x Aura", aura.robux, owner ~= nil and hasPass(owner, "DoubleAura"))
	local nextPass = if owner then nextCashPass(owner) else "Cash2x"
	if nextPass then
		local pass = Products.GamePasses[nextPass]
		set(stations.cashPass, `x{pass.multiplier or 1} Cash`, pass.robux, false)
	else
		set(stations.cashPass, "x12 Cash", 0, true)
	end
end

function MonetizationService.refresh(player: Player)
	if player.Parent ~= Players then
		return
	end
	player:SetAttribute("CashPass", MonetizationService.cashPassMultiplier(player))
	player:SetAttribute("FriendBoost", Economy.friendBoost(MonetizationService.friendCount(player)))
	player:SetAttribute("Premium", MonetizationService.isPremium(player))
	player:SetAttribute("AuraMultiplier", MonetizationService.auraMultiplier(player))
	player:SetAttribute("AutoCollect", MonetizationService.hasAutoCollect(player))
	local plot = Plots.get(player)
	if plot then
		MonetizationService.refreshPads(plot)
	end
end

local function grantPass(player: Player, name: string)
	local set = owned[player]
	if not set then
		set = {}
		owned[player] = set
	end
	set[name] = true
	MonetizationService.refresh(player)
end

-- What a dev product does. Returns whether it was granted.
local function grantProduct(player: Player, name: string): boolean
	local product = Products.DevProducts[name]
	if not product then
		return false
	end
	if name == "FinishNow" then
		if not finishNowHandler then
			return false
		end
		finishNowHandler(player)
		notify:FireClient(player, "Processor finished!", "good")
		return true
	end
	local data = DataService.get(player)
	local size = product.size
	if not data or not size then
		return false
	end
	local amount = Economy.cashPackAmount(math.max(1, data.highestTier), size)
	data.cash += amount
	data.totalCashEarned += amount
	DataService.sync(player)
	notify:FireClient(player, `Received {Format.short(amount)} Cash!`, "cash")
	return true
end

local function promptPass(player: Player, name: string)
	local pass = Products.GamePasses[name]
	if not pass then
		return
	end
	if hasPass(player, name) then
		notify:FireClient(player, "You already own this!", "good")
		return
	end
	if pass.id > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif simulating() then
		grantPass(player, name)
		notify:FireClient(player, `[Studio] Simulated purchase: {name}`, "good")
	else
		warn(`[Monetization] Game pass {name} has no ID yet (Config/Products)`)
	end
end

local function promptProduct(player: Player, name: string)
	local product = Products.DevProducts[name]
	if not product then
		return
	end
	if product.id > 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif simulating() then
		grantProduct(player, name)
	else
		warn(`[Monetization] Dev product {name} has no ID yet (Config/Products)`)
	end
end

local function promptCashPass(player: Player)
	local nextPass = nextCashPass(player)
	if not nextPass then
		notify:FireClient(player, "You own the best Cash multiplier!", "good")
		return
	end
	promptPass(player, nextPass)
end

local function productName(productId: number): string?
	for name, product in Products.DevProducts do
		if product.id > 0 and product.id == productId then
			return name
		end
	end
	return nil
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = tostring(info.PurchaseId)
	if data.receipts[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local name = productName(info.ProductId)
	if not name or not grantProduct(player, name) then
		warn(`[Monetization] Could not grant product {tostring(info.ProductId)} to {player.Name}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.receipts[key] = true
	DataService.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function loadOwnership(player: Player)
	local set: { [string]: boolean } = {}
	owned[player] = set
	for name, pass in Products.GamePasses do
		if pass.id > 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and result then
				set[name] = true
			elseif not ok then
				warn(`[Monetization] Could not check game pass {name} for {player.Name}: {tostring(result)}`)
			end
		end
	end
	MonetizationService.refresh(player)
end

local function updateFriends(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok and isFriend and player.Parent == Players and other.Parent == Players then
					friendPairs[player] = friendPairs[player] or {}
					friendPairs[other] = friendPairs[other] or {}
					friendPairs[player][other] = true
					friendPairs[other][player] = true
					MonetizationService.refresh(player)
					MonetizationService.refresh(other)
				end
			end)
		end
	end
end

local function onPlayerAdded(player: Player)
	loadOwnership(player)
	updateFriends(player)
end

local function onPlayerRemoving(player: Player)
	owned[player] = nil
	lastBuy[player] = nil
	local mine = friendPairs[player]
	friendPairs[player] = nil
	for other in mine or {} do
		local theirs = friendPairs[other]
		if theirs then
			theirs[player] = nil
		end
		MonetizationService.refresh(other)
	end
end

local function onBuyProduct(player: Player, name: unknown)
	-- "CashPass" (the HUD promo) offers the next Cash multiplier pass up.
	if typeof(name) ~= "string" or not (PRODUCT_INTENTS[name] or name == "CashPass") then
		return
	end
	local now = os.clock()
	if now - (lastBuy[player] or 0) < BUY_PRODUCT_COOLDOWN then
		return
	end
	lastBuy[player] = now
	if name == "CashPass" then
		promptCashPass(player)
	else
		promptProduct(player, name)
	end
end

function MonetizationService:Init()
	notify = Remotes.event("Notify")
	Remotes.event("BuyProduct").OnServerEvent:Connect(onBuyProduct)
end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for name, pass in Products.GamePasses do
				if pass.id > 0 and pass.id == passId then
					grantPass(player, name)
					notify:FireClient(player, "Thank you for your purchase!", "good")
				end
			end
		end
	)

	for _, plot in Plots.all() do
		local stations = plot.stations
		Plots.onStep(plot, stations.finishNow, function(player)
			promptProduct(player, "FinishNow")
		end)
		Plots.onStep(plot, stations.autoCollect, function(player)
			promptPass(player, "AutoCollect")
		end)
		Plots.onStep(plot, stations.doubleAura, function(player)
			promptPass(player, "DoubleAura")
		end)
		Plots.onStep(plot, stations.cashPass, function(player)
			promptCashPass(player)
		end)
		MonetizationService.refreshPads(plot)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return MonetizationService
