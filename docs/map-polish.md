# Map polish: deep dive

Goal: make the onsen look as detailed and appealing as Capybara Onsen. The user's verdict on the first pass (2026-09-29): "the bare minimum, not really visually appealing". This document says why, what the reference does, and what closes the gap. The companion prompt that turns this into a step-by-step plan is `docs/prompts/map-polish-plan.md`.

References: `reference/capybara-onsen-plot-overview.webp`, `-plot-layout.webp`, `-baths.webp`, `-stations.webp` (all Capybara Onsen).

## 1. Why ours looks bare

The code builds the map from flat-coloured boxes. That gives correct layout and zero atmosphere. Capybara Onsen's polish comes from things a box cannot give:

1. **Texture on every surface.** Grass, water, stone and wood all carry a studded / pegboard pattern. Ours are flat colour, so large areas read as empty plastic.
2. **Custom shapes.** Curved roofs, a round striped processor barrel with a chimney, sloped slides, rounded cherry canopies, stepped cliffs. Ours are cubes.
3. **Density.** Something interesting every few studs: flowers, bushes, stepping stones, lanterns, banners, signs, steam, splashes. Ours has a handful of props.
4. **Depth and scale.** Tall walls, towering bamboo and trees, huge layered cliffs with a waterfall and mist, neighbouring plots visible in the distance, a bright sky. Ours was low and close.
5. **Light and atmosphere.** Warm sun, soft haze, bloom, saturated colour. Ours used the default gloomy lighting.
6. **Motion.** Steam on baths, foam where slides meet the river, falling petals, waterfall mist, flowing water. Ours was static.
7. **Small UI-in-world touches.** Directional arrows on the floor toward pads, framed signboards, hanging scrolls, name plate over the plot.

## 2. What the reference contains (inventory)

| Area | Observed in the reference |
| --- | --- |
| Ground | Bright green, studded / checker surface; stone-brick path borders; white daisies and low green shrubs scattered; stepping stones |
| Boundary | Tall tan pegboard wall (dotted panels) with dark posts and a top rail; white hanging paper scrolls with calligraphy; tall bamboo stalks (ringed) rising above it; pink cherry trees with blocky canopies rising above it |
| Backdrop | Huge grey-blue cliffs in layers with grassy ledges; a cyan waterfall with mist; bright blue sky; other plots and their processors visible beyond |
| Baths | Raised stone-brick tubs with studded rims; cyan studded water; tiny sparkle-foam splashes where slides meet the river; steam wisps; small hanging lanterns at bath ends; wooden slides with plank steps; a wooden bridge over the channel |
| Pool | Stone-brick rim, cyan studded water, colourful drops piled up and bobbing |
| Processor | Big orange barrel with white bands, grey chimney and hatch, a stone-brick base ring, steam from the top |
| Info board | Framed pegboard sign under a curved dark-wood roof (torii style) on posts, with a paper-style panel |
| Deposit stand | Wooden stall with red and white striped awning, a character behind the counter, sign with the item icon |
| Market board | Black chalkboard in a dark wood frame with a graph, on tall posts |
| Hot-spring banner | Blue noren-style banner with a steam symbol on wooden posts |
| Pads | Coloured rounded pads with a dark border, floating labels, animated arrows on the floor pointing to them |
| Props | Stone lanterns (glowing), wooden fences, small bridges |
| Screen | Soft bright light, saturated colours, visible sky, distance haze |

## 3. Where we are now (after the first two passes)

Done in code: fence / wall (tall, with scrolls), stepped cliffs with a waterfall and mist, cherry trees with petals, bamboo, stone lanterns, daisies, steam on baths, sky / haze / bloom / colour correction (`AtmosphereService`), grass-green floor.

Still missing: any texture, curved or custom shapes, path borders, bushes, bridge, floor arrows, torii-style roofs, banner, foam splashes at slides, distant scenery, sound, and most of the density.

## 4. The levers, ranked by impact for effort

| # | Lever | Impact | Effort | Needs |
| --- | --- | --- | --- | --- |
| 1 | Lighting, atmosphere, post-processing | Very high | Low | Code only (first pass done; tune by eye) |
| 2 | **Stud / pegboard textures** on grass, water, stone, wood, wall | Very high | Medium | Tile images uploaded as Roblox assets (Texture / SurfaceAppearance) or the built-in stud surface as an experiment; the user must upload images |
| 3 | Particles: steam, foam splash at slides, petals, mist, sparkles on pads | High | Low | Code + built-in textures |
| 4 | Density: shrubs, more flowers, stepping stones, path borders, floor arrows, small props | High | Medium | Code (parts) |
| 5 | Custom props as real models: torii roof, processor barrel, stall with awning, cherry / bamboo / lantern, bridge | High | Medium to high | Creator Store models via the Studio MCP, or hand-built in Studio; saved to `assets/` like the brainrot pack |
| 6 | Sound: water, birds, ambient music, pad clicks, purchase / unlock sounds | High for feel | Low | Roblox audio asset IDs (free library) |
| 7 | Distant scenery and skyline (neighbouring plots' cliffs, distant hills, clouds) | Medium | Medium | Code or models |
| 8 | Animated water (scrolling texture) and waterfall | Medium | Low once textures exist | Texture asset |
| 9 | UI-in-world: floor arrows, framed signs, plot name plate | Medium | Low to medium | Code |
| 10 | Performance pass: merge static parts, StreamingEnabled, shadow / fidelity settings, mobile budget | Required | Medium | Code, profiling in Studio |

## 5. Technical notes and options

- **Textures without art assets.** The classic stud surface (`SurfaceType.Studs` on Plastic parts) may give a free Lego-like look on grass and stone. It needs an in-Studio look to judge; treat as an experiment. The reliable route is a small set of seamless tile images (grass, water, stone brick, plank / pegboard) uploaded once and applied with `Texture` instances (tiled, `StudsPerTileU/V`). We cannot upload from here: the user uploads to the Creator Dashboard and gives us the asset IDs (or we find suitable free ones).
- **Shapes.** Real roofs, barrels and canopies are meshes. Options: (a) Creator Store packs of Japanese-garden / blocky props, imported through the Studio MCP and saved as `.rbxmx` under `assets/` (same pipeline as `tools/extract_brainrot_pack.py`); (b) build in Studio from wedges / cylinders / unions; (c) commission or generate meshes. Never load unvetted scripts; strip them on import.
- **Performance budget.** A plot is roughly 900 parts already; 6 plots on screen plus decoration must stay smooth on phones. Merge static decor into unions or single meshes where possible, turn off `CastShadow` on small parts, avoid hundreds of tiny parts, keep particle rates low, consider `StreamingEnabled`. Profile in Studio on a low-end preset.
- **Consistency.** The pack brainrots are detailed textured meshes; the map should not look like flat boxes beside them. Texture and prop quality is the main thing to raise.
- **Sky and distance.** Neighbouring plots are visible in the reference. Our plots are far apart and the cliffs are the only backdrop; consider matching skyline and a distant hill ring.

## 6. Risks

- **Asset dependence and rights.** Third-party models and audio can be taken down or carry licences; keep local copies, credit creators, avoid ripped assets.
- **Performance on mobile.** More detail can hurt the frame rate; budget before adding.
- **Blind iteration.** Claude cannot see Studio. Every visual pass needs the user's screenshots; the Studio MCP (when connected in a session) lets Claude inspect and build directly and is the best way to iterate.
- **Scope.** The map is large (6 plots). Polish one plot to the target look first, then replicate.

## 7. Open questions for the user

1. Are you able to upload a few tile images (grass, water, stone, plank) to Roblox, or should we look for free texture assets first?
2. Do you want to keep pushing code-built props, or bring in Creator Store / Studio-built models for the big items (roof, barrel, stall, trees)? (Recommended: models for those, code for density.)
3. Audio: ambient loop and click sounds; any preference (calm Japanese onsen vs upbeat)?
4. Which single area should look perfect first (suggested: the pool, station row and first two bath rows, as in the overview screenshot)?
