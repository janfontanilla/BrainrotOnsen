# Launch checklist and store copy (draft 2026-09-30)

## Store page

**Title:** Brainrot Onsen ♨

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
> Join the group and like the game for a Cash reward every 5 minutes!
>
> Brainrot models: "Brainrot Pack [150+]" by Agus_Fellini2.

**Genre:** Simulation (Tycoon). **Max players:** 6.

## Before publishing

- [ ] Studio API access on; saving, offline earnings and leaderboards tested
- [ ] Balance target chosen and tuned (first merge < 1 min, first Upgrade Buy Tier target)
- [ ] 6 game passes and 4 dev products created; IDs in `src/shared/Config/Products.luau`
- [ ] Group created; ID in `Products.GROUP_ID`
- [ ] Stray free-model `Workspace.Leaderboard` deleted from the place
- [ ] Phone test (frame rate, HUD fits)
- [ ] Icon (512 x 512) and 3+ thumbnails (1920 x 1080): the plot overview, the station row, a merge / lucky chest moment
- [ ] `Economy.STUDIO_*` knobs have no effect live (gated by `RunService:IsStudio()`; check anyway)

## Credits

- Brainrot models: "Brainrot Pack [150+]" by Agus_Fellini2 (Creator Store 137461628889541). Credited in the Index window and the description.
- Music: "Japanese Zen Garden", "Koto Plucks" (DistroKid, Roblox audio library). Water: Pro Sound Effects (Roblox audio library).
