--!strict
-- The tutorial, hosted by Tung Tung Tung Sahur (2026-10-06, user idea; 2026-10-09 the
-- user's pick: "Tung Tung Tung Sahur" by ATMnou, free Creator Store model 138151705692565,
-- one mesh rebuilt here as a Part + SpecialMesh so no asset has to live in the place): he stands in the bottom right corner above
-- Total Brainrots, bobbing in a little window, and talks
-- in a speech bubble: one short, punchy line per step, a quick cheer ("Nice!",
-- "Awesome!") with a chime and a hop when a step is done, a few explaining lines
-- before some steps (Tutorial step `intro`: the market board, the processor sign), and
-- "Good luck! Tung Tung Sa-out!" with a wave at the end, then he leaves. While a step is on, its map objects flash (Highlight), a
-- beam runs from the character to the pad and an arrow bobs over it. A quiet "Skip"
-- shows from step Tutorial.SKIP_FROM (tap twice). Shown only while the tutorial runs
-- (TutorialStep attribute < Tutorial.DONE); the client only sends TutorialAction "skip".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Remotes = require(Shared.Remotes)
local Tutorial = require(Shared.Tutorial)
local Style = require(script.Parent.Parent.Style)

local player = Players.LocalPlayer

-- The host mesh (from the Creator Store model above): ids and its native size.
local HOST_MESH = "rbxassetid://82464974337955"
local HOST_TEXTURE = "rbxassetid://105445253181063"
local HOST_MESH_SIZE = Vector3.new(0.397, 0.997, 0.410)
local HOST_HEIGHT = 4.75 -- studs (only the proportions matter in the window)
local CHEER_SECONDS = 1.3 -- the cheer stays this long before the next instruction
local FINISH_SECONDS = 5 -- the last line stays this long, then the host leaves
local SKIP_CONFIRM_SECONDS = 4

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(40, 32, 26)
local OUTLINE = Color3.fromRGB(24, 24, 30)
local CHEER_COLOR = Color3.fromRGB(40, 160, 40)
local GREY, GREY_DARK = Color3.fromRGB(150, 150, 160), Color3.fromRGB(50, 50, 60)
local BEAM_COLOR = Color3.fromRGB(255, 236, 90)
local FLASH_COLOR = Color3.fromRGB(255, 226, 60)
local FLASH_SPEED = 5 -- radians per second of the highlight's pulse

local GuideController = {}

type Goal = {
	text: string,
	target: string?,
	flash: { string }?, -- map objects to highlight
}

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- While the host explains something before a step (its `intro`), this is shown instead.
local introGoal: Goal? = nil

local function currentGoal(): Goal?
	if introGoal then
		return introGoal
	end
	local step = number("TutorialStep")
	local def = Tutorial.STEPS[step]
	if not def then
		return nil
	end
	local target = def.target
	local text = def.text
	if def.id == "merge" and player:GetAttribute("MergeReady") ~= true and def.altTarget then
		target = def.altTarget
	elseif def.count and def.count > 1 then
		text = `{text} ({number("TutorialCount")}/{def.count})`
	end
	return { text = text, target = target, flash = def.flash }
end

-- A part or model by name in the player's own plot.
local function findObject(name: string): Instance?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and typeof(index) == "number" and plots:FindFirstChild(`Plot{index}`)
	return plot and plot:FindFirstChild(name, true)
end

local function findTarget(name: string): BasePart?
	local part = findObject(name)
	return if part and part:IsA("BasePart") then part else nil
end

function GuideController:Start()
	local tutorialAction = Remotes.event("TutorialAction")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Guide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the Index and lucky block windows
	gui.IgnoreGuiInset = true
	Style.autoScale(gui)

	-- The host, bottom right above Total Brainrots: Tung in a window, a speech bubble
	-- to his left.
	local host = Instance.new("Frame")
	host.Name = "Host"
	host.AnchorPoint = Vector2.new(1, 1)
	host.Position = UDim2.new(1, -10, 1, -64)
	host.Size = UDim2.fromOffset(560, 190)
	host.BackgroundTransparency = 1
	host.Visible = false
	host.Parent = gui
	local hostPop = Instance.new("UIScale")
	hostPop.Parent = host

	local view = Instance.new("ViewportFrame")
	view.Name = "Tung"
	view.AnchorPoint = Vector2.new(1, 1)
	view.Position = UDim2.fromScale(1, 1)
	view.Size = UDim2.fromOffset(170, 190)
	view.BackgroundTransparency = 1
	view.Parent = host
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local tung = Instance.new("Model")
	tung.Name = "TungHost"
	local scale = HOST_HEIGHT / HOST_MESH_SIZE.Y
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.Size = HOST_MESH_SIZE * scale
	body.CFrame = CFrame.new(0, body.Size.Y / 2, 0) -- pivot at the feet, face toward -Z
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = HOST_MESH
	mesh.TextureId = HOST_TEXTURE
	mesh.Scale = Vector3.one * scale
	mesh.Parent = body
	body.Parent = tung
	tung.WorldPivot = CFrame.new()
	tung.Parent = view
	local _, tungSize = tung:GetBoundingBox()
	local tungMid = Vector3.new(0, tungSize.Y / 2, 0)
	camera.CFrame = CFrame.lookAt(tungMid + Vector3.new(0, 0.4, -tungSize.Y * 2.1), tungMid)

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.AnchorPoint = Vector2.new(1, 0.5)
	bubble.Position = UDim2.new(1, -165, 0.45, 0)
	bubble.Size = UDim2.fromOffset(370, 96)
	bubble.BackgroundColor3 = WHITE
	bubble.Parent = host
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = bubble
	local bubbleStroke = Instance.new("UIStroke")
	bubbleStroke.Color = OUTLINE
	bubbleStroke.Thickness = 4
	bubbleStroke.Parent = bubble
	local tail = Instance.new("Frame") -- the little point toward Tung
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(1, 2, 0.6, 0)
	tail.Size = UDim2.fromOffset(18, 18)
	tail.Rotation = 45
	tail.BackgroundColor3 = WHITE
	tail.BorderSizePixel = 0
	tail.ZIndex = 0
	tail.Parent = bubble
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(16, 10)
	line.Size = UDim2.new(1, -32, 1, -20)
	line.Font = Style.FONT
	line.TextScaled = true
	line.TextWrapped = true
	line.TextColor3 = INK
	line.ZIndex = 2
	line.Parent = bubble
	local lineSize = Instance.new("UITextSizeConstraint")
	lineSize.MaxTextSize = 30
	lineSize.Parent = line

	local skip, skipLabel = Style.button(host, "Skip", GREY, GREY_DARK)
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -170, 0.45, 56)
	skip.Size = UDim2.fromOffset(130, 32)
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

	-- Flashing highlights on the step's map objects (one Highlight each).
	local highlights: { [string]: Highlight } = {}
	local function setFlash(names: { string }?)
		local wanted: { [string]: boolean } = {}
		for _, name in names or {} do
			wanted[name] = true
			local existing = highlights[name]
			local object = findObject(name)
			if object and (not existing or existing.Adornee ~= object) then
				if existing then
					existing:Destroy()
				end
				local highlight = Instance.new("Highlight")
				highlight.Name = "GuideFlash"
				highlight.FillColor = FLASH_COLOR
				highlight.OutlineColor = WHITE
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Adornee = object
				highlight.Parent = object
				highlights[name] = highlight
			end
		end
		for name, highlight in highlights do
			if not wanted[name] then
				highlight:Destroy()
				highlights[name] = nil
			end
		end
	end

	local chime = Instance.new("Sound")
	chime.Name = "StepDone"
	chime.SoundId = Sounds.GOOD
	chime.Volume = Sounds.CUE_VOLUME
	chime.Parent = gui

	local function setTarget(target: string?)
		local part = if target then findTarget(target) else nil
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

	local function pop()
		hostPop.Scale = 0.85
		TweenService:Create(hostPop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end

	local function say(text: string, cheer: boolean)
		line.Text = text
		line.TextColor3 = if cheer then CHEER_COLOR else INK
		pop()
	end

	local lastStep = number("TutorialStep")
	local cheeringUntil = 0
	local skipArmedAt = 0
	local leaving = false
	local waving = false
	local introPlayed: { [number]: boolean } = {}
	local introPlaying = false
	local refresh: () -> ()

	-- Says a step's intro lines one by one, each pointing at its thing on the map.
	local function playIntro(step: number)
		introPlaying = true
		introPlayed[step] = true
		for _, item in Tutorial.STEPS[step].intro or {} do
			if number("TutorialStep") ~= step then
				break
			end
			introGoal = { text = item.text, target = item.target, flash = item.flash }
			say(item.text, false)
			refresh()
			task.wait(item.seconds)
		end
		introGoal = nil
		introPlaying = false
		refresh()
		pop()
	end

	function refresh()
		local step = number("TutorialStep")
		local goal = currentGoal()
		local justDone = step > lastStep and lastStep >= 1 and lastStep < Tutorial.DONE
		lastStep = step
		if justDone then
			chime:Play()
			if goal then
				-- A quick cheer, then the next instruction.
				say(Tutorial.CHEERS[math.random(1, #Tutorial.CHEERS)], true)
				cheeringUntil = os.clock() + CHEER_SECONDS
				task.delay(CHEER_SECONDS, function()
					cheeringUntil = 0
					refresh()
					pop()
				end)
			else
				-- Finished: the last line, then the host waves off.
				say(Tutorial.FINISH, true)
				leaving = true
				waving = true
				task.delay(FINISH_SECONDS, function()
					host.Visible = false
					leaving = false
					waving = false
				end)
			end
		end
		if goal then
			host.Visible = true
			if os.clock() >= cheeringUntil then
				line.Text = goal.text
				line.TextColor3 = INK
				local def = Tutorial.STEPS[step]
				if not introGoal and not introPlaying and def and def.intro and not introPlayed[step] then
					-- Deferred: started inline, this refresh would finish after the intro's
					-- first line and put the step's own flash and beam back over it.
					introPlaying = true
					task.defer(playIntro, step)
				end
			end
		elseif not leaving then
			host.Visible = false
		end
		setFlash(if goal then goal.flash else nil)
		setTarget(if goal then goal.target else nil)
		skip.Visible = goal ~= nil and step >= Tutorial.SKIP_FROM
		if os.clock() - skipArmedAt > SKIP_CONFIRM_SECONDS then
			skipLabel.Text = "Skip"
		end
	end

	skip.Activated:Connect(function()
		if os.clock() - skipArmedAt <= SKIP_CONFIRM_SECONDS then
			tutorialAction:FireServer("skip")
			skipArmedAt = 0
		else
			skipArmedAt = os.clock()
			skipLabel.Text = "Sure?"
		end
	end)

	for _, name in { "TutorialStep", "TutorialCount", "BuyTier", "MergeReady", "PlotIndex" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)

	-- Bob the arrow, pulse the highlights, and keep Tung bobbing in his window.
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		arrow.StudsOffset = Vector3.new(0, 7 + math.sin(t * 4) * 0.8, 0)
		local pulse = (math.sin(t * FLASH_SPEED) + 1) / 2
		for _, highlight in highlights do
			highlight.FillTransparency = 0.35 + 0.5 * pulse
			highlight.OutlineTransparency = 0.6 * pulse
		end
		if host.Visible then
			-- Bob, hop while cheering, rock side to side as a wave goodbye at the end.
			local size = tungSize.Y
			local hop = if os.clock() < cheeringUntil then math.abs(math.sin(t * 12)) * 0.08 * size else 0
			local rock = if waving then math.sin(t * 9) * 0.25 else 0
			tung:PivotTo(
				CFrame.new(0, math.sin(t * 2.2) * 0.025 * size + hop, 0)
					* CFrame.Angles(0, math.sin(t * 1.1) * 0.2, rock)
			)
		end
	end)

	local playerGui = player:WaitForChild("PlayerGui")
	arrow.Parent = playerGui -- a BillboardGui only draws outside a ScreenGui
	gui.Parent = playerGui
	refresh()
end

return GuideController
