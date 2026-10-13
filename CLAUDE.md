# Brainrot Onsen ♨

Player-facing name: **Brainrot Bathhouse** (renamed from "Brainrot Onsen" 2026-09-30; code, folders and docs keep "Onsen" internally, but every text players see says "Bathhouse"). Store listing: `docs/store-assets.md`; image prompts (Gemini): `docs/gemini-prompts/`. Where the project stands: `PROGRESS.md` "Handoff (start here)".

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
- Plot layout (Capybara Onsen): the bath field is SUNK into the floor (floor top y=4.5 on the map ground; sunken water sheet at y=3.1, the pool 1.5 lower with a pour-over with a stone lip and a dark bed): 8 rows of thin stone-ring baths (rims just above the grass) on both sides of a centre channel, each with its river in front (river, bath, river, bath...), slides from bath rims down into the rivers, rivers flow to the channel, the channel into the pool (the sunken water jutting out in front, 14 wide). Merge! centred in front of the pool; a pad row along the first bath row, read left to right from the spawn: Buy 1, Buy 5, Auto Collect | pool | Buy 25, Buy 100, Upgrade Buy Tier ("right" = the Upgrade Buy Tier side, -x); station row in front, backing onto the front wall: market board, deposit stall (Tung Tung Tung Sahur on the counter); the processor barrel stands by the -x wall beside the pool with Collect Cash in front and the BATHS signpost beside it; the processor controls (info board, upgrade pad, Finish Now) stand together on the +x side wall beside the pool; every Robux pad sits in line on the -x side of the free pad it boosts (x2 Cash beside Collect Cash toward the road); group reward pad in front of the group sign on the curved +x front wall; floor arrows pool > Deposit > Collect Cash > buy row. Plot front: steps up from the map ground, grass verge with the dark wooden entrance gate (blue noren, name board), bridge over a kerbed canal through the tall pegboard front wall. Between the two rows (140 studs): a 400 x 80 lake whose 10-stud streams (conveyor current) loop round a raised grass island with three leaderboard pavilions, cliffs and waterfalls at both ends (`server/Plaza`).
- Drop cap: 50 uncollected drops per plot. At the cap, all production silently stops (no banner) until drops are picked up.
- Buy 100 always auto-merges (together with what the player already owns). Buy 1/5/25 and lucky block results only merge when the onsen maxes out: if they wouldn't fit, or the onsen is full after adding them, everything merges automatically. Otherwise they wait for the Merge! pad. Buy 1/5/25 buy as many as fit and charge only for those.
- Tier value is roughly 4x the tier below (must always be more than 3x so merging pays).
- Upgrade Buy Tier permanently raises the tier the buy pads sell and carries the price over (user decision 2026-10-11, `Economy.PRICE_CARRY_OVER` / `carriedBought`): the new tier's first brainrot costs what the old tier's next one would have, never less than the new tier's base price. It then merges everything that can merge and silently promotes every leftover brainrot below the new buy tier to the buy tier (user decision 2026-10-11). Its cost grows faster than income (user decision 2026-10-04: an expanding curve, quick to hook, then slower and slower so passes are worth buying): next tier's base price x `BUY_TIER_UPGRADE_MULTIPLIER` x `BUY_TIER_UPGRADE_GROWTH` ^ steps, where the growth applies from buy tier `TIER_GROWTH_FROM` to `TIER_GROWTH_TO`. Simulated (`tools/economy_sim.py`, 2 h play a day, growth 2.35 since the carry-over): free player owns a tier 20 around day 50, x7 Cash player around day 9 (target: a week or more).
- Offline earnings are never cut to slow the game (user decision 2026-10-04); pacing comes from costs.
- Offline: brainrots earn at 100% forever, straight into the Aura counter (ignores the drop cap). Processor keeps processing.
- Lucky blocks: after a random 40-100 s of production the next drop from a brainrot is a lucky block instead of Aura (floats into the pool like a drop). Several can float at once (up to 5); a player holds one. Chests follow progress (user decision 2026-10-04, replaces "random, not tied to progress"): a type only spawns when it can still give the buy tier (unlock tier + 2 >= buy tier) and the player owns its lowest tier (unlock tier - 1 <= highest tier), weighted (Wood most common, Cosmic rarest) among those; contents are the unlock tier -1 to +2 at 60/30/9/1 odds with results below the buy tier raised to it (`LuckyBlocks.rollsFor`; the odds panel shows these). Price = `LuckyBlocks.priceFor`: Aura of the tier it really gives x `LUCKY_BLOCK_PRICE_MULTIPLIER` (10) on the Upgrade Buy Tier growth curve. Paid with Cash, or when Cash is short with the 89 Robux "Unlock Lucky Chest" dev product (`LuckyUnlock`, one price for every chest; hidden where `PolicyService` restricts paid random items, `PaidRandomItems` attribute).
- Cash multiplier game passes: x2 / x4 / x7 / x12 at 40 / 80 / 140 / 240 Robux (multiplier x 20; x12 added 2026-09-29, user request). Highest owned applies, no stacking between them.
- Auto Collect game pass collects Aura drops, not Cash.
- Finish Now dev product instantly processes the processor queue (with the same Cash multipliers).
- Cash packs (S / M / L) give `CASH_PACK_SHARE` (10% / 50% / 150%) of the player's next Upgrade Buy Tier cost (at least `CASH_PACK_MIN` 1K / 5K / 15K): they grow only with the buy tier, never with the brainrots owned (user decision 2026-10-09).
- Group reward: every 10 minutes (`GROUP_REWARD_INTERVAL` 600, user request 2026-10-04).
- Boosts multiply: Aura = 2x pass x (1 + 10% Premium); processor Cash = highest Cash pass x (1 + friend boost). Auto Collect credits each drop straight to Aura (no floating drop, never hits the cap).
- Total Brainrots counts brainrots obtained by buying or lucky block unlocks (not merges).
- No pedestals. The Index is the collection.
- 6 players per server, one plot each.
- New players start with 1,000 Cash (`Economy.STARTING_CASH`).

## Architecture

Rojo project. The server owns every number; the client only renders and sends intents ("stepped on Merge!"). Never trust amounts from the client.

```
src/shared/   -> ReplicatedStorage.Shared   (Config/, Format, Remotes, DropPath, Visuals, Models)
src/server/   -> ServerScriptService.Server (ConfigCheck, Plots, Services/)
src/client/   -> StarterPlayerScripts.Client (Controllers/)
Packages/       -> ReplicatedStorage.Packages (Wally shared deps, gitignored)
ServerPackages/ -> ServerStorage.ServerPackages (Wally server deps like ProfileStore, gitignored)
reference/    Capybara Onsen screenshots: the visual reference for layout and UI
docs/         launch-plan.md (the plan to launch, phase by phase), launch.md (pre-publish checklist), store-assets.md (store listing text, research), gemini-prompts/ (one image prompt per file), store-reference/ (in-game captures), map-polish-roadmap.md, map-polish.md, prompts/
assets/store/ the store icon (icon-512.png, icon-1024.png) and, once made, the thumbnails
assets/       Brainrots.rbxmx: the 20 pack models (Tier1..Tier20), synced to ReplicatedStorage.Assets.Brainrots; textures/: generated map tiles and HUD images (one shared style; uploaded, IDs in Config/Textures, default.project.json and client/Style)
tools/        extract_brainrot_pack.py (rebuilds assets/Brainrots.rbxmx), make_textures.py (regenerates assets/textures), voxel_forge.py (designs the voxel map props, writes src/shared/PropData.luau, renders previews)
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
| `server/Decor` | Per-plot decoration (walls, front edge: kerbed canal + tall front wall with a curved corner + bridge + entrance gate + group sign, layered cliffs, waterfall, trees, bamboo, sprigs, daisies, stone path), `Decor.horizon` (map-wide), particle helpers (steam, foam, petals, mist, smoke) and `Decor.ambient` sounds |
| `server/Plaza` | The middle area: rectangular lake loop round an island (leaderboard on it), conveyor current (`AssemblyLinearVelocity`, ~27 studs/s) on `FlowWater`-tagged parts, promenades |
| `Controllers/WaterController` | Scrolls the textures of `FlowWater` parts along their flow |
| `server/Billboard` | `Billboard.new(part, {width, height, ...})`: outlined floating labels sized in studs (pads, sign, brainrot names); `Billboard.color(text, hex)` + colour constants |
| `shared/Props` + `PropData` | Voxel props (generated by tools/voxel_forge.py) built as merged boxes: map props, station props, drop items `Drop<tier>`, lucky chests `Chest<Name>`; `Props.place(name, cframe, parent, scale)`, `Props.clone`, `Props.has` |
| `server/Skin` | `Skin.apply(part, key, tint?)`: tile look via the MaterialVariants `MaterialService.Onsen_<key>` declared in `default.project.json` (game scripts cannot create them); part Color tints the tile; falls back to 1-stud Studs. `Skin.tile`: per-face Textures (water only, for scrolling) |
| `Services/AtmosphereService` | Lighting, sky, haze, bloom, colour correction |
| `Services/MonetizationService` | Game passes, dev products (`ProcessReceipt` + `data.receipts`), Aura / Cash multipliers, friend + Premium boosts, Robux pads, `BuyProduct` intent |
| `Services/LeaderboardService` | Player list leaderstats (Best Tier, Cash, Total Brainrots); three pavilions on the plaza island (Top Brainrots, Net Worth = lifetime Cash earned stored as log10 x 1e6, Playtime) from OrderedDataStores |
| `Services/TutorialService` + `shared/Tutorial` | New-player tutorial, 6 steps (buy, collect 3 drops, deposit, collect Cash, merge, Upgrade Buy Tier paid by a reward worth exactly that upgrade); each step flashes its map objects (market board, deposit stall, processor board + barrel, pads): `data.tutorialStep`, `TutorialService.record(player, id)` called by Shop / Drop / Processor services, `TutorialStep` / `TutorialCount` attributes, skip from step 2 (`TutorialAction`); old profiles with brainrots skip it |
| `server/Analytics` | Roblox AnalyticsService wrappers (live only): onboarding funnel, buy tier funnel, Cash sources / sinks |
| `Services/GroupRewardService` | Group reward pad: members claim Cash every `Economy.GROUP_REWARD_INTERVAL` (max(min, base price x multiplier)); `Products.GROUP_ID` 0 = Studio treats everyone as a member |
| `client/Style` | HUD building blocks in Capybara Onsen's style: `Style.button` (studded blocky button, dark border, outlined label), `Style.outlined` (big outlined text, no box), `Style.autoScale` (shrinks a ScreenGui on small screens), image ids |
| `Controllers/SoundController` | Music playlist and cues (`Config/Sounds`); 3D water loops are placed by `Decor.ambient` |
| `Controllers/HudController` | Home button, Aura / Cash / boosts / Total Brainrots, Cash pack buttons, Premium + friend boost, toasts and big popups (`Notify` kinds) |
| `Controllers/DropController` | Animates drops and lucky blocks along their path, asks to collect, "+X" gain |
| `Controllers/BrainrotController`, `PadController` | Rise-from-the-bath and a gentle code-driven bob and sway in the water (the pack's idle animations are owned by its creator and Roblox refuses them here); pad-press animation |
| `Controllers/MarketBoardController` | Draws the market boards |
| `Controllers/LuckyBlockController` | Held chest + tool-hold animation, odds panel, on-screen unlock reveal |
| `Controllers/IndexController` | Index button and grid |
| `Controllers/CameraController` | Turns the camera toward the baths after spawning and after any teleport (Home) |
| `Controllers/EffectsController` | Sparkle burst on Merge! when brainrots merge, gold coin burst on Collect Cash |
| `Controllers/GuideController` | The tutorial guide under Home, shown only while the tutorial runs (gone after it, user decision 2026-10-04): step text, flashing map objects, beam + bobbing arrow, chime on each step, Skip |

Conventions:

- All tunable numbers live in `src/shared/Config/` (`Tiers`, `Economy`, `LuckyBlocks`, `Products`, `Sounds`, `Textures`). Never hard-code a balance number in a service. Visual-only layout numbers (studs, colors) live at the top of the module that uses them.
- Studio-only test knobs are `Economy.STUDIO_*` (0 / false = off), always gated by `RunService:IsStudio()`. `STUDIO_PROFILE_SUFFIX` loads a separate profile (play as a brand-new player without touching the real save); `STUDIO_GIVE_EACH_TIER` gives a new profile n of every tier (model checks); `STUDIO_FORCE_TUTORIAL` restarts the tutorial. `STUDIO_SIMULATE_PURCHASES` grants passes / products whose ID is still 0 for free in Studio.
- Brainrots are stored as counts per tier (`data.counts`, dense array), not as instances.
- Saving: ProfileStore with session locking. New `Data` fields go in `DataService`'s `TEMPLATE`; `Reconcile` fills them into old profiles. Dev product receipts are logged in the profile.
- Server -> client state: player attributes (`Aura`, `Cash`, `Brainrots`, `TotalBrainrots`, `HighestTier`, `BuyTier`, `AuraPerSecond`, `MergeReady`, `TutorialStep`, `TutorialCount`, `Discovered`, `LuckyBlock`, `PlotIndex`, and from MonetizationService `CashPass`, `FriendBoost`, `Premium`, `AuraMultiplier`, `AutoCollect`) and part attributes; events through `Shared.Remotes` (the list and payloads are in its header).
- Messages: `Notify(message, kind?)`: nil = red toast, "good" = green toast, "deposit" / "cash" / "away" / "lucky" / "newBrainrot" = big popup.
- Brainrot art: the free "Brainrot Pack [150+]" by Agus_Fellini2 (Creator Store asset 137461628889541; credit him in-game). `Shared.Models.makeBrainrot(tier)` clones `ReplicatedStorage.Assets.Brainrots.Tier<N>` (scaled to the bath, pivot at the bottom centre) and falls back to a code-built model. Models must not set a `PrimaryPart` (it overrides `WorldPivot`). Drop items are voxel props (`Drop<tier>`, cloned by `makeDropItem`); lucky block chests are voxel props (`Chest<Name>`, cloned by `Visuals.makeLuckyBlock`).
- Placeholder art: `Shared.Visuals` (`tierColor`, `blockColor`, `makeLuckyBlock`) and `Shared.Models` (`makeBrainrot(tier)`, `makeDropItem(tier)`: blocky models built in code; brainrot origin = bottom centre, front = -Z, `Label` anchor above the head). Art order (user decision): code-built models, then Studio-MCP-built models, and the user's own models last. Swap models by keeping these function signatures.
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
- Commit only when asked. Work directly in `C:\dev\BrainrotOnsen` on `main` (user decision 2026-09-30); no worktrees.

## Tooling

- Toolchain versions are pinned in `rokit.toml` (rojo, wally, stylua, selene). The exes live in `~/.rokit/bin`. On this machine Avast's HTTPS scanning breaks Rokit's own downloads, so tools are updated by downloading release zips with `curl` into `~/.rokit/bin`.
- `rojo build -o <file>.rbxl` is the quickest check that the project tree is valid.
- `rojo serve` then connect from the Rojo plugin in Studio.
- `wally install` to fetch packages.
- `stylua src` and `selene src` (0 errors, 0 warnings) and `rojo build` before finishing any change.
- Patch scripts: stylua rewraps long lines, so an exact-string replacement written against pre-format code can miss. Assert every match (and that it's unique) before writing, and never replace an empty string.
- Keep this project outside OneDrive; sync fights Rojo's file watcher.
- Studio MCP (when connected): `screen_capture` with a camera position takes the map check shots (Studio in Play); `upload_image` uploads images to the user's account from an `http://localhost` URL (serve `assets/textures` with `python -m http.server 8765`); `execute_luau` runs with more rights than game scripts, so a Studio test through it does not prove a game script may do the same.
