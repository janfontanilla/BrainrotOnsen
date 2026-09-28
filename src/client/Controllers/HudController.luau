--!strict
-- HUD: Home button (top center), Aura (bottom center) and Cash (bottom left)
-- from the player's server-set attributes, plus messages
-- the server sends through Notify: big outlined popups for deposits and
-- collected Cash, small toasts for everything else.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

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

local HudController = {}

local function makeLabel(parent: Instance, name: string, order: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.fromOffset(190, 44)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label
	return label
end

function HudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local aura = makeLabel(gui, "Aura", 1, Color3.fromRGB(200, 150, 255))
	aura.AnchorPoint = Vector2.new(0.5, 1)
	aura.Position = UDim2.new(0.5, 0, 1, -16)
	aura.Size = UDim2.fromOffset(240, 52)
	local cash = makeLabel(gui, "Cash", 2, Color3.fromRGB(125, 255, 138))
	cash.AnchorPoint = Vector2.new(0, 1)
	cash.Position = UDim2.new(0, 16, 1, -16)
	cash.Size = UDim2.fromOffset(240, 52)

	local home = Instance.new("TextButton")
	home.Name = "Home"
	-- Home sits left of center; IndexController puts Index right of center.
	home.AnchorPoint = Vector2.new(1, 0)
	home.Position = UDim2.new(0.5, -6, 0, 8)
	home.Size = UDim2.fromOffset(160, 48)
	home.BackgroundColor3 = Color3.fromRGB(60, 190, 230)
	home.Font = Enum.Font.FredokaOne
	home.TextScaled = true
	home.TextColor3 = Color3.new(1, 1, 1)
	home.Text = "Home"
	home.Parent = gui
	local homeCorner = Instance.new("UICorner")
	homeCorner.CornerRadius = UDim.new(0, 10)
	homeCorner.Parent = home
	local homeStroke = Instance.new("UIStroke")
	homeStroke.Thickness = 3
	homeStroke.Color = Color3.fromRGB(20, 60, 90)
	homeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	homeStroke.Parent = home
	local homePadding = Instance.new("UIPadding")
	homePadding.PaddingTop = UDim.new(0, 6)
	homePadding.PaddingBottom = UDim.new(0, 6)
	homePadding.Parent = home
	local goHome = Remotes.event("GoHome")
	home.Activated:Connect(function()
		goHome:FireServer()
	end)

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 66)
	toast.Size = UDim2.fromOffset(420, 36)
	toast.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	toast.BackgroundTransparency = 0.15
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Visible = false
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

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
		aura.Text = `Aura {Format.short(number("Aura"))}`
		cash.Text = `Cash {Format.short(number("Cash"))}`
	end
	for _, name in { "Aura", "Cash" } do
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
		toast.BackgroundColor3 = if kind == "good" then Color3.fromRGB(50, 160, 80) else Color3.fromRGB(200, 60, 60)
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
