# Visual overhaul: from "generated" to clean Capybara Onsen blocky (analysis 2026-10-06)

Compared side by side: `reference/capybara-onsen-*.webp` (the target) against captures of our plot (Studio 2026-10-06, `docs/store-reference/*.jpg`). The user's words: "keep the blocky models, but ours looks super AI generated, not like Capybara Onsen: blocky but clean"; "the rows where the brainrots sit should look more like theirs"; "the entire plot isn't as detailed".

**The one-line answer:** Capybara Onsen's plot has **height and structure** (raised stone baths, stepped edges, ramps going down into lower rivers) built from **few, consistent, calm materials**. Ours is **flat** (every bath is a thin outline on one water sheet) with **loud, high-contrast tiles and many tiny scattered props**. Flat + loud + busy is what reads as "generated".

## What differs, ranked by how much it changes the look

| # | Area | Capybara Onsen | Ours | Fix |
|---|---|---|---|---|
| 1 | **Bath rows** | Each bath is a **raised stone platform**: 2-3 layers of light-grey studded blocks, a wide base and a narrower top (stepped), about 2-3 studs above the rivers. The animal sits on top, in a shallow water channel. Rivers run **lower**, between the platforms. | Every bath is a 1-stud rim drawn on the same water sheet as the rivers, rims 0.5-0.9 above the water. From any angle it reads as a flat grid of lines; the brainrots seem to stand in a puddle. | Rebuild each bath as a raised stepped platform (see "Bath rows" below). This is the single biggest win. |
| 2 | **Slides** | Wooden **ramps** from the platform top down into the river, with two posts and side rails, a white foam splash where they land. | Short flat planks lying on the rims (rails added 2026-10-06), barely visible. | Ramps that drop the full platform height, posts at the top, foam at the bottom. |
| 3 | **Lanterns** | Big boxy stone lanterns (stone cap, glowing square window) standing **on the platform corners**, regular, every bath. | Small lanterns on the channel end only (both ends since 2026-10-06), lost against the water. | Bigger lantern on each platform corner; window glows (Neon + PointLight). |
| 4 | **Grass** | Muted lime with **small, subtle** 1-stud studs. | Neon green, big high-contrast stud squares (the generated tile). This is the loudest surface on screen. | Desaturate (about RGB 120, 196, 72), smaller, lower-contrast studs (regenerate `assets/textures/grass.png` with `tools/make_textures.py`). |
| 5 | **Stone** | Light grey, studded blocks, soft shading. | Dark slate-blue bricks with a big inset square per brick (busy, cold). | Light warm-grey studded block tile, one brick size; same tile for rims, lips, steps. |
| 6 | **Clutter** | Few props, each big and readable: lanterns, bamboo clumps, cherry trees, a sign or two. Open, calm floor. | Many tiny scattered bits: sprigs, daisies, small boxes, a lone orange step block on a rim. Each is random-looking; together they read as noise. | Remove the random scatter; keep fewer, bigger, deliberately placed props (corners, along walls). |
| 7 | **Palette** | ~5 colours: lime, light grey, warm wood, cyan water, pink blossom + red accents. | More hues, more saturation (neon green, slate blue, purple, many label colours). | Pin a palette at the top of `server/Plots` / `server/Decor` and use only it. |
| 8 | **Backdrop** | Cliffs layered, green-topped, lighter, with waterfalls; they frame, not dominate. | Tall flat blue-grey boxes, monotone, fill half the sky in most shots. | Lower and layer them, grass tops, lighter stone, fewer and wider. |
| 9 | **Station row** | Deposit stall full of goods (yuzu crates, fruit), roofed info board, market board in a heavy frame, barrel with details. | Stall counter mostly empty (one white cube, one purple slab), keeper on a stool. | Fill the counter with goods (Aura crystals / drop items in crates), a sign on the awning. |
| 10 | **Brainrot models** | Every animal is a clean voxel model in one style. | The pack's models mix styles (smooth faces, odd proportions next to voxel props). This also reads as "generated". | Later, model by model (voxel versions with `tools/voxel_forge.py`), starting with the most seen tiers 1-6. Not before launch. |

Things that already match and should stay: the pegboard wall with posts, cherry trees and bamboo, water colour and wave texture, the pad style (thick pad in a dark tray), the red bridge, the floor arrows, outlined labels.

## Bath rows: the target design

Per bath (one row, one side of the channel), from the river up:

1. **River** (unchanged height): the low water lane in front of the bath.
2. **Platform base**: light-grey studded stone, as long as the bath, ~1.5 studs tall above the river surface, 1 stud wider than the top on each side (the step).
3. **Platform top**: a second stone layer, ~1 stud tall, with a **shallow water channel** sunk into its middle (the bath water), 5 spots along it.
4. **Seats**: each brainrot stands on the bath water at the platform top, so it is ~2.5 studs above the rivers and clearly on display.
5. **Lanterns** on the four top corners of the platform.
6. **Slides**: a wooden ramp beside every spot, from the platform top edge down into the river, with two posts at the top and a foam splash at the bottom (drop paths follow automatically: `Plots.dropPath` uses the same constants).

Numbers to change in `server/Plots`: `BATH_WATER_TOP` and `BATH_RIM_TOP` (raised by ~2 studs), a new platform base part per bath, `LANE_WIDTH` stays 7 (row spacing and the 220-stud plot depth stay valid). Checks afterwards: the drop path still runs rim > slide > river > channel > pool; brainrot labels clear; the rise animation still starts in the water.

## Status

- 2026-10-06: steps 1-3 done and seen in Studio: raised stepped bath platforms with 2 lanterns each and railed slides; calm grass and light grey stone tiles (re-uploaded); cliffs about half as tall and lighter; random daisies / sprigs cut. Then the same day: slides filled with flowing water; two crates of drop items on the deposit counter; Plaza end cliffs halved; cliff tile neutral warm grey; lucky chests glow (light + sparkles by rarity, a light beam from Diamond up). Still to do: the HUD pass (waiting on what the user dislikes in the UI), voxel brainrot models (later).

## Order of work

1. **Bath platforms + slides + lanterns** (items 1-3). One session, Studio captures before / after from the same camera spots.
2. **Materials and palette** (items 4, 5, 7): regenerate the grass and stone tiles calmer, re-upload, tune tints.
3. **De-clutter** (item 6) and **backdrop** (item 8).
4. **Station row goods** (item 9) and the lucky chest glow (planned before).
5. HUD pass against `reference/` (the user asked for "the UI" too: compare our HUD screen by screen once the map is done).
6. Later: voxel brainrot models (item 10).

## Captures to compare after each step

Same camera, before and after (plot 1, world = plot-local + (-142, 0, 70)):

- Baths: camera (-128, 16, 150) looking at (-142, 4, 195).
- Overview: camera (-142, 55, 55) looking at (-142, 4, 160).
- Station row: camera (-150, 13, 140) looking at (-165, 7, 95).

The Studio game window must be wide (1296 x 682 worked) or the captures are too small to judge.
