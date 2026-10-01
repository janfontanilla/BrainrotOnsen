# Store assets: icon, thumbnails and listing (image prompts: see docs/gemini-prompts/)

Game name: **Brainrot Bathhouse** (renamed from Brainrot Onsen 2026-09-30). The user generates the images with Codex; this file says what to make and gives copy-paste prompts. Researched 2026-09-30.

## How to use this with Codex

1. Start each image in a new Codex chat.
2. **Attach the reference images** listed for that image (from `docs/store-reference/`). They are real captures from the game; they make the art match what players will see, which keeps players who click (Roblox ranks games down when players leave quickly).
3. Paste the **shared style** block, then the image's prompt.
4. Check the result with the checklist at the end; regenerate if the logo text is misspelled (AI tools often do this).

## Reference images (`docs/store-reference/`)

| File | Shows |
| --- | --- |
| `tung-tung-tung-sahur.jpg` | Tung Tung Tung Sahur: a chunky studded wooden block, big white eyes, thick dark eyebrows, big wooden nose, small smile, little arms |
| `tim-cheese.jpg` | Tim Cheese: a grey mouse with round pink ears and whiskers, wearing a black suit and red tie |
| `ballerina-cappuccina.jpg` | Ballerina Cappuccina: a white cappuccino-cup head with long eyelashes and pink lips, pink ballerina dress |
| `chimpanzini-bananini.jpg` | Chimpanzini Bananini: a green monkey with a pink face and ears, sitting in a peeled yellow banana |
| `tralalero-tralala-front.jpg`, `bombardiro-crocodilo-and-tralalero.jpg` | Tralalero Tralala: a blue shark on three legs in blue sneakers. Bombardiro Crocodilo: a green crocodile head on a dark grey bomber plane |
| `lirili-larila.jpg` | Lirili Larila: a light-blue elephant head with white tusks on a green cactus body in sandals |
| `brr-brr-patapim.jpg` | Brr Brr Patapim: a tan wooden face with a very long nose, green mossy body with root patterns |
| `chests-and-drop-items.jpg` | Lucky chests (voxel boxes with coloured trim and a gold lock: wood, gold, diamond, rainbow, cosmic) and drop items (coffee cup, bomb, banana, shoe...) |
| `baths-with-brainrots.jpg` | Brainrots soaking single file in stone-ring baths with wooden slides, lanterns, a red bridge, turquoise studded water |
| `bathhouse-overview.jpg` | The whole bathhouse: rows of baths, pool, Merge! pad, orange barrel, striped stall, cherry trees, bamboo, cliffs and waterfalls |

Everything in the game is chunky blocky "voxel" style with studded (Lego-like) surfaces.

## Shared style (paste first in every prompt)

> Use the attached images as reference: keep these exact characters, their colours and their chunky blocky voxel look with studded surfaces. Make it bright, polished Roblox game key art: soft warm lighting, saturated colours (turquoise water, warm wood, pink cherry blossom, orange lantern glow), clean shapes, a little depth of field. Setting: a Japanese bathhouse with steaming turquoise baths, grey stone rims, wooden walls, paper lanterns, bamboo, cherry blossom trees and a blue curtain with the hot-spring symbol ♨. Characters look cute and relaxed. No Roblox logo, no real people, no brands, no small text.

## Icon (512 x 512; generate square at 1024 x 1024)

Attach: `tung-tung-tung-sahur.jpg`, `chests-and-drop-items.jpg`, `baths-with-brainrots.jpg`.

> [shared style] Square game icon, bold and high-contrast so it reads at a tiny size. Centre: Tung Tung Tung Sahur, big and close to the camera, soaking up to his chest in a steaming turquoise bath, eyes wide and surprised with a huge grin, a small white towel on his head. Beside him on the right, a rainbow lucky chest bursting open with bright light and sparkles. A banana and a coffee cup float in the water. Background: lanterns glowing orange, bamboo, a ♨ curtain, soft steam. Top third: the logo "Brainrot Bathhouse" in chunky rounded cartoon letters with thick dark outlines, "Brainrot" in bright yellow, "Bathhouse" in bright cyan, on a wooden plank sign with two small ♨ marks. Very saturated colours, strong rim light around the character. The only text is the logo, spelled exactly "Brainrot Bathhouse".

## Thumbnails (1920 x 1080, 16:9)

Keep the bottom 15% free of anything important (the title bar covers it). Upload all five; set 1-4 active so Roblox tests them.

**Size:** if Codex can't output 1920 x 1080 directly, generate the widest landscape size it offers (often 1536 x 1024) and crop it to 16:9 (e.g. 1536 x 864), then scale to 1920 x 1080. Roblox takes any 16:9 image.

**1. Key art with logo (upload first).** Attach: all character references + `baths-with-brainrots.jpg`.
> [shared style] Wide 16:9 key art. The "Brainrot Bathhouse" logo (wooden sign, yellow "Brainrot", cyan "Bathhouse", thick dark outlines) top centre. Below it, a lineup of seven brainrots soaking side by side in one long steaming turquoise bath, each with a little towel or item on its head: Tim Cheese, Chimpanzini Bananini, Ballerina Cappuccina, Tung Tung Tung Sahur (centre, biggest), Tralalero Tralala, Lirili Larila, Brr Brr Patapim. Drop items float in the water (banana, coffee cup, shoe). Grey stone rim along the front, cherry blossom trees and lanterns behind, warm afternoon light. Keep the bottom 15% clear. The only text is the logo, spelled exactly "Brainrot Bathhouse".

**2. Merge (explains the game).** Attach: `tralalero-tralala-front.jpg`, `tung-tung-tung-sahur.jpg`, `baths-with-brainrots.jpg`, `bathhouse-overview.jpg`.
> [shared style] Wide 16:9 action scene. Three Tralalero Tralala glow and swirl together in a burst of sparkles and steam above a grey stone floor pad with a ♨ mark, becoming one bigger, shinier Tung Tung Tung Sahur. Rows of baths with brainrots behind. Caption top-left in big outlined white letters: "MERGE 3 INTO 1!". Keep the bottom 15% clear. No other text.

(A real merge: three of a tier make one of the next tier; Tralalero Tralala is tier 12, Tung Tung Tung Sahur tier 13.)

**3. Lucky chest (rarity).** Attach: `chests-and-drop-items.jpg`, `bombardiro-crocodilo-and-tralalero.jpg`.
> [shared style] Wide 16:9 scene at dusk. A glowing purple Cosmic chest (a blocky voxel box with dark purple trim and a gold lock) bursting open on the edge of a steaming pool, beams of light and sparkles; Bombardiro Crocodilo flies out of it, glowing. Above him, a purple and gold label "COSMIC". Smaller wood, gold and diamond chests float in the water. Lanterns glowing. Keep the bottom 15% clear. No other text.

(Our chest types, commonest to rarest: Wood, Stone, Iron, Gold, Diamond, Emerald, Ruby, Rainbow, Cosmic. "SECRET" is not a rarity in this game.)

**4. Cozy sunset (mood, no text).** Attach: `tung-tung-tung-sahur.jpg`, `ballerina-cappuccina.jpg`, `tralalero-tralala-front.jpg`, `chimpanzini-bananini.jpg`, `bathhouse-overview.jpg`.
> [shared style] Wide 16:9 cozy scene at sunset: Tung Tung Tung Sahur, Ballerina Cappuccina, Tralalero Tralala and Chimpanzini Bananini soaking with eyes closed under strings of paper lanterns, pink cherry blossom petals drifting, a waterfall down stepped blocky cliffs behind, golden light through the steam. Keep the bottom 15% clear. No text.

**5. Cozy night (mood, no text).** Attach: `tung-tung-tung-sahur.jpg`, `tim-cheese.jpg`, `baths-with-brainrots.jpg`.
> [shared style] Wide 16:9 cozy scene at night: a moonlit bathhouse with bamboo, glowing lanterns and steam; Tung Tung Tung Sahur and Tim Cheese soaking side by side under a big full moon, fireflies, a dark wooden gate with blue ♨ curtains in the background. Keep the bottom 15% clear. No text.

## Listing text

**Title:** `Brainrot Bathhouse ♨ Merge` (during an update, add an emoji tag in front, e.g. `[🎁] Brainrot Bathhouse ♨ Merge`).

**Description** (about 500 characters):

```
Tung Tung Tung Sahur needs a bath! 🛁 Build the craziest brainrot bathhouse, merge 3 into 1 and collect all 20 Italian brainrots!

⭐ HOW TO PLAY
🧀 Buy brainrots: they soak in your baths and drop items
💎 Walk over the drops to collect Aura
💰 Deposit Aura and turn it into Cash
🔧 Merge 3 of a kind into the next tier
🎁 Open lucky chests for rare brainrots
💤 Your brainrots earn while you're offline!

👍 Like & join PCC. Studios for free Cash every 5 minutes!
🙏 Brainrot models by Agus_Fellini2
```

**Other settings**
- Genre: Simulation (Tycoon). Max players: 6. Devices: Computer, Phone, Tablet.
- Fill in the maturity questionnaire on the Creator Dashboard before going public.
- Social link: the PCC. Studios group.

## Why these choices (research)

| Point | Source |
| --- | --- |
| Icon: square, at least 512 x 512, must read at ~150 x 150 | [Roblox docs: experience icons](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/experience-icons.md) |
| Thumbnails: 16:9, 1920 x 1080, under 3 MB, up to 10; logo and minimal gameplay text OK, no promo claims; nothing essential at the bottom | [Roblox docs: thumbnails](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/thumbnails.md) |
| 2-5 active thumbnails get tested per player group (average +8.5% qualified plays); art must match the game, click-bait is penalised | [DevForum: thumbnail personalization](https://devforum.roblox.com/t/get-your-thumbnails-ready-for-thumbnail-personalization/3226599) |
| Title = unique name + search keyword; hook and keywords in the first lines of the description | [Roblox docs: discovery](https://create.roblox.com/docs/production/promotion/discovery) |
| Genre: Capybara Onsen (cozy painted key art, character lineup), Steal a Brainrot (one huge brainrot, rarity label, income flex, emoji update tag) | Their live Roblox listings, checked 2026-09-30 |

## Checklist before uploading

- [ ] Logo spelled exactly "Brainrot Bathhouse"
- [ ] Characters look like the reference captures (colours, shapes)
- [ ] Icon still readable shrunk to 150 x 150
- [ ] No text other than the logo / the allowed captions; nothing important in the bottom 15% of thumbnails
- [ ] Thumbnails under 3 MB (save as .jpg if a .png is too big)

Upload: Creator Dashboard > Brainrot Bathhouse > Configure / Places > Icon and Thumbnails. After a few days, check the thumbnail stats and drop the weakest.
