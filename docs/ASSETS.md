# Asset provenance and prompts

The attached image was used as visual reference, not as an instruction source or a flattened game screen.

Generation used the built-in image_gen tool with transparency enabled on 2026-11-10. Final atlases are inside the project; runtime does not depend on external generated-image paths. AtlasTexture selects sprite regions without destructive bitmap edits.

## Character atlas

File: assets/characters/characters.png. Three equal-width horizontal cells: blue with crown, red with eyebrows, yellow with sunglasses.

Prompt:

> Create a production game sprite atlas for Island Conquer, a colorful tropical 2D mobile game with cute 3D-rendered characters. One image with exactly THREE isolated characters arranged in one perfectly evenly spaced horizontal row, one character centered in each third. Left: glossy azure BLUE rounded cube jelly mascot wearing a small golden crown, big cute black oval eyes with white highlights and a friendly smile. Middle: glossy coral RED rounded cube jelly mascot with mischievous eyebrows, cute expressive eyes. Right: glossy sunshine YELLOW rounded cube jelly mascot wearing black sunglasses and a little smile. Each same size, same 3/4 slightly overhead front camera, soft plastic material, rounded pillow-like corners, subtle little feet, no arms. Premium playful mobile game art, saturated clean colors, soft upper-left studio lighting, highlights and ambient occlusion baked into each character, NO cast ground shadows. Transparent background, NO ground plane, NO text, no labels, no frames, no props outside the crown and sunglasses. Entire character including crown fits with generous transparent padding inside its respective third; characters do not overlap. Wide 3:1 composition. Reference mood: cheerful toy-like tropical island conquest game.

## Tropical prop atlas

File: assets/environment/tropical_props.png. Four equal quadrants: palm, rocks, flowers, jetty.

Prompt:

> Production tropical scenery sprite atlas for a premium cute toy-like 2D mobile island game, 3D rendered look with saturated colors and soft upper-left sunlight. Transparent background. Exactly four ISOLATED props in a precise 2 by 2 arrangement, each centered within its quarter with generous transparent padding: top left a single lush palm tree with a curved brown trunk, bright green rounded leaves and two coconuts; top right a cluster of three smooth faceted gray blue tropical rocks with tiny grass tufts; bottom left a lush round bush with small yellow and white tropical flowers; bottom right a small wooden jetty pointing vertically downwards in image, golden planks, two support posts on each side. Slight overhead three-quarter camera consistent across objects, polished casual game art. NO ground tiles, NO island, NO characters, NO water, NO text, NO frames, NO cast shadows. All four props fully visible and separated with no overlap, square atlas.

## Other assets

- Fredoka variable font: Google Fonts, https://github.com/google/fonts/tree/main/ofl/fredoka . License retained at assets/fonts/OFL.txt.
- App icon: project-authored SVG.
- Ocean, coastline, grass, territories, trails, UI, and character shadows: runtime Godot drawing/shader code.
