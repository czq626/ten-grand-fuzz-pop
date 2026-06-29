# Visual Change Log

This document records UI, art, and presentation changes for `Ten Grand Fuzz Pop`.
Update it whenever visual, layout, asset, or player-facing copy changes are made.

## 2026-06-29 - Booster Obstacle Damage Rules

### Goal

- Ensure all board boosters respect layered obstacle durability instead of clearing multi-layer obstacles outright.

### Implemented

- Board booster effects no longer force-clear ordinary hit targets.
- Wood crates now lose only 1 hp per booster hit, including arrow, bomb, and rainbow effects.
- Chains and ice still lose only their overlay layer when hit by any board booster.
- Rainbow target selection now traverses different targets first; repeated hits on the same target happen only after the available target list has been used once.
- Smoke coverage now checks that arrow, bomb, and rainbow hits reduce a 3-hp crate to 2 hp, and that a rainbow with nine different crate targets hits each once instead of double-hitting one target.

### Verification

The following commands passed after this pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
```

## 2026-06-29 - Readable Chain Overlay and Obstacle Hit Feedback

### Goal

- Make lock chains readable without hiding the fuzzy color needed for matching.
- Add distinct audio and visual feedback when obstacles are hit.

### Implemented

- Replaced the lock-chain runtime overlay with `assets/art/special/obstacle_chain_readable.png`.
- The new lock-chain art uses only two diagonal crossing chains plus a small edge lock, leaving most of the fuzzy color visible.
- Obstacle hits now play specific generated sounds: wood crack for crates, high glassy crack for ice, and metallic ring for chains.
- Ice and chain removal now spawn colored shard particles.
- Crate damage and crate clearing now both play the crate break sound and wood splinter particles.

### Verification

The following commands passed after this pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --level=/tmp/codex-obstacle-visual-level.json --screenshot=/tmp/codex-chain-readable-check-3.png
```

## 2026-06-28 - Obstacle Art Scale and Three-Level Crates

### Goal

- Improve the readability and physicality of ice, lock chains, and wood crates.
- Add a third crate durability level and make crate levels visually distinct.

### Implemented

- Ice overlays are now larger than the fuzzy and read as a translucent shell wrapping around the fuzzy.
- Lock-chain overlays are now oversized cross straps with link shapes and a lock, reading as tied around the fuzzy.
- Added 3-level crate support. Level 3 is reinforced with metal bands and corner plates, level 2 is an intact crossed-plank crate, and level 1 is a cracked/damaged crate.
- Wood crates are no longer randomly generated. They appear only from level JSON or editor placement.
- Crate damage now reduces exactly 1 durability level per adjacent match or booster hit, and crate objectives count only when the final layer clears.
- The level editor now exposes `木箱1`, `木箱2`, and `木箱3` brushes; level JSON `blockers` values support 1, 2, and 3.
- Runtime crate assets were added at `assets/art/blocker_crate_level1.png`, `assets/art/blocker_crate_level2.png`, and `assets/art/blocker_crate_level3.png`.
- Existing ice/chain runtime overlays at `assets/art/special/obstacle_ice.png` and `assets/art/special/obstacle_chain.png` were replaced with larger transparent versions.
- AIART generated candidate reference sheets under `assets/generated/images/wood-crate-three-levels*.png` and `assets/generated/images/large-ice-chain-overlays*.png`. They remain generated references; runtime uses the transparent/cropped PNGs listed above for reliable board readability.

### Verification

The following commands passed after this pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --level=/tmp/codex-obstacle-visual-level.json --screenshot=/tmp/codex-obstacle-visual-check-3.png
```

## 2026-06-28 - Lock/Ice Obstacles, Refill Control, and Playable Outline

### Goal

- Reduce system-created chain reactions after refill, draw disabled-cell holes as part of the board outline, improve drag/rebound feedback, and add two configurable strategic overlay obstacles.

### Implemented

- Added lock-chain and ice overlay obstacles on normal colored fuzzies.
- Chained and iced fuzzies still participate in same-color connected groups by their underlying fuzzy color.
- Matches and booster hits remove only the lock/ice layer and leave the fuzzy in place.
- Rows or columns containing a lock chain now rebound instead of dragging and do not spend a move.
- Ice-covered fuzzies can move with row and column drags.
- The level editor now has lock-chain and ice brushes plus lock/ice target counts; level JSON exports `chains`, `ice`, `chain_target`, and `ice_target`.
- Refill safety now fixes the same-color cluster size check and runs a light post-refill reroll pass to reduce immediate system-made matches.
- Runtime board framing now traces the actual playable-cell outline and draws inner borders around disabled-cell holes instead of one fixed rectangle.
- Added transparent runtime obstacle overlays at `assets/art/special/obstacle_chain.png` and `assets/art/special/obstacle_ice.png`.
- AIART was also used to generate candidate obstacle sheets under `assets/generated/images/chain-ice-obstacle-overlays*.png`; those candidates are kept as generated references, while the runtime uses the transparent overlay PNGs so the underlying fuzzy color remains visible.

### Verification

The following commands passed after this pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --level=res://data/levels/level_001.json --screenshot=/tmp/codex-disabled-outline-check.png
```

## 2026-06-26 - Candy UI and Asset Pass

### Goal

- Move the game away from a dark prototype look and toward a brighter commercial casual puzzle style.
- Keep core gameplay rules unchanged while improving readability, polish, and player-facing language.
- Use generated art where it improves quality, but keep layout and board alignment driven by code.

### Main UI Direction

- Theme moved to a bright candy, jelly, and fuzzy-pop style.
- Player-facing UI text was localized to Chinese.
- The title shown in-game is now `软糖毛球`.
- Common controls now use Chinese labels such as `菜单`, `提示`, `重排`, `爆破`, and `染色`.
- HUD hierarchy was revised for stage, score, target progress, fever, moves, and powerups.

### Board Layout and Alignment

- Board remains 9x9.
- Tile metrics were adjusted for a less crowded layout:
  - `TILE_SIZE` changed to `41.0`.
  - `TILE_GAP` changed to `4.0`.
  - `BOARD_PADDING` changed to `8.0`.
  - `BOARD_TOP` changed to `204.0`.
- The board frame is now drawn from the same mathematical board rectangle as the tiles.
- This replaced the earlier attempt to align against an AI-generated board image with built-in grid lines.
- The AI board-frame art exists in `assets/art/ui/`, but `BoardFrameArt` is hidden at runtime because the generated frame/grid did not align exactly with the true 9x9 tile coordinates.
- The current safe rule is: tile cells, tile positions, grid backing, and decorative frame must all derive from `board_origin`, `board_size`, `TILE_SIZE`, `TILE_GAP`, and `BOARD_PADDING`.

### UI Assets Added

Generated and sliced UI assets were added under `assets/art/ui/`:

- Board frame candidates:
  - `ui_board_frame.png`
  - `ui_board_frame_with_grid.png`
- Popup and panel pieces:
  - `ui_popup_panel.png`
  - `ui_button_panel.png`
- Progress-bar candidates:
  - `ui_progress_yellow.png`
  - `ui_progress_blue.png`
  - `ui_progress_pink.png`
  - `ui_progress_green.png`
  - `ui_progress_purple.png`
- Icon candidates:
  - `ui_icon_menu.png`
  - `ui_icon_hint.png`
  - `ui_icon_shuffle.png`
  - `ui_icon_blast.png`
  - `ui_icon_paint.png`
  - `ui_icon_goal.png`
  - `ui_icon_fever.png`
- Candy color references:
  - `ui_candy_red.png`
  - `ui_candy_yellow.png`
  - `ui_candy_green.png`
  - `ui_candy_blue.png`
  - `ui_candy_purple.png`

Generation metadata was appended to `assets/generated/aiart_manifest.jsonl`.

### Runtime Visual Implementation

- `scripts/Main.gd` now loads UI art into `ui_textures`.
- Button styles were rebuilt with light candy colors, rounded corners, thicker borders, shadows, hover states, pressed states, and disabled states.
- Powerup buttons were restyled as larger candy-like controls with two-line text and state-specific styling.
- The background and major UI containers are drawn with helper functions:
  - `_draw_soft_panel`
  - `_draw_candy_bar`
  - `_draw_round_box`
  - `_draw_meter`
  - `_draw_aligned_board_frame`
- Progress meters are drawn as capsule candy bars instead of plain rectangular bars.
- The board frame is drawn by `_draw_aligned_board_frame` to stay synchronized with the true tile grid.
- Fuzzy tile textures were adjusted to use softer colors, shadows, highlights, and cleaner facial details.

### Decisions and Lessons

- Pure code drawing is useful for exact layout, responsive alignment, and stateful UI, but it can look too plain if it carries the whole art direction.
- AI-generated UI art can raise material quality, but generated composite UI kits often have imperfect proportions, baked-in grids, or off-center elements.
- For precision-critical elements like the board, code-driven geometry is safer than relying on a generated frame with baked-in internal grid lines.
- The best current approach is hybrid:
  - Code controls layout, interaction states, meters, and board geometry.
  - Generated art is kept as a source for icons, panels, texture references, and future cut-in pieces.

### Known Follow-Ups

- Bottom powerup buttons could benefit from dedicated horizontal button assets generated specifically for their runtime size.
- Popup panels can be revisited with a purpose-built nine-patch style asset instead of using an oversized generated panel.
- The currently unused UI art should be reviewed before release; keep useful source candidates, remove dead assets only after the final visual direction is stable.
- Chain reactions can still feel frequent under the connected-group rules. The recommended next gameplay direction is stricter refill control based on `last_resolution_chain_count`, plus a light post-refill reroll pass.

### Verification Run During This Pass

The following commands were reported passing after the UI/layout changes:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
```

Screenshot checks were also used repeatedly while tuning the board/frame alignment.

## 2026-06-27 - In-Game Level Editor

### Goal

- Add a built-in level editor without replacing the existing stage flow yet.
- Let authored JSON levels configure board structure, color pool, objectives, move limit, and crate placement.
- Keep normal gameplay generation random within the authored constraints.

### Implemented

- Added an in-game editor entry from the pause menu via `编辑器`.
- Added `--level-editor` launch support for opening directly into the editor.
- Added `--level=res://data/levels/level_001.json` support for loading a JSON level for playtest.
- Added a level list backed by `res://data/levels/index.json`.
- Added save/new/playtest controls.
- Level list clicks now load a level directly for editing.
- Added level management controls: add, delete, duplicate, move up, and move down.
- Reordering updates `level_index` in `index.json` without renaming JSON files.
- Added editor brushes for:
  - Normal cell
  - Disabled cell
  - Crate durability 1
  - Crate durability 2
- Brush placement supports dragging across cells to paint in batches.
- Added color-pool selection. Refill, opening rerolls, and opening guaranteed-move seeding now use the active level color pool.
- Added objective editing for target color, target fuzzy count, crate target, score target, and move limit.
- Score, target fuzzy, and crate objectives are optional. A value of `0` disables that objective, hides it from the relevant UI, and removes it from completion checks.
- Added permanent disabled-cell terrain. Disabled cells act as holes: no spawn, no crate, no matching, no gravity fill.
- Added default sample files:
  - `data/levels/index.json`
  - `data/levels/level_001.json`

### Transitional Route

- The existing stage progression remains the default path.
- JSON levels are active when launched through `--level=...` or when the editor playtest action saves and starts the selected level.
- This is the agreed route 1.5: keep the old flow stable while introducing JSON-authored levels.

### Verification

The following commands passed after this change:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
```

## 2026-06-27 - GitHub Pages Web Export

### Goal

- Make the Godot game deployable to GitHub Pages from the repository.
- Fix missing Chinese glyphs in the GitHub Pages build.
- Make Web level-editor saves survive browser refreshes.

### Implemented

- Added `export_presets.cfg` with a Web export preset.
- Chose a local-export deployment flow: export the Godot Web build locally and publish the generated static files from the `gh-pages` branch.
- Removed the GitHub Actions export workflow so Pages does not need to download Godot or export templates on GitHub runners.
- Added `data/levels/*.json` to the Web preset include filter so authored level JSON files are packed into the exported game.
- Added `assets/fonts/NotoSansCJKsc-Regular.otf` and set it as the runtime UI theme default font so Chinese labels render correctly in browser builds.
- Changed the level editor to merge built-in `res://data/levels` entries with local `user://levels` entries.
- New or edited levels are saved under `user://levels/` so Web builds can restore them from browser-local persistence after refresh.
- Simplified editor import/export to full-list JSON only.
- `导出` writes a `level_pack` JSON containing the current merged level list.
- `导入` accepts that full `level_pack` JSON.
- Web export downloads JSON through the browser when possible and always shows copyable JSON; desktop Godot also writes JSON under `user://exports/`.

### Verification

- Local Web export was used for verification before publishing.
- Local screenshot check passed with Chinese glyphs visible:
  - `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --screenshot=/tmp/codex-font-check.png`
- Local persistence check passed:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test`
- Editor layout screenshot passed after simplifying to full-list import/export buttons:
  - `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --level-editor --screenshot=/tmp/codex-editor-export-simple.png`
- In the restricted Codex sandbox, GUI Godot invocations exited before producing logs; the same logic was verified with headless commands and should be rechecked visually in a normal desktop/browser run.

Additional screenshot checks were run for:

- `--level=res://data/levels/level_001.json --screenshot=/tmp/codex-level-json-2.png`
- `--level-editor --screenshot=/tmp/codex-level-editor.png`

## 2026-06-28 - Large Fuzzy and Board Boosters

### Goal

- Add a hand-placed 2x2 colored large fuzzy blocker.
- Make match sizes create clickable board boosters.

### Implemented

- Added the `BIG_FUZZ` tile kind.
- Added an editor brush for 2x2 large fuzzies. Saved levels now include a `big_fuzzies` list with anchor and color data.
- Large fuzzies are stored as one 2x2 object with a top-left anchor. The object renders as one enlarged fuzzy, falls together, clears together, and is not randomly generated on ordinary boards.
- Large fuzzy cells do not self-connect into a free 4-match. The anchor counts as one colored single for external same-color connected groups.
- Dragging from a large fuzzy moves the two occupied rows or two occupied columns together. A normal one-line drag that would split another large fuzzy rebounds.
- Pause menu and level-editor overlays now reset board interaction state and block pointer input from leaking through to the board.
- Groups of 4 create a directional arrow booster at the last moved-in matched cell; groups of 5 create a bomb booster; groups of 6+ create a rainbow booster.
- Board boosters are clicked to activate and spend 1 move.
- Arrow boosters clear one line in their stored direction. Bomb boosters clear 3x3. Rainbow boosters target 9 cells, prioritizing wood crates, then large fuzzies, then target-color fuzzies, then random board elements.
- Added AIART-sourced large fuzzy art at `assets/art/special/large_fuzzy.png` and generated polished board-booster icons at `assets/art/special/booster_arrow.png`, `assets/art/special/booster_bomb.png`, and `assets/art/special/booster_rainbow.png`.
- `export_presets.cfg` now includes `assets/art/special/*.png` so these runtime-loaded assets are included in Web exports.
- Fixed match scanning so valid 3+ groups are not skipped after scanning non-anchor cells of a large fuzzy.
- Hidden large-fuzzy part nodes stay hidden during snap and rebound animations, preventing small fuzzy flicker while dragging the 2x2 object.

### Verification

The following commands passed after this change:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
```

## 2026-06-28 - Booster Colorless Rules and Five-Color Large Fuzzies

### Goal

- Finish the follow-up rule pass for colorless board boosters, booster chain reactions, color-specific large fuzzy art, and overlay draw order.

### Implemented

- Board boosters no longer store generated color data and are excluded from same-color match scanning, target-color collection, paint groups, and rainbow target-color prioritization.
- Booster effects that hit another board booster now trigger that booster and clear it through the same resolution pass.
- Drag highlighting leaves booster sprites at their normal size while still moving them with the dragged row or column.
- Overlay layer draw order is raised above board tiles, and result popups reset active drag/preview tile z-index before showing.
- Added five color-specific large fuzzy assets: `large_fuzzy_red.png`, `large_fuzzy_yellow.png`, `large_fuzzy_green.png`, `large_fuzzy_blue.png`, and `large_fuzzy_purple.png`. The older `large_fuzzy.png` remains only as a fallback.
- Smoke coverage now checks that boosters are unmatchable and that booster-on-booster hits chain-trigger.

### Verification

The following commands passed after this follow-up pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --screenshot=/tmp/codex-game-check.png
```

## 2026-06-28 - Disabled Gaps, Match Residue, and Large Fuzzy Visual Cleanup

### Goal

- Fix reported issues where large fuzzy art looked inconsistent, disabled-cell drags showed blank gaps, and visible connected groups could remain after resolution.

### Implemented

- Disabled terrain cells now render as holes during play, with no board-slot rectangle drawn in the disabled positions.
- Disabled terrain cells split row and column drags into continuous playable segments. Drag preview, snap, rebound, and committed shifts operate on the selected segment instead of wrapping across disabled gaps.
- Added smoke coverage for disabled-gap drag behavior and for ensuring resolved boards do not retain immediate 3+ connected groups.
- Made large fuzzy runtime visuals use the same generated fuzzy texture family as normal fuzzies, scaled to the 2x2 footprint. The AI-generated `large_fuzzy*.png` assets remain in the tree as generated/abandoned art but are not used at runtime.
- Adjusted big-fuzzy match scanning so starting from a non-anchor part redirects to the anchor instead of silently skipping a possible cluster.

### Verification

The following commands passed after this pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --screenshot=/tmp/codex-game-check.png
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --level=/tmp/codex-big-fuzz-level.json --screenshot=/tmp/codex-big-fuzz-check.png
```

## 2026-06-28 - Four-Match Booster Rule Removal

### Goal

- Make 4-tile connected groups clear normally instead of creating arrow boosters.

### Implemented

- Match-size booster generation now starts at 5 tiles.
- 4-tile groups clear all four tiles with no reserved booster cell.
- 5-tile groups still create bomb boosters, and 6+ groups still create rainbow boosters.
- Existing arrow booster activation behavior remains for any arrow boosters already present in a board state.
- Smoke coverage now checks that 4 matches do not generate boosters and 5 matches still generate bombs.

### Verification

The following commands passed after this pass:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx --quit-after 3
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --drag-input-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --big-fuzz-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --smoke-test --stage=4
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --level=res://data/levels/level_001.json --screenshot=/tmp/codex-disabled-hole-check.png
```
