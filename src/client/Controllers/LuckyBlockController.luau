--!strict
-- Lucky blocks on the client:
--   * Held block: every player whose LuckyBlock attribute is set carries the chest
--     above their head, gently bobbing and turning (drawn locally, so it's smooth;
--     2026-10-10, user: the arm-out hold looked off on many avatars).
--   * Panel (owner only, right side; 2026-10-10 restyle, user: "polish this UI"): a
--     studded header in the chest's colour with its picture and "<Name> Chest", the
--     odds as dark rows edged in each tier's colour, the cost, Unlock and Discard.
--     Odds and price come from the shared Config/LuckyBlocks; the server rolls.
--   * Reveal: on LuckyBlockOpened the chest leaves the holder's hand. For the
--     owner, a big chest drops into the middle of the screen, shakes, then pops
--     open into the brainrot that was rolled (name + tier), holds, and shrinks away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared.Config.Tiers)
local LuckyBlocks = require(Shared.Config.LuckyBlocks)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Models = require(Shared.Models)
local Visuals = require(Shared.Visuals)
local Style = require(script.Parent.Parent.Style)
local Sounds = require(Shared.Config.Sounds)

local player = Players.LocalPlayer

local HELD_SIZE = 2.4 -- 2026-10-09: 3.6 -> 2.4 (user: smaller)
local HELD_GAP = 0.6 -- studs between the top of the head and the chest
local HELD_BOB = 0.2 -- studs up and down
local HELD_BOB_SPEED = 2.4
local HELD_SPIN = math.rad(12) -- it turns gently back and forth
local DROP_TIME = 0.5 -- chest drops into the middle of the screen
local SHAKE_TIME = 1 -- then shakes
local REVEAL_HOLD = 1.8 -- the brainrot stays on screen this long
local REVEAL_SIZE = 320 -- pixels

local LuckyBlockController = {}

-- Player -> the chest they carry over their head
local held: { [Player]: Model } = {}

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

-- Where the held chest floats: centred over the character's head (the top of the
-- Head part, or of the whole character when there is none), bobbing gently.
local function aboveHead(target: Player): CFrame?
	local root = rootOf(target)
	local character = target.Character
	if not root or not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	local top: number
	if head and head:IsA("BasePart") then
		top = head.Position.Y + head.Size.Y / 2
	else
		local box, size = character:GetBoundingBox()
		top = box.Position.Y + size.Y / 2
	end
	local t = os.clock()
	local y = top + HELD_GAP + HELD_SIZE / 2 + math.sin(t * HELD_BOB_SPEED) * HELD_BOB
	local flat = root.CFrame - root.CFrame.Position
	return CFrame.new(root.Position.X, y, root.Position.Z) * flat * CFrame.Angles(0, math.sin(t * 1.3) * HELD_SPIN, 0)
end

local function dropHeld(target: Player)
	local model = held[target]
	if model then
		model:Destroy()
		held[target] = nil
	end
end

local function refreshHeld(target: Player)
	local block = findBlock(target:GetAttribute("LuckyBlock"))
	if not block then
		dropHeld(target)
		return
	end
	dropHeld(target)
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
-- Plays a sound once (2D) and cleans it up.
local function cueOnce(id: string, volume: number, pitch: number)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

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

	-- Shake, harder towards the end, with a soft swish on the swings (closer together
	-- and a little higher as it shakes harder).
	local start = os.clock()
	local nextSwish = 0
	local swish = 0
	while os.clock() - start < SHAKE_TIME do
		if revealSerial ~= serial then
			return
		end
		local t = os.clock() - start
		revealView.Rotation = math.sin(t * 45) * (4 + 10 * t / SHAKE_TIME)
		if t >= nextSwish and #Sounds.CHEST_SWISH > 0 then
			swish = swish % #Sounds.CHEST_SWISH + 1
			cueOnce(Sounds.CHEST_SWISH[swish], Sounds.CHEST_SWISH_VOLUME, 1 + 0.25 * t / SHAKE_TIME)
			nextSwish = t + 0.3 - 0.14 * t / SHAKE_TIME
		end
		RunService.RenderStepped:Wait()
	end
	revealView.Rotation = 0
	cueOnce(Sounds.CHEST_POP, Sounds.CHEST_POP_VOLUME, 1)

	-- Open: the chest pops away and the brainrot pops in.
	local pop = TweenService:Create(
		revealScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.2 }
	)
	pop:Play()
	pop.Completed:Wait()
	setRevealContent(brainrotModel(tier))
	local jingle = Instance.new("Sound")
	jingle.SoundId = Sounds.SPECIAL
	jingle.Volume = Sounds.CUE_VOLUME
	jingle.PlayOnRemove = true -- plays now, and cleans itself up
	jingle.Parent = SoundService
	jingle:Destroy()
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

local INK = Color3.fromRGB(20, 20, 26)
local BODY = Color3.fromRGB(34, 34, 40)
local ROW = Color3.fromRGB(46, 46, 54)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function border(parent: Instance, thickness: number)
	local b = Instance.new("UIStroke")
	b.Color = INK
	b.Thickness = thickness
	b.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = parent
end

local function buildPanel(): (ScreenGui, () -> ())
	local action = Remotes.event("LuckyBlockAction")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LuckyBlock"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Style.autoScale(gui)

	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(1, 0.5)
	root.Position = UDim2.new(1, -16, 0.5, 10)
	root.Size = UDim2.fromOffset(330, 480)
	root.BackgroundColor3 = BODY
	root.Visible = false
	root.Parent = gui
	corner(root, 12)
	border(root, 4)

	-- Header: studded, in the chest's colour, the chest picture poking out top left.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 74)
	header.Parent = root
	corner(header, 12)
	local headerStroke = Instance.new("UIStroke")
	headerStroke.Thickness = 3
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = header
	local studs = Instance.new("ImageLabel")
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.Image = Style.STUDS_IMAGE
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(32, 32)
	studs.ImageTransparency = 0.45
	studs.Parent = header
	corner(studs, 12)

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.AnchorPoint = Vector2.new(0, 0.5)
	viewport.Size = UDim2.fromOffset(104, 104)
	viewport.Position = UDim2.new(0, -14, 0.5, -10)
	viewport.ZIndex = 3
	viewport.Parent = header
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local title = Style.outlined(header, "Title", Color3.new(1, 1, 1), INK, 3)
	title.Position = UDim2.fromOffset(94, 6)
	title.Size = UDim2.new(1, -104, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2
	local subtitle = Style.outlined(header, "Subtitle", Color3.fromRGB(255, 240, 200), INK, 2)
	subtitle.Text = "Lucky Chest"
	subtitle.Position = UDim2.fromOffset(95, 44)
	subtitle.Size = UDim2.new(1, -104, 0, 24)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.ZIndex = 2

	-- The odds: one dark row per result, edged in the tier's colour.
	local oddsTitle = Style.outlined(root, "OddsTitle", Color3.new(1, 1, 1), INK, 2)
	oddsTitle.Text = "Chances"
	oddsTitle.Position = UDim2.fromOffset(0, 80)
	oddsTitle.Size = UDim2.new(1, 0, 0, 26)
	local odds = Instance.new("Frame")
	odds.Name = "Odds"
	odds.BackgroundTransparency = 1
	odds.Position = UDim2.fromOffset(14, 112)
	odds.Size = UDim2.new(1, -28, 0, 236)
	odds.Parent = root
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = odds

	-- Cost, then the buttons.
	local cost = Instance.new("Frame")
	cost.Name = "Cost"
	cost.BackgroundColor3 = ROW
	cost.Position = UDim2.fromOffset(14, 356)
	cost.Size = UDim2.new(1, -28, 0, 40)
	cost.Parent = root
	corner(cost, 8)
	border(cost, 3)
	local costKey = Style.outlined(cost, "Key", Color3.new(1, 1, 1), INK, 2)
	costKey.Text = "Cost"
	costKey.Position = UDim2.fromOffset(12, 6)
	costKey.Size = UDim2.new(0.4, -12, 1, -12)
	costKey.TextXAlignment = Enum.TextXAlignment.Left
	local price = Style.outlined(cost, "Price", Color3.fromRGB(125, 255, 110), INK, 2)
	price.AnchorPoint = Vector2.new(1, 0)
	price.Position = UDim2.new(1, -12, 0, 6)
	price.Size = UDim2.new(0.6, -12, 1, -12)
	price.TextXAlignment = Enum.TextXAlignment.Right

	local unlock, unlockLabel = Style.button(root, "Unlock", Color3.fromRGB(110, 210, 50), Color3.fromRGB(30, 90, 14))
	unlock.Position = UDim2.fromOffset(14, 406)
	unlock.Size = UDim2.new(0.62, -18, 0, 58)
	local discard, discardLabel =
		Style.button(root, "Discard", Color3.fromRGB(226, 70, 50), Color3.fromRGB(110, 20, 10))
	discard.AnchorPoint = Vector2.new(1, 0)
	discard.Position = UDim2.new(1, -14, 0, 406)
	discard.Size = UDim2.new(0.38, -10, 0, 58)
	discardLabel.Text = "Discard"

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

	local function row(
		order: number,
		name: string,
		sub: string,
		subColor: Color3,
		color: Color3,
		percent: string,
		dim: boolean
	)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.BackgroundColor3 = ROW
		frame.Size = UDim2.new(1, 0, 0, 52)
		frame.Parent = odds
		corner(frame, 8)
		border(frame, 3)
		local edge = Instance.new("Frame")
		edge.BackgroundColor3 = color
		edge.BorderSizePixel = 0
		edge.Size = UDim2.new(0, 8, 1, 0)
		edge.Parent = frame
		corner(edge, 6)
		local nameLabel = Style.outlined(frame, "Name", color, INK, 2)
		nameLabel.Text = name
		nameLabel.Position = UDim2.fromOffset(18, 4)
		nameLabel.Size = UDim2.new(1, -110, 0, 26)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		local subLabel = Style.outlined(frame, "Tier", subColor, INK, 1.5)
		subLabel.Text = sub
		subLabel.Position = UDim2.fromOffset(18, 30)
		subLabel.Size = UDim2.new(1, -110, 0, 17)
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Position = UDim2.new(1, -8, 0.5, 0)
		pill.Size = UDim2.fromOffset(80, 36)
		pill.BackgroundColor3 = BODY
		pill.Parent = frame
		corner(pill, 18)
		local percentLabel = Style.outlined(pill, "Percent", Color3.new(1, 1, 1), INK, 2)
		percentLabel.Text = percent
		percentLabel.Position = UDim2.fromOffset(6, 4)
		percentLabel.Size = UDim2.new(1, -12, 1, -8)
		if dim then
			nameLabel.TextTransparency = 0.5
			edge.BackgroundTransparency = 0.5
		end
	end

	local function show()
		local block = findBlock(player:GetAttribute("LuckyBlock"))
		if not block then
			root.Visible = false
			return
		end
		local color = Visuals.blockColor(block.name)
		header.BackgroundColor3 = color
		headerStroke.Color = color:Lerp(INK, 0.6)
		title.Text = `{block.name} Chest`

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
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		-- The chest's own rows. A result below the buy tier is still listed with its
		-- odds, dimmed, with the tier it really turns into ("Tier 2 -> Frigo Camelo"),
		-- so the shown odds stay exactly the real ones (Roblox paid random item rules).
		local buyTier = player:GetAttribute("BuyTier")
		local floorTier = math.min(if typeof(buyTier) == "number" then buyTier else 1, Tiers.MAX_TIER)
		for i, roll in block.rolls do
			local raised = roll.tier < floorTier
			row(
				i,
				Tiers.get(roll.tier).name,
				if raised then `Tier {roll.tier} → {Tiers.get(floorTier).name}` else `Tier {roll.tier}`,
				if raised then Color3.fromRGB(125, 255, 110) else Color3.fromRGB(220, 220, 230),
				Visuals.tierColor(roll.tier),
				`{roll.weight}%`,
				raised
			)
		end
		local blockPrice = LuckyBlocks.priceFor(block, if typeof(buyTier) == "number" then buyTier else 1)
		price.Text = `${Format.short(blockPrice)}`
		local cash = player:GetAttribute("Cash")
		local short = typeof(cash) == "number" and cash < blockPrice
		robuxMode = short and player:GetAttribute("PaidRandomItems") == true
		price.TextColor3 = if short then Color3.fromRGB(255, 110, 90) else Color3.fromRGB(125, 255, 110)
		unlockLabel.Text = if robuxMode
			then `{utf8.char(0xE002)} {Products.DevProducts.LuckyUnlock.robux}` -- the Robux glyph
			else "Unlock!"
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

	-- Keep every held chest floating over its holder's head.
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
