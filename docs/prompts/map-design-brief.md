# Design brief for the map (hand this to the designer Opus)

Purpose: everything a fresh designer needs to plan the visual polish of the Brainrot Onsen map without this conversation. Read this first, then follow the task in `docs/prompts/map-polish-plan.md` (which lists what to produce). This brief is the context; that file is the assignment.

Written 2026-09-29. If something here disagrees with the code, the code wins; if it disagrees with the design doc (linked in `CLAUDE.md`), the design doc wins on game rules.

## 1. The game and the ask

Brainrot Onsen is a Roblox merge tycoon inspired by Capybara Onsen: Italian-brainrot characters soak in each player's onsen baths, drop items that become Aura, and merge 3-into-1 up a 20-tier ladder. Six players per server, one plot each.

The gameplay works and the user has play-tested it through Phase 4. **The problem is the look.** The user's verdict on the map: "the bare minimum, not really visually appealing, I wouldn't continue playing a game like this." They want **the same level of detail and appeal as Capybara Onsen's maps**, and they want the map, backdrop and waterfalls to be **coherent and consistent** (one style), not a patchwork of store assets.

The designer's job: a concrete, phased plan (see `map-polish-plan.md`) to get there.

## 2. How we work (constraints that shape any plan)

- **Rojo project.** Everything is code and files in the repo; the server builds the map at runtime. The user tests in Studio (`rojo serve` from the worktree, Connect in the plugin, Play) and answers with screenshots. Claude cannot see Studio unless the Studio MCP is connected in the session.
- **Claude can look at pictures.** The voxel forge renders preview PNGs, and Claude can open any PNG or WebP with its Read tool. That is the visual feedback loop when Studio is not available: design in code, render, look, iterate.
- **Only the user can upload assets to Roblox** (images, meshes, audio). Anything needing an asset ID must be listed for the user to upload, with the slot where the ID goes.
- **Balance and gameplay numbers stay in `src/shared/Config/`.** Visual layout numbers live at the top of the module that uses them.
- **Quality gates for any change:** `stylua src`, `selene src` (0 errors, 0 warnings), `rojo build -o <tmp>.rbxl`; update `PROGRESS.md`; commit only when the user asks. There is no Luau type checker on the machine, so strict-typing mistakes only show in Studio.
- **Performance matters:** six plots visible, mobile players. Today a plot is roughly 2,000 parts. A performance pass is already needed; every proposal should state its part and particle cost.
- **Style constraint from the user:** consistency beats novelty. Prefer making assets ourselves in one style over mixing store models.

## 3. The reference (what "good" looks like)

Images in `reference/`. Open and study them before planning:

| File | What it shows |
| --- | --- |
| `capybara-onsen-plot-overview.webp` | Whole-plot view: bright studded green ground, tall pegboard wall with hanging scrolls, cherry trees and tall bamboo above it, layered grey-blue cliffs and a waterfall behind, rows of raised stone baths with cyan studded water, the big orange barrel processor, striped-awning stall, lanterns, daisies, floor arrows |
| `capybara-onsen-plot-layout.webp` | The same layout from a lower angle: rows of baths and rivers, slides, pool with piled drops, Merge / buy / Upgrade pads with labels |
| `capybara-onsen-baths.webp` | Close-up of raised stone baths, studded cyan water, wooden slides and foam sparkles at their base, lanterns on the rims, tall bamboo |
| `capybara-onsen-stations.webp` | Station row: framed pegboard info sign under a curved dark-wood roof, orange barrel processor with white bands and a chimney, red-white striped stall with a character behind the counter, black chalkboard market board, blue noren banner with a steam symbol, stone lantern, wooden bridge, neighbouring plots in the distance |
| `lucky-block-*.png/webp`, `popup-*.png`, `drop-pickup-gain.png` | UI references (popups, lucky block panel and reveal), not map |

**What makes the reference look rich** (observed): studded texture on every surface (grass, water, stone, wooden wall); toy-brick voxel shapes with chunky proportions; strong saturated colours (bright green, cyan, orange, red, pink); very tall boundary wall and props for scale; layered cliffs with a waterfall and mist; steam and foam sparkles; dense small details (daisies, shrubs, stepping stones, lanterns, scrolls, signs); floor arrows guiding to pads; other plots visible in the distance; a bright sky.

## 4. What exists now

### Layout (plot-local studs; do not move gameplay elements)
- Plot 130 wide (x from -65 to 65) and 220 deep (z from 0 at the road to 220). Two rows of three plots face each other across a 30-stud road; plots are 12 apart. Back-row plots are rotated 180 degrees; the code works in plot-local coordinates through an `at(x, y, z)` helper.
- Floor top at y=1. Spawn at z=52.
- 8 rows of raised baths (`LANES_FRONT_Z` = 90, pitch 15: an 8-stud river then a 7-stud bath), one bath each side of a centre channel (8 wide), 5 brainrots per bath (spots 9 apart), baths raised to y=4. Wooden slides run from each bath rim into its river; rivers flow to the channel; the channel empties into a narrow pool (14 wide, z 60 to 88) with a stone rim.
- Station row (structures at z=26, pads at z=38, facing +z): processor info board (x=-52), processor tank (x=-30), deposit stand (x=-10), market board (x=12). Buy pads at z=72 (x 18..50), Merge (18,58), Upgrade Buy Tier (36,58). Robux pads at z=46.
- Plot entrance from the road: a wooden sign at z=2; the torii gate at z=14.

### Art and decoration (all built in code, anchored)
- `src/server/Plots.luau`: geometry; `src/server/Decor.luau`: wall, cliffs + waterfall, props placement, particles; `src/server/Skin.luau` + `src/shared/Config/Textures.luau`: texture application (IDs are 0 until the user uploads `assets/textures/*.png`); `src/server/Services/AtmosphereService.luau`: sun, sky, haze, bloom, colour correction, sun rays.
- **Voxel prop forge** (`tools/voxel_forge.py`): designs props as voxels, greedy-merges to boxes, renders previews, writes `src/shared/PropData.luau`; `src/shared/Props.luau` places them. Existing props: CherryTree (88 boxes), StoneLantern (23), Torii (19), Bamboo (45).
- **Generated textures** (`tools/make_textures.py` -> `assets/textures/`): grass, water, stone, pegboard, cliff, arrow; seamless, studded, toy-brick colours. Waiting for the user to upload and paste asset IDs.
- **Brainrot characters** are third-party textured skinned meshes from a free pack by Agus_Fellini2 (20 Normal-variant models in `assets/Brainrots.rbxmx`, synced to `ReplicatedStorage.Assets.Brainrots`), scaled to fit the baths; they stand still by choice. Drop items are still crude code-built blocks (`src/shared/Models.luau`) and should be redone.
- Wall: 11-stud tan wall with dark posts, top rail and hanging paper scrolls on the two sides and the back. Cliffs: three stepped grey-blue blocks 62 to 92 studs tall behind the back wall with a waterfall and mist. Steam on every bath. Petals fall from trees. Daisies near the entrance and along the walls.

### Known gaps (see `docs/map-polish.md` for the full analysis)
No textures applied yet; no custom shapes for the big stations (the processor is a plain cylinder, the deposit stand a counter with an awning box, no real curved roof over the info board); sparse density; no bridge, bushes, stepping stones, floor arrows, banners; static water; foam splashes at slide bottoms missing; no sound; no distant scenery or skyline; drop items ugly; performance not yet optimised.

## 5. Decisions already made by the user (do not re-litigate)

- The layout of the plot is approved: 8 rows x 5 brainrots per side, rivers and slides, centre channel and narrow pool, station row in front of the pool. Brainrots fill front row first, left to right.
- Art plan order: (1) props we make in code, (3) models built through the Studio MCP, (2) the user's own or bought models at the very end. The user leans toward making everything ourselves for consistency ("make the background and waterfalls yourself").
- Brainrot models come from the pack; they stand still; drop items can be fixed later.
- Game passes and dev products are deferred to the end; do not plan monetization work.
- The processor should look like the reference's orange barrel, not a Japanese house. The market/deposit stall agent should be a brainrot (Tung Tung Tung Sahur, the Tier13 model) behind the counter. The user likes bamboo, their own mini pool and onsen signs like the reference.
- Store models the user shared were mostly rejected as stylistically inconsistent. Possible small exceptions: the paper lantern (asset 11526055489), the rubber duck (5134201685), and the arched bridge from "Cherry Blossom tree lake" (6003209103). All others: skip. The full verdict list is in `PROGRESS.md` (Phase 6).

## 6. Tools the designer's session may have

- File tools and the shell (Python 3.13 with Pillow, Rojo, StyLua, Selene). Read can open images, so previews can be inspected.
- The **Studio MCP** if the session was started after it was added (it runs `StudioMCP.exe` via `%LOCALAPPDATA%\Roblox\mcp.bat`; Studio must be open with the project and "Enable Studio as MCP server" on in Assistant). It can run code in Studio, insert Creator Store assets by ID, read console output, and start/stop play. Verify with a tool list before relying on it.
- The design doc (`CLAUDE.md` has the link) is read with the Claude Docs tools, never a web fetch. Web fetch/search work for public Roblox pages and the Roblox thumbnail and economy APIs (useful to preview and vet assets).

## 7. What the plan must settle (the important decisions)

1. **Texture route:** generated studded tiles the user uploads, versus the stud surface type, versus both; order of application; what to do about water animation.
2. **Big-prop route:** which stations/props to make in the voxel forge, which need a smoother shape, and where the Studio MCP or a mesh pipeline is actually worth it (curved roof, barrel, cliffs).
3. **Backdrop:** how to make cliffs and waterfalls that are layered, consistent with the studded look, and cheap; what neighbouring plots and the horizon should look like; sky.
4. **Density:** what small props to add and how to place them procedurally without colliding with pads and stations.
5. **Motion and sound:** particles (steam, foam at slides, mist, petals, sparkles), animated water, and an audio plan (assets the user must find).
6. **Performance:** part budgets per plot, merging static geometry, StreamingEnabled, shadows, mobile.
7. **Order of work and the "definition of done"** that the user can verify with screenshots.

## 8. Open questions for the user (ask early, do not block on all)

- Can they upload the six generated textures now (they should; steps in `assets/textures/README.md`)?
- Audio style: calm Japanese onsen, or upbeat?
- Which single area should be perfect first (suggested: the pool, station row and first two bath rows, as in the overview screenshot)?
- Are they happy with the brainrot pack's look next to the voxel props, or should the props lean more polished/rounded?
