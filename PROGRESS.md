# Progress

Current phase: **Phase 1 (plots and drops)**
Last updated: 2026-09-28

## Phase checklist

### Phase 0: Setup
- [x] Project folder `C:\dev\BrainrotOnsen` (outside OneDrive)
- [x] CLAUDE.md and PROGRESS.md
- [x] Stop hook that enforces PROGRESS.md updates (`.claude/settings.json`)
- [x] Git repo initialized (nothing committed yet)
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
- [ ] 6 plots, assigned on join, cleared on leave, name sign
- [ ] 8 lanes x 6 spots per plot, floating name + tier labels
- [ ] Buy 1 / 5 / 25 pads with price scaling
- [ ] Drops every 7 seconds, batched per tier, floating in the lanes
- [ ] Walk over drops = Aura, 50-drop cap
- [ ] Aura counter on the HUD

### Phase 2: Cash loop
- [ ] Server-wide market multiplier, 0.50x to 1.50x every 30 seconds
- [ ] Market board with graph and countdown
- [ ] Deposit Aura stand
- [ ] Processor queue, rate per second, sign
- [ ] Collect Cash pad
- [ ] Processor upgrade pad
- [ ] Cash on the HUD

### Phase 3: Progression and saving
- [ ] Merge! pad, cascading merges
- [ ] Buy 100 with auto-merge
- [ ] Upgrade Buy Tier pad
- [ ] All 20 tiers in config
- [ ] ProfileStore saving with session locking
- [ ] Offline earnings, 100% rate, straight to Aura
- [ ] Home button

### Phase 4: Lucky blocks and Index
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
- To work in Studio: run `rojo serve` in `C:\dev\BrainrotOnsen`, then Connect from the Rojo plugin.
- Avast's HTTPS scanning breaks Rust tools' downloads (Rokit, Selene std, Wally updates). Pause Avast Web Shield briefly when one of those needs the network.
- Code is untested in-game until Rojo syncs into Studio.

## Log (newest first)
- 2026-09-28: Phase 0 done. Studio play test prints ConfigCheck OK, server and client started. Moving to Phase 1.
- 2026-09-28: Studio installed; Rojo plugin added; `rojo serve` running on port 34872.
- 2026-09-28: Selene Roblox std generated (Avast shield paused); lint clean.
- 2026-09-28: Installed Rojo, Wally, StyLua, Selene; wally install done; test build passes; StyLua formatting applied. Blocked on Studio install.
- 2026-09-28: Phase 0 scaffold: Rojo project, config modules (Tiers, Economy, LuckyBlocks, Products), Format, ConfigCheck, server/client bootstraps, wally.toml, lint/format config, Stop hook for PROGRESS.md.
- 2026-09-28: Design doc finished. Project folder, CLAUDE.md and PROGRESS.md created.
