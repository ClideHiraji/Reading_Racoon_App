# Icon credits

The one-colour glyphs in this folder come from **game-icons.net** (https://game-icons.net,
source: https://github.com/game-icons/icons), licensed under
**CC BY 3.0** (https://creativecommons.org/licenses/by/3.0/).

Changes: backgrounds removed so each icon is a white silhouette that the app tints,
files renamed, and the four "badges" icons cropped.

| File | Original | Author |
|---|---|---|
| cat, hat, sun, tree, moon, book, lock, crown, chest, trophy, bulb, repeat, talk, night, waves, cloud | lorc/cat, top-hat, sun, oak, moon, open-book, padlock, crown, locked-chest, trophy, light-bulb, cycle, conversation, night-sky, waves, fluffy-cloud | Lorc |
| fish, house, boat, pear, hen, pencil, speaker, check, sparkles, ear, stories, raccoon, palm, hut | delapouite/tropical-fish, house, sailboat, pear, chicken, pencil, speaker, check-mark, sparkles, human-ear, book-cover, raccoon-head, palm-tree, hut | Delapouite |
| chest_open | skoll/open-treasure-chest | Skoll |
| heart_plus | zeromancer/heart-plus | Zeromancer |
| star, heart, bolt, mountain | badges/star, heart, bolt, mountain | game-icons.net "badges" set |
| play, pause, dot, arrow_left, arrow_right, glasses, scarf, full_screen, full_screen_exit | drawn for this project: rounded play and pause signs, a plain dot, two arrows, glasses, a scarf, and corner marks to open and close full screen | Reading Racoon team |

The earned star, Regain Heart and Broken Heart animations were provided by the team as Lottie files (`Star.lottie`, `Regain Heart.lottie`, `Broken Heart.lottie`); their JSON is in `assets/anim/lottie/` and the game plays it live with `ui/lottie_player.gd` (D-022), the hearts in the lesson hearts' colors. `regain_heart.json` is adjusted to match the team's `Regain Heart.mp4`: normal speed, 3.25 s, and a grey empty heart (with Broken Heart's outline, so the two meet) instead of the black outline. The still hearts in a lesson are these animations' end frames. The animated SVG exports (`Animated - Star.svg`, `Regain Heart.svg`, `Broken Heart.svg`) are kept as references in `tools/team-animations/`, outside the game. Confirm their source and license before release.

The full-colour pictures for words, stickers, Home tiles and Practice games are in `assets/pictures/`, drawn for the game (D-027); they need no credit. The silhouettes they replaced were removed on 2026-11-18.
