--!strict
-- Sound asset IDs (Phase 7 audio). Swap any ID here; "" turns a sound off.
-- Music and water loops are Roblox-licensed library audio (DistroKid, Pro Sound
-- Effects), so they stay available; the short cues are Roblox's built-in client
-- sounds (rbxasset://) except the coins, a free Creator Store clip.

local Sounds = {}

-- Calm Japanese onsen music, played in turn on every client.
Sounds.MUSIC = {
	"rbxassetid://114959040480366", -- "Japanese Zen Garden" (DistroKid)
	"rbxassetid://125998752968951", -- "Koto Plucks" (DistroKid)
}
Sounds.MUSIC_VOLUME = 0.25

-- 3D loops placed in the world.
Sounds.WATERFALL = "rbxassetid://9120550180" -- "Waterfall Cu 1" (Pro Sound Effects)
Sounds.STREAM = "rbxassetid://9120606523" -- "Water Stream 1" (Pro Sound Effects)
Sounds.WATERFALL_VOLUME = 0.5
Sounds.STREAM_VOLUME = 0.35

-- UI cues, by what happened.
Sounds.PAD = "rbxasset://sounds/button.wav" -- stepping onto any pad on your plot
Sounds.DEPOSIT = "rbxasset://sounds/swoosh.wav"
Sounds.CASH = "rbxassetid://1319346243" -- coins into a register: Collect Cash, purchases
Sounds.GOOD = "rbxasset://sounds/electronicpingshort.wav" -- bought brainrots, merges, rewards
Sounds.SPECIAL = "rbxasset://sounds/electronicpingshort.wav" -- new brainrot, lucky block
Sounds.CUE_VOLUME = 0.6

return Sounds
