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
Sounds.PAD = "rbxassetid://6586979979" -- stepping onto any pad on your plot: "cartoon_pop" (2026-10-06, was button.wav, user: ugly)
Sounds.DEPOSIT = "rbxasset://sounds/swoosh.wav"
Sounds.CASH = "rbxassetid://1319346243" -- coins into a register: Collect Cash, purchases
Sounds.GOOD = "rbxassetid://72264591133889" -- bought brainrots, merges, rewards: "ui-pop-sound" (2026-10-06, was electronicpingshort)
Sounds.SPECIAL = "rbxassetid://4612374036" -- new brainrot, lucky chest unlock: "bling_big_diamond_pickup" (2026-10-06)
Sounds.CUE_VOLUME = 0.6

return Sounds
