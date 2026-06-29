# FAQ

## What is the game now?

You drag one whole row or one whole column. If the drag starts on a 2x2 large fuzzy, its two occupied rows or two occupied columns move together. After release, any same-color group of 3 or more orthogonally connected tiles clears.

The current board is 9x9 so each tile is easier to read.

The current fuzzy palette has 5 colors: red, yellow, green, blue, and purple.

## Does a match need to be a straight line?

No. A valid group can be straight, L-shaped, T-shaped, block-shaped, or any shape connected by up/down/left/right neighbors.

## Do diagonals count?

No. Diagonal contact does not connect a group.

## What happens after a group clears?

The board applies gravity, refills empty cells, then scans again. New valid connected groups auto-clear as chains.

Refill tries not to create immediate 3+ connected groups by itself, because 5 colors make accidental long chains very likely. After refill, the board also makes a light reroll pass to break system-created groups when possible.

## What should the opening board avoid?

New games and REMIX should not contain any immediately clearable connected group of 3 or more.

## Are special tiles part of the current core rules?

Yes, but they are created by match-size rules rather than random board generation.

A group of 4 clears normally and does not create a booster. A group of 5 creates a bomb booster. A group of 6 or more creates a rainbow booster. Clicking a board booster spends 1 move.

Board boosters are colorless tools. They do not connect with same-color fuzzy groups, do not count toward target-color collection, and are not removed by ordinary matches. If a booster effect hits another booster, the hit booster triggers its own effect and is removed as part of the chain.

Arrow boosters clear one line in their stored direction. Bomb boosters clear a 3x3 area. Rainbow boosters fire 9 one-cell attacks, prioritizing wood crates, then large fuzzies, then target-color fuzzies, then random board elements.

All board boosters deal only 1 layer of damage per hit to layered obstacles. A 3-level crate becomes 2, a 2-level crate becomes 1, and only a 1-level crate clears. Chains and ice lose only their overlay layer. Rainbow attacks prefer different targets first and only repeat targets after the available target list has been traversed once.

Board boosters use dedicated powerup art instead of reusing ordinary fuzzy tiles.

## How do blockers work?

Blockers do not count as same-color tiles. They crack or clear when adjacent to a resolved connected group.

They are shown as wood crates with 3 durability levels: reinforced crate, intact crate, and cracked crate. Crates are placed by level JSON or the level editor and are not randomly generated.

Each adjacent match or booster hit lowers a crate by 1 level. The crate target only advances when the final cracked crate clears.

Crates, ice, and chains play obstacle-specific break sounds and shard/splinter particles when hit, including partial crate damage.

## How do lock chains and ice work?

Lock chains and ice are overlay obstacles on ordinary colored fuzzies.

The underlying fuzzy still has a color and can participate in same-color connected groups. When a match or booster hits a chained or iced fuzzy, only the obstacle layer is removed; the fuzzy stays in that cell.

Lock chains also lock movement. If a dragged row or column contains a chain, that drag rebounds and does not spend a move. The chain visual uses two diagonal crossing chains and a small edge lock so the fuzzy color remains readable for matching.

Ice-covered fuzzies can still move with row and column drags.

Both obstacle types are configured in level JSON or the level editor. They can be optional level targets, and they cannot be stacked on crates, large fuzzies, boosters, disabled cells, or each other.

## How do large fuzzies work?

Large fuzzies are 2x2 colored blockers placed through the level editor and rendered as an enlarged fuzzy from the same visual style as normal fuzzies. Their four cells do not self-connect into a free 4-match; the top-left anchor counts as one single for same-color connected groups. If that colored single connects with enough external same-color fuzzies to make a group of 3 or more, the whole 2x2 clears.

Large fuzzies fall as a whole object. Dragging from a large fuzzy moves two rows or two columns together, while a normal one-line drag that would split another large fuzzy rebounds.

Booster hits clear the entire 2x2 large fuzzy directly.

Disabled cells split row and column drags into continuous playable segments. Tiles do not cycle across a disabled gap.

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
- Lock chains rebound row/column drags and only lose their overlay layer when matched or hit.
- Ice overlays can move and only lose their overlay layer when matched or hit.

## What are the main verification commands?

- `--drag-input-test`
- `--big-fuzz-test`
- `--smoke-test`
- `--smoke-test --stage=4`
- `--screenshot=...`

## Is there a level editor?

Yes. The game has an in-game level editor that can be opened from the pause menu with `编辑器`, or at launch with `--level-editor`.

The first editor version supports:

- A merged level list from built-in `res://data/levels/index.json` and local `user://levels/index.json`.
- Built-in JSON level files under `res://data/levels/`.
- Player-created or edited JSON level files under `user://levels/`.
- Clicking a level in the list loads it for editing.
- Adding, deleting, duplicating, and reordering levels with up/down controls.
- A 9x9 board.
- Normal cells and disabled cells.
- Wooden crates with configurable durability 1, 2, or 3.
- Lock chain and ice overlay obstacle brushes.
- 2x2 large fuzzies.
- Brush placement by clicking or dragging across cells to paint in batches.
- A selectable color pool, so a level can choose exactly which fuzzy colors can spawn.
- Random fuzzy generation from the selected color pool.
- Goal configuration for move limit, score target, target color, target fuzzy count, crate-clear count, lock-chain count, and ice count.
- Save, load, new level, full level-list export/import, and playtest actions.

Normal stage progression is still preserved. JSON levels are currently used through the editor/playtest path or the `--level=res://data/levels/level_001.json` launch argument. This is the transitional route before fully replacing stage logic with authored JSON levels.

On GitHub Pages and other Web exports, `res://` is bundled into the game package and is read-only. The editor saves browser-local changes into `user://levels/`, which Godot stores through browser local persistence. Refreshing the same browser should keep those levels, but clearing site data, using private browsing, or switching devices can lose them.

Use `导出` to export one JSON file containing the current merged level list. Web builds download the file through the browser when possible; otherwise the export panel shows copyable JSON. Desktop Godot also writes the file to `user://exports/`. Use `导入` to paste that full level-list JSON back into the editor.

## How is the web build deployed?

GitHub Pages serves the `gh-pages` branch. The web build is exported locally with the `Web` preset from `export_presets.cfg`, then the generated static files are committed to `gh-pages`.

This keeps generated web files out of `main` while avoiding a GitHub Actions runner download of Godot and the Web export templates.

## How do disabled cells work?

Disabled cells are holes in the board and are not drawn as board slots during play. They do not spawn fuzzies, cannot hold crates, do not participate in matches, and stay empty during gravity and refill.

The board frame follows the actual playable-cell outline, including inner borders around disabled-cell holes.

## How do optional goals work?

Score, target fuzzy count, crate-clear count, lock-chain count, and ice count are optional level goals.

If a target value is `0`, that goal is disabled for the level. Disabled goals do not appear in HUD/mission/result text and do not block completion.

For example, `score_target = 0` means score is shown as free play, while `goal_target = 0` means target-color fuzzy collection is not required.

## What are common failure modes?

- Match logic accidentally checks only straight lines.
- Diagonal tiles are accidentally treated as connected.
- Opening stabilization leaves a 3+ connected group.
- A test calls board mutation directly but the real pointer path is broken.
- Random tile generation reintroduces legacy special tiles.
- Random tile generation reintroduces wood crates instead of leaving crates to authored levels.
- Large fuzzies are split by drag, gravity, remix, or direct clear.
- Board boosters fail to spend a move or accidentally trigger during ordinary matching instead of on click.
- Board shake tweens stack and leave the board offset from its intended origin.
- JSON color pools are ignored and refill or opening stabilization creates a color not selected for that level.
- Disabled cells are treated as temporary empty cells and get refilled.
- Lock chains or ice are accidentally treated as separate colors, full blockers, or target-color collection.
