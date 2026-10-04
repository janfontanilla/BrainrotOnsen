# Launch plan (2026-10-04)

The path from today to a public Brainrot Bathhouse, in order. Each phase lists what to build, how it gets checked, and when it counts as done. `PROGRESS.md` "Next up" points here; tick phases off there as they finish.

## Ground rules (user decisions)

- **Offline earnings stay at 100%, uncapped, for every tier.** A player's brainrots work around the clock. Pacing is tuned with costs, never by cutting offline income.
- **Optimize for engagement and retention.** Every session should end with something bought and a goal the player can afford next time they log in. New players should learn the loop in under 3 minutes without reading anything long.
- **Order the user asked for:** tutorial, model fits, Studio checks, phone check, publish, play-test on another account, thumbnail 4.

## What changed from the user's order, and why

| Change | Why |
|---|---|
| **Phase 0 (balance) comes first** | With offline always on, a free player owns a tier 20 on day ~1.5 (sim baseline, 2026-10-01). Once the game is public, players hold the brainrots they earned under the old numbers, so the economy has to be right before launch. The tutorial's "first upgrade" step also depends on the first upgrade's cost. |
| **Model fits and Studio checks share one Studio session** | Both need Rojo connected, Play mode and screen captures. Doing them together saves a setup round. |
| **Publish privately, test on the alt, then go public** | Same order you asked for, but the alt-account test happens while the game is still private, so a bug found there never reaches real players. |
| **Thumbnail 4 runs in parallel and doesn't block publishing** | It only needs Gemini and a resize. Roblox accepts 4 thumbnails; the fifth can be added any time, even after launch. |

```
Phase 0 Balance ──► Phase 1 Tutorial + goals ──► Phase 2+3 Studio session (model fits, checks)
                                                         │
Phase 5 Thumbnail 4 (parallel, any time) ─────────────────┤
                                                         ▼
                              Phase 4 Phone check ──► Phase 6 Publish (private)
                                                         ▼
                              Phase 7 Alt-account play-test ──► Phase 8 Go public + launch week
                                                                          ▼
                                                              Phase 9 Retention updates
```

---

## Phase 0: Balance with offline always on (done 2026-10-04)

**Problem.** Offline earnings are ~5x active play (20 h/day at 100%), and every tier costs about the same multiple of the income it brings. So every tier takes about the same time, and the whole ladder collapses into a day or two. A flat `BUY_TIER_UPGRADE_MULTIPLIER` can't make the first upgrade take under 10 minutes and tier 20 take 2.5 weeks at the same time.

**Steps**

1. **Make `tools/economy_sim.py` fast enough for multi-week runs.** Skip ahead to the next moment something becomes affordable instead of ticking every 10 s, and keep 2 s ticks only for the first hour. Target: one 120-day free-player run in under 2 s.
2. **Add a per-tier growth to the Upgrade Buy Tier cost.** New constant `Economy.BUY_TIER_UPGRADE_GROWTH`; the cost becomes `basePrice(next) x BUY_TIER_UPGRADE_MULTIPLIER x GROWTH^(buyTier - 1)` (one line in `Economy.buyTierUpgradeCost`). This makes early tiers fast and late tiers slow. Confirm with the sim that constants alone can't hit both targets, and show the numbers.
3. **Reference pace (user's own Capybara Onsen play, 2026-10-04):** many tiers in the first few days, then from about tier 12-13 less than one new tier per day, getting slower. Match this shape.
4. **Sweep the levers** in the order the prompt gives: upgrade multiplier + growth, `PRICE_GROWTH`, processor constants, lucky block price. Targets (user decision 2026-10-04: an expanding curve, quick to hook, then slower and slower so the passes are worth buying):
   - first merge under 1 min, tutorial done in under 3 min, first Upgrade Buy Tier under 10 min (free, 1,000 starting Cash);
   - each buy tier step takes about 1.6x longer than the one before (real time, a free player logging in daily): ~5 min for tier 2, ~1 h by tier 7, ~10 h by tier 12, ~2 days by tier 16, about a week for the last steps;
   - free player: tier 12 around day 2-3 (Capybara-like start), tier 16 around day 8-14, tier 20 around day 50-60;
   - x7 player owns a tier 20 after **a week or more** (user decision 2026-10-04), about 8 days;
   - **retention target:** in the mid game, one night's offline Aura pays for about one Upgrade Buy Tier, so "come back tomorrow" always has a reward;
   - no more than ~2 h of play without something to buy, and no step more than ~4x longer than the one before.
5. **Report the free / x7 / whale curves and the Cash pack values.** The free-to-x7 ratio will come out near 7x, because every cost is in Cash and the pass multiplies all Cash.
   - **Cash packs sized to the next upgrade**, not to the highest tier: S = ~15%, M = ~60%, L = ~150% of the current Upgrade Buy Tier cost (`Economy.cashPackAmount` reads the upgrade cost; one formula change). Each pack then means "this upgrade, now", and none skips more than about one step.
   - **Finish Now:** tune the processor so the pile deposited after a night takes ~30-60 min to process in the mid game. Finish Now (19 Robux) is then a natural small buy at login, and never skips more than that backlog.
6. **Group reward every 10 minutes** (`GROUP_REWARD_INTERVAL = 600`). Update the group sign text in `server/Decor.luau` ("every 5 minutes"), `docs/store-assets.md` and `docs/launch.md` to match.
7. **Apply and document.** Change Config only after you approve the table. Then: `ConfigCheck` invariants, stylua / selene / rojo build, the design doc, CLAUDE.md "Rules", PROGRESS.

**Done when:** you approve the milestone table, the new config is in, and the sim's numbers are recorded in `PROGRESS.md`.

---

## Phase 1: Tutorial and the "next goal" system (done 2026-10-04)

The tutorial teaches the loop once. A goal tracker keeps pointing at the next thing to do forever after. Together they're the main engagement and retention work before launch.

### 1a. Guided first session (TutorialService + TutorialController)

| Step | Instruction (short, top of screen) | Points at | Advances when (server event) |
|---|---|---|---|
| 1 | "Buy your first brainrot!" | Buy 1 pad | a buy succeeds |
| 2 | "Walk over the drops to collect Aura" | the pool | 3 drops collected (5 felt slow: 1 brainrot drops every 7 s) |
| 3 | "Deposit your Aura" | Deposit stall | a deposit succeeds |
| 4 | "Collect your Cash" | Collect Cash pad | Cash collected |
| 5 | "Buy 2 more, then press Merge!" | Buy 1 pad, then Merge! | a merge happens |
| 6 | "Done! Next goal: Upgrade Buy Tier" (progress bar starts filling) | hands over to the goal tracker | - |

- **Server owns progress.** New `Data` field `tutorialStep` (0 = not started, 6 = done) in `DataService` TEMPLATE. Existing profiles with `totalBrainrots > 0` are marked done on load, so current players never see it. `TutorialService.advance(player, "deposit")` is called from the services that already handle each action (ShopService, DropService, ProcessorService). No client trust.
- **Client shows the way.** A `Beam` from the character to the target pad (works on every device). A bobbing arrow above the pad. One instruction line in the HUD style (`Style.outlined`). **Runs by default for every new player** (user decision 2026-10-04). A small grey "Skip tutorial" in a corner from step 2 on, with a confirm ("Skip the tutorial? You can follow the Next goal line instead."); skipping hands straight to the goal tracker, so Deposit and Collect Cash are still pointed at. The processor upgrade is taught by the goal tracker when the queue backs up, not by the tutorial (a stat bump is a weak ending; the first Upgrade Buy Tier is the payoff). Each finished step plays a cheerful sound and shows a green toast.
- **Never stuck.** Each step checks it can still be done: if the player has no Cash for step 5, the step gives the 2 brainrots' Cash. If the player leaves mid-tutorial, the next session resumes at the same step.
- **Studio knob:** `Economy.STUDIO_FORCE_TUTORIAL` (false = off) restarts the tutorial on join. Test with `STUDIO_STARTING_CASH = 0` so the flow matches a real new player.

### 1b. Next-goal tracker (retention)

- A permanent line under the Cash counter: **"Next: Upgrade Buy Tier · 32K / 50K"** with a progress bar. Tapping it turns the beam on for that pad.
- Goal order: Upgrade Buy Tier, otherwise the processor when its queue is backing up, otherwise "Merge! (3 ready)", otherwise "Collect your drops (cap reached)".
- **Show what a pass would do (the main conversion lever):** under the goal, a small line "x7 Cash: ready in 3 h instead of 21 h" for the next Cash pass the player doesn't own, tapping opens the pass prompt. Shown only from the first slow step (about buy tier 8, when a step first takes longer than a session), never in the first session, so the hook comes first.
- **Offers at real friction points, once each, never as pop-ups mid-action:** Auto Collect when the drop cap stops production ("Your bathhouse stopped: 50 drops waiting"); Finish Now at login when the queue would take more than 20 min; x2 Cash (40 Robux, the cheapest entry) at the first step that takes longer than a session; the bigger Cash passes on the goal line after that.
- **Welcome back:** the existing "away" popup is followed by a goal of "Deposit your 1.2B Aura" with the beam to the stall. The offline loop only pays once the pile is deposited, and new players won't know that.

### 1c. Measure it (Roblox Analytics, free)

- `AnalyticsService:LogOnboardingFunnelStepEvent` for each tutorial step. The Creator Dashboard then shows exactly where new players drop off.
- `LogFunnelStepEvent` for the progression funnel (buy tiers 2, 5, 10, 15, 20).
- `LogEconomyEvent` for Cash sources (processor, group reward, packs) and sinks (buys, upgrades, lucky blocks), to check balance on real data.

**Done when:** a fresh Studio profile finishes the tutorial in under 3 min without help, existing profiles skip it, the goal tracker always shows something, and the analytics calls fire in Studio (they log a warning there and record only live).

---

## Phase 2 + 3: One Studio session (model fits and checks) (done 2026-10-04, except the dev product test purchases)

Start `rojo serve`, reconnect the plugin, confirm the sync, enter Play. Captures one at a time (see PROGRESS "How to work here").

### Phase 2: Model fits (play-test item "some models look off")

- **Check every tier in a bath.** Use `execute_luau` to give the test profile one of each tier, then capture each bath from the front and from the side. Tiers 2, 3, 6, 7, 9-11 and 19 have never been checked; check the rest again too.
- **Pass if:** the model sits at the water, faces the pool, doesn't poke into the next bath at its size, and its label is clear above its head. The rise animation also has to look right.
- **Fix:** add a small per-tier table in `shared/Models.luau` (`PACK_FIXES = { [tier] = { yaw, sink, scale } }`) applied after the automatic fit, so each odd model gets one line instead of special cases in code.
- Also check the Index thumbnails and the lucky block reveal, which use the same models.

### Phase 3: Checks that are coded but not seen in Studio

- [ ] Processor controls (info board, upgrade pad, Finish Now) on the +x side wall
- [ ] Smaller lucky chest labels, shown only within 25 studs
- [ ] Voxel drop items (Drop1..Drop20) floating down to the pool
- [ ] Sounds: music playlist, water loops, cues
- [ ] Index grid, silhouettes and the "New brainrot!" popup
- [ ] Phase 5 items still unticked in PROGRESS (passes, dev products, Robux pads, friend / Premium boosts, leaderboard): test each and tick it. Buy every dev product once through Studio's free test purchase prompt and check the receipt in `data.receipts` and the Cash credited (no real-money purchase is planned)
- [ ] Phase 0 numbers feel right in play (first merge, first upgrade)
- [ ] Tutorial and goal tracker (Phase 1) in real play
- [ ] Every `Economy.STUDIO_*` knob is off or gated by `RunService:IsStudio()`

**Done when:** every box is ticked or has a fix logged, and the captures are saved for the design doc.

---

## Phase 4: Phone check

1. **Studio Device Emulator:** iPhone SE (smallest), a mid Android, an iPad. Check that the HUD, the tutorial line, the goal tracker, the Index and the lucky block panel fit and can be tapped (buttons at least 44 px), with nothing under the Roblox top bar or the thumbstick.
2. **Performance:** Studio's MicroProfiler plus `Stats` on the emulator. Targets: 60 fps on desktop, steady 30+ on a mid phone, memory under ~1.5 GB with 6 plots full. If it's slow, the map-polish roadmap Phase 8 trims come first (particle counts, distant decor, shadows on small parts).
3. **A real phone** joins the private published place in Phase 6 (the Roblox app can open private games you own).

**Done when:** no layout breaks on the three emulated devices and the real phone holds its frame rate.

---

## Phase 5: Thumbnail 4 (in parallel)

- **The problem:** Gemini returned a 1024 x 1024 square. Cropping a square to 16:9 cuts off the title and the chest.
- **Fix the prompt:** make `docs/gemini-prompts/4-thumbnail-lucky-chest.txt` open with a strict size line ("Landscape 16:9, 1920 x 1080, much wider than tall; never square"), put the scene left and right of the centre, and add a matching line to `fixes.txt` ("Make it 16:9 landscape, wider, same scene").
- **You** regenerate the image in a new Gemini chat and send it. Claude resizes it to 1920 x 1080 (< 3 MB) as `assets/store/thumbnail-4-lucky-chest.jpg`.
- **Fallback:** publish with thumbnails 1, 2, 3 and 5 and add 4 later.

---

## Phase 6: Publish (private first)

Following `docs/launch.md`:

1. Update the store text (`docs/store-assets.md` + `docs/launch.md`) for the 10-minute group reward and anything the tutorial adds.
2. Upload the icon and thumbnails (1, 2, 3, 5, and 4 when ready), paste the title and description, set the genre (Simulation) and max players (6).
3. Fill in the maturity and compliance questionnaire.
4. Check that the game passes and dev products are on sale at the planned Robux prices.
5. Publish with visibility **Private**.

**Done when:** the place is published privately with the full store page.

---

## Phase 7: Play-test on another account

Test on an alt account with no passes, in the private place. Use a timer and write the numbers down.

| Check | Target |
|---|---|
| Tutorial finished, without help | under 3 min |
| First merge | under 1 min |
| First Upgrade Buy Tier | under 10 min |
| Leave for 1 h or more, rejoin | "away" popup, Aura pile shown, the goal says deposit, depositing works |
| Data | Cash, brainrots, processor level, tutorial step all kept |
| Group reward | claim works, and the next one is 10 min later |
| Leaderboards | the alt appears on all three pavilions |
| Phone | the same flow on the real phone |

Fix what it finds, then run it again if anything in the flow changed.

**Done when:** every row passes on a clean alt account.

---

## Phase 8: Go public and launch week

- Set visibility to **Public**.
- **Day 1-3:** read the Developer Console (server and client errors) daily, the onboarding funnel (which tutorial step loses people) and the Economy dashboard.
- **Day 7:** D1 / D7 retention, average session length, conversion per pass. Raise any balance change through the sim first. Raising future costs is safe once players exist; lowering rewards they already have is not.
- Hotfixes follow the usual rule: `stylua`, `selene`, `rojo build`, Studio check, publish.

---

## Phase 9: Retention updates (after launch, ranked by expected effect)

1. **Experience notifications:** "Your brainrots made 1.2B Aura while you were away". The game's whole design is offline income, so this is the strongest pull-back. Needs the opt-in prompt and a template on the Creator Dashboard.
2. **Daily login streak:** a free lucky block on day 1, Cash on later days, a better chest on day 7.
3. **Favourite reminder** after the first Upgrade Buy Tier: a one-time popup asking players to favourite the game (check first whether Roblox offers a native favourite prompt for experiences).
4. **Index rewards:** Cash for discovering each new tier, and a bonus for completing rows.
5. **Weekend events:** double market luck, a guaranteed Cosmic chest hour.
6. **Lucky block polish** (you said it could be polished; what to change still needs deciding), idle animations, bath steam and splashes, more tiers past 20.

---

## Questions for you before Phase 0 and Phase 1

1. Is the target still **tier 20 in ~17.5 days for an x7 player at 4 h/day**, with free players taking ~7x as long (structural, see Phase 0)?
2. ~~Skippable?~~ Answered 2026-10-04: runs by default, skippable from step 2 with a confirm.
3. ~~Real purchase on the alt?~~ Answered 2026-10-04: no. Purchases are checked in Studio instead (Studio purchase prompts are free test purchases that run the real `ProcessReceipt` with the real product IDs; see Phase 3).
