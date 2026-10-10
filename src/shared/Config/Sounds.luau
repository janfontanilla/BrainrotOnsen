--!strict
-- Sound asset IDs (Phase 7 audio). Swap any ID here; "" turns a sound off.
-- Music and water loops are Roblox-licensed library audio (DistroKid, Pro Sound
-- Effects), so they stay available; the short cues are free Creator Store clips
-- (built-in rbxasset:// sounds are "not approved" in live games and never play).

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
Sounds.DEPOSIT = "rbxassetid://9125648149" -- magic whoosh (Pro Sound Effects; 2026-10-09: the built-in swoosh.wav is "not approved" and never played)
Sounds.CASH = "rbxassetid://134810204798705" -- "Cash Register" cha-ching: Collect Cash, Cash rewards (2026-10-06, user request; was 1319346243)
Sounds.GOOD = "rbxassetid://72264591133889" -- bought brainrots, merges, rewards: "ui-pop-sound" (2026-10-06, was electronicpingshort)
Sounds.SPECIAL = "rbxassetid://4612374036" -- new brainrot, lucky chest unlock: "bling_big_diamond_pickup" (2026-10-06)
Sounds.PICKUP = "rbxassetid://7381723507" -- walking over an Aura drop: "pick_up" (2026-10-09; the bubble pop with a rising pitch sounded wonky)
Sounds.MERGE = "rbxassetid://135968996204345" -- brainrots merged: "sparkle magic sound"
Sounds.LEVEL_UP = "rbxassetid://105193542038988" -- Upgrade Buy Tier: "Cute level up"
Sounds.CHEST_OPEN = "rbxassetid://9120873624" -- the chest starts opening: "Wooden Chest Open Close Cedar Box 5" (Pro Sound Effects), soft
Sounds.CHEST_OPEN_VOLUME = 0.6
Sounds.ERROR = "rbxassetid://87519554692663" -- red toasts (not enough Cash, ...): "ui-simple-negative-error"
Sounds.CUE_VOLUME = 0.6
Sounds.PICKUP_VOLUME = 0.35
Sounds.ERROR_VOLUME = 0.4
Sounds.PITCH_JITTER = 0.05 -- every cue plays at a slightly random pitch (+-5%) so repeats don't sound robotic
Sounds.MUSIC_DUCK = 0.35 -- music drops to this share of its volume during big moments (level up, new brainrot)

-- Ambience.
Sounds.BIRDS = "rbxassetid://9119383684" -- "Sonoma Morning Birds" (Pro Sound Effects), 2D loop on every client
Sounds.BIRDS_VOLUME = 0.12
Sounds.FOUNTAIN = "rbxassetid://9120557577" -- "Water Fountain 2" (Pro Sound Effects), 3D loop at each koi pond
Sounds.FOUNTAIN_VOLUME = 0.3

return Sounds
