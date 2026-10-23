# 图像生成提示词记录

日期：2026-10-23。使用内置 image_gen 工具；未使用 CLI 或用户 API Key。所有成品按 `transparent_background: true` 请求，实际 alpha 质量须独立检查。

## 多角度角色探索

参考：用户照片中的正面坐姿、侧面站姿与脸部特写。

Use case: stylized-concept.
Asset type: character model sheet for a macOS desktop companion, original cartoon adaptation of the SAME pet cat in the reference photographs.
Input images: all supplied photographs are subject/identity references, not backgrounds to retain.
Primary request: design a charming, clean, animation-friendly 2D cartoon of this specific silver-gray tabby cat. Preserve the recognizable round plush cheeks, upright triangular ears with soft pink interiors, large olive-green/yellow-green eyes with dark rims, small pink nose outlined in dark charcoal, pale muzzle, white bib/chest, white sock paws, dark forehead M-shaped tabby marking, charcoal leg bands and ringed thick tail. Stocky short-haired body, gentle slightly curious expression, not a kitten, not a generic gray cat.
Style: refined hand-drawn 2D mascot, compact rounded proportions, head about 42 percent of seated height, soft warm charcoal outlines, simple solid silver-gray shapes and restrained soft shading, readable at 96–128 screen pixels. No photoreal fur, no pixel art, no 3D, no clothes, no collar, no accessories.
Composition: one single clean horizontal character reference sheet, THREE equally sized full-body views aligned on the same ground baseline: front seated; right-facing side standing on all four paws (for walking reference); three-quarter rear seated with visible ringed tail. Keep consistent scale, proportions, stripe design, paw colors, face identity across views. Generous transparent space between views and around edges. All ears, whiskers, paws and tails fully within canvas.
Background: actual transparent alpha, no floor, no shadows beneath feet, no scenery, no white matte, no checkerboard painted into image.
Text: no text, no labels, no watermark.
This is the approved subject direction for future sequential animation frames; clean consistent model construction is essential.

## 卡通主形象

参考：上一版角色探索与用户照片。

Use case: stylized-concept. Asset type: definitive single-character cartoon mascot master for a tiny desktop pet, transparent PNG.
The first input is a previous illustrated model of the user's silver tabby, the other inputs show the real cat. Retain THIS cat's identity but SIMPLIFY THE DRAWING STYLE substantially. Draw ONE full-body three-quarter-front seated cat, centered, with a thick ringed tail curving around its paws. Large round head 45 percent of total height, small chunky adult body, short legs. Keep olive-green eyes, rosy triangular nose with charcoal outline, large pale muzzle, white chest bib, all white sock paws, silver-gray coat with dark M on forehead, two simple cheek stripes, sparse broad dark body stripes and tail rings, pink ear interiors. Gentle curious slightly serious personality.
STRICT STYLE: charming flat 2D cartoon, bold clean warm-charcoal outlines, simple smooth filled color shapes, 2-tone cel shading only. No fine fur strokes, no realistic hair, no painterly rendering, no photographic texture, no gradients, no 3D. It must be instantly readable at 96px. Think carefully designed hand-drawn animation character with stable simple shapes and discrete coat markings. Not a generic solid gray cat. No accessories, no collar.
One cat only, no text, no decorative elements, no shadows under cat, no floor, true transparent background. Entire ears, whiskers, tail and paws in frame with ample transparent margins.

## 六组动作关键帧

参考：本轮生成的卡通主形象。

Use case: stylized-concept.
Asset type: animation KEYFRAME SPRITE SHEET for an original macOS desktop cat companion.
Input image: reference is the definitive cartoon MASTER. Match that exact silver tabby character, same clean 2D cel-shaded drawing style, face, proportions, olive-green eyes, pink nose, pale white bib and muzzle, white sock paws, dark forehead M and charcoal tabby bands, ringed thick tail. Keep coat markings consistent in every frame. No other characters.

Create ONE square sheet with EXACTLY 36 separate full-body cat drawings, in a perfectly regular 6 COLUMN × 6 ROW GRID. Six sequential animation keyframes per row, read left to right, top to bottom. NO additional pose outside the grid. Every cell same dimensions, same body scale, consistent paw baseline and generous transparent padding; each cat fully contained inside its cell with no overlapping neighboring cells and no clipped tails or ears. Cat body height approximately 65% of cell height. Real transparent background. NO labels, letters, numbers, grid lines, symbols, speech bubbles, props, floor shadows or decorative elements. Use as high resolution as available, ideally a 2048px square.

ROW 1, seated idle / blink, six continuous poses: eyes open neutral; eyelids half closed; eyes fully closed; eyes reopening; subtle chest breath and tail tip shift; back to eyes open neutral. Keep head angle mostly constant.
ROW 2, WALK RIGHT, all six are strict RIGHT-FACING SIDE VIEW ON ALL FOUR LEGS, a coherent in-place quadruped WALK CYCLE: first contact; down/weight transfer; passing; opposite contact; opposite down; opposite passing. Alternate front/back legs naturally and visibly, feet change positions. Keep body level and tail behind. NO seated poses in this row, NO turn to face viewer, NO running or leaping. The window will handle translation.
ROW 3, STRETCH, six continuous poses: all-fours neutral; front paws slide forward; chest lowers; deep front-down bottom-up stretch with closed eyes; gradually rising; back to all-fours neutral. Keep limbs anatomically coherent and white sock paws intact.
ROW 4, seated THINKING, six continuous poses: neutral; eyes glance upward; head tilts slightly; one front paw gently toward cheek; blink with paw lowering; return neutral.
ROW 5, seated TALKING, six continuous poses: mouth closed; tiny mouth opening; slightly wider small mouth; smaller opening; subtle nod; closed mouth return. Do not turn into a large human smile.
ROW 6, curled NAPPING, six continuous poses in the SAME CURLED LYING POSE: closed-eye resting; tiny inhalation; tiny exhalation; small ear twitch; slight tail tip shift; back to starting closed-eye resting pose. NOT a sequence of six different standing/sitting postures.

Style is polished, warm and charming 2D cartoon, strong clean charcoal outlines with broad simplified gray markings. Strong identity consistency with the input master. This sheet is for animation pose design, not a poster. Prioritize the exact six-by-six layout and coherent within-row motion.

## 动作图背景清理

Use case: background-extraction.
Edit target: the attached 6 by 6 animation keyframe sprite sheet.
Precise task: clean ONLY the background and alpha edges. There are exactly 36 silver tabby cartoon poses, arranged six columns and six rows. Preserve every cat drawing, pose, order, proportions, gray tabby colors, white paws and chest, green eyes, all whiskers, all tails, line art, and the entire original sheet composition. Do NOT redesign, do NOT move poses, do NOT add or remove frames.
Remove ALL the faint gray mottled haze, colored speckles, checkerboard-like artifacts and low-opacity fog BETWEEN the cats. The background needs to be genuine clean transparent alpha=0, not merely white/gray pixels, and not a drawn checkerboard. The cats themselves should be fully opaque except natural antialiased boundary pixels. Preserve white chest and paws as solid character colors. Keep transparent gaps between poses and around the whole sheet. No labels or grid lines.
Return a clean transparent PNG sprite design sheet.

## 修正思考动作的重复爪子（v3）

使用内置 image_gen 编辑 v2，选用去除多余抬爪、保留双前爪落地的修正版。

Use case: precise-object-edit.
Edit the supplied 36-pose silver tabby animation sheet. Make one very small object-removal correction in TWO poses ONLY.
Locate row FOUR (the seated thinking row), column FOUR and column FIVE.
In each of those two cats REMOVE THE ENTIRE RAISED PAW AND ITS BENT ARM from the face and chest. There must be NO raised paw anywhere in either pose. Restore the smooth white chest / gray side area behind the removed arm, matching the seated cats in columns one, two, three and six of this same row. KEEP the original three grounded white paw shapes at the bottom, unchanged.
The cat in row4 col4 should simply sit with both front paws on the floor, head tilted slightly thoughtfully, eyes OPEN. The cat in row4 col5 should simply sit with both front paws on the floor, eyes CLOSED in a calm blink. Neither cat is touching its cheek. NO arm or white mitten near the cheek, chin, or chest. All forelegs are on the ground.
Use row4 col3 and row4 col6 as exact anatomical references for the front legs. Only the head angle and eyes vary to convey thinking.
Preserve every other pose and every other part of the sheet. Keep the same exact 6 columns and 6 rows, 36 drawings, same framing, same tabby character, same eye color, stripes, tail, white bib and socks. Transparent background, no labels.
This is removal of duplicated limbs, not an invitation to draw a new gesture.

## CAT-3 行走重绘（v4）

使用内置 imagegen，主形象作为身份参考。一次整表编辑网络失败，重试整表仍有彩色杂点，未接入运行时；最终采用单独重绘的六帧行走稿 `walk-cycle-v4.png`。请求尺寸为 3072×2048，工具实际输出 **1536×1024 RGBA**，以实际结果为准。原有五组动作继续使用 v3，未把其放大当成新细节。原始生成图保留，离线清理与对齐由 `Tools/CatArtExporter/main.swift` 完成。

实际采用的提示词：

Create a NEW six-frame WALK CYCLE sprite sheet of this exact silver tabby character. Input is character identity reference ONLY; redraw a side-on WALKING cat facing RIGHT in all six cells, not seated. Landscape image 3072x2048 pixels, a strictly uniform grid of THREE columns by TWO rows, exactly one full cat inside each square cell, transparent RGBA background. Equal body size, head height and ground baseline in all frames, grounded paws at 88% of each cell. Read frames left-to-right top row then bottom row. Six successive locomotion phases: (1) near foreleg forward planted and near hindleg back, (2) body passes over planted paws with far foreleg swinging, (3) near foreleg lifts under chest, (4) far foreleg forward planted with opposite hindleg back, (5) weight transfer opposite side, (6) near foreleg swings forward preparing frame 1. Anatomically exactly FOUR legs, natural far-side occlusion, no extra feet. Chubby round body and face, yellow-green eyes, white muzzle/chest and white mitten feet, silver gray dark tabby stripes, pink ears and nose, gently lifted thick striped tail. Match reference's soft cartoon illustration and charcoal outline. Fully show tail, whiskers and all anatomical paws; generous transparent gutter. No red or yellow artifacts, no floor, no shadows, no text, no gridlines, no props. Each pose must be distinct to animate genuine walking, never duplicate six identical poses. Deliver native detailed high-resolution clean antialiased artwork, NOT upscaled blurry raster.
