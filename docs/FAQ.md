# FAQ

## What is the game now?

You drag one whole row or one whole column. The line rotates cyclically. After release, any same-color group of 3 or more orthogonally connected tiles clears.

The current board is 9x9 so each tile is easier to read.

The current fuzzy palette has 5 colors: red, yellow, green, blue, and purple.

## Does a match need to be a straight line?

No. A valid group can be straight, L-shaped, T-shaped, block-shaped, or any shape connected by up/down/left/right neighbors.

## Do diagonals count?

No. Diagonal contact does not connect a group.

## What happens after a group clears?

The board applies gravity, refills empty cells, then scans again. New valid connected groups auto-clear as chains.

Refill tries not to create immediate 3+ connected groups by itself, because 5 colors make accidental long chains very likely.

## What should the opening board avoid?

New games and REMIX should not contain any immediately clearable connected group of 3 or more.

## Are special tiles part of the current core rules?

No. Bomb, row-clear, column-clear, and rainbow tile kinds remain in code as legacy support, but random board generation should not create them. The current board policy is normal color tiles plus blockers.

## How do blockers work?

Blockers do not count as same-color tiles. They crack or clear when adjacent to a resolved connected group.

They are shown as wood crates: a full crate has 2 durability, and a damaged crate has 1 durability.

## What happens if a drag cannot create a clear?

The dragged line rebounds to its original state. The board does not change and the move count does not decrease.

## Why is there a drag-input test?

Visual checks can pass while pointer input is broken. `--drag-input-test` proves the real drag/release path changes the board and spends a move.

## What should I check before changing gameplay code?

- Drag still rotates one whole row or column cyclically.
- Release still commits the move.
- Same-color connected groups of 3+ clear.
- Non-straight connected groups clear.
- Invalid drags rebound and do not spend moves.
- Opening and REMIX avoid immediate clearable groups.
- Refill should not routinely create runaway chain reactions.
- Wood crate blockers still crack beside resolved groups.

## What are the main verification commands?

- `--drag-input-test`
- `--smoke-test`
- `--smoke-test --stage=4`
- `--screenshot=...`

## Is there a level editor?

Yes. The game has an in-game level editor that can be opened from the pause menu with `编辑器`, or at launch with `--level-editor`.

The first editor version supports:

- A level list from `res://data/levels/index.json`.
- JSON level files under `res://data/levels/`.
- Clicking a level in the list loads it for editing.
- Adding, deleting, duplicating, and reordering levels with up/down controls.
- A 9x9 board.
- Normal cells and disabled cells.
- Wooden crates with configurable durability 1 or 2.
- Brush placement by clicking or dragging across cells to paint in batches.
- A selectable color pool, so a level can choose exactly which fuzzy colors can spawn.
- Random fuzzy generation from the selected color pool.
- Goal configuration for move limit, score target, target color, target fuzzy count, and crate-clear count.
- Save, load, new level, and playtest actions.

Normal stage progression is still preserved. JSON levels are currently used through the editor/playtest path or the `--level=res://data/levels/level_001.json` launch argument. This is the transitional route before fully replacing stage logic with authored JSON levels.

## How is the web build deployed?

GitHub Pages is deployed by `.github/workflows/pages.yml`. On pushes to `main`, the workflow downloads Godot 4.6.2, installs the Web export templates, exports the `Web` preset from `export_presets.cfg`, and publishes the generated `_site` artifact to Pages.

## How do disabled cells work?

Disabled cells are holes in the board. They do not spawn fuzzies, cannot hold crates, do not participate in matches, and stay empty during gravity and refill.

## How do optional goals work?

Score, target fuzzy count, and crate-clear count are optional level goals.

If a target value is `0`, that goal is disabled for the level. Disabled goals do not appear in HUD/mission/result text and do not block completion.

For example, `score_target = 0` means score is shown as free play, while `goal_target = 0` means target-color fuzzy collection is not required.

## What are common failure modes?

- Match logic accidentally checks only straight lines.
- Diagonal tiles are accidentally treated as connected.
- Opening stabilization leaves a 3+ connected group.
- A test calls board mutation directly but the real pointer path is broken.
- Random tile generation reintroduces legacy special tiles.
- Board shake tweens stack and leave the board offset from its intended origin.
- JSON color pools are ignored and refill or opening stabilization creates a color not selected for that level.
- Disabled cells are treated as temporary empty cells and get refilled.
