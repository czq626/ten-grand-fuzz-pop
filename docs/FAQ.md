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

## What are common failure modes?

- Match logic accidentally checks only straight lines.
- Diagonal tiles are accidentally treated as connected.
- Opening stabilization leaves a 3+ connected group.
- A test calls board mutation directly but the real pointer path is broken.
- Random tile generation reintroduces legacy special tiles.
- Board shake tweens stack and leave the board offset from its intended origin.
