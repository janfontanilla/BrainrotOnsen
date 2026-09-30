# Map polish roadmap (approved 2026-09-29)

The plan for making the onsen look like Capybara Onsen (`reference/capybara-onsen-*.webp`). Context: `docs/map-polish.md` (gap analysis) and `docs/prompts/map-design-brief.md`. Execute one phase per Studio session; every phase ends with the check shots below.

## User decisions (2026-09-29)

- Claude may upload images through the Studio MCP (`upload_image`, served from a local `python -m http.server`). The 8 textures are uploaded; IDs are in `Config/Textures`.
- 1-stud built-in studs are fine where no tile applies (pads, fallback when an ID is 0).
- Audio: calm Japanese onsen music and ambience.
- Perfect first: the station row, the pool and the first two bath rows (check shots A and C).

## What Studio showed (MCP inspection, 2026-09-29)

- Studio was running a pre-forge build (about 920 parts per plot). **The current branch build is about 1,520 parts and 23 emitters per plot** (after Phase 1): cherry trees 528 (6 x 88 boxes), bamboo 270, stone lanterns 138, daisies 114. StreamingEnabled is already on. The sky is a custom "Tycoon" skybox.
- The place file holds a stray free-model leaderboard with a script (`Workspace.Leaderboard.LeaderBoard.SurfaceGui.Script`, DataStore `GlobalLeaderboard_Kills`), not ours; the user should delete it.
- Worst offenders: flat plastic everywhere; dark navy cliff slabs; Neon waterfalls and pads blooming to white; primitive stations; thin grey baths; bare grass.
- Proven in the live place: `SurfaceType.Studs` on `Plastic` gives the toy-brick look; runtime `MaterialVariant`s with the uploaded tiles render, and the part Color multiplies the tile (so textured parts are near-white). `Lighting.Technology` cannot be set by a script (set it in the project file or by hand).

## Done outside the phase list (2026-09-29, user request)

Front edge (canal, kerbs, pegboard fence, bridge, torii with name plaque, path), pad trays and colours, Merge! engraving, floor arrows, outlined stud-sized labels, and the pad layout the user chose (Merge! centred in front of the pool, Buy 1 / 5 against the pool, x2 Cash in front of Collect Cash). Phase 4's arrows are partly done (Deposit > Collect Cash).

## Later rounds (2026-09-29, from the user's Capybara Onsen screenshots)

- Layout settled by the user: narrow pool with Merge! in front; pad row Buy 1 / Buy 5 / Auto Collect | pool | Buy 25 / Buy 100 / Upgrade Buy Tier ("right" = the Upgrade Buy Tier side, -x); Robux pads in line on that side of the pad they boost; barrel by the -x wall with Collect Cash in front; group reward pad in front of the group sign.
- Rows like Capybara's: the whole bath field is sunk into the floor (one streaming water sheet, stone lip, dark bed); baths are thin stone rings whose rims sit just above the grass.
- Declutter: few prop types, small leaf sprigs instead of big bushes, open lawns, spaced pads, smaller labels; warm lantern glow.
- Entrance: dark wooden gate with blue hot-spring noren (forge `EntranceGate`).
- Middle area: 140 studs, lake loop with conveyor current, raised island with three leaderboard pavilions, end cliffs with waterfalls.
- HUD copied from Capybara Onsen (`client/Style`).

## Check shots

Plot-local camera positions; for Plot 1 world = local + (-142, 0, 15). With the MCP connected Claude takes them with `screen_capture` (Studio must be in Play).

| Shot | Camera | Look at | Compare with |
| --- | --- | --- | --- |
| A overview | (-18, 30, 30) | (0, 5, 95) | `capybara-onsen-plot-overview.webp` |
| B baths | (-20, 14, 100) | (-20, 4, 130) | `capybara-onsen-baths.webp` |
| C stations | (0, 14, 60) | (0, 8, 20) | `capybara-onsen-stations.webp` |
| D backdrop | (0, 40, 80) | (0, 40, 260) | cliffs and waterfall |

## Technical decisions

- **Surfaces:** uploaded tiles as MaterialVariants (`MaterialService.Onsen_<key>`, declared in `default.project.json` because game scripts cannot set `BaseMaterial`; applied by `Skin.apply`), no per-face Texture instances (they would have cost about 2,500 across the map). Water keeps per-face `Texture`s (`Skin.tile`) because only those can scroll. Built-in 1-stud studs for pads and as the fallback while an ID is 0.
- **Props:** everything through the voxel forge (`tools/voxel_forge.py`) for one consistent blocky style; the reference itself is blocky. No runtime CSG unions. Store exceptions only if a forge prop disappoints: paper lantern 11526055489, rubber duck 5134201685, bridge from 6003209103.
- **Merging:** the forge's greedy box merge is the merge; keep a prop at 100 boxes or fewer; `LevelOfDetail = StreamingMesh` on large models.
- **Shadows:** ShadowMap technology; shadows only on trees, stations, wall and cliffs.
- **Budget (revised after measuring):** at most 1,900 parts and 45 emitters per plot (hard cap 2,100, about 12k parts map-wide); total emitter rate at most about 150 particles/s per plot. To make room, Phase 2 includes a forge diet: CherryTree 88 > 45 boxes, Bamboo 45 > 25 (fewer lighter/darker voxels), saving about 380 parts per plot.

## Phases

Parts and emitters are per plot, on top of the previous phase.

| # | Phase | Main files | Cost | Check |
| --- | --- | --- | --- | --- |
| 0 | Sync: `rojo serve` from the worktree, reconnect the plugin (Studio was running a pre-forge build) | none | 0 | Decor has `CherryTree` / `Torii` models |
| 1 (done 2026-09-29) | Quick win: tiles on grass, stone, wall, cliffs, slides, water; pads matte with studs and a dark frame; waterfall not Neon; lighter haze, higher bloom threshold; no shadows on small parts | `Skin`, `Plots`, `Decor`, `AtmosphereService`, `Config/Textures` | +16 parts (pad frames) | A and B: studded tiles, no white glare, pale cliffs |
| 2 (done 2026-09-29) | Station row props: `ProcessorBarrel`, `ToriiRoofBoard`, `DepositStall` (+ Tier 13 Tung Tung Tung Sahur behind the counter), `BoardFrame`, `Noren` (onsen decal); chimney smoke; forge diet for CherryTree and Bamboo | `voxel_forge.py`, `PropData`, `Plots` station section | +240 - 380, +1 emitter | C against the stations reference; every station pad reachable, labels readable |
| 3 (done 2026-09-29) | Baths and water: darker rim caps, `RimLantern` props instead of Neon cubes, foam along each river where slides land, lower steam, `Bridge` over the channel at z 89, water textures scrolling toward the pool | `Plots` bath section, `Decor`, `voxel_forge.py`, new `Controllers/WaterController` | +130, +16 emitters | B; brainrots do not clip lanterns; drops visible under the bridge |
| 4 (done 2026-09-29) | Density and floor guidance: seeded scatter with keep-out rectangles built from the `Plots` layout constants (pads + 3 studs, stations, pool, baths, channel, an 8-stud walk corridor road > spawn > pool); `Bush` S/M/L, `DaisyPatch`, `SteppingStone`, kerb strips, arrow chevrons (arrow texture) toward Deposit and Collect Cash | `Decor`, `voxel_forge.py` | +250 | A density; walk to every pad |
| 5 (done 2026-09-29) | Backdrop: three layers of stepped cliffs with grass ledges and trees, a 3-step cascade waterfall with foam pools and mist, a ring of far hazy hills around the map | `Decor`, `Plots.build` | +40 (+60 map-wide), +2 emitters | D, and from the station row toward the road: no void |
| 6 (done 2026-09-29: unified tile set) | Tile polish: tune `studsPerTile`, tints; planks on the stall / bridge; `onsen` decal on noren banners | `Config/Textures`, props | 0 | A, B, C |
| 7 (done 2026-09-29) | Sound: calm Japanese onsen ambient music loop, 3D waterfall and river sounds, pad click / purchase / merge / deposit / collect SFX | new `Config/Sounds`, new `Controllers/SoundController`, `Decor` | 3 Sounds | walk road > waterfall; SFX not annoying after 5 min |
| 8 | Performance and sign-off: daisies 3 > 1-2 parts, scrolls 4 > 2, stone lanterns 23 > 15 boxes, CastShadow audit, streaming radii (min 128, target 384), `Lighting.Technology = ShadowMap` in the project file, device emulator + MicroProfiler + the user's phone | several | about -130 | budget met, 60 FPS on a mid phone |

## Asset list

- **Textures (uploaded 2026-09-29 through the MCP; IDs in `Config/Textures`, and for the five tile variants also in `default.project.json`):** grass, water, stone, pegboard, cliff, arrow, planks, onsen. Regenerate with `tools/make_textures.py`; re-upload through the MCP when one changes.
- **Models:** all voxel-forge: processor barrel, torii-roof board, deposit stall, board frame, noren, rim lantern, bridge, bushes, daisy patch, stepping stone, chevron (cherry tree, bamboo, stone lantern, torii exist).
- **Audio (Creator Store > Audio, Roblox-made only, public and free):** ambient music "japanese koto calm", "zen garden" (seamless loop 60-180 s); "waterfall loop"; "stream water loop"; "ui click soft"; "cash register" / "coins"; "pop" / "magic sparkle"; "whoosh". SFX under 1.5 s, similar loudness.

## Risks

- Legacy stud surfaces may be deprecated some day: the tiles cover almost everything already.
- Props blocking pads: keep-out list from the same constants as the pads, plus the walk check.
- Back-row plots are rotated 180 degrees: check both rows every phase.
- Freshly uploaded images can take a moment to pass moderation; an image that shows grey is usually still pending.

## Acceptance checklist

- [ ] Shot A matches the overview in density and colour; no bare grass patch wider than about 10 studs outside the walkway.
- [ ] Shots B and C match the baths and stations references element for element.
- [ ] No white glare except lantern cores; cliffs pale and layered; no void from any plot.
- [ ] Water visibly flows; ambient music and SFX play.
- [ ] Every pad and label reachable and readable; no clipping with brainrots, drops or players.
- [ ] Both plot rows identical.
- [ ] At most 1,900 parts and 45 emitters per plot; 60 FPS on a mid-range phone with 6 plots filled.
- [ ] `stylua`, `selene` (0/0), `rojo build` clean after every phase.
