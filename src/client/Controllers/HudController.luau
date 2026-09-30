--!strict
-- HUD: Home button (top center), Aura (bottom center), Cash (bottom left) with
-- the Cash multiplier and friend boost, Total Brainrots (bottom right), Cash
-- pack buttons + Premium + friend boost (left side), all from the player's
-- server-set attributes, plus messages
-- the server sends through Notify: big outlined popups for deposits and
-- collected Cash, small toasts for everything else.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

-- Popup styles by Notify kind: text color and outline color.
local POPUP_STYLES: { [string]: { text: Color3, stroke: Color3 } } = {
	deposit = { text = Color3.fromRGB(255, 226, 150), stroke = Color3.fromRGB(90, 55, 20) },
	away = { text = Color3.fromRGB(255, 226, 150), stroke = Color3.fromRGB(90, 55, 20) },
	cash = { text = Color3.fromRGB(110, 255, 90), stroke = Color3.fromRGB(20, 70, 10) },
	lucky = { text = Color3.fromRGB(255, 215, 60), stroke = Color3.fromRGB(90, 50, 0) },
	newBrainrot = { text = Color3.fromRGB(255, 120, 255), stroke = Color3.fromRGB(60, 0, 80) },
}
local POPUP_HOLD = 1.6 -- seconds on screen before floating away

-- Cash pack buttons (left side): the amount scales with the highest tier owned.
local PACKS: { { name: string, size: "S" | "M" | "L" } } = {
	{ name = "CashPackS", size = "S" },
	{ name = "CashPackM", size = "M" },
	{ name = "CashPackL", size = "L" },
}

local HudController = {}

-- Colours, from Capybara Onsen's HUD.
local GREEN, GREEN_DARK = Color3.fromRGB(128, 214, 58), Color3.fromRGB(28, 86, 18)
local LIME = Color3.fromRGB(222, 255, 96)
local CASH_GREEN = Color3.fromRGB(120, 250, 70)
local GOLD, GOLD_DARK = Color3.fromRGB(255, 196, 84), Color3.fromRGB(96, 52, 10)
local OUTLINE = Color3.fromRGB(24, 24, 30)

function HudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	-- Bottom centre: the Aura gem and a big white number.
	local auraBox = Instance.new("Frame")
	auraBox.Name = "AuraBox"
	auraBox.AnchorPoint = Vector2.new(0.5, 1)
	auraBox.Position = UDim2.new(0.5, 0, 1, -8)
	auraBox.Size = UDim2.fromOffset(340, 76)
	auraBox.BackgroundTransparency = 1
	auraBox.Parent = gui
	local gem = Instance.new("ImageLabel")
	gem.Name = "Icon"
	gem.BackgroundTransparency = 1
	gem.Image = Style.AURA_ICON
	gem.Size = UDim2.fromOffset(68, 68)
	gem.Position = UDim2.fromOffset(0, 4)
	gem.Parent = auraBox
	local aura = Style.outlined(auraBox, "Aura", Color3.new(1, 1, 1), OUTLINE, 4)
	aura.Size = UDim2.new(1, -76, 1, 0)
	aura.Position = UDim2.fromOffset(76, 0)
	aura.TextXAlignment = Enum.TextXAlignment.Left

	-- Bottom left: big green Cash, the Cash multiplier beside it.
	local cash = Style.outlined(gui, "Cash", CASH_GREEN, GREEN_DARK, 4)
	cash.AnchorPoint = Vector2.new(0, 1)
	cash.Position = UDim2.new(0, 14, 1, -8)
	cash.Size = UDim2.fromOffset(300, 72)
	cash.TextXAlignment = Enum.TextXAlignment.Left
	local boosts = Style.outlined(gui, "Boosts", Color3.fromRGB(60, 170, 40), Color3.fromRGB(12, 44, 6), 3)
	boosts.AnchorPoint = Vector2.new(0, 1)
	boosts.Position = UDim2.new(0, 320, 1, -16)
	boosts.Size = UDim2.fromOffset(170, 46)
	boosts.TextXAlignment = Enum.TextXAlignment.Left

	-- Bottom right: Total Brainrots in gold.
	local total = Style.outlined(gui, "TotalBrainrots", GOLD, GOLD_DARK, 3)
	total.AnchorPoint = Vector2.new(1, 1)
	total.Position = UDim2.new(1, -14, 1, -12)
	total.Size = UDim2.fromOffset(440, 50)
	total.TextXAlignment = Enum.TextXAlignment.Right

	-- Left side: the next Cash pass ("PERMANENT! 12X Money"), then the Cash packs.
	local buyProduct = Remotes.event("BuyProduct")
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.new(0, 14, 0.5, -10)
	left.Size = UDim2.fromOffset(240, 330)
	left.BackgroundTransparency = 1
	left.Parent = gui

	local promo, promoLabel = Style.button(left, "CashPassPromo", GREEN, GREEN_DARK)
	promo.Size = UDim2.fromOffset(236, 70)
	promo.Position = UDim2.fromOffset(0, 22)
	promoLabel.TextColor3 = LIME
	promo.Activated:Connect(function()
		buyProduct:FireServer("CashPass")
	end)
	local permanent = Style.outlined(left, "Permanent", Color3.fromRGB(255, 96, 40), Color3.fromRGB(80, 10, 0), 3)
	permanent.Text = "PERMANENT!"
	permanent.Size = UDim2.fromOffset(170, 30)
	permanent.Position = UDim2.fromOffset(-4, 0)
	permanent.Rotation = -6
	permanent.ZIndex = 3
	local promoPrice = Style.outlined(left, "PromoPrice", Color3.new(1, 1, 1), OUTLINE, 3)
	promoPrice.Size = UDim2.fromOffset(120, 32)
	promoPrice.Position = UDim2.fromOffset(58, 96)

	local packButtons: { [string]: { button: TextButton, amount: TextLabel } } = {}
	for i, pack in PACKS do
		local button, amount = Style.button(left, pack.name, GREEN, GREEN_DARK)
		button.Size = UDim2.fromOffset(236, 54)
		button.Position = UDim2.fromOffset(0, 138 + (i - 1) * 64)
		amount.TextColor3 = LIME
		amount.Size = UDim2.new(1, -84, 1, -14)
		amount.TextXAlignment = Enum.TextXAlignment.Left
		local price = Style.outlined(button, "Price", Color3.new(1, 1, 1), GREEN_DARK, 2)
		price.AnchorPoint = Vector2.new(1, 0.5)
		price.Position = UDim2.new(1, -8, 0.5, 0)
		price.Size = UDim2.fromOffset(64, 22)
		price.ZIndex = 2
		price.Text = `R$ {Products.DevProducts[pack.name].robux}`
		button.Activated:Connect(function()
			buyProduct:FireServer(pack.name)
		end)
		packButtons[pack.name] = { button = button, amount = amount }
	end

	-- Premium and friend boost, small, above Cash.
	local premium = Style.outlined(gui, "Premium", Color3.new(1, 1, 1), OUTLINE, 2)
	premium.AnchorPoint = Vector2.new(0, 1)
	premium.Position = UDim2.new(0, 14, 1, -84)
	premium.Size = UDim2.fromOffset(150, 28)
	premium.TextXAlignment = Enum.TextXAlignment.Left
	local friends = Style.outlined(gui, "Friends", Color3.fromRGB(255, 222, 90), OUTLINE, 2)
	friends.AnchorPoint = Vector2.new(0, 1)
	friends.Position = UDim2.new(0, 170, 1, -84)
	friends.Size = UDim2.fromOffset(120, 28)
	friends.TextXAlignment = Enum.TextXAlignment.Left

	-- Top centre: Home (cyan); IndexController puts Index (tan) right of it.
	local home, homeLabel = Style.button(gui, "Home", Color3.fromRGB(64, 196, 236), Color3.fromRGB(18, 66, 104))
	home.AnchorPoint = Vector2.new(1, 0)
	home.Position = UDim2.new(0.5, -8, 0, 8)
	home.Size = UDim2.fromOffset(180, 58)
	homeLabel.Text = "Home"
	local goHome = Remotes.event("GoHome")
	home.Activated:Connect(function()
		goHome:FireServer()
	end)

	-- Toasts: big outlined text in the middle of the screen, red for "no", green for "yes".
	local toast = Style.outlined(gui, "Toast", Color3.fromRGB(255, 84, 64), Color3.fromRGB(80, 8, 0), 3)
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.fromScale(0.5, 0.6)
	toast.Size = UDim2.fromOffset(640, 44)
	toast.Visible = false
	local toastStroke = toast:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- Popup: big outlined text in the lower middle of the screen that pops in,
	-- holds, then floats up and fades.
	local popup = Instance.new("TextLabel")
	popup.Name = "Popup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Size = UDim2.new(0.8, 0, 0, 56)
	popup.BackgroundTransparency = 1
	popup.Font = Enum.Font.FredokaOne
	popup.TextScaled = true
	popup.Visible = false
	popup.Parent = gui
	local popupStroke = Instance.new("UIStroke")
	popupStroke.Thickness = 3
	popupStroke.Parent = popup
	local popupScale = Instance.new("UIScale")
	popupScale.Parent = popup
	local popupSize = Instance.new("UITextSizeConstraint")
	popupSize.MaxTextSize = 48
	popupSize.Parent = popup

	local popupSerial = 0
	local function showPopup(message: string, style: { text: Color3, stroke: Color3 })
		popupSerial += 1
		local serial = popupSerial
		popup.Text = message
		popup.TextColor3 = style.text
		popupStroke.Color = style.stroke
		popup.TextTransparency = 0
		popupStroke.Transparency = 0
		popup.Position = UDim2.fromScale(0.5, 0.72)
		popupScale.Scale = 0.5
		popup.Visible = true
		TweenService
			:Create(popupScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		task.delay(POPUP_HOLD, function()
			if popupSerial ~= serial then
				return
			end
			local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(popup, fade, { Position = UDim2.fromScale(0.5, 0.64), TextTransparency = 1 }):Play()
			TweenService:Create(popupStroke, fade, { Transparency = 1 }):Play()
			task.delay(0.5, function()
				if popupSerial == serial then
					popup.Visible = false
				end
			end)
		end)
	end

	local function number(name: string): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else 0
	end

	local function refresh()
		aura.Text = Format.short(number("Aura"))
		cash.Text = "$" .. Format.short(number("Cash"))
		total.Text = `Total Brainrots: {Format.commas(number("TotalBrainrots"))}`

		local pass = number("CashPass")
		local friendBoost = number("FriendBoost")
		boosts.Text = if pass > 1 then `{pass}x Cash` else ""
		boosts.Visible = pass > 1

		-- The promo offers the next Cash pass up; hidden once the best is owned.
		local nextPass: Products.Pass? = nil
		for i = #Products.CASH_MULTIPLIER_PASSES, 1, -1 do
			local candidate = Products.GamePasses[Products.CASH_MULTIPLIER_PASSES[i]]
			if (candidate.multiplier or 1) > pass then
				nextPass = candidate
				break
			end
		end
		promo.Visible = nextPass ~= nil
		permanent.Visible = nextPass ~= nil
		promoPrice.Visible = nextPass ~= nil
		if nextPass then
			promoLabel.Text = `{nextPass.multiplier or 1}X Money`
			promoPrice.Text = `R$ {nextPass.robux}`
		end

		local highest = math.max(1, number("HighestTier"))
		for _, pack in PACKS do
			local entry = packButtons[pack.name]
			entry.amount.Text = "+$" .. Format.short(Economy.cashPackAmount(highest, pack.size))
		end
		local isPremium = player:GetAttribute("Premium") == true
		premium.Text = if isPremium
			then `Premium +{math.round(Economy.PREMIUM_AURA_BOOST * 100)}%`
			else "Premium: Inactive"
		friends.Text = `Friends {math.round(friendBoost * 100)}%`
	end
	for _, name in { "Aura", "Cash", "TotalBrainrots", "CashPass", "FriendBoost", "Premium", "HighestTier" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	local toastSerial = 0
	Remotes.event("Notify").OnClientEvent:Connect(function(message: unknown, kind: unknown)
		if typeof(message) ~= "string" then
			return
		end
		local style = if typeof(kind) == "string" then POPUP_STYLES[kind] else nil
		if style then
			showPopup(message, style)
			return
		end
		local good = kind == "good"
		toast.TextColor3 = if good then Color3.fromRGB(120, 250, 80) else Color3.fromRGB(255, 84, 64)
		toastStroke.Color = if good then Color3.fromRGB(16, 70, 10) else Color3.fromRGB(80, 8, 0)
		toastSerial += 1
		local serial = toastSerial
		toast.Text = message
		toast.Visible = true
		task.delay(2.5, function()
			if toastSerial == serial then
				toast.Visible = false
			end
		end)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return HudController
