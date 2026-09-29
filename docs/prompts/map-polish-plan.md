# Prompt: plan the map polish

Paste everything below the line into a fresh Claude Code session, ideally in plan mode, with the Roblox Studio MCP connected if possible. It should produce a plan, not code.

---

You are planning the visual polish of the map in **Brainrot Onsen**, a Roblox merge tycoon built with Rojo in `C:\dev\BrainrotOnsen` (or its current worktree). The user's verdict on the first pass was: "the bare minimum, not really visually appealing, I wouldn't continue playing a game like this." The target is the level of detail in the Capybara Onsen screenshots.

## Read first
1. `CLAUDE.md` (rules, architecture, module map, conventions).
2. `PROGRESS.md` ("Handoff (start here)", Phase 6).
3. `docs/map-polish.md` (gap analysis: why it looks bare, the reference inventory, ranked levers, risks, open questions).
4. Look at every image in `reference/` (Read them). Before planning, write a short inventory per screenshot of every visible map element, material, colour, particle and light, and note how big things are relative to the player.
5. The code that builds the map: `src/server/Plots.luau` (geometry), `src/server/Decor.luau` (decoration, particles), `src/server/Services/AtmosphereService.luau` (lighting), `src/shared/Models.luau`, and `assets/`, `tools/`.
6. If the Studio MCP tools are available, inspect the live place (what a plot looks like, part counts, lighting) before planning. If not, say so and plan around screenshots from the user.

## Facts and constraints
- Six plots, each 130 x 220 studs, two rows facing a road; a plot has 8 rows of raised baths (80 spots), rivers, a channel and pool, and a station row (processor, deposit stand, market board, pads). Layout is fixed and approved by the user; do not move gameplay elements.
- Everything is built in code by the server so it syncs through Rojo; the pack brainrot models come from `assets/Brainrots.rbxmx`. Models from other sources must be scripts-stripped and saved under `assets/` (see `tools/extract_brainrot_pack.py`). Restart `rojo serve` and reconnect the plugin when `default.project.json` changes.
- The user tests in Studio and reports with screenshots; Claude cannot see Studio unless the MCP is connected. Every phase needs a concrete "what to look at" check.
- Performance matters: six plots visible, mobile devices. Give a part / particle budget per plot and per phase.
- Third-party assets: free only, keep local copies, credit creators, no scripts, no ripped content. Textures and audio need Roblox asset IDs; only the user can upload, so list exactly what to upload and the ID slots to fill.
- Do not commit unless asked. Code must pass `stylua src`, `selene src` (0 errors, 0 warnings) and `rojo build`. Update `PROGRESS.md` after any project change.

## Deliverable
A plan the user can approve and then execute phase by phase. Produce:

1. **Reference inventory** (from step 4) and a **gap list**: what the reference has that we lack, ranked by visual impact.
2. **Target look**: one paragraph per area (ground, boundary wall, backdrop, baths and water, pool, processor and station row, props, lighting and sky, particles, sound, floor guidance) saying what "done" looks like and which reference image it matches.
3. **Phased roadmap.** Each phase must be small enough to test in one Studio session and list: goal, exact files / modules to add or change, technique (code parts, textures, models, particles, audio), asset needs (what the user must upload or find, with search terms or specs), performance cost, the visual check the user does, and what could go wrong. Order phases by impact per effort; start with the ones that change the look most (lighting tuning, textures, density, big props). Include a quick-win phase that can ship within one session.
4. **Asset shopping list**: textures (grass, water, stone brick, plank / pegboard), models (torii roof, processor barrel, stall with awning, cherry tree, bamboo, lanterns, bridge, bushes, banner), audio (ambient loop, water, click, purchase), each with size / style spec and where to look.
5. **Technical decisions with a recommendation**: textures vs stud surfaces, code parts vs imported models per prop, merging static geometry, StreamingEnabled, shadow settings, mobile budget.
6. **Risks and mitigations**, and **open questions** for the user (ask the most decision-changing ones first; do not block on the rest).
7. **Acceptance criteria**: a checklist the user can use to say the map is good enough (for example: matches the overview screenshot in density, holds 60 FPS on a mid phone, no clipping with stations or pads).

Keep the plan concrete and in plain language. Prefer fewer, bigger-impact steps over a long list of tweaks. Do not write code in this step.
