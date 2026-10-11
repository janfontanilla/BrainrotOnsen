--!strict
-- Music, ambience and sound cues (ids in Shared.Config.Sounds). Music: the playlist on
-- loop, fading in, ducked under big moments. Ambience: a quiet birdsong loop (the 3D
-- water loops are placed in the world by the server: Decor, Plaza, Plots). Cues: the
-- Notify kinds the server sends (deposit, cash, good, lucky, ..., red toasts), a pop
-- for each Aura pickup that rises in pitch on a streak, a sparkle on merges, a fanfare
-- on Upgrade Buy Tier, and a click when a pad on the player's own plot is pressed.
-- Every cue plays at a slightly random pitch so repeats don't sound robotic.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Remotes = require(Shared.Remotes)

local PAD_TAG = "Pad" -- matches Plots.PAD_TAG on the server
local PAD_HEAR_RANGE = 12 -- studs: only clicks for pads the local player is standing on
local MUSIC_FADE_IN = 4 -- seconds
local DUCK_SECONDS = 2.5
local PICKUP_GAP = 0.08 -- seconds: at most one pickup pop this often

local SoundController = {}

local player = Players.LocalPlayer
local random = Random.new()

local function group(name: string): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	return g
end

local effects = group("Effects")
local musicGroup = group("Music")
local ambience = group("Ambience")

local function cue(id: string, volume: number?, pitch: number?, steady: boolean?)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or Sounds.CUE_VOLUME
	local jitter = if steady then 0 else random:NextNumber(-Sounds.PITCH_JITTER, Sounds.PITCH_JITTER)
	sound.PlaybackSpeed = (pitch or 1) * (1 + jitter)
	sound.SoundGroup = effects
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Lowers the music for a moment so a big cue stands out.
local duckSerial = 0
local function duck()
	duckSerial += 1
	local serial = duckSerial
	TweenService:Create(musicGroup, TweenInfo.new(0.25), { Volume = Sounds.MUSIC_DUCK }):Play()
	task.delay(DUCK_SECONDS, function()
		if duckSerial == serial then
			TweenService:Create(musicGroup, TweenInfo.new(1.2), { Volume = 1 }):Play()
		end
	end)
end

local KIND_CUES: { [string]: string } = {
	deposit = Sounds.DEPOSIT,
	cash = Sounds.CASH,
	good = Sounds.GOOD,
	lucky = Sounds.SPECIAL,
	newBrainrot = Sounds.SPECIAL,
	away = Sounds.CASH,
}
local KIND_DUCKS: { [string]: boolean } = { lucky = true, newBrainrot = true, away = true }
-- A lucky chest opening: LuckyBlockController plays the jingle when the brainrot is
-- revealed, so the unlock's own Notify ("lucky" / "newBrainrot") stays quiet.
local CHEST_QUIET_SECONDS = 3
local lastChestOpened = -math.huge

local function playMusic()
	if #Sounds.MUSIC == 0 then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.Volume = Sounds.MUSIC_VOLUME
	music.SoundGroup = musicGroup
	music.Parent = SoundService
	local index = 0
	local function nextTrack()
		index = index % #Sounds.MUSIC + 1
		music.SoundId = Sounds.MUSIC[index]
		music:Play()
	end
	music.Ended:Connect(nextTrack)
	musicGroup.Volume = 0
	nextTrack()
	TweenService:Create(musicGroup, TweenInfo.new(MUSIC_FADE_IN), { Volume = 1 }):Play()
end

local function playAmbience()
	if Sounds.BIRDS == "" then
		return
	end
	local birds = Instance.new("Sound")
	birds.Name = "Birds"
	birds.SoundId = Sounds.BIRDS
	birds.Volume = Sounds.BIRDS_VOLUME
	birds.Looped = true
	birds.SoundGroup = ambience
	birds.Parent = SoundService
	birds:Play()
end

local function watchPad(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local pad = instance
	local lastClick = 0
	local function click()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local now = os.clock()
		if
			now - lastClick > 0.15 -- the step and its first purchase arrive together: one click
			and root
			and root:IsA("BasePart")
			and (root.Position - pad.Position).Magnitude <= PAD_HEAR_RANGE
		then
			lastClick = now
			cue(Sounds.PAD)
		end
	end
	pad:GetAttributeChangedSignal("Pressed"):Connect(function()
		if pad:GetAttribute("Pressed") == true then
			click()
		end
	end)
	-- Every purchase on a held buy pad clicks again (BuyFlash counts them; 2026-10-11, user).
	pad:GetAttributeChangedSignal("BuyFlash"):Connect(click)
end

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- A pickup sound for Aura drops (not with Auto Collect, which credits every drop on
-- its own), at a steady pitch and at most one per PICKUP_GAP.
local function watchPickups()
	local lastAura = number("Aura")
	local lastPop = 0
	player:GetAttributeChangedSignal("Aura"):Connect(function()
		local aura = number("Aura")
		local gained = aura > lastAura
		lastAura = aura
		if not gained or player:GetAttribute("AutoCollect") == true then
			return
		end
		local now = os.clock()
		if now - lastPop < PICKUP_GAP then
			return
		end
		lastPop = now
		cue(Sounds.PICKUP, Sounds.PICKUP_VOLUME, 1, true)
	end)
end

-- Merges (fewer brainrots without new ones obtained), buy tier ups, lucky chest pickups.
local function watchProgress()
	local lastBrainrots, lastTotal = number("Brainrots"), number("TotalBrainrots")
	player:GetAttributeChangedSignal("Brainrots"):Connect(function()
		local now, total = number("Brainrots"), number("TotalBrainrots")
		if now < lastBrainrots and total <= lastTotal then
			cue(Sounds.MERGE)
		end
		lastBrainrots, lastTotal = now, total
	end)
	player:GetAttributeChangedSignal("TotalBrainrots"):Connect(function()
		lastTotal = number("TotalBrainrots")
	end)

	local lastTier = number("BuyTier")
	player:GetAttributeChangedSignal("BuyTier"):Connect(function()
		local tier = number("BuyTier")
		if tier > lastTier and lastTier > 0 then
			cue(Sounds.LEVEL_UP)
			duck()
		end
		lastTier = tier
	end)

	player:GetAttributeChangedSignal("LuckyBlock"):Connect(function()
		local held = player:GetAttribute("LuckyBlock")
		if typeof(held) == "string" and held ~= "" then
			cue(Sounds.PICKUP, Sounds.CUE_VOLUME, 0.75) -- a deeper pop: picked up a chest
		end
	end)
end

function SoundController:Start()
	playMusic()
	playAmbience()
	Remotes.event("Notify").OnClientEvent:Connect(function(message: unknown, kind: unknown)
		if typeof(message) == "string" and string.find(message, "^Buy pads now sell") then
			return -- Upgrade Buy Tier: the level-up fanfare (watchProgress) plays instead
		end
		if (kind == "lucky" or kind == "newBrainrot") and os.clock() - lastChestOpened < CHEST_QUIET_SECONDS then
			duck()
			return
		end
		if kind == nil then
			cue(Sounds.ERROR, Sounds.ERROR_VOLUME) -- red toast
		elseif typeof(kind) == "string" and KIND_CUES[kind] then
			cue(KIND_CUES[kind])
			if KIND_DUCKS[kind] then
				duck()
			end
		end
	end)
	Remotes.event("LuckyBlockOpened").OnClientEvent:Connect(function(target: unknown)
		if target == player then
			lastChestOpened = os.clock()
		end
	end)
	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		watchPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(watchPad)
	watchPickups()
	watchProgress()
end

return SoundController
