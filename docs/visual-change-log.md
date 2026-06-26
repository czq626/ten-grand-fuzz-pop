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
