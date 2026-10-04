# Prompt: balance the progression so tier 20 takes about 2.5 weeks

Paste everything below the line into a fresh Claude Opus 5.5 session started in `C:\dev\BrainrotOnsen` (so it can read the repo). It does analysis and simulation first, and changes `src/shared/Config/` only after the numbers are agreed.

---

You are the economy designer for **Brainrot Bathhouse**, a Roblox merge tycoon (code folder "BrainrotOnsen"). Read `CLAUDE.md` first (rules and module map), then `PROGRESS.md` "Handoff (start here)". The design doc is the source of truth for rules (link in CLAUDE.md; read it with the Claude Docs tools, never web-fetch it). All tunable numbers live in `src/shared/Config/` (`Economy`, `Tiers`, `LuckyBlocks`, `Products`); read those files before you start. Do not edit anything until step 5.

## Goal

Tune the economy so that a **typical paying-light player who owns the x7 Cash game pass** buys / owns a **tier 20 brainrot after about 2.5 weeks (~17.5 days)** of normal play. State your play-time assumption explicitly and justify it (my default guess: 3 to 4 hours of active play per day plus the game running offline the rest of the day; offline earnings are 100% and uncapped, so account for them). Also produce the same curve for a **free player (no passes)** and for a **x12 Cash + 2x Aura + Auto Collect** whale, so I can see how far apart they are. Free players should reach tier 20 in roughly 3 to 4 times as long as the x7 player (tell me if you recommend a different ratio).

Interpretation of "hit tier 20": the player's highest owned brainrot tier is 20 (most likely by merging, or by Upgrade Buy Tier + buying). Say which milestone you model and also report when the **buy tier** reaches 20.

Also keep the early game fast and fun: first merge in under 1 minute, first Upgrade Buy Tier in under 10 minutes for a brand-new player with 1,000 starting Cash and no passes.

## The game in one paragraph

Cash buys brainrots on the buy pads. Each brainrot drops its tier's Aura item every 7 s (50 uncollected drops per plot max; at the cap production stops). Walking over drops turns them into Aura (Auto Collect pass does it automatically and never fills the cap). Aura is deposited at the deposit stall as Aura x market multiplier (server-wide, random 0.50x to 1.50x, rerolled every 30 s, so the average is ~1.0x) into a processor queue. The processor converts queued Aura to Cash 1:1 at a rate in Aura per second (level 1 = 20/s, each level x1.35, upgrade cost 100 x 1.45^(level-1) Cash). Cash waits on the Collect Cash pad; the Cash multiplier pass is applied when the player collects. Merge! merges every 3 of one tier into 1 of the next tier, cascading. Plot holds 80 brainrots. Upgrade Buy Tier permanently raises the tier the buy pads sell and resets price scaling. Offline: brainrots earn at 100% forever straight into the Aura counter (ignores the drop cap) and the processor keeps processing.

## Things the code does that are easy to model wrong (checked 2026-10-01)

- **Offline Aura is not offline Cash.** `DataService.applyOffline` credits offline Aura to the Aura counter only; it is never deposited. The processor only keeps working through the queue that existed at logout. On return the player deposits the pile and it drains at the processor rate. Model this exactly; with long offline stretches the processor rate is likely the binding constraint.
- **Offline Aura ignores the 2x Aura pass and Premium** (`DataService.auraPerSecond` uses raw tier Aura). The Cash pass still applies when the processed Cash is collected.
- **Processor cost outgrows its rate** (cost x1.45 per level, rate x1.35). Before choosing levers, report which constraint binds at each stage (buy prices, Upgrade Buy Tier cost, processor rate, drop cap / collection) and pick levers that act on the binding one.
- **Drop cap with a full plot:** 80 brainrots fill the 50-drop cap in ~4.4 s. Without Auto Collect, every trip to the deposit stall, buy pads or Merge! stops production almost at once. Derive collection efficiency from how the active player splits time between the pool and the stations rather than as a flat number.
- **Market timing:** a player can wait for a high market roll before depositing. Model a naive depositor (average 1.0x) and a patient one (e.g. deposits only at >= 1.2x, average ~1.35x) and report both.
- **Lucky block value:** a block costs unlock-tier Aura x 800 (= 40 buys of that tier) but its expected contents are worth about 1 brainrot of that tier, so "expected value beats price" never holds. Its real value is reaching tiers above the buy tier: compare its price with the cheapest alternative route to the same tier (Upgrade Buy Tier, or 3^k merges from the buy tier).
- **Free vs paid ratio depends on the curve's shape.** If income grows exponentially, a constant x7 Cash multiplier saves a roughly constant amount of time and the free / x7 ratio tends to 1; if costs outgrow income it tends to 7. Say which regime the economy is in and what that means for the 3 to 4x target.
- **Known gap:** the `BUY_TIER_UPGRADE_MULTIPLIER` comment says the first upgrade takes ~12 min with today's numbers; the target below is under 10 min.

## Current numbers (from the code, 2026-10-01)

Economy: `DROP_INTERVAL` 7 s, `DROP_CAP` 50, `BASE_PRICE_MULTIPLIER` 20 (base buy price = aura per drop x 20), `PRICE_GROWTH` 1.005 (unit price x 1.005 per brainrot bought at the current buy tier), `BUY_TIER_UPGRADE_MULTIPLIER` 500 (upgrade cost = next tier's base price x 500), `MERGE_COUNT` 3, `PROCESSOR_BASE_RATE` 20, `PROCESSOR_RATE_GROWTH` 1.35, `PROCESSOR_UPGRADE_BASE_COST` 100, `PROCESSOR_COST_GROWTH` 1.45, `STARTING_CASH` 1,000, `OFFLINE_RATE` 1.0, market 0.5 to 1.5 every 30 s, `LUCKY_BLOCK_PRICE_MULTIPLIER` 800, lucky block spawns after a random 40 to 100 s of production (up to 5 floating, a player holds one), `GROUP_REWARD_INTERVAL` 300 s, `GROUP_REWARD_MIN` 10,000, `GROUP_REWARD_MULTIPLIER` 25.

Rules that must stay true: tier value is roughly 4x the tier below and must always be more than 3x so merging pays; two currencies only (Aura, Cash); no caps on either; 80 spots; Buy 100 always auto-merges, Buy 1/5/25 only merge when the onsen would overflow; the Cash multiplier passes do not stack (highest applies); friend boost +10% per friend (max +50%) on processor Cash, Premium +10% Aura.

### Tiers, buy prices and Upgrade Buy Tier costs (current)

| Tier | Name | Aura/drop | Buy price (x20) | Upgrade Buy Tier to this tier (x500) |
|---|---|---|---|---|
| 1 | Tim Cheese | 1 | 20 | - |
| 2 | Trippi Troppi | 5 | 100 | 50K |
| 3 | Boneca Ambalabu | 25 | 500 | 250K |
| 4 | Frigo Camelo | 90 | 1.8K | 900K |
| 5 | Lirili Larila | 300 | 6K | 3M |
| 6 | Chimpanzini Bananini | 1.1K | 22K | 11M |
| 7 | Brr Brr Patapim | 4K | 80K | 40M |
| 8 | Bombombini Gusini | 15K | 300K | 150M |
| 9 | Cappuccino Assassino | 60K | 1.2M | 600M |
| 10 | Ballerina Cappuccina | 235K | 4.7M | 2.35B |
| 11 | Bombardiro Crocodilo | 900K | 18M | 9B |
| 12 | Tralalero Tralala | 4M | 80M | 40B |
| 13 | Tung Tung Tung Sahur | 16M | 320M | 160B |
| 14 | La Vaca Saturno Saturnita | 64M | 1.28B | 640B |
| 15 | Glorbo Fruttodrillo | 250M | 5B | 2.5T |
| 16 | Cocofanto Elefanto | 1B | 20B | 10T |
| 17 | Odin Din Din Dun | 4B | 80B | 40T |
| 18 | Girafa Celestre | 16B | 320B | 160T |
| 19 | Tigrrullini Watermellini | 64B | 1.28T | 640T |
| 20 | Los Tralaleritos | 250B | 5T | 2.5Qa |

(Buy 5 / 25 / 100 cost n x the current unit price, no discount.)

### Lucky blocks (current)

Cash only, never Robux. Type is a weighted random roll (not tied to progress). Contents: unlock tier -1 / 0 / +1 / +2 at 60 / 30 / 9 / 1 percent (capped at tier 20). Price = unlock tier's Aura x 800.

| Block | Weight | Unlock tier | Price | Contents |
|---|---|---|---|---|
| Wood | 30 | 3 | 20K | T2 60%, T3 30%, T4 9%, T5 1% |
| Stone | 22 | 5 | 240K | T4 60%, T5 30%, T6 9%, T7 1% |
| Iron | 16 | 7 | 3.2M | T6 60%, T7 30%, T8 9%, T9 1% |
| Gold | 11 | 9 | 48M | T8 60%, T9 30%, T10 9%, T11 1% |
| Diamond | 8 | 11 | 720M | T10 60%, T11 30%, T12 9%, T13 1% |
| Emerald | 6 | 13 | 12.8B | T12 60%, T13 30%, T14 9%, T15 1% |
| Ruby | 4 | 15 | 200B | T14 60%, T15 30%, T16 9%, T17 1% |
| Rainbow | 2 | 17 | 3.2T | T16 60%, T17 30%, T18 9%, T19 1% |
| Cosmic | 1 | 19 | 51.2T | T18 60%, T19 30%, T20 10% |

A lucky block is worth buying when it reaches a tier more cheaply than the alternatives (see above), not when its contents beat its price; check that blocks are an interesting-but-not-mandatory choice at every stage (not so cheap they skip the ladder, not so dear nobody opens one). Model a sensible strategy (e.g. open a block when Cash on hand is at least some multiple of its price) and report how much it speeds up or slows down progression.

### Monetization (must be part of the model)

Game passes (Robux): x2 Cash 40, x4 Cash 80, x7 Cash 140, x12 Cash 240 (multiplier applied when Cash is collected, highest owned wins, no stacking); 2x Aura 499; Auto Collect 79 (drops credited straight to Aura, no cap, no walking).
Dev products: Finish Now 19 (instantly processes the whole processor queue, with the same Cash multiplier); Cash packs S 29 / M 149 / L 499 Robux, amount = base price of the player's **highest tier** x 50 / 2,500 / 125,000 (e.g. at highest tier 10: 235M / 11.75B / 587.5B; at tier 15: 250B / 12.5T / 625T).
Group reward pad ("Join the group + Like for money every N minutes"): members claim Cash every `GROUP_REWARD_INTERVAL`; amount = max(`GROUP_REWARD_MIN`, base price of the current **buy tier** x `GROUP_REWARD_MULTIPLIER`). **I want the interval to be 10 minutes (600 s) instead of the current 5 minutes.** Model a player who claims it every 10 minutes while playing and whenever they log on (one claim per login stretch is fine for offline), and tell me the amounts so it is a helpful nudge (a noticeable boost early, a rounding error late), never a main income.
Cash packs and Finish Now should feel like a shortcut, not a skip: report for each pack, at tiers 1, 5, 10, 15, 19, how many minutes of normal play it is worth, and flag any that skip more than about a day of progress. Recommend changes to the pack multipliers if needed.

## What to produce

1. **A simulator** (Python, in `tools/economy_sim.py`) that models: drops every 7 s per brainrot with the 50-drop cap and a collection-efficiency parameter (what fraction of drops an active player picks up, 0.6 to 1.0, 1.0 with Auto Collect), the market multiplier (mean 1.0, random), deposit timing, the processor queue and rate, processor upgrades, Cash multiplier at collection, offline earnings (assume the player is offline 20 hours a day for the x7 case, and report sensitivity for 0, 12 and 20), buying at the buy tier with the 1.005 price growth, the 80-spot limit with merging (the Merge! pad mid-run and auto-merge when full), Upgrade Buy Tier, lucky blocks, the group reward and optionally Cash packs. The player strategy must be explicit and sensible (it should save for the next Buy Tier upgrade once the onsen is full instead of spending everything on cheap buys; my last quick model without that behaviour gave misleading numbers). Make every parameter a named constant so it can be tuned.
2. **Baseline result with today's config:** time to first merge, first Upgrade Buy Tier, buy tier 5 / 10 / 15 / 20, and highest owned tier 20, for: free player, x7 Cash player, whale. (My rough earlier simulation of a free, always-saving, always-online player with today's numbers reached tier 20 in about 64 hours of active play; check that against your more careful model.)
3. **A tuned config** that makes the x7 player hit tier 20 in about 17.5 days. Prefer changing as few levers as possible, in this order: `BUY_TIER_UPGRADE_MULTIPLIER`, `PRICE_GROWTH`, the processor growth / upgrade constants, the lucky block price multiplier, then tier Aura values (only if the 3x merge rule and the "4x per tier" feel survive). Say why the chosen levers and not others. Keep the early game targets above.
4. **A milestone table** for the x7 player: day and hours played at buy tier 2, 5, 8, 10, 12, 15, 18, 20 and at highest tier 5, 10, 15, 20, with Cash per hour at each, the processor level, how long the processor queue backs up, and how many lucky blocks of each type the player typically opens. Flag any flat spots longer than about 2 hours of active play (the player must always have something to buy or upgrade) and any cliff where one step is more than ~4x the previous one.
5. **Sensitivity:** how the tier-20 time moves with +-25% on play time, collection efficiency, market luck, and the Cash pass owned (none, x2, x4, x7, x12). A short table is enough.
6. **Concrete edits** to `src/shared/Config/*.luau` (diff-style, constants only, comments updated with today's date), plus `GROUP_REWARD_INTERVAL = 600`. Do not change service code. Run `ConfigCheck`-relevant invariants by reading `src/server/ConfigCheck.luau` so the new numbers still pass it.

Do not edit the Config files until you have shown me the baseline and the proposed tuning in steps 2 to 5 and I have approved them. After the edit: run `stylua src`, `selene src` and `rojo build -o <tmp>.rbxl`, then update `PROGRESS.md` (checklist, "Last updated", one dated Log line) as `CLAUDE.md` requires, and update the design doc and `CLAUDE.md` where a stated rule or number changed (CLAUDE.md says the design doc wins if they disagree).

Be quantitative and state assumptions. If something I asked for is inconsistent (for example the 2.5-week target versus the early-game targets, or the pack sizes), say so and propose the fix instead of silently picking one.
