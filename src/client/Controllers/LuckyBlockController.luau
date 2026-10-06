--!strict
-- Lucky blocks on the client:
--   * Held block: every player whose LuckyBlock attribute is set gets a chest
--     resting on the end of their right hand (drawn locally, so it's smooth).
--     The holder's own client plays Roblox's tool-hold animation (right arm
--     straight out), which Roblox replicates to everyone else.
--   * Panel (owner only, right side): block picture, "<Name> / Lucky Box", odds
--     with each tier's name and number, the Cash cost, Unlock! and Discard.
--     Odds and price come from the shared Config/LuckyBlocks; the server rolls.
--   * Reveal: on LuckyBlockOpened the chest leaves the holder's hand. For the
--     owner, a big chest drops into the middle of the screen, shakes, then pops
--     open into the brainrot that was rolled (name + tier), holds, and shrinks away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local LuckyBlocks = require(Shared.Config.LuckyBlocks)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Models = require(Shared.Models)
local Visuals = require(Shared.Visuals)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

local HELD_SIZE = 3.6
local HELD_FALLBACK = CFrame.new(1.5, 1, -2.5) -- from the root part when the hand can't be found
-- Roblox's default "holding a tool" animations (right arm straight out). The
-- local player plays it on their own character; Roblox replicates it to others.
local HOLD_ANIMATION_R15 = "rbxassetid://507768375"
local HOLD_ANIMATION_R6 = "rbxassetid://182393478"
local DROP_TIME = 0.5 -- chest drops into the middle of the screen
local SHAKE_TIME = 1 -- then shakes
local REVEAL_HOLD = 1.8 -- the brainrot stays on screen this long
local REVEAL_SIZE = 320 -- pixels

local LuckyBlockController = {}

-- Player -> chest held in their right hand
local held: { [Player]: Model } = {}
-- The local player's hold animation while they carry a block
local holdTrack: AnimationTrack? = nil

local function findBlock(name: unknown): LuckyBlocks.Block?
	if typeof(name) ~= "string" or name == "" then
		return nil
	end
	for _, block in LuckyBlocks.list do
		if block.name == name then
			return block
		end
	end
	return nil
end

local function rootOf(target: Player): BasePart?
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Holds the right arm out in front, or lowers it again. Only the local player's
-- own character is animated here; other players' poses arrive through
-- Roblox's animation replication.
local function setArmsUp(target: Player, up: boolean)
	if target ~= player then
		return
	end
	if not up then
		if holdTrack then
			holdTrack:Stop(0.15)
			holdTrack = nil
		end
		return
	end
	if holdTrack and holdTrack.IsPlaying then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15
		then HOLD_ANIMATION_R15
		else HOLD_ANIMATION_R6
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.15)
	holdTrack = track
end

-- Where the held chest sits: gripped by the outstretched right hand, like a
-- tool: in front of the hand at hand height (reference/lucky-block-held-tool-pose.png).
local function aboveHead(target: Player): CFrame?
	local root = rootOf(target)
	if not root then
		return nil
	end
	local character = target.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then
		return root.CFrame * HELD_FALLBACK
	end
	-- The hand's -Y end is its fingertips; the box starts there and extends the
	-- way the arm points, raised a little so the hand holds its lower half.
	local armDirection = -hand.CFrame.UpVector
	local tip = hand.Position + armDirection * (hand.Size.Y / 2)
	local center = tip + armDirection * (HELD_SIZE / 2 - 0.3) + Vector3.new(0, HELD_SIZE * 0.2, 0)
	return CFrame.new(center) * root.CFrame.Rotation
end

local function dropHeld(target: Player)
	local model = held[target]
	if model then
		model:Destroy()
		held[target] = nil
	end
	setArmsUp(target, false)
end

local function refreshHeld(target: Player)
	local block = findBlock(target:GetAttribute("LuckyBlock"))
	if not block then
		dropHeld(target)
		return
	end
	dropHeld(target)
	setArmsUp(target, true)
	local model = Visuals.makeLuckyBlock(block.name, HELD_SIZE)
	model.Parent = workspace
	held[target] = model
end

local function watchPlayer(target: Player)
	target:GetAttributeChangedSignal("LuckyBlock"):Connect(function()
		refreshHeld(target)
	end)
	target.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		character:WaitForChild("Humanoid")
		task.wait()
		refreshHeld(target)
	end)
	refreshHeld(target)
end

-- The screen reveal (owner only). Built once in Start.
local revealFrame: Frame
local revealView: ViewportFrame
local revealCamera: Camera
local revealScale: UIScale
local revealName: TextLabel
local revealTier: TextLabel
local revealSerial = 0

local function buildReveal(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LuckyReveal"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(REVEAL_SIZE, REVEAL_SIZE + 90)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromOffset(REVEAL_SIZE, REVEAL_SIZE)
	view.BackgroundTransparency = 1
	view.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.5, -11), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera

	local function caption(y: number, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Size = UDim2.new(1, 0, 0, height)
		label.Position = UDim2.fromOffset(0, y)
		label.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(30, 20, 10)
		stroke.Parent = label
		return label
	end
	revealName = caption(REVEAL_SIZE, 50)
	revealTier = caption(REVEAL_SIZE + 50, 32)
	revealTier.TextColor3 = Color3.new(1, 1, 1)

	revealFrame = frame
	revealView = view
	revealCamera = camera
	revealScale = scale
	return gui
end

local function setRevealContent(model: Instance)
	for _, child in revealView:GetChildren() do
		if child ~= revealCamera then
			child:Destroy()
		end
	end
	model.Parent = revealView
end

local function brainrotModel(tier: number): Model
	local model = Models.makeBrainrot(tier)
	local anchor = model:FindFirstChild("Label")
	if anchor then
		anchor:Destroy()
	end
	-- Centre it on the origin and turn it a little towards the camera.
	local height = model:GetExtentsSize().Y
	model:PivotTo(CFrame.new(0, -height / 2, 0) * CFrame.Angles(0, math.rad(-30), 0))
	return model
end

-- Owner's screen: chest drops in, shakes, opens into the brainrot.
local function playScreenReveal(blockName: string, tier: number)
	revealSerial += 1
	local serial = revealSerial
	local def = Tiers.get(tier)

	local chest = Visuals.makeLuckyBlock(blockName, 4)
	chest:PivotTo(CFrame.Angles(math.rad(-10), math.rad(-30), 0))
	setRevealContent(chest)
	revealName.Text = ""
	revealTier.Text = ""
	revealView.Rotation = 0
	revealScale.Scale = 1
	revealFrame.Position = UDim2.fromScale(0.5, -0.3)
	revealFrame.Visible = true

	-- Drop in.
	TweenService:Create(
		revealFrame,
		TweenInfo.new(DROP_TIME, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.45) }
	):Play()
	task.wait(DROP_TIME)

	-- Shake, harder towards the end.
	local start = os.clock()
	while os.clock() - start < SHAKE_TIME do
		if revealSerial ~= serial then
			return
		end
		local t = os.clock() - start
		revealView.Rotation = math.sin(t * 45) * (4 + 10 * t / SHAKE_TIME)
		RunService.RenderStepped:Wait()
	end
	revealView.Rotation = 0

	-- Open: the chest pops away and the brainrot pops in.
	local pop = TweenService:Create(
		revealScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.2 }
	)
	pop:Play()
	pop.Completed:Wait()
	setRevealContent(brainrotModel(tier))
	revealName.Text = def.name
	revealName.TextColor3 = Visuals.tierColor(tier)
	revealTier.Text = `Tier {tier}`
	TweenService
		:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.wait(REVEAL_HOLD)
	if revealSerial ~= serial then
		return
	end

	-- Shrink away.
	local out = TweenService:Create(
		revealScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Scale = 0 }
	)
	out:Play()
	out.Completed:Wait()
	if revealSerial == serial then
		revealFrame.Visible = false
	end
end

local function reveal(target: Player, blockName: string, tier: number)
	-- The chest leaves the holder's hand (the arm comes down with it).
	dropHeld(target)
	if target == player then
		playScreenReveal(blockName, tier)
	end
end

local function text(parent: Instance, value: string, color: Color3, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = value
	label.Size = size
	label.Position = position
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 20, 10)
	stroke.Parent = label
	return label
end

local function box(parent: Instance, color: Color3, size: UDim2, position: UDim2, radius: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.Size = size
	frame.Position = position
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = Color3.fromRGB(40, 25, 10)
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = frame
	return frame
end

local function button(parent: Instance, value: string, color: Color3, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 60)
	b.Position = position
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = value
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = Color3.fromRGB(30, 20, 10)
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = b
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Color3.fromRGB(30, 20, 10)
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = b
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = b
	return b
end

local function buildPanel(): (ScreenGui, () -> ())
	local action = Remotes.event("LuckyBlockAction")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LuckyBlock"
	gui.ResetOnSpawn = false
	Style.autoScale(gui)

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(1, 0.5)
	root.Position = UDim2.new(1, -16, 0.5, 0)
	root.Size = UDim2.fromOffset(320, 560)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	-- Main card: picture + title, then the odds box.
	local card = box(root, Color3.fromRGB(220, 170, 90), UDim2.new(1, 0, 0, 380), UDim2.new(), 12)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromOffset(110, 110)
	viewport.Position = UDim2.fromOffset(4, -20)
	viewport.Parent = card
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local title = text(card, "", Color3.new(1, 1, 1), UDim2.new(1, -124, 0, 50), UDim2.fromOffset(118, 10))
	text(card, "Lucky Box", Color3.new(1, 1, 1), UDim2.new(1, -124, 0, 34), UDim2.fromOffset(118, 60))

	local odds = box(card, Color3.fromRGB(80, 60, 35), UDim2.new(1, -24, 0, 256), UDim2.fromOffset(12, 110), 10)
	local cost = box(root, Color3.fromRGB(70, 60, 45), UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 392), 10)
	text(cost, "Cost:", Color3.new(1, 1, 1), UDim2.new(0.4, -12, 1, -12), UDim2.fromOffset(12, 6))
	local price = text(cost, "", Color3.fromRGB(125, 255, 110), UDim2.new(0.6, -12, 1, -12), UDim2.new(0.4, 0, 0, 6))
	price.TextXAlignment = Enum.TextXAlignment.Right

	local unlock = button(root, "🔓 Unlock!", Color3.fromRGB(110, 210, 50), UDim2.fromOffset(0, 454))
	local discard = button(root, "🗑 Discard", Color3.fromRGB(230, 80, 40), UDim2.fromOffset(0, 520))
	unlock.Size = UDim2.new(1, 0, 0, 58)
	discard.Size = UDim2.new(1, 0, 0, 40)
	local buyProduct = Remotes.event("BuyProduct")
	local robuxMode = false -- Cash is short: the button buys "Unlock Lucky Chest" (Robux)
	unlock.Activated:Connect(function()
		if robuxMode then
			buyProduct:FireServer("LuckyUnlock")
		else
			action:FireServer("unlock")
		end
	end)
	discard.Activated:Connect(function()
		action:FireServer("discard")
	end)

	local function show()
		local block = findBlock(player:GetAttribute("LuckyBlock"))
		if not block then
			root.Visible = false
			return
		end
		local color = Visuals.blockColor(block.name)
		card.BackgroundColor3 = color:Lerp(Color3.fromRGB(220, 170, 90), 0.5)
		title.Text = block.name
		title.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)

		for _, child in viewport:GetChildren() do
			if child:IsA("Model") then
				child:Destroy()
			end
		end
		local model = Visuals.makeLuckyBlock(block.name, 4)
		local beacon = model:FindFirstChild("Beacon")
		if beacon then
			beacon:Destroy() -- the rare-chest light beam would fill the panel's picture
		end
		model:PivotTo(CFrame.Angles(math.rad(-15), math.rad(-30), 0))
		model.Parent = viewport
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 2, -11), Vector3.zero)

		for _, child in odds:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		-- The chest's own rows, as before. A result below the buy tier is still listed
		-- with its odds, dimmed, with the tier it really turns into ("-> Lirili Larila"),
		-- so the shown odds stay exactly the real ones (Roblox paid random item rules).
		local buyTier = player:GetAttribute("BuyTier")
		local floorTier = math.min(if typeof(buyTier) == "number" then buyTier else 1, Tiers.MAX_TIER)
		local rolls = block.rolls
		local rowHeight = 236 / #rolls
		for i, roll in rolls do
			local raised = roll.tier < floorTier
			local y = 10 + (i - 1) * rowHeight
			local tier = Tiers.get(roll.tier)
			local nameLabel = text(
				odds,
				tier.name,
				Visuals.tierColor(roll.tier),
				UDim2.new(0.72, -12, 0, rowHeight * 0.55),
				UDim2.fromOffset(12, y)
			)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			local tierLabel = text(
				odds,
				if raised then `Tier {roll.tier} → {Tiers.get(floorTier).name}` else `Tier {roll.tier}`,
				if raised then Color3.fromRGB(125, 255, 110) else Color3.new(1, 1, 1),
				UDim2.new(0.72, -12, 0, rowHeight * 0.3),
				UDim2.fromOffset(12, y + rowHeight * 0.55)
			)
			tierLabel.TextXAlignment = Enum.TextXAlignment.Left
			local percent = text(
				odds,
				`{roll.weight}%`,
				Color3.new(1, 1, 1),
				UDim2.new(0.28, -12, 0, rowHeight * 0.6),
				UDim2.new(0.72, 0, 0, y + rowHeight * 0.1)
			)
			percent.TextXAlignment = Enum.TextXAlignment.Right
			if raised then
				nameLabel.TextTransparency = 0.55
				percent.TextTransparency = 0.3
			end
		end
		local blockPrice = LuckyBlocks.priceFor(block, if typeof(buyTier) == "number" then buyTier else 1)
		price.Text = `{Format.short(blockPrice)} Cash`
		local cash = player:GetAttribute("Cash")
		robuxMode = typeof(cash) == "number" and cash < blockPrice and player:GetAttribute("PaidRandomItems") == true
		unlock.Text = if robuxMode
			then `🔓 Unlock for R$ {Products.DevProducts.LuckyUnlock.robux}`
			else "🔓 Unlock!"
		unlock.BackgroundColor3 = if robuxMode then Color3.fromRGB(60, 170, 90) else Color3.fromRGB(110, 210, 50)
		root.Visible = true
	end

	player:GetAttributeChangedSignal("LuckyBlock"):Connect(show)
	for _, name in { "Cash", "BuyTier", "PaidRandomItems" } do
		player:GetAttributeChangedSignal(name):Connect(show)
	end
	return gui, show
end

function LuckyBlockController:Start()
	for _, target in Players:GetPlayers() do
		watchPlayer(target)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(target)
		dropHeld(target)
	end)

	-- Keep every held chest on its holder's outstretched hand (still; it only shakes
	-- while being unlocked).
	RunService.RenderStepped:Connect(function()
		for target, model in held do
			local place = aboveHead(target)
			if place then
				model:PivotTo(place)
			end
		end
	end)

	Remotes.event("LuckyBlockOpened").OnClientEvent:Connect(function(target: unknown, blockName: unknown, tier: unknown)
		if
			typeof(target) == "Instance"
			and target:IsA("Player")
			and typeof(blockName) == "string"
			and typeof(tier) == "number"
		then
			task.spawn(reveal, target, blockName, tier)
		end
	end)

	buildReveal().Parent = player:WaitForChild("PlayerGui")

	local gui, show = buildPanel()
	show()
	gui.Parent = player:WaitForChild("PlayerGui")
end

return LuckyBlockController
