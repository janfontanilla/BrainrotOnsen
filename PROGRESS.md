# Progress

Current phase: **Phase 4 (lucky blocks and Index)**
Last updated: 2026-09-28

## Phase checklist

### Phase 0: Setup
- [x] Project folder `C:\dev\BrainrotOnsen` (outside OneDrive)
- [x] CLAUDE.md and PROGRESS.md
- [x] Stop hook that enforces PROGRESS.md updates (`.claude/settings.json`)
- [x] Git repo initialized, Phase 0 committed (8ae4205)
- [x] Rojo project file (`default.project.json`)
- [x] `wally.toml` with ProfileStore 1.0.3 (server realm)
- [x] StyLua + Selene config
- [x] Config modules: `Tiers`, `Economy`, `LuckyBlocks`, `Products`
- [x] `Format` module (K, M, B, T, Qa...)
- [x] Server and client bootstraps + `ConfigCheck`
- [x] Toolchain installed: Rojo 7.7.0, Wally 0.3.2, StyLua 2.5.2, Selene 0.31.0 (in `~/.rokit/bin`, on PATH)
- [x] `wally install` (ProfileStore in `ServerPackages/`)
- [x] `rojo build` succeeds; `stylua --check src` clean
- [x] Selene Roblox standard library generated; `selene src` 0 errors, 0 warnings
- [x] Roblox Studio installed
- [x] Rojo 7.7.0 plugin placed in `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` (downloaded from the release; `rojo plugin install` needs registry keys Studio writes on first launch)
- [x] Project synced from Studio, ConfigCheck prints OK (play test: ConfigCheck OK, server and client started)
- [ ] Roblox Studio MCP connected (optional, moved to "do when needed" for building models)
- **Phase 0 done 2026-09-28.**
- Done when: the project syncs into Studio and every config module loads without errors

### Phase 1: Plots and drops
- [x] 6 plots, assigned on join, cleared on leave, name sign (`Plots.luau`, `PlotService`)
- [x] 8 rows x 5 spots per side (80) per plot, floating name + tier labels (`PoolService`)
- [x] Buy 1 / 5 / 25 pads with price scaling (`ShopService`)
- [x] Drops every 7 seconds from every brainrot (own timer each), floating bath > slide > river > channel > pool (`DropService`, client `DropController`)
- [x] Walk over drops = Aura, 50-drop cap (server distance check via `CollectDrop` remote)
- [x] Aura counter on the HUD (`HudController`)
- [x] Testing aid: new players get `Economy.STARTING_CASH` (1,000); Cash on the HUD
- Done when: you can buy Tim Cheeses, watch them drop cheese, and collect Aura until the cap stops them
- **Phase 1 done 2026-09-28** (user play test: buying, drops, pickup, cap).

### Phase 2: Cash loop
- [x] Server-wide market multiplier, 0.50x to 1.50x every 30 seconds (`MarketService`, `ReplicatedStorage.Market` attributes)
- [x] Market board with graph and countdown (client `MarketBoardController`, one board per plot)
- [x] Deposit Aura stand (`ProcessorService`)
- [x] Processor queue, rate per second, sign (`ProcessorService`)
- [x] Collect Cash pad
- [x] Processor upgrade pad
- [x] Cash on the HUD
- **Phase 2 done 2026-09-28** (user play test: deposit, processor, Collect Cash, upgrade, market board, popups).

### Phase 3: Progression and saving
- [x] Merge! pad, cascading merges (silent; pad gold when something can merge, grey otherwise)
- [x] Buy 100 with auto-merge
- [x] Upgrade Buy Tier pad
- [x] All 20 tiers in config
- [ ] ProfileStore saving with session locking (coded; persistence test deferred until the place is published with API access)
- [ ] Offline earnings, 100% rate, straight to Aura (coded; needs the same test)
- [x] Home button

### Phase 4: Lucky blocks and Index
Coded 2026-09-28 (lint + build clean), waiting on the Studio play test.
- [ ] Block spawning every 3 minutes, block type by highest tier
- [ ] Pick up and hold a block, odds panel, Unlock / Discard
- [ ] Rolls with 60 / 30 / 9 / 1 odds, no auto-merge
- [ ] Index grid with silhouettes and "New brainrot!" popup

### Phase 5: Monetization and social
- [ ] Game passes: 2x Aura, Auto Collect, x2 / x4 / x7 Cash
- [ ] Dev products: Finish Now, Cash packs S / M / L, ProcessReceipt + receipt log
- [ ] Robux pads next to their stations, Cash pack buttons on the HUD
- [ ] Friend boost, Premium boost
- [ ] Total Brainrots leaderstat + global leaderboard

### Phase 6: Art, polish and launch
- [ ] 20 brainrot parody models + 20 drop item models
- [ ] Onsen map: lanes, water, processor, market stand, decoration
- [ ] Idle animations
- [ ] Bath polish: steam, flowing water in rivers/channel, splash where slides meet the river
- [ ] Mobile UI scaling and touch testing
- [ ] Balance playtest (first merge < 1 min, first Upgrade Buy Tier < 10 min)
- [ ] Title, description, icon, thumbnails
- [ ] Publish

### Phase 7: Post-launch
- [ ] Group reward pad
- [ ] New-player tutorial
- [ ] Music and sound effects
- [ ] More tiers past 20, events

## Blockers / needs from you
- Phases 1 and 2 live on branch `claude/priceless-cori-962788` (worktree `C:\dev\BrainrotOnsen\.claude\worktrees\priceless-cori-962788`), committed (45a8502) but not merged into `main`. Run `rojo serve` from that folder, or ask Claude to commit and merge so `C:\dev\BrainrotOnsen` works again.
- Saving only persists in Studio once the place is published (File > Publish to Roblox) and Game Settings > Security > "Enable Studio Access to API Services" is on. Until then ProfileStore runs in mock mode (no persistence).
- Deferred: publish the place and enable Studio API access, then test saving + offline earnings (stop, wait a few minutes, replay).
- Avast's HTTPS scanning breaks Rust tools' downloads (Rokit, Selene std, Wally updates). Pause Avast Web Shield briefly when one of those needs the network.
- Some Capybara Onsen screenshots (HUD, Index, lucky box panel) were pasted in chat only and never saved as files. Drop them into `reference/` and Claude will add them to the design doc.
- Data is in memory only until Phase 3 (ProfileStore); every join starts with 1,000 Cash.

## Log (newest first)
- 2026-09-28: Unlock reveal moved to the screen: the chest leaves the hand, a big chest drops into the middle of the owner's screen, shakes, then pops open into the brainrot (name + tier), holds, shrinks away.
- 2026-09-28: Held lucky block: right arm held straight out (tool pose), chest rests on the end of the right hand; left arm stays down.
- 2026-09-28: Lucky block fixes: panel never showed (clearing the viewport destroyed its camera, error on show); held chest now rests on the character's raised hands (shoulders rotated locally) and stays still, shaking only during the unlock reveal.
- 2026-09-28: Lucky blocks now arrive as a drop (user decision): when due, the next drop from a brainrot is the block and it floats bath > slide > river > channel > pool; pick up anywhere on the way. Held block drawn client-side as a chest swinging above the head; panel restyled after `reference/lucky-block-panel.png` (picture, name / Lucky Box, odds box, Cost box, Unlock! / Discard); unlock reveal: chest shakes then pops open into the brainrot above the head (`LuckyBlockOpened`). Shared chest builder `Visuals.makeLuckyBlock`.
- 2026-09-28: Lucky blocks: Studio-only Output line explaining why no block spawns (no block unlocked below tier 3, no brainrots, or drop cap reached).
- 2026-09-28: Full onsen now auto-merges (user decision): Buy 1/5/25 and lucky block unlocks merge first if they wouldn't fit, and merge again if the onsen is full afterwards. Design doc + CLAUDE.md updated.
- 2026-09-28: Phase 4 coded: LuckyBlockService (block floats into the pool after 3 min of production, best unlocked type, walk over to pick up and hold above head, Unlock for Cash / Discard, 60/30/9/1 roll into a free spot, no auto-merge, saved across rejoin), lucky block panel (client), Index button + grid with "???" silhouettes, "New brainrot!" popup on first discovery. Shared `Visuals` for placeholder colors. Economy: LUCKY_BLOCK_PICKUP_RANGE, STUDIO_LUCKY_BLOCK_INTERVAL.
- 2026-09-28: Phases 1-3 committed on branch `claude/priceless-cori-962788` (45a8502). Not merged into `main` yet.
- 2026-09-28: User confirmed Merge!, Buy 100 and Upgrade Buy Tier. Saving/offline test deferred until API access is set up.
- 2026-09-28: Buy 100 merges instantly again (delay removed at user's request); message stays "Bought 100 <name>!".
- 2026-09-28: Buy 100 now says "Bought 100 <name>!" and shows the new brainrots for `AUTO_MERGE_DELAY` (1.2s) before merging; Merge! is silent; Merge! pad is gold when something can merge, grey otherwise. User confirmed Phase 3 features working so far.
- 2026-09-28: `Economy.STUDIO_STARTING_CASH` = 500K: brand-new profiles in Studio start with it for testing; live stays 1,000. Set to 0 to test the real start.
- 2026-09-28: Design doc save-data shape updated to match `DataService`. Rojo serve restarted so it picks up ServerPackages.
- 2026-09-28: Phase 3 coded: ProfileStore saving (`PlayerData_v1`, key `Player_<UserId>`, session lock, lastOnline stamped every 10s), offline earnings at join (brainrots straight to Aura, processor keeps processing, "While you were away" popup), Merge! pad (cascading), Buy 100 (buy + merge with what you own, refused only if it won't fit), Upgrade Buy Tier pad, Home button. HUD moved to the doc layout: Home top center, Aura bottom center, Cash bottom left. ServerPackages copied into the worktree from the main checkout.
- 2026-09-28: Phase 2 done (user confirmed). Moving to Phase 3.
- 2026-09-28: Drops no longer carry name/value labels; collecting shows a green "+X" over the player that adds up quick pickups, then floats up and fades (`DropCollected` remote, `reference/drop-pickup-gain.png`).
- 2026-09-28: Blockers refreshed (branch/worktree note, Phase 2 retest of station row and popups).
- 2026-09-28: Deposit and Collect Cash now show big outlined popups ("Deposited X (+Y) Aura [x1.36]!", "Collected X Cash!") styled after `reference/popup-*.png`.
- 2026-09-28: Stations rearranged into one row in front of the pool facing it (from `reference/capybara-onsen-stations.webp`): processor info board, processor tank, deposit stand, market board, pads on the pool side; floating processor sign replaced by a framed info board. User confirmed the Phase 2 loop works.
- 2026-09-28: Phase 1 done. Phase 2 coded: MarketService (server-wide 0.50x-1.50x, 30s, last 20 rolls), market board per plot, Deposit Aura pad + stand, processor tank with "Processing / per second" sign, Collect Cash pad, processor upgrade pad; stations on the player's right of the pool. Shared `Plots.onStep` pad helper (buy pads use it too). Green "good" toasts. STARTING_CASH kept as the real new-player Cash (added to design doc).
- 2026-09-28: User confirmed drop pickup and Aura counter work. Drops changed from one batched drop per tier per cycle to one drop per brainrot every 7s, each on its own timer from when it was placed (user decision; design doc updated). With 80 spots a full onsen makes 80 drops per 7s against the 50-drop cap.
- 2026-09-28: Studio play test: plots, bath rows, fill order, buy pads and the rise/press animations confirmed by user. Drop pickup and the 50-drop cap still unconfirmed.
- 2026-09-28: Polish: new brainrots rise out of the bath (client `BrainrotController`; server now only rebuilds changed spots and stamps SpawnedAt), buy pads sink while pressed (server `Pressed` attribute on `Pad`-tagged parts, client `PadController`). Bath polish (steam, water flow) added to Phase 6.
- 2026-09-28: Spot fill order is now front row first, left to right across both sides (10 spots), then the next row back. Buy pads moved to the player's left of the pool (as in the reference).
- 2026-09-28: Rows changed from bath pairs sharing a river to river-then-bath repeated 8 times (each bath drains into its own lower river); plot depth 220. Doc + CLAUDE.md updated.
- 2026-09-28: Spots now 80 (8 rows x 5 per side; user decision, design doc + ConfigCheck updated). Rows rebuilt as raised stone baths paired around lower rivers, with wooden slides and lanterns, matching the new `reference/capybara-onsen-baths.webp`. Drops follow brainrot > slide > river > channel > pool (`Shared/DropPath`) and can be collected anywhere along the way; server checks distance to the drop's live position and warns in Studio when it refuses. HUD "Onsen x/N" box removed. DROP_FLOW_SECONDS 5 -> 10 for the longer path. Pickup bug reported; cause not confirmed, needs retest.
- 2026-09-28: 6 lanes x 8 spots (was 8 x 6; still 48) to match Capybara Onsen; lanes longer, plot 190 x 140. Design doc, CLAUDE.md updated.
- 2026-09-28: Plot scaled up (160 x 150 studs), longer lanes, narrow pool (14 wide) right in front of the lanes, open ground in front for stations; `DROP_FLOW_SECONDS` 4 -> 5 for the longer path. Second reference screenshot saved and added to the design doc.
- 2026-09-28: `reference/` folder added with the Capybara Onsen plot layout screenshot; same image added to the design doc under "Plot layout".
- 2026-09-28: Plot layout reworked from Capybara Onsen screenshots: lanes are rows (4 per side) flowing into a center channel and a stone-rimmed collection pool at the front; drops float down lane and channel into the pool (`DROP_FLOW_SECONDS` = 4) and are collected there. Design doc and CLAUDE.md updated. Screenshots still to be added to the doc.
- 2026-09-28: Phase 1 coded: plots (built in code), lanes/spots with placeholder brainrots, Buy 1/5/25 pads, 7s batched drops, walk-over collection with server distance check, 50-drop cap, HUD (Aura, Cash, Onsen x/48), Remotes module. Economy: STARTING_CASH, DROP_TOUCH_RANGE, STUDIO_DROP_INTERVAL. stylua/selene/rojo build clean. Awaiting Studio play test.
- 2026-09-28: Phase 0 done. Studio play test prints ConfigCheck OK, server and client started. Moving to Phase 1.
- 2026-09-28: Studio installed; Rojo plugin added; `rojo serve` running on port 34872.
- 2026-09-28: Selene Roblox std generated (Avast shield paused); lint clean.
- 2026-09-28: Installed Rojo, Wally, StyLua, Selene; wally install done; test build passes; StyLua formatting applied. Blocked on Studio install.
- 2026-09-28: Phase 0 scaffold: Rojo project, config modules (Tiers, Economy, LuckyBlocks, Products), Format, ConfigCheck, server/client bootstraps, wally.toml, lint/format config, Stop hook for PROGRESS.md.
- 2026-09-28: Design doc finished. Project folder, CLAUDE.md and PROGRESS.md created.
