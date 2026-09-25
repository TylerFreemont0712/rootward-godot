# Vesper — Star-Script Witch

Blender reference pack for a Rootward battle skin. `reference/full-front.png` is the **design authority**. The other views explain depth and parts; when details disagree, follow the front image. These are concept images, not texture maps or measured blueprints.

## Images

| File | Use |
| --- | --- |
| `reference/full-front.png` | Canonical clothed A-pose, costume, color, and silhouette |
| `reference/full-left-profile.png` | Left-side proportions and layering |
| `reference/full-back.png` | Back of the hat, mantle, tunic, boots, and book attachment |
| `reference/full-three-quarter.png` | Volume and overlap check |
| `reference/head-front-left-profile.png` | Face and hair without the hat |
| `reference/body-blockout-front.png` | Costume-free articulated mannequin for body scale and joint centers |
| `reference/body-blockout-left-profile.png` | Costume-free side blockout |
| `accessories/hat-turnaround.png` | Separate hat shape and materials |
| `accessories/mantle-front-back.png` | Separate cropped mantle |
| `accessories/spellbook-turnaround.png` | Closed book, spine, back, and belt attachment |
| `accessories/boots-gloves.png` | Boot and fingerless-glove details |
| `style/pushed-anime-front.png` | Alternate, more exaggerated anime treatment of the same skin |

The requested unclothed anatomical sheets were rejected by the image generator. The body-blockout images use a non-anatomical jointed mannequin instead. They show proportions and rig landmarks without costume occlusion.

## Model and rig notes

- Build the body from the blockout, then use the canonical full front to fit the outfit. Align the side and back images by head and sole height in Blender; the generated views are not guaranteed to share exact pixel scale or geometry.
- Keep the hat as its own mesh. The brim and band can follow the head; the soft cone can use a short bone chain for a subtle secondary sway. The gold crescent and dangling star are separate simple pieces.
- Keep the mantle as a separate short mesh, weighted to shoulders and upper torso, with no hem extending past the elbows. Keep the book attached to **Vesper's left hip** (viewer right in the front image; viewer left in the back image).
- The tunic star, hat crescent, purple hair, and mantle form the read at the game's 360 × 480 hero viewport. Favor these large shapes over small accessory detail.
- Leave spell sigils, projectiles, and shields out of the character mesh; Rootward's stage draws those effects separately. Keep the hands unobstructed for casting.
- Test the model with the game's idle, light cast, heavy cast, channel, guard, hurt, victory, and death motions. The hat tip, mantle hem, book, and boot cuffs need collision/weight checks during those poses.

All images were made with ChatGPT's built-in image generation. See `PROMPTS.md` for the prompt set.
