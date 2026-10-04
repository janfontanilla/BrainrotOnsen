# Launch checklist and store copy (draft 2026-09-30)

Icon, thumbnail and listing brief with the Codex prompts: `docs/store-assets.md` (its description supersedes the draft below).

## Store page

**Title:** Brainrot Bathhouse ♨ Merge (renamed 2026-09-30; see `docs/store-assets.md`)

**Description:**

> Run your own hot spring for the internet's favourite Italian brainrots!
>
> ♨ Buy brainrots and watch them soak in your onsen
> 🧀 Every brainrot drops its own item: cheese, shrimp, tires, bombs, golden shoes...
> ✨ Merge 3 of a kind into the next tier and climb 20 tiers, from Tim Cheese to Los Tralaleritos
> 💰 Deposit your Aura, watch the market, and turn it into Cash
> 🎁 Open lucky chests for rare brainrots
> 🌊 Ride the river between onsens and visit your friends
>
> Join the group and like the game for a Cash reward every 10 minutes!
>
> Brainrot models: "Brainrot Pack [150+]" by Agus_Fellini2.

**Genre:** Simulation (Tycoon). **Max players:** 6.

## Before publishing

- [x] Studio API access on; saving, offline earnings and leaderboards tested
- [ ] Balance target chosen and tuned (first merge < 1 min, first Upgrade Buy Tier target)
- [x] 6 game passes and 4 dev products created; IDs in `src/shared/Config/Products.luau`
- [x] Group: PCC. Studios, ID in `Products.GROUP_ID`
- [x] Stray free-model `Workspace.Leaderboard` deleted from the place
- [ ] Phone test (frame rate, HUD fits)
- [ ] Icon (512 x 512) and 3-5 thumbnails (1920 x 1080), generated with Codex from `docs/store-assets.md`
- [ ] `Economy.STUDIO_*` knobs have no effect live (gated by `RunService:IsStudio()`; check anyway)

## Credits

- Brainrot models: "Brainrot Pack [150+]" by Agus_Fellini2 (Creator Store 137461628889541). Credited in the Index window and the description.
- Music: "Japanese Zen Garden", "Koto Plucks" (DistroKid, Roblox audio library). Water: Pro Sound Effects (Roblox audio library).
