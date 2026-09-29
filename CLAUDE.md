# Brainrot Onsen ♨

Roblox merge tycoon: famous Italian brainrot characters soak in each player's onsen, drop Aura, and merge 3-into-1 up a 20-tier ladder. Inspired by Capybara Onsen (https://www.roblox.com/games/120336108521610/Capybara-Onsen). Goal: publish, grow, monetize.

Full design doc (source of truth for every rule and number):
https://claude.ai/code/artifact/7a31dba9-3407-4173-8b51-22914630d885
Read it with the Claude Docs tools (never web-fetch it). If the doc and this file disagree, the doc wins; update this file.

## Core loop

1. Cash buys brainrots from the buy pads (Buy 1 / 5 / 25 / 100 of the player's current buy tier).
2. Each brainrot drops its own themed item every 7s on its own timer (Tung Tung Tung Sahur drops sticks, etc.). Drops slide out of the bath, float down the river and the center channel, and gather in the collection pool.
3. Walking over a drop (anywhere on its way or in the pool) turns it into Aura instantly. No inventory, no carry cap.
4. Deposit stand: all Aura goes into the processor queue as Aura x market multiplier (server-wide, random 0.50x to 1.50x, rerolled every 30s).
5. Processor turns queued Aura into Cash 1:1 at a rate per second. Cash waits on the Collect Cash pad.
6. Merge! pad merges every triple of the same tier into 1 of the next tier, cascading.

## Rules that are easy to get wrong

- Two currencies only: Aura (only use: depositing) and Cash (everything else). No caps on either.
- 80 brainrot spots per plot (8 rows x 5 per side of the center channel). No capacity upgrades.
- Plot layout (Capybara Onsen): 8 rows at the back, each a raised stone-rimmed bath on both sides of a center channel; each bath has its own lower river in front of it (river, bath, river, bath...), wooden slides carry drops from bath to river, rivers flow into the channel, and the channel empties into a narrow stone-rimmed pool just in front of the lanes; Merge!/buy pads beside the pool; big open ground in front for the other stations.
- Drop cap: 50 uncollected drops per plot. At the cap, all production silently stops (no banner) until drops are picked up.
- Buy 100 always auto-merges (together with what the player already owns). Buy 1/5/25 and lucky block results only merge when the onsen maxes out: if they wouldn't fit, or the onsen is full after adding them, everything merges automatically. Otherwise they wait for the Merge! pad. Buy 1/5/25 buy as many as fit and charge only for those.
- Tier value is roughly 4x the tier below (must always be more than 3x so merging pays).
- Upgrade Buy Tier permanently raises the tier the buy pads sell and resets price scaling.
- Offline: brainrots earn at 100% forever, straight into the Aura counter (ignores the drop cap). Processor keeps processing.
- Lucky blocks: after every 3 minutes of production the next drop is a lucky block instead of Aura (floats into the pool like a drop, one at a time). Type depends on highest tier ever owned (Wood unlocks at tier 3); contains unlock tier -1 to +2 at 60/30/9/1 odds; paid with Cash only (never Robux directly); very expensive.
- Cash multiplier game passes: x2 / x4 / x7 at 40 / 80 / 140 Robux (multiplier x 20). Highest owned applies, no stacking between them.
- Auto Collect game pass collects Aura drops, not Cash.
- Finish Now dev product instantly processes the processor queue.
- No pedestals. The Index is the collection.
- 6 players per server, one plot each.
- New players start with 1,000 Cash (`Economy.STARTING_CASH`).

## Architecture

Rojo project. The server owns every number; the client only renders and sends intents ("stepped on Merge!"). Never trust amounts from the client.

```
src/shared/   -> ReplicatedStorage.Shared   (Config/, Format, Remotes, DropPath, Visuals)
src/server/   -> ServerScriptService.Server (ConfigCheck, Plots, Services/)
src/client/   -> StarterPlayerScripts.Client (Controllers/)
Packages/       -> ReplicatedStorage.Packages (Wally shared deps, gitignored)
ServerPackages/ -> ServerStorage.ServerPackages (Wally server deps like ProfileStore, gitignored)
reference/    Capybara Onsen screenshots: the visual reference for layout and UI
```

- `src/server/init.server.luau` runs `ConfigCheck` (asserts config invariants), then loads every module in `Services/`: `:Init()` on all, then `:Start()` on all (Start runs in its own thread). The client does the same with `Controllers/`.
- Add a new system as a new module in `Services/` or `Controllers/`; no registration needed. Build shared geometry/state in `:Init()`, connect and loop in `:Start()`. Services require each other directly; avoid require cycles.

Module map:

| Module | Job |
| --- | --- |
| `server/Plots` | Builds the 6 plots in code (baths, rivers, slides, channel, pool, pads, station row, signs), owner assignment, `Plots.onStep` (once-per-step pad touches + `Pressed` attribute), drop paths, pool points |
| `Services/DataService` | ProfileStore profiles (`PlayerData_v1`, key `Player_<UserId>`), the `Data` shape, offline earnings, player attributes |
| `Services/PlotService` | Join/leave lifecycle: load data, assign plot, send home, Home button |
| `Services/PoolService` | Lays brainrots out in spots (diff render, `SpawnedAt` for the rise animation) |
| `Services/ShopService` | Buy 1/5/25/100, Merge!, Upgrade Buy Tier, merge logic (`mergeCounts`, `makeRoom`, `mergeIfFull`) |
| `Services/DropService` | Per-brainrot 7s drop timers, drop cap, `CollectDrop` validation, `replaceNextDrop` hook |
| `Services/MarketService` | Server-wide multiplier (`ReplicatedStorage.Market` attributes) |
| `Services/ProcessorService` | Deposit, processor queue, Collect Cash, processor upgrades, station labels |
| `Services/LuckyBlockService` | Lucky block timer, block-as-drop, pickup, Unlock / Discard |
| `Controllers/HudController` | Home button, Aura / Cash, toasts and big popups (`Notify` kinds) |
| `Controllers/DropController` | Animates drops and lucky blocks along their path, asks to collect, "+X" gain |
| `Controllers/BrainrotController`, `PadController` | Rise-from-the-bath and pad-press animations |
| `Controllers/MarketBoardController` | Draws the market boards |
| `Controllers/LuckyBlockController` | Held chest + tool-hold animation, odds panel, on-screen unlock reveal |
| `Controllers/IndexController` | Index button and grid |

Conventions:

- All tunable numbers live in `src/shared/Config/` (`Tiers`, `Economy`, `LuckyBlocks`, `Products`). Never hard-code a balance number in a service. Visual-only layout numbers (studs, colors) live at the top of the module that uses them.
- Studio-only test knobs are `Economy.STUDIO_*` (0 = off), always gated by `RunService:IsStudio()`.
- Brainrots are stored as counts per tier (`data.counts`, dense array), not as instances.
- Saving: ProfileStore with session locking. New `Data` fields go in `DataService`'s `TEMPLATE`; `Reconcile` fills them into old profiles. Dev product receipts are logged in the profile.
- Server -> client state: player attributes (`Aura`, `Cash`, `Brainrots`, `Discovered`, `LuckyBlock`, `PlotIndex`) and part attributes; events through `Shared.Remotes` (the list and payloads are in its header).
- Messages: `Notify(message, kind?)`: nil = red toast, "good" = green toast, "deposit" / "cash" / "away" / "lucky" / "newBrainrot" = big popup.
- Placeholder art until Phase 6: colored parts from `Shared.Visuals` (`tierColor`, `blockColor`, `makeLuckyBlock`).
- Luau with `--!strict` at the top of every module.
- Number display always goes through `Shared.Format`.

## Progress tracking

`PROGRESS.md` is the single place that says where the project is. After any change to the project (code, config, tooling, decisions), before ending your turn:

- Tick the finished checklist items and update "Current phase" and "Last updated".
- Add one dated line at the top of the Log saying what changed.
- Keep "Blockers / needs from you" current.

A Stop hook in `.claude/settings.json` blocks ending a turn when files under `src/` or config changed after PROGRESS.md was last written.

## Development phases

Current phase: see `PROGRESS.md`.

0. Setup: Rojo, Wally, config modules, Format
1. Plots and drops: plots, lanes, Buy 1/5/25, drops, Aura, drop cap
2. Cash loop: market multiplier, deposit, processor, Collect Cash, processor upgrades
3. Progression and saving: Merge!, Buy 100 auto-merge, Upgrade Buy Tier, ProfileStore, offline
4. Lucky blocks and Index
5. Monetization and social: passes, dev products, boosts, leaderboards
6. Art, polish, launch (placeholder models until here)
7. Post-launch: group reward pad, tutorial, music, more tiers

## Working with the user

- The user play-tests in Studio and reports back with screenshots. End each change with exact play-test steps.
- Match Capybara Onsen's look and feel closely; the screenshots in `reference/` are the target. Save new screenshots the user shares into `reference/` and add them to the design doc.
- When a user request changes a rule, update the design doc, this file and `Config` together.
- Commit only when asked. Work happens on a branch/worktree; merge into `main` only when asked.

## Tooling

- Toolchain versions are pinned in `rokit.toml` (rojo, wally, stylua, selene). The exes live in `~/.rokit/bin`. On this machine Avast's HTTPS scanning breaks Rokit's own downloads, so tools are updated by downloading release zips with `curl` into `~/.rokit/bin`.
- `rojo build -o <file>.rbxl` is the quickest check that the project tree is valid.
- `rojo serve` then connect from the Rojo plugin in Studio.
- `wally install` to fetch packages.
- `stylua src` and `selene src` (0 errors, 0 warnings) and `rojo build` before finishing any change.
- Patch scripts: stylua rewraps long lines, so an exact-string replacement written against pre-format code can miss. Assert every match (and that it's unique) before writing, and never replace an empty string.
- Keep this project outside OneDrive; sync fights Rojo's file watcher.
