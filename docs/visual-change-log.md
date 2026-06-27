# Visual Change Log

This document records UI, art, and presentation changes for `Ten Grand Fuzz Pop`.
Update it whenever visual, layout, asset, or player-facing copy changes are made.

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
- Added editor import/export actions for copying or downloading level JSON as a backup and sharing path.

### Verification

- Local Web export was used for verification before publishing.
- Local screenshot check passed with Chinese glyphs visible:
  - `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/happyelements/ai项目/codex-game-mx -- --screenshot=/tmp/codex-font-check.png`
- Local persistence check passed:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/happyelements/ai项目/codex-game-mx -- --level-persistence-test`
- In the restricted Codex sandbox, GUI Godot invocations exited before producing logs; the same logic was verified with headless commands and should be rechecked visually in a normal desktop/browser run.

Additional screenshot checks were run for:

- `--level=res://data/levels/level_001.json --screenshot=/tmp/codex-level-json-2.png`
- `--level-editor --screenshot=/tmp/codex-level-editor.png`
