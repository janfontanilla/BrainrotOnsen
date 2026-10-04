--!strict
-- The guide line under the Home button, the player's "what next":
--   * during the tutorial (TutorialStep attribute < Tutorial.DONE): the step's
--     instruction, a beam from the character to the pad and a bobbing arrow over
--     it, and a quiet "Skip tutorial" button from step Tutorial.SKIP_FROM (tap twice);
--   * afterwards, the next goal: deposit a big Aura pile, collect Cash that pays for
--     the upgrade, Merge! when ready, else "Next: Upgrade Buy Tier" with a progress
--     bar. Tapping the line toggles the beam; urgent goals show it by themselves.
--   * a hint button under the goal at real friction points: Auto Collect while the
--     drop cap stops production, Finish Now while the processor queue is long, and
--     the next Cash pass ("x7 Cash: ready in 3h instead of 21h") once a step takes
--     longer than a sitting. Never in the first buy tiers, never a pop-up.
-- Everything is read from player attributes the server sets; the client only sends
-- intents (TutorialAction "skip", BuyProduct).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Tiers = require(Shared.Config.Tiers)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Tutorial = require(Shared.Tutorial)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

-- When goals and hints show (UX, not balance).
local DEPOSIT_GOAL_SECONDS = 600 -- Aura worth this many seconds of production asks for a deposit
local FINISH_NOW_HINT_SECONDS = 1200 -- processor queue longer than this offers Finish Now
local PASS_HINT_MIN_SECONDS = 1800 -- the Cash pass hint shows once the goal is this far away...
local PASS_HINT_FROM_TIER = 6 -- ...and the player is past the first buy tiers
local SKIP_CONFIRM_SECONDS = 4

local WHITE = Color3.new(1, 1, 1)
local OUTLINE = Color3.fromRGB(24, 24, 30)
local GREEN, GREEN_DARK = Color3.fromRGB(128, 214, 58), Color3.fromRGB(28, 86, 18)
local GREY, GREY_DARK = Color3.fromRGB(150, 150, 160), Color3.fromRGB(50, 50, 60)
local BEAM_COLOR = Color3.fromRGB(255, 236, 90)

local GuideController = {}

type Goal = {
	text: string,
	target: string?,
	urgent: boolean, -- show the beam without a tap
	progress: number?, -- 0..1 shows the bar
	progressText: string?,
	hint: { text: string, product: string }?,
}

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function duration(seconds: number): string
	if seconds < 3600 then
		return `{math.max(1, math.ceil(seconds / 60))} min`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600 * 10 + 0.5) / 10} h`
	end
	return `{math.floor(seconds / 86400 * 10 + 0.5) / 10} days`
end

local function nextCashPass(owned: number): Products.Pass?
	for i = #Products.CASH_MULTIPLIER_PASSES, 1, -1 do
		local candidate = Products.GamePasses[Products.CASH_MULTIPLIER_PASSES[i]]
		if (candidate.multiplier or 1) > owned then
			return candidate
		end
	end
	return nil
end

-- The friction hint for a goal that is still far away, or nil.
local function hintFor(secondsLeft: number, buyTier: number, cashPass: number): { text: string, product: string }?
	if player:GetAttribute("DropsCapped") == true and player:GetAttribute("AutoCollect") ~= true then
		return { text = `Drops full! Auto Collect: R$ {Products.GamePasses.AutoCollect.robux}`, product = "AutoCollect" }
	end
	local wait = number("ProcessorWait")
	if wait > FINISH_NOW_HINT_SECONDS then
		return {
			text = `Processor busy {duration(wait)}. Finish Now: R$ {Products.DevProducts.FinishNow.robux}`,
			product = "FinishNow",
		}
	end
	local pass = nextCashPass(cashPass)
	if pass and buyTier >= PASS_HINT_FROM_TIER and secondsLeft > PASS_HINT_MIN_SECONDS then
		local faster = secondsLeft * math.max(cashPass, 1) / (pass.multiplier or 1)
		return {
			text = `{pass.multiplier}x Cash: {duration(faster)} instead of {duration(secondsLeft)} (R$ {pass.robux})`,
			product = "CashPass",
		}
	end
	return nil
end

local function currentGoal(): Goal
	local step = number("TutorialStep")
	local def = Tutorial.STEPS[step]
	if def then
		local target = def.target
		local text = def.text
		if def.id == "merge" and player:GetAttribute("MergeReady") ~= true and def.altTarget then
			target = def.altTarget
		elseif def.count and def.count > 1 then
			text = `{text} ({number("TutorialCount")}/{def.count})`
		end
		return { text = text, target = target, urgent = true }
	end
	if step == 0 then
		return { text = "", urgent = false }
	end

	local aura, auraPerSecond = number("Aura"), number("AuraPerSecond")
	local cash, pending = number("Cash"), number("PendingCash")
	local buyTier = math.max(1, number("BuyTier"))
	local cashPass = math.max(1, number("CashPass"))
	local cost = Economy.buyTierUpgradeCost(buyTier)

	if aura > 0 and aura >= auraPerSecond * DEPOSIT_GOAL_SECONDS then
		return { text = `Deposit your {Format.short(aura)} Aura`, target = "DepositPad", urgent = true }
	end
	if cost and cash < cost and cash + pending >= cost then
		return { text = "Collect your Cash: enough for the upgrade!", target = "CollectCashPad", urgent = true }
	end
	if player:GetAttribute("MergeReady") == true then
		return { text = "Merge! is ready", target = "MergePad", urgent = false }
	end
	if not cost then
		return { text = "Max buy tier! Fill your bathhouse with Los Tralaleritos", urgent = false }
	end
	local nextName = Tiers.get(buyTier + 1).name
	if cash >= cost then
		return { text = `Upgrade Buy Tier: {nextName}!`, target = "UpgradeBuyTierPad", urgent = true, progress = 1 }
	end
	-- Cash income per second before the market: brainrots' Aura x the Cash pass.
	local income = auraPerSecond * cashPass
	local secondsLeft = if income > 0 then (cost - cash - pending) / income else math.huge
	return {
		text = `Next: Upgrade Buy Tier ({nextName})`,
		target = "UpgradeBuyTierPad",
		urgent = false,
		progress = math.clamp((cash + pending) / cost, 0, 1),
		progressText = `{Format.short(cash + pending)} / {Format.short(cost)}`,
		hint = hintFor(secondsLeft, buyTier, cashPass),
	}
end

local function findTarget(name: string): BasePart?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and typeof(index) == "number" and plots:FindFirstChild(`Plot{index}`)
	local part = plot and plot:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

function GuideController:Start()
	local tutorialAction = Remotes.event("TutorialAction")
	local buyProduct = Remotes.event("BuyProduct")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Guide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the Index and lucky block windows
	Style.autoScale(gui)

	-- Under the Home / Index buttons, top centre.
	local panel = Instance.new("TextButton")
	panel.Name = "Goal"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 74)
	panel.Size = UDim2.fromOffset(620, 96)
	panel.Parent = gui

	local title = Style.outlined(panel, "Title", WHITE, OUTLINE, 3)
	title.Size = UDim2.new(1, 0, 0, 40)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 44)
	bar.Size = UDim2.fromOffset(360, 22)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	bar.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = OUTLINE
	barStroke.Thickness = 3
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = GREEN
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill
	local barText = Style.outlined(bar, "Amount", WHITE, OUTLINE, 2)
	barText.Size = UDim2.new(1, 0, 1, -2)
	barText.ZIndex = 2

	local hint, hintLabel = Style.button(gui, "Hint", GREEN, GREEN_DARK)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 148)
	hint.Size = UDim2.fromOffset(460, 42)
	hint.Visible = false

	local skip, skipLabel = Style.button(gui, "Skip", GREY, GREY_DARK)
	skip.AnchorPoint = Vector2.new(0.5, 0)
	skip.Position = UDim2.new(0.5, 380, 0, 80)
	skip.Size = UDim2.fromOffset(150, 34)
	skip.Visible = false

	-- Beam from the character to the target, and an arrow bobbing over the target.
	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "GuideFrom"
	local toAttachment = Instance.new("Attachment")
	toAttachment.Name = "GuideTo"
	toAttachment.Position = Vector3.new(0, 1, 0)
	local beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Color = ColorSequence.new(BEAM_COLOR)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	beam.Enabled = false
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "GuideArrow"
	arrow.AlwaysOnTop = true
	arrow.Size = UDim2.fromScale(4, 4)
	arrow.LightInfluence = 0
	arrow.Enabled = false
	local arrowLabel = Style.outlined(arrow, "Arrow", BEAM_COLOR, OUTLINE, 3)
	arrowLabel.Size = UDim2.fromScale(1, 1)
	arrowLabel.Text = "▼"

	local beamWanted = false -- the player tapped the goal line
	local lastTarget: string? = nil
	local currentHint: string? = nil
	local skipArmedAt = 0

	local function setTarget(goal: Goal)
		if goal.target ~= lastTarget then
			lastTarget = goal.target
			beamWanted = false
		end
		local show = goal.target ~= nil and (goal.urgent or beamWanted)
		local part = if show and goal.target then findTarget(goal.target) else nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if part and root then
			if toAttachment.Parent ~= part then
				toAttachment.Parent = part
			end
			if fromAttachment.Parent ~= root then
				fromAttachment.Parent = root
			end
			beam.Parent = root
			beam.Enabled = true
			arrow.Adornee = part
			arrow.Enabled = true
		else
			beam.Enabled = false
			arrow.Enabled = false
		end
	end

	local function refresh()
		local goal = currentGoal()
		title.Text = goal.text
		panel.Visible = goal.text ~= ""
		bar.Visible = goal.progress ~= nil
		if goal.progress then
			fill.Size = UDim2.fromScale(goal.progress, 1)
			barText.Text = goal.progressText or (if goal.progress >= 1 then "Ready!" else "")
		end
		local h = goal.hint
		hint.Visible = h ~= nil
		hint.Position = UDim2.new(0.5, 0, 0, if goal.progress then 148 else 118)
		if h then
			hintLabel.Text = h.text
			currentHint = h.product
		else
			currentHint = nil
		end
		local step = number("TutorialStep")
		skip.Visible = step >= Tutorial.SKIP_FROM and step < Tutorial.DONE
		if os.clock() - skipArmedAt > SKIP_CONFIRM_SECONDS then
			skipLabel.Text = "Skip tutorial"
		end
		setTarget(goal)
	end

	panel.Activated:Connect(function()
		beamWanted = not beamWanted
		refresh()
	end)
	hint.Activated:Connect(function()
		if currentHint then
			buyProduct:FireServer(currentHint)
		end
	end)
	skip.Activated:Connect(function()
		if os.clock() - skipArmedAt <= SKIP_CONFIRM_SECONDS then
			tutorialAction:FireServer("skip")
			skipArmedAt = 0
		else
			skipArmedAt = os.clock()
			skipLabel.Text = "Sure? Tap again"
		end
	end)

	for _, name in
		{
			"TutorialStep",
			"TutorialCount",
			"Aura",
			"AuraPerSecond",
			"Cash",
			"PendingCash",
			"BuyTier",
			"CashPass",
			"MergeReady",
			"DropsCapped",
			"AutoCollect",
			"ProcessorWait",
			"PlotIndex",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)

	-- Bob the arrow over its pad.
	RunService.RenderStepped:Connect(function()
		arrow.StudsOffset = Vector3.new(0, 7 + math.sin(os.clock() * 4) * 0.8, 0)
	end)

	local playerGui = player:WaitForChild("PlayerGui")
	arrow.Parent = playerGui -- a BillboardGui only draws outside a ScreenGui
	gui.Parent = playerGui
	refresh()
end

return GuideController
