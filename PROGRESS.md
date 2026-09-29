# Progress

Current phase: **Phase 6 (art, polish and launch) in progress. Phase 5 game passes / dev products are deferred to the end (user decision 2026-09-29); Phase 4: Index check pending.**
Last updated: 2026-09-29

## Handoff (start here)

- **Where the code is:** branch `claude/priceless-cori-962788` in the worktree
  `C:\dev\BrainrotOnsen\.claude\worktrees\priceless-cori-962788`. Phases 1-4 are committed
  there; `main` (`C:\dev\BrainrotOnsen`) is still at Phase 0 (278349a). Merge the branch into
  `main` when the user asks.
- **How the user tests:** `rojo serve` from the worktree folder (not `C:\dev\BrainrotOnsen`
  until the branch is merged), Connect in the Rojo plugin, Play in Studio. Claude can start
  `rojo serve` in the background; only one server can hold port 34872.
- **`ServerPackages/` is gitignored:** a fresh worktree needs `wally install` or a copy of
  `C:\dev\BrainrotOnsen\ServerPackages` (ProfileStore). Restart `rojo serve` after adding it.
- **Before finishing any change:** `stylua src`, `selene src` (0 errors, 0 warnings),
  `rojo build -o <tmp>.rbxl`; update this file (the Stop hook enforces it). Commit only when
  the user asks.
- **Studio-only test knobs** in `Config/Economy` (ignored in live servers):
  `STUDIO_DROP_INTERVAL` (0 = off), `STUDIO_STARTING_CASH` (500K for new profiles),
  `STUDIO_LUCKY_BLOCK_INTERVAL` (0 = off; the user sets 10 to test blocks),
  `STUDIO_SIMULATE_PURCHASES` (true: a pass / product with ID 0 is granted free in Studio).
- **Visual references:** `reference/*.webp|png` are Capybara Onsen screenshots the user gave;
  the user wants layout and UI to match them closely. When the user shares a new screenshot,
  save it to `reference/` and add it to the design doc.
- **Voxel prop forge (2026-09-29):** the chosen art route for map props. Edit designs in `tools/voxel_forge.py`, run `python tools/voxel_forge.py` (writes `PropData.luau`; previews go to `$PROP_PREVIEW_DIR` or the temp folder and can be looked at with Read), then Rojo syncs. Keep box counts low; use lighter/darker voxels sparingly because they split boxes.
- **Store link verdicts (user's 12 links, 2026-09-29):** use: Japanese Lantern paper lantern 11526055489 (cartoon, hanging decoration), Rubber Duck 5134201685 (bath prop), maybe the wooden arched bridge from Cherry Blossom tree lake 6003209103 (extract only the bridge), maybe Torii 15999380118 recoloured brighter, Anime Sky 135781140278534 (a sky image; spammy title, inspect for scripts/audio before use; extract only the Sky). Skip: Reeds, Heaven's Plant, grass floor (dull realistic), Enhanced Sakura tree (realistic, heavy), stone lantern 12521854808 (dark realistic), Japanese house / Assets Pack (dark realistic; maybe mine tatami mat and planter trees). Not the processor: use a barrel-style processor built by us.
- **Ideas from the user:** Tung Tung Tung Sahur (Tier13 model) as the market/deposit stall agent; bamboo-fenced mini pool and onsen signs like the reference; build cliffs / waterfalls / backdrop ourselves for consistency.
- **Next up (map polish is the priority):** run `docs/prompts/map-polish-plan.md`, get the user's answers to the open questions in `docs/map-polish.md` (texture uploads, models vs code, audio), then execute the plan phase by phase. Phase 6 art: play-test the pack models (fit, facing, idle animation), then Index viewports, drop items, bath polish, map decoration, credits. Phase 5 monetization (passes, products,
  Robux pads) is deferred to the end; resume it with the known issue in the Phase 5 section. Studio purchases are
  simulated free while product IDs are 0 (`Economy.STUDIO_SIMULATE_PURCHASES`); product IDs in `Config/Products` are
  0 until created on the Creator Dashboard.
- **Open decisions for the user:** drop cap stays 50 even though a full onsen (80 brainrots)
  fills it in ~5 s (raised with the user, no answer yet; kept at 50); Robux prices marked "suggested" in the doc.

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
- [x] Block every 3 minutes of production, type by highest tier (arrives as a drop and floats into the pool; `LuckyBlockService`)
- [x] Pick up and hold a block (tool pose, chest in the right hand), odds panel, Unlock / Discard (`LuckyBlockController`)
- [x] Rolls with 60 / 30 / 9 / 1 odds; only merges if the onsen is full; on-screen open-up reveal
- [ ] Index grid with silhouettes and "New brainrot!" popup (`IndexController`; coded, not yet confirmed in Studio)
- Done when: you can open every block type and each result shows up correctly in the Index

### Phase 5: Monetization and social
**Game passes and dev products are DEFERRED to the end** (user decision 2026-09-29): do them after Phase 6 art / polish, before publishing. The code exists and is in the game, but treat it as unfinished. Tested by the user so far: the Cash x2 / x4 / x7 pads work (simulated Studio purchases) and Auto Collect works.
- **Known issue to fix when this resumes:** the Cash multiplier is applied when the processor produces Cash, so Cash already waiting on the Collect Cash pad is not multiplied when a pass is bought (the user saw no multiplication on walking over the pad). Capybara Onsen applies it at collection ("[x4 Cash] Collect Cash" on the pad, `reference/capybara-onsen-stations.webp`). Fix: keep `pendingCash` raw, multiply in `collectCash` and in the pad label (show `[xN Cash]`), stop multiplying in `process` and `finishNow` (`ProcessorService`), and refresh the label every tick so it follows pass / friend changes.
- [ ] Game passes: 2x Aura, Auto Collect (credits drops instantly, never fills the cap), x2 / x4 / x7 Cash (`MonetizationService`)
- [ ] Dev products: Finish Now, Cash packs S / M / L, ProcessReceipt + receipt log (`data.receipts`)
- [ ] Robux pads next to their stations (Finish Now, Auto Collect, 2x Aura, Cash pass), Cash pack buttons on the HUD
- [ ] Friend boost (+10% per friend, max 50%, on processor Cash), Premium boost (+10% Aura)
- [ ] Total Brainrots leaderstat + global leaderboard board in the middle of the map (`LeaderboardService`)
- Done when: every pass and product works in a Studio test purchase and survives a rejoin

### Phase 6: Art, polish and launch
**Art plan (user decision 2026-09-29): use all three approaches, in this order:** (1) blocky models built in code (`Shared/Models`), (3) models built directly in Studio through the Studio MCP, and (2) the user's own / bought models at the very end.
- **Studio MCP:** added 2026-09-29 with `claude mcp add --transport stdio Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"` (Roblox's built-in `StudioMCP.exe`; health check "Connected"). It is in the local config of the worktree path only, so a new worktree needs the command again (or `--scope user`), and its tools only appear in a session started after it was added. Studio must be open with the project and Assistant > Manage MCP Servers > "Enable Studio as MCP server" on. Models built this way must be saved as `.rbxm` under the repo (e.g. `assets/`) and synced by Rojo, then `Shared/Models` should clone them when present and fall back to the code-built ones.
- [x] 20 brainrot models: **imported from the free "Brainrot Pack [150+]" by Agus_Fellini2** (Creator Store asset 137461628889541, [store page](https://create.roblox.com/store/asset/137461628889541/Brainrot-Pack-150); free / public domain flag; the user's copy is `C:\Users\janfo\OneDrive\Desktop\Brainrot Models.rbxm`). User confirmed in Studio (2026-09-29) that they load and look right. Not yet confirmed: whether the idle animation plays (it may not, see Known risks); test in the published game too.
  - How it works: `tools/extract_brainrot_pack.py` trims the pack (87 characters x 7 rarity variants, skinned + animated) to the 20 Normal-variant models in `assets/Brainrots.rbxmx` (Tier1..Tier20, scripts and lights removed). Rojo syncs it to `ReplicatedStorage.Assets.Brainrots`; `Shared/Models.makeBrainrot` clones `Tier<N>`, scales it to fit a bath (max 4.6 wide, 6.5 tall), stands it on the origin (WorldPivot, no PrimaryPart) and falls back to the code-built design if the asset is missing. Client `BrainrotController` loops the pack's `Anims/Idle`.
  - Tier mapping (in the script): 1 Tim Cheese, 2 Trippi Troppi, 3 Boneca Ambalabu, 4 Frigo Camelo, 5 Lirili Larila, 6 Chimpanzini Bananini, 7 Brr Brr Patapim, 8 Bombombini Gusini, 9 Cappuccino Assassino, 10 Ballerina Cappuccina, 11 Bombardiro Crocodilo, 12 Tralalero Tralala, 13 Tung Sahur, 14 La Vacca Saturno Saturnita, 15 Glorbo Fruttodrillo, 16 Cocofanto Elefanto, 17 Odin Din Din Dun, 18 Girafa Celeste, 19 Gorillo Watermelondrillo (substitute: no Tigrrullini Watermellini in the pack), 20 Los Tralaleritos.
  - Known risks: the pack's meshes, textures and animation are owned by Agus_Fellini2, referenced by ID, so they can break if he removes them, and his idle animation may not play in our experience (Roblox restricts animation ownership); fall back to a code-driven idle if so. Test in the published game, not only Studio.
  - To do: credit Agus_Fellini2 in-game / in the description; the pack has ~65 more characters and rarity variants (Oro, Diamante, Galaxia, Lava, Arcoiris, Hacker) usable later (events, lucky block rewards, more tiers).
- [ ] 20 drop item models: code-built for all 20 tiers (`Models.makeDropItem`), untested in Studio; the pack has none, so replace via Studio MCP or the user's models later.
- [x] Index grid: shows the models (ViewportFrames; silhouettes when undiscovered) instead of color swatches. Coded, waiting on the Studio look.
- [ ] Onsen map (**user verdict 2026-09-29: first pass is "the bare minimum, not visually appealing"; wants Capybara Onsen's level of detail**). Deep dive: `docs/map-polish.md`; planning prompt: `docs/prompts/map-polish-plan.md` (run it in a fresh plan-mode session, ideally with the Studio MCP connected). Second pass coded 2026-09-29 (tall pegboard wall with paper scrolls, huge stepped cliffs, big cherry trees with petals, tall bamboo, bigger lanterns, daisies, steam on baths, `AtmosphereService` lighting / haze / bloom), not yet seen in Studio. Lanes, water, processor, market stand done; decoration coded 2026-09-29 (`server/Decor.luau`: fences, cliffs + waterfall, cherry trees, bamboo, stone lanterns; plot floor now grass green), waiting on the Studio look. Still to do: steam / water flow, backdrop beyond the plots
- [ ] Idle animations
- [ ] Lucky block polish (user 2026-09-29: "lucky blocks can be polished"; what to change is not specified yet, ask): chest look, floating / pickup effect, panel, reveal
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
- After changing `default.project.json` (or adding files Rojo must serve), restart `rojo serve` and Disconnect / Connect the plugin; an old server keeps serving the old tree (this is why the pack did not show the first time).
- Saving only persists in Studio once the place is published (File > Publish to Roblox) and Game Settings > Security > "Enable Studio Access to API Services" is on. Until then ProfileStore runs in mock mode (no persistence) and every join is a new player.
- Deferred by the user: publish the place and enable Studio API access, then test saving + offline earnings (stop, wait a few minutes, replay).
- Confirm the Index (open it after getting a few tiers; undiscovered = "???").
- Before launch, create the 5 game passes and 4 dev products on the Creator Dashboard and put their IDs in `Config/Products` (Robux prices in that file are reference only; the doc marks Cash pack prices 29 / 149 / 499 as suggested). The global leaderboard also needs the published place + Studio API access.
- Avast's HTTPS scanning breaks Rust tools' downloads (Rokit, Selene std, Wally updates). Pause Avast Web Shield briefly when one of those needs the network.
- A few early Capybara Onsen screenshots (HUD, Index) were pasted in chat only and never saved as files. Drop them into `reference/` and Claude will add them to the design doc.

## Log (newest first)
- 2026-09-29: Map polish work (voxel forge, textures, atmosphere, decoration, planning docs) committed on branch `claude/priceless-cori-962788` (ae39e30). Not merged into `main` yet.
- 2026-09-29: User asked to make all props ourselves for a coherent, detailed look. Built a voxel prop forge (`tools/voxel_forge.py`): designs props as coloured voxels, greedy-merges them into boxes, renders isometric previews (Claude can see them without Studio) and writes `src/shared/PropData.luau`; `Shared/Props.place` builds and places them. Pilot props: CherryTree (88 boxes), StoneLantern (23), Torii (19), Bamboo; Decor now uses them (torii over the entrance, trees + bamboo + lanterns). Next props: market stall with awning, processor barrel, wooden bridge, bush, onsen sign, noren banner, bath fence, waterfall / cliff pieces. Part-count perf pass still to do (about 2000 parts per plot).
- 2026-09-29: Vetted the user's 12 Creator Store links by thumbnail (see Phase 6 map notes): mixed styles, most clash with the bright toy-brick look. Decision: make the backdrop (cliffs, waterfalls, ground, water, wall) ourselves so it is consistent. Generated matching studded textures (`tools/make_textures.py` -> `assets/textures/*.png`) and wired `Config/Textures` + `server/Skin` (inert until the user uploads the PNGs and pastes the asset IDs; steps in `assets/textures/README.md`).
- 2026-09-29: Map polish second pass after the user called the map bare: taller wall + scrolls, bigger cliffs / trees / bamboo / lanterns, daisies, steam, AtmosphereService (lighting, sky, haze, bloom, colour correction). Wrote `docs/map-polish.md` (deep dive) and `docs/prompts/map-polish-plan.md` (prompt to produce the polish plan).
- 2026-09-29: Phase 5 code, brainrot pack import, decoration and Index images committed on branch `claude/priceless-cori-962788` (e31030f). Not merged into `main` yet.
- 2026-09-29: Added "lucky block polish" to the Phase 6 list at the user's request (details to be asked).
- 2026-09-29: User decided the brainrots should stand still (no idle needed) and drop items can be fixed later. Added map decoration (`server/Decor.luau`, per plot: fence, three cliffs with a waterfall, cherry trees, bamboo clusters, stone lanterns; plot floor grass green) and the Index now shows the brainrot models in ViewportFrames (silhouettes when undiscovered).
- 2026-09-29: User confirmed the pack brainrot models load in the baths (needed a Rojo serve restart after the project file changed). Idle animation still unconfirmed.
- 2026-09-29: Docs updated for the imported brainrot pack (Phase 6 section, tier mapping, risks, credit to do); CLAUDE.md gained the assets/, tools/ and pack notes.
- 2026-09-29: Brainrot pack imported: user's `Brainrot Models.rbxm` (by Agus_Fellini2; 87 characters x 7 rarity variants, skinned + animated) trimmed by `tools/extract_brainrot_pack.py` into `assets/Brainrots.rbxmx` (20 Normal-variant models Tier1..Tier20, scripts + lights removed), synced by Rojo to ReplicatedStorage.Assets.Brainrots. `Shared/Models.makeBrainrot` uses them (scaled to fit a bath, bottom-centre pivot) with the code-built ones as fallback; client `BrainrotController` loops the pack's Anims.Idle. Tier 19 uses Gorillo Watermelondrillo (no Tigrrullini in the pack). Fixed: code-built models set a PrimaryPart, which overrides WorldPivot, so they sank into the baths.
- 2026-09-29: Studio MCP server added to the Claude Code config for this worktree (see Phase 6 art plan); tools available from the next session.
- 2026-09-29: Phase 6 started. Art plan: code-built models first, Studio MCP models second (user must connect it), user's own models last. Added `Shared/Models` (brainrot designs 1-5 + generic 6-20, 20 drop items); baths, drops and the unlock reveal now use models instead of cubes / balls.
- 2026-09-29: User deferred game passes / dev products to the end. Recorded the known Cash-multiplier-at-collection issue and the fix in the Phase 5 section; Phase 5 code left in place, uncommitted. Rojo serve running on the worktree (port 34872).
- 2026-09-29: Phase 5 coded (untested): MonetizationService (passes, Finish Now, Cash packs via ProcessReceipt + receipt log, Aura / Cash multipliers, friend + Premium boosts, Auto Collect), Robux pads beside their stations, HUD Cash pack buttons / Premium / friend boost / Cash multiplier / Total Brainrots, LeaderboardService (leaderstat + global OrderedDataStore board in the middle of the map). Studio-only `STUDIO_SIMULATE_PURCHASES` grants purchases free while product IDs are 0.
- 2026-09-29: Lucky block hold pose and handoff docs committed on branch `claude/priceless-cori-962788` (cdf2a96). Not merged into `main` yet.
- 2026-09-28: Handoff docs: PROGRESS "Handoff (start here)" section, Phase 4 lucky block items ticked (user confirmed), stale blockers removed; CLAUDE.md gained a module map, conventions and workflow notes.
- 2026-09-28: User confirmed the tool-hold arm pose. Held chest now sits in front of the hand at hand height, gripped like a tool (bigger, 3.6), per `reference/lucky-block-held-tool-pose.png`.
- 2026-09-28: Held lucky block arm pose now uses Roblox's default tool-hold animation (R15 507768375 / R6 182393478) played by the holder; editing shoulder Motor6D C0 had no effect on the user's rig.
- 2026-09-28: Phase 4 work committed on branch `claude/priceless-cori-962788` (0fc8e9f). Not merged into `main` yet.
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
