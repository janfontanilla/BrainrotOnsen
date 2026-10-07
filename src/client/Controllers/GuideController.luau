--!strict
-- The tutorial guide under the Home button, shown only while the tutorial runs
-- (TutorialStep attribute < Tutorial.DONE; gone afterwards, user decision 2026-10-04):
-- the step's instruction,
-- the step's map objects flashing (Highlight), a beam from the character to the pad
-- and a bobbing arrow over it, a chime + pop when a step is done, and a quiet
-- "Skip tutorial" button from step Tutorial.SKIP_FROM (tap twice).
-- Everything is read from player attributes the server sets; the client only sends
-- intents (TutorialAction "skip").

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

local SKIP_CONFIRM_SECONDS = 4

local WHITE = Color3.new(1, 1, 1)
local OUTLINE = Color3.fromRGB(24, 24, 30)
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
		return {
			text = text,
			target = target,
			flash = def.flash,
		}
	end
	return { text = "" } -- not started, finished or skipped: nothing on screen
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
	gui.IgnoreGuiInset = true -- measured from the screen top, right under Home / Index
	Style.autoScale(gui)

	-- Under the Home / Index buttons, top centre.
	local panel = Instance.new("Frame")
	panel.Name = "Step"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 74)
	panel.Size = UDim2.fromOffset(620, 96)
	panel.Parent = gui

	local title = Style.outlined(panel, "Title", WHITE, OUTLINE, 3)
	title.Size = UDim2.new(1, 0, 0, 40)
	local titlePop = Instance.new("UIScale")
	titlePop.Parent = title

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
	local lastStep = number("TutorialStep")

	local skipArmedAt = 0

	local function setTarget(goal: Goal)
		local part = if goal.target then findTarget(goal.target) else nil
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
		setFlash(goal.flash)
		local stepNow = number("TutorialStep")
		if stepNow > lastStep and lastStep >= 1 and lastStep < Tutorial.DONE then
			-- A step was just done: chime and pop the new instruction in.
			chime:Play()
			titlePop.Scale = 0.6
			TweenService
				:Create(titlePop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
		lastStep = stepNow
		local step = number("TutorialStep")
		skip.Visible = step >= Tutorial.SKIP_FROM and step < Tutorial.DONE
		if os.clock() - skipArmedAt > SKIP_CONFIRM_SECONDS then
			skipLabel.Text = "Skip tutorial"
		end
		setTarget(goal)
	end

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
			"BuyTier",
			"MergeReady",
			"PlotIndex",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)

	-- Bob the arrow over its pad and pulse the highlights.
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		arrow.StudsOffset = Vector3.new(0, 7 + math.sin(t * 4) * 0.8, 0)
		local pulse = (math.sin(t * FLASH_SPEED) + 1) / 2
		for _, highlight in highlights do
			highlight.FillTransparency = 0.35 + 0.5 * pulse
			highlight.OutlineTransparency = 0.6 * pulse
		end
	end)

	local playerGui = player:WaitForChild("PlayerGui")
	arrow.Parent = playerGui -- a BillboardGui only draws outside a ScreenGui
	gui.Parent = playerGui
	refresh()
end

return GuideController
