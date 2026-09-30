--!strict
-- Music and sound cues (ids in Shared.Config.Sounds). Music: the playlist on loop.
-- Cues: the Notify kinds the server sends (deposit, cash, good, lucky, ...) and a
-- click when a pad on the player's own plot is pressed. The 3D water loops are
-- placed in the world by the server (Decor, Plaza, Plots).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Remotes = require(Shared.Remotes)

local PAD_TAG = "Pad" -- matches Plots.PAD_TAG on the server
local PAD_HEAR_RANGE = 12 -- studs: only clicks for pads the local player is standing on

local SoundController = {}

local function cue(id: string)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Sounds.CUE_VOLUME
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local KIND_CUES: { [string]: string } = {
	deposit = Sounds.DEPOSIT,
	cash = Sounds.CASH,
	good = Sounds.GOOD,
	lucky = Sounds.SPECIAL,
	newBrainrot = Sounds.SPECIAL,
	away = Sounds.CASH,
}

local function playMusic()
	if #Sounds.MUSIC == 0 then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.Volume = Sounds.MUSIC_VOLUME
	music.Parent = SoundService
	local index = 0
	local function nextTrack()
		index = index % #Sounds.MUSIC + 1
		music.SoundId = Sounds.MUSIC[index]
		music:Play()
	end
	music.Ended:Connect(nextTrack)
	nextTrack()
end

local function watchPad(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local pad = instance
	pad:GetAttributeChangedSignal("Pressed"):Connect(function()
		if pad:GetAttribute("Pressed") ~= true then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - pad.Position).Magnitude <= PAD_HEAR_RANGE then
			cue(Sounds.PAD)
		end
	end)
end

function SoundController:Start()
	playMusic()
	Remotes.event("Notify").OnClientEvent:Connect(function(_message: unknown, kind: unknown)
		if typeof(kind) == "string" and KIND_CUES[kind] then
			cue(KIND_CUES[kind])
		end
	end)
	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		watchPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(watchPad)
end

return SoundController
