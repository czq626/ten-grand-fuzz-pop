extends Control

const BOARD_COLS := 9
const BOARD_ROWS := 9
const DESIGN_SIZE := Vector2(448, 960)
const TILE_SIZE := 47.0
const TILE_GAP := 1.0
const BOARD_PADDING := 7.0
const BOARD_TOP := 190.0
const SCORE_TARGET := 10000
const GOAL_TARGET := 24
const SAVE_PATH := "user://save.cfg"
const STAGE_BACKDROP_PATH := "res://assets/art/stage_backdrop.png"
const BLOCKER_CRATE_FULL_PATH := "res://assets/art/blocker_crate_full.png"
const BLOCKER_CRATE_DAMAGED_PATH := "res://assets/art/blocker_crate_damaged.png"
const MAX_FEVER := 100.0
const POWERUP_SHUFFLE := "shuffle"
const POWERUP_BLAST := "blast"
const POWERUP_PAINT := "paint"
const COLORS := [
	Color("#f33348"),
	Color("#ffcb2f"),
	Color("#25c15f"),
	Color("#3d4fe0"),
	Color("#b62ee8")
]

enum TileKind { NORMAL, BOMB, ROW_CLEAR, COLUMN_CLEAR, RAINBOW, BLOCKER }

var board: Array = []
var tile_nodes: Array = []
var textures: Array[Texture2D] = []
var badge_textures: Dictionary = {}
var blocker_textures: Dictionary = {}
var rng := RandomNumberGenerator.new()
var score := 0
var high_score := SCORE_TARGET
var best_score := 0
var stage := 1
var moves := 35
var combo := 0
var last_resolution_chain_count := 0
var goal_color := 1
var goal_collected := 0
var goal_target := GOAL_TARGET
var blocker_cleared := 0
var blocker_target := 0
var shuffle_charges := 2
var blast_charges := 2
var paint_charges := 1
var bonus_blast_next := 0
var bonus_paint_next := 0
var armed_powerup := ""
var fever := 0.0
var ended := false
var assist_given := false
var goal_milestone_shown := false
var score_milestone_shown := false
var blocker_milestone_shown := false
var fever_warning_shown := false
var selected_cells: Array[Vector2i] = []
var busy := false
var drag_origin := Vector2i(-1, -1)
var drag_start_pos := Vector2.ZERO
var drag_axis := ""
var drag_steps := 0
var preview_axis := ""
var preview_index := -1

var content_root: Control
var backdrop: Control
var content_scale := 1.0
var content_offset := Vector2.ZERO
var board_origin := Vector2.ZERO
var board_size := Vector2.ZERO
var board_layer: Node2D
var fx_layer: Node2D
var board_bump_tween: Tween
var title_label: Label
var level_label: Label
var best_label: Label
var score_label: Label
var moves_label: Label
var goal_label: Label
var status_label: Label
var mission_label: Label
var combo_label: Label
var score_progress_label: Label
var goal_progress_value_label: Label
var fever_value_label: Label
var target_bar: TextureProgressBar
var goal_bar: TextureProgressBar
var fever_bar: TextureProgressBar
var hint_button: Button
var restart_button: Button
var shuffle_button: Button
var blast_button: Button
var paint_button: Button
var overlay_layer: Control
var sfx_player: AudioStreamPlayer


func _ready() -> void:
	rng.randomize()
	_load_save()
	_apply_stage_arg()
	board_size = Vector2(
		BOARD_COLS * TILE_SIZE + (BOARD_COLS - 1) * TILE_GAP + BOARD_PADDING * 2.0,
		BOARD_ROWS * TILE_SIZE + (BOARD_ROWS - 1) * TILE_GAP + BOARD_PADDING * 2.0
	)
	_create_textures()
	_build_interface()
	await get_tree().process_frame
	_layout_root()
	_new_game()
	_maybe_run_smoke_test()
	_maybe_run_drag_input_test()
	_maybe_capture_result()
	_maybe_capture_menu()
	_maybe_capture_viewport()


func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	best_score = int(config.get_value("progress", "best_score", 0))
	stage = max(1, int(config.get_value("progress", "stage", 1)))


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_score", best_score)
	config.set_value("progress", "stage", stage)
	config.save(SAVE_PATH)


func _apply_stage_arg() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage = max(1, int(arg.get_slice("=", 1)))


func _maybe_capture_viewport() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			var output_path := arg.get_slice("=", 1)
			await get_tree().process_frame
			await get_tree().process_frame
			var texture := get_viewport().get_texture()
			var image := texture.get_image() if texture != null else null
			if image != null:
				image.save_png(output_path)
			if is_instance_valid(sfx_player):
				sfx_player.stop()
				sfx_player.stream = null
			get_tree().quit()


func _maybe_capture_menu() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-screenshot="):
			var output_path := arg.get_slice("=", 1)
			_show_pause_menu()
			await get_tree().process_frame
			await get_tree().process_frame
			var texture := get_viewport().get_texture()
			var image := texture.get_image() if texture != null else null
			if image != null:
				image.save_png(output_path)
			get_tree().quit()


func _maybe_capture_result() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--result-screenshot="):
			var output_path := arg.get_slice("=", 1)
			score = high_score
			goal_collected = goal_target
			_update_hud()
			await _end_game()
			await get_tree().process_frame
			await get_tree().process_frame
			var texture := get_viewport().get_texture()
			var image := texture.get_image() if texture != null else null
			if image != null:
				image.save_png(output_path)
			get_tree().quit()


func _has_capture_arg() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot=") or arg.begins_with("--menu-screenshot=") or arg.begins_with("--result-screenshot="):
			return true
	return false


func _is_verification_mode() -> bool:
	return OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--drag-input-test") or _has_capture_arg()


func _maybe_run_drag_input_test() -> void:
	if not OS.get_cmdline_user_args().has("--drag-input-test"):
		return
	await get_tree().process_frame
	_prepare_smoke_shift_match()
	var before_signature := _board_signature()
	var before_moves := moves
	var start := _screen_position_for_cell(Vector2i(0, 0))
	var end := start + Vector2((TILE_SIZE + TILE_GAP) * content_scale * 1.25, 0)
	_begin_drag_at(start)
	_update_drag_at(end)
	await _release_drag_at(end)
	await get_tree().process_frame
	if _board_signature() == before_signature:
		push_error("Drag input test failed: board signature did not change")
		get_tree().quit(1)
		return
	if moves != before_moves - 1:
		push_error("Drag input test failed: moves did not decrement")
		get_tree().quit(1)
		return
	before_signature = _board_signature()
	before_moves = moves
	start = _screen_position_for_cell(Vector2i(0, 0))
	end = start + Vector2((TILE_SIZE + TILE_GAP) * content_scale * 0.18, 0)
	_begin_drag_at(start)
	_update_drag_at(end)
	await _release_drag_at(end)
	await get_tree().process_frame
	if _board_signature() != before_signature or moves != before_moves:
		push_error("Drag input test failed: invalid drag did not rebound cleanly")
		get_tree().quit(1)
		return
	print("Drag input test passed: moves=%d" % moves)
	if is_instance_valid(sfx_player):
		sfx_player.stop()
		sfx_player.stream = null
	get_tree().quit()


func _maybe_run_smoke_test() -> void:
	if not OS.get_cmdline_user_args().has("--smoke-test"):
		return
	await get_tree().process_frame
	var before_score := score
	if stage >= 2 and _count_blockers() <= 0:
		push_error("Smoke test failed: stage blocker coverage missing")
		get_tree().quit(1)
		return
	if stage >= 4 and _count_blockers() < blocker_target:
		push_error("Smoke test failed: blocker objective supply missing")
		get_tree().quit(1)
		return
	if not _find_matches().is_empty():
		push_error("Smoke test failed: opening board has accidental matches")
		get_tree().quit(1)
		return
	if not _has_any_move():
		push_error("Smoke test failed: opening board has no row/column shift move")
		get_tree().quit(1)
		return
	if not _smoke_connected_group_detection():
		push_error("Smoke test failed: connected group detection missed non-line group")
		get_tree().quit(1)
		return
	_prepare_smoke_shift_match()
	await _commit_line_shift(Vector2i(0, 0), "row", 1)
	if score <= before_score:
		push_error("Smoke test failed: row shift did not create match")
		get_tree().quit(1)
		return
	if last_resolution_chain_count > 4:
		push_error("Smoke test failed: chain reaction ran too long (%d)" % last_resolution_chain_count)
		get_tree().quit(1)
		return
	if board_layer.position.distance_to(board_origin) > 0.1:
		push_error("Smoke test failed: board layer drifted after resolution")
		get_tree().quit(1)
		return
	if shuffle_charges <= 0:
		push_error("Smoke test failed: initial powerup state invalid")
		get_tree().quit(1)
		return
	var shuffle_before: int = shuffle_charges
	await _arm_powerup(POWERUP_SHUFFLE)
	if shuffle_charges != shuffle_before - 1:
		push_error("Smoke test failed: remix did not consume or refresh")
		get_tree().quit(1)
		return
	if not _find_matches().is_empty():
		push_error("Smoke test failed: remixed board has accidental matches")
		get_tree().quit(1)
		return
	if not _has_any_move():
		push_error("Smoke test failed: remixed board has no row/column shift move")
		get_tree().quit(1)
		return
	await _arm_powerup(POWERUP_PAINT)
	if armed_powerup != POWERUP_PAINT:
		push_error("Smoke test failed: paint did not arm")
		get_tree().quit(1)
		return
	var paint_target := _first_non_blocker_cell()
	if not _valid_cell(paint_target):
		push_error("Smoke test failed: no paint target")
		get_tree().quit(1)
		return
	await _use_armed_powerup(paint_target)
	if armed_powerup != "" or paint_charges != 0:
		push_error("Smoke test failed: paint did not consume")
		get_tree().quit(1)
		return
	await _arm_powerup(POWERUP_BLAST)
	if armed_powerup != POWERUP_BLAST:
		push_error("Smoke test failed: blast did not arm")
		get_tree().quit(1)
		return
	var blast_before: int = blast_charges
	await _use_armed_powerup(_first_non_blocker_cell())
	if armed_powerup != "" or blast_charges > blast_before:
		push_error("Smoke test failed: blast did not consume")
		get_tree().quit(1)
		return
	if not await _smoke_break_blocker():
		push_error("Smoke test failed: blocker did not break from nearby pop")
		get_tree().quit(1)
		return
	if stage >= 4:
		if blocker_target <= 0:
			push_error("Smoke test failed: blocker objective missing")
			get_tree().quit(1)
			return
		score = high_score
		goal_collected = goal_target
		blocker_cleared = blocker_target - 1
		if _stage_complete():
			push_error("Smoke test failed: blocker objective not required")
			get_tree().quit(1)
			return
		blocker_cleared = blocker_target
		if not _stage_complete():
			push_error("Smoke test failed: blocker objective completion invalid")
			get_tree().quit(1)
			return
	var filled := 0
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			if not board[row][col].is_empty():
				filled += 1
	if score <= before_score or filled != BOARD_COLS * BOARD_ROWS:
		push_error("Smoke test failed: score=%d filled=%d" % [score, filled])
		get_tree().quit(1)
		return
	print("Smoke test passed: score=%d filled=%d" % [score, filled])
	if is_instance_valid(sfx_player):
		sfx_player.stop()
		sfx_player.stream = null
	await get_tree().process_frame
	get_tree().quit()


func _first_non_blocker_cell() -> Vector2i:
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			var cell := Vector2i(col, row)
			if _valid_cell(cell) and int(_tile(cell).kind) != TileKind.BLOCKER:
				return cell
	return Vector2i(-1, -1)


func _count_blockers() -> int:
	var total := 0
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			if int(board[row][col].kind) == TileKind.BLOCKER:
				total += 1
	return total


func _ensure_blocker_objective_supply() -> void:
	var minimum_blockers := _minimum_stage_blockers()
	if minimum_blockers <= 0:
		return
	var needed := minimum_blockers - _count_blockers()
	if needed <= 0:
		return
	var placed := 0
	for row in range(1, BOARD_ROWS, 2):
		for col in range((row + stage) % 2, BOARD_COLS, 3):
			if placed >= needed:
				return
			var tile: Dictionary = board[row][col]
			if int(tile.kind) == TileKind.BLOCKER:
				continue
			tile.kind = TileKind.BLOCKER
			tile.hp = 2
			placed += 1


func _minimum_stage_blockers() -> int:
	if blocker_target > 0:
		return blocker_target
	if stage >= 2:
		return 2
	return 0


func _board_signature() -> String:
	var parts: Array[String] = []
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			var tile: Dictionary = board[row][col]
			parts.append("%d:%d:%d" % [int(tile.get("id", 0)), int(tile.get("kind", 0)), int(tile.get("color", 0))])
	return "|".join(parts)


func _prepare_smoke_shift_match() -> void:
	_prepare_cluster_shift_match(0, 0, 0)


func _smoke_connected_group_detection() -> bool:
	var backup := []
	for row in BOARD_ROWS:
		var line := []
		for col in BOARD_COLS:
			line.append(board[row][col].duplicate(true))
		backup.append(line)
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			board[row][col].kind = TileKind.NORMAL
			board[row][col].hp = 0
			board[row][col].color = (row * 3 + col) % COLORS.size()
	board[0][0].color = 0
	board[1][0].color = 0
	board[1][1].color = 0
	var matches := _find_matches()
	board = backup
	_update_all_tile_nodes()
	return matches.has(Vector2i(0, 0)) and matches.has(Vector2i(0, 1)) and matches.has(Vector2i(1, 1))


func _smoke_break_blocker() -> bool:
	var blocker := Vector2i(1, 0)
	board[blocker.y][blocker.x].kind = TileKind.BLOCKER
	board[blocker.y][blocker.x].hp = 2
	board[blocker.y][blocker.x].id = -4242
	var match_row := _prepare_blocker_cluster_shift_match(blocker)
	_update_tile_node(blocker)
	await _resolve_cells([Vector2i(0, match_row), Vector2i(1, match_row), Vector2i(2, match_row)], false)
	var cracked := _find_cell_by_id(-4242)
	if not _valid_cell(cracked) or int(_tile(cracked).get("hp", 0)) != 1:
		return false
	board[cracked.y][cracked.x].kind = TileKind.BLOCKER
	board[cracked.y][cracked.x].hp = 1
	board[cracked.y][cracked.x].id = -4242
	match_row = _prepare_blocker_cluster_shift_match(cracked)
	_update_tile_node(cracked)
	await _resolve_cells([Vector2i(0, match_row), Vector2i(1, match_row), Vector2i(2, match_row)], false)
	return not _valid_cell(_find_cell_by_id(-4242))


func _find_cell_by_id(id_value: int) -> Vector2i:
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			if int(board[row][col].get("id", 0)) == id_value:
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _prepare_smoke_row_match_near_blocker(row: int) -> void:
	_prepare_cluster_shift_match(row, 0, 0)
	for col in BOARD_COLS:
		_update_tile_node(Vector2i(col, row))


func _prepare_blocker_cluster_shift_match(blocker: Vector2i) -> int:
	var match_row: int = min(BOARD_ROWS - 1, blocker.y + 1)
	if match_row == blocker.y:
		match_row = max(0, blocker.y - 1)
	_prepare_cluster_shift_match(match_row, 0, 0)
	for row in [max(0, match_row - 1), match_row, min(BOARD_ROWS - 1, match_row + 1)]:
		for col in BOARD_COLS:
			if int(board[row][col].kind) != TileKind.BLOCKER:
				board[row][col].color = (row * 3 + col + 2) % COLORS.size()
	board[match_row][0].color = 0
	board[match_row][1].color = 0
	board[match_row][BOARD_COLS - 1].color = 0
	for row in [max(0, match_row - 1), match_row, min(BOARD_ROWS - 1, match_row + 1)]:
		for col in BOARD_COLS:
			_update_tile_node(Vector2i(col, row))
	return match_row


func _prepare_cluster_shift_match(row: int, color: int, offset: int) -> void:
	for col in BOARD_COLS:
		board[row][col].kind = TileKind.NORMAL
		board[row][col].hp = 0
		board[row][col].color = (col + offset + 1) % COLORS.size()
	var upper_row: int = max(0, row - 1)
	var lower_row: int = min(BOARD_ROWS - 1, row + 1)
	for col in BOARD_COLS:
		if upper_row != row and int(board[upper_row][col].kind) != TileKind.BLOCKER:
			board[upper_row][col].color = (col + offset + 3) % COLORS.size()
		if lower_row != row and int(board[lower_row][col].kind) != TileKind.BLOCKER:
			board[lower_row][col].color = (col + offset + 5) % COLORS.size()
	board[row][0].color = color
	board[row][1].color = color
	board[row][BOARD_COLS - 1].color = color
	for col in BOARD_COLS:
		_update_tile_node(Vector2i(col, row))
	if upper_row != row:
		for col in BOARD_COLS:
			_update_tile_node(Vector2i(col, upper_row))
	if lower_row != row:
		for col in BOARD_COLS:
			_update_tile_node(Vector2i(col, lower_row))


func _style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#27183c")
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#3b2454")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.35)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#140d20")
	disabled.border_color = Color("#4c4059")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#8c8494"))
	button.add_theme_font_size_override("font_size", 14)


func _style_powerup_button(button: Button, accent: Color, armed: bool, disabled: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.48) if armed else Color("#27183c")
	normal.border_color = Color.WHITE if armed else accent
	normal.set_border_width_all(3 if armed else 2)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.34) if armed else Color("#3b2454")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.24)
	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color("#120d1a")
	disabled_style.border_color = Color("#4a4054")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color("#fff9bd") if armed else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#746a82") if disabled else Color("#fff9bd"))


func _powerup_accent(powerup: String) -> Color:
	match powerup:
		POWERUP_BLAST:
			return Color("#ff606d")
		POWERUP_PAINT:
			return Color("#68f3ff")
		_:
			return Color("#ffda36")


func _input(event: InputEvent) -> void:
	if busy or ended:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _begin_drag_at(event.position):
				accept_event()
		else:
			if _valid_cell(drag_origin):
				accept_event()
				await _release_drag_at(event.position)
	elif event is InputEventMouseMotion and _motion_has_left_button(event):
		if _update_drag_at(event.position):
			accept_event()


func _begin_drag_at(pos: Vector2) -> bool:
	var cell := _cell_from_position(pos)
	drag_start_pos = pos
	drag_axis = ""
	drag_steps = 0
	drag_origin = cell
	if not _valid_cell(cell):
		return false
	if armed_powerup.is_empty():
		_preview_shift_origin(cell)
	return true


func _update_drag_at(pos: Vector2) -> bool:
	if not _valid_cell(drag_origin) or not armed_powerup.is_empty():
		return false
	_update_line_drag_preview(pos)
	return true


func _release_drag_at(pos: Vector2) -> void:
	var committed := false
	if _valid_cell(drag_origin):
		if armed_powerup.is_empty():
			_update_line_drag_preview(pos)
		if not armed_powerup.is_empty():
			await _use_armed_powerup(drag_origin)
		elif drag_steps != 0 and not drag_axis.is_empty():
			committed = true
			await _commit_line_shift(drag_origin, drag_axis, drag_steps)
	if not committed:
		_clear_shift_preview()
	drag_origin = Vector2i(-1, -1)
	drag_axis = ""
	drag_steps = 0


func _motion_has_left_button(event: InputEventMouseMotion) -> bool:
	if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_root()


func _build_interface() -> void:
	content_root = Control.new()
	content_root.name = "ContentRoot"
	content_root.size = DESIGN_SIZE
	add_child(content_root)

	var bg := ColorRect.new()
	bg.name = "Backplate"
	bg.size = DESIGN_SIZE
	bg.color = Color("#150f27")
	content_root.add_child(bg)

	var bg_art := TextureRect.new()
	bg_art.name = "StageBackdropArt"
	bg_art.texture = _load_png_texture(STAGE_BACKDROP_PATH)
	bg_art.size = DESIGN_SIZE
	bg_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_art.modulate = Color(0.82, 0.82, 0.9, 0.72)
	content_root.add_child(bg_art)

	backdrop = Control.new()
	backdrop.name = "StageBackdrop"
	backdrop.size = DESIGN_SIZE
	content_root.add_child(backdrop)
	backdrop.draw.connect(_draw_backdrop.bind(backdrop))

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(8, 8)
	top_bar.size = Vector2(432, 34)
	top_bar.add_theme_constant_override("separation", 8)
	content_root.add_child(top_bar)

	restart_button = Button.new()
	restart_button.text = "MENU"
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.pressed.connect(_show_pause_menu)
	_style_button(restart_button, Color("#ffd23f"))
	top_bar.add_child(restart_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(292, 1)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	hint_button = Button.new()
	hint_button.text = "HINT"
	hint_button.focus_mode = Control.FOCUS_NONE
	hint_button.pressed.connect(_show_hint)
	_style_button(hint_button, Color("#7df8ff"))
	top_bar.add_child(hint_button)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "FUZZ POP"
	title_label.position = Vector2(20, 46)
	title_label.size = Vector2(150, 28)
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color("#fff6c7"))
	title_label.add_theme_color_override("font_shadow_color", Color("#39113d"))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	content_root.add_child(title_label)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "STAGE %d" % stage
	level_label.position = Vector2(310, 50)
	level_label.size = Vector2(112, 24)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.add_theme_color_override("font_color", Color("#93fff1"))
	content_root.add_child(level_label)

	best_label = Label.new()
	best_label.name = "BestLabel"
	best_label.text = "BEST 0"
	best_label.position = Vector2(300, 76)
	best_label.size = Vector2(122, 20)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label.add_theme_font_size_override("font_size", 12)
	best_label.add_theme_color_override("font_color", Color("#c9b8ff"))
	content_root.add_child(best_label)

	var orb_holder := Control.new()
	orb_holder.name = "PrizeOrb"
	orb_holder.position = Vector2(176, 42)
	orb_holder.size = Vector2(96, 96)
	content_root.add_child(orb_holder)
	orb_holder.draw.connect(_draw_prize_orb.bind(orb_holder))

	target_bar = TextureProgressBar.new()
	target_bar.name = "TargetBar"
	target_bar.position = Vector2(154, 137)
	target_bar.size = Vector2(138, 22)
	target_bar.min_value = 0
	target_bar.max_value = high_score
	target_bar.value = 0
	target_bar.tint_progress = Color("#d52330")
	target_bar.tint_under = Color("#05040a")
	content_root.add_child(target_bar)

	score_progress_label = Label.new()
	score_progress_label.name = "ScoreProgressLabel"
	score_progress_label.position = Vector2(154, 139)
	score_progress_label.size = Vector2(138, 18)
	score_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_progress_label.add_theme_font_size_override("font_size", 10)
	score_progress_label.add_theme_color_override("font_color", Color("#ffe9d2"))
	score_progress_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_progress_label.add_theme_constant_override("shadow_offset_x", 1)
	score_progress_label.add_theme_constant_override("shadow_offset_y", 1)
	content_root.add_child(score_progress_label)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(145, 112)
	score_label.size = Vector2(156, 26)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	content_root.add_child(score_label)

	moves_label = Label.new()
	moves_label.name = "MovesLabel"
	moves_label.position = Vector2(18, 102)
	moves_label.size = Vector2(82, 58)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	moves_label.add_theme_font_size_override("font_size", 18)
	moves_label.add_theme_color_override("font_color", Color("#f6ecff"))
	content_root.add_child(moves_label)

	goal_label = Label.new()
	goal_label.name = "GoalLabel"
	goal_label.position = Vector2(302, 102)
	goal_label.size = Vector2(128, 58)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.add_theme_font_size_override("font_size", 17)
	goal_label.add_theme_color_override("font_color", Color("#fff4ad"))
	content_root.add_child(goal_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(80, 674)
	status_label.size = Vector2(288, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#d8fff9"))
	content_root.add_child(status_label)

	mission_label = Label.new()
	mission_label.name = "MissionLabel"
	mission_label.text = "Rotate rows/columns to make 3+ connected."
	mission_label.position = Vector2(40, 712)
	mission_label.size = Vector2(368, 22)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.add_theme_font_size_override("font_size", 13)
	mission_label.add_theme_color_override("font_color", Color("#bfaee8"))
	content_root.add_child(mission_label)

	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(164, 160)
	combo_label.size = Vector2(120, 24)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 16)
	combo_label.add_theme_color_override("font_color", Color("#ffe767"))
	content_root.add_child(combo_label)

	board_layer = Node2D.new()
	board_layer.name = "BoardLayer"
	content_root.add_child(board_layer)

	fx_layer = Node2D.new()
	fx_layer.name = "FxLayer"
	content_root.add_child(fx_layer)

	goal_bar = TextureProgressBar.new()
	goal_bar.name = "GoalProgressBar"
	goal_bar.position = Vector2(72, 752)
	goal_bar.size = Vector2(328, 14)
	goal_bar.min_value = 0
	goal_bar.max_value = goal_target
	goal_bar.value = 0
	goal_bar.tint_under = Color("#16111f")
	goal_bar.tint_progress = Color("#b62ee8")
	content_root.add_child(goal_bar)

	var goal_progress_label := Label.new()
	goal_progress_label.name = "GoalProgressLabel"
	goal_progress_label.text = "GOAL"
	goal_progress_label.position = Vector2(26, 747)
	goal_progress_label.size = Vector2(46, 24)
	goal_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_progress_label.add_theme_font_size_override("font_size", 12)
	goal_progress_label.add_theme_color_override("font_color", Color("#fff4ad"))
	content_root.add_child(goal_progress_label)

	goal_progress_value_label = Label.new()
	goal_progress_value_label.name = "GoalProgressValue"
	goal_progress_value_label.position = Vector2(300, 736)
	goal_progress_value_label.size = Vector2(100, 16)
	goal_progress_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_progress_value_label.add_theme_font_size_override("font_size", 11)
	goal_progress_value_label.add_theme_color_override("font_color", Color("#fff4ad"))
	content_root.add_child(goal_progress_value_label)

	fever_bar = TextureProgressBar.new()
	fever_bar.name = "FeverBar"
	fever_bar.position = Vector2(72, 780)
	fever_bar.size = Vector2(328, 22)
	fever_bar.min_value = 0
	fever_bar.max_value = 100
	fever_bar.value = 0
	fever_bar.tint_under = Color("#16111f")
	fever_bar.tint_progress = Color("#fb2147")
	content_root.add_child(fever_bar)

	var fever_label := Label.new()
	fever_label.name = "FeverLabel"
	fever_label.text = "FEVER"
	fever_label.position = Vector2(26, 778)
	fever_label.size = Vector2(46, 24)
	fever_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fever_label.add_theme_font_size_override("font_size", 12)
	fever_label.add_theme_color_override("font_color", Color("#ffe767"))
	content_root.add_child(fever_label)

	fever_value_label = Label.new()
	fever_value_label.name = "FeverValue"
	fever_value_label.position = Vector2(300, 765)
	fever_value_label.size = Vector2(100, 16)
	fever_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fever_value_label.add_theme_font_size_override("font_size", 11)
	fever_value_label.add_theme_color_override("font_color", Color("#ffb6c7"))
	content_root.add_child(fever_value_label)

	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "PowerupBar"
	bottom_bar.position = Vector2(38, 819)
	bottom_bar.size = Vector2(396, 44)
	bottom_bar.add_theme_constant_override("separation", 10)
	content_root.add_child(bottom_bar)

	shuffle_button = _make_powerup_button("REMIX", POWERUP_SHUFFLE)
	blast_button = _make_powerup_button("BLAST", POWERUP_BLAST)
	paint_button = _make_powerup_button("PAINT", POWERUP_PAINT)
	bottom_bar.add_child(shuffle_button)
	bottom_bar.add_child(blast_button)
	bottom_bar.add_child(paint_button)

	var reward_label := Label.new()
	reward_label.name = "RewardLabel"
	reward_label.text = "FEVER rewards bonus BLAST or PAINT"
	reward_label.position = Vector2(42, 870)
	reward_label.size = Vector2(364, 24)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 12)
	reward_label.add_theme_color_override("font_color", Color("#8cf9ff"))
	content_root.add_child(reward_label)

	overlay_layer = Control.new()
	overlay_layer.name = "OverlayLayer"
	overlay_layer.size = DESIGN_SIZE
	content_root.add_child(overlay_layer)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SfxPlayer"
	add_child(sfx_player)

	call_deferred("_layout_root")


func _load_png_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	var file_path := path
	if path.begins_with("res://"):
		file_path = ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(file_path)
	if image == null:
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _texture_fit_scale(texture: Texture2D, target_size: float) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var texture_size := texture.get_size()
	var largest_edge: float = max(texture_size.x, texture_size.y)
	if largest_edge <= 0.0:
		return Vector2.ONE
	var fit := target_size / largest_edge
	return Vector2(fit, fit)


func _make_powerup_button(label: String, powerup: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(122, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_arm_powerup.bind(powerup))
	button.set_meta("powerup", powerup)
	_style_button(button, _powerup_accent(powerup))
	return button


func _layout_root() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		call_deferred("_layout_root")
		return
	var sx: float = viewport_size.x / DESIGN_SIZE.x
	var sy: float = viewport_size.y / DESIGN_SIZE.y
	content_scale = min(sx, sy)
	if content_scale <= 0.0:
		call_deferred("_layout_root")
		return
	content_offset = (viewport_size - DESIGN_SIZE * content_scale) * 0.5
	content_root.position = content_offset
	content_root.scale = Vector2(content_scale, content_scale)
	board_origin = Vector2((448.0 - board_size.x) * 0.5, BOARD_TOP)
	board_layer.position = board_origin
	fx_layer.position = board_origin


func _new_game() -> void:
	if is_instance_valid(overlay_layer):
		_clear_overlay()
	busy = false
	score = 0
	high_score = SCORE_TARGET + (stage - 1) * 1800
	moves = max(24, 36 - stage)
	combo = 0
	goal_color = rng.randi_range(0, COLORS.size() - 1)
	goal_collected = 0
	goal_target = GOAL_TARGET + (stage - 1) * 3
	blocker_cleared = 0
	blocker_target = _stage_blocker_target()
	shuffle_charges = 2
	blast_charges = 2 + bonus_blast_next
	paint_charges = 1 + bonus_paint_next
	bonus_blast_next = 0
	bonus_paint_next = 0
	armed_powerup = ""
	fever = 0.0
	ended = false
	assist_given = false
	goal_milestone_shown = false
	score_milestone_shown = false
	blocker_milestone_shown = false
	fever_warning_shown = false
	board.clear()
	_clear_tiles()
	for row in BOARD_ROWS:
		var line := []
		var node_line: Array = []
		for col in BOARD_COLS:
			var tile := _create_tile(col, row)
			line.append(tile)
			var node := _make_tile_node(tile)
			board_layer.add_child(node)
			node.position = _tile_position(col, row)
			node_line.append(node)
		board.append(line)
		tile_nodes.append(node_line)
	_ensure_blocker_objective_supply()
	_stabilize_opening_board()
	_update_all_tile_nodes()
	if is_instance_valid(mission_label):
		mission_label.text = _stage_mission_line()
	_update_hud()
	if not OS.get_cmdline_user_args().has("--smoke-test") and not _has_capture_arg():
		_show_start_card()


func _next_stage() -> void:
	stage += 1
	_save_progress()
	_clear_overlay()
	_new_game()


func _show_pause_menu() -> void:
	if busy and not ended:
		return
	busy = true
	var card := _make_overlay_card("PAUSED", "Best %d\n%s" % [best_score, _pause_goal_line()], "")
	card.position = Vector2(44, 344)
	overlay_layer.add_child(card)
	var resume := _make_overlay_button("CLOSE" if ended else "RESUME", Vector2(72, 470), func() -> void:
		card.queue_free()
		if not ended:
			busy = false
	)
	var restart := _make_overlay_button("RESTART", Vector2(172, 470), func() -> void:
		_clear_overlay()
		_new_game()
	)
	var next := _make_overlay_button("NEXT", Vector2(272, 470), func() -> void:
		_next_stage()
	)
	var help := _make_overlay_button("HELP", Vector2(172, 512), func() -> void:
		_clear_overlay()
		_show_help_card()
	)
	overlay_layer.add_child(resume)
	overlay_layer.add_child(restart)
	overlay_layer.add_child(next)
	overlay_layer.add_child(help)


func _show_help_card() -> void:
	busy = true
	var card := _make_overlay_card(
		"HOW TO PLAY",
		"Drag one row or column to rotate it\nMake 3+ connected same color to pop\nwood crates crack beside matches",
		"Connected groups can chain"
	)
	card.position = Vector2(44, 330)
	overlay_layer.add_child(card)
	var back := _make_overlay_button("BACK", Vector2(181, 506), func() -> void:
		_clear_overlay()
		_show_pause_menu()
	)
	overlay_layer.add_child(back)


func _make_overlay_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(86, 34)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, Color("#93fff1"))
	button.pressed.connect(callback)
	return button


func _clear_overlay() -> void:
	for child in overlay_layer.get_children():
		child.queue_free()


func _arm_powerup(powerup: String) -> void:
	if busy:
		return
	match powerup:
		POWERUP_SHUFFLE:
			if shuffle_charges <= 0:
				_flash_status("No remix left")
				return
			shuffle_charges -= 1
			armed_powerup = ""
			_flash_status("Board remixed")
			_play_sfx("power")
			_remix_board()
			_update_hud()
			await _animate_drop()
		POWERUP_BLAST:
			if blast_charges <= 0:
				_flash_status("No blast left")
				return
			armed_powerup = POWERUP_BLAST
			_flash_status("Choose a tile to blast")
		POWERUP_PAINT:
			if paint_charges <= 0:
				_flash_status("No paint left")
				return
			armed_powerup = POWERUP_PAINT
			_flash_status("Choose a group to paint goal color")
	_update_hud()


func _use_armed_powerup(cell: Vector2i) -> void:
	match armed_powerup:
		POWERUP_BLAST:
			if blast_charges <= 0:
				armed_powerup = ""
				return
			blast_charges -= 1
			var blast_cells: Array[Vector2i] = []
			for y in range(cell.y - 1, cell.y + 2):
				for x in range(cell.x - 1, cell.x + 2):
					var near := Vector2i(x, y)
					if _valid_cell(near):
						blast_cells.append(near)
			armed_powerup = ""
			await _resolve_cells(blast_cells)
		POWERUP_PAINT:
			if paint_charges <= 0:
				armed_powerup = ""
				return
			paint_charges -= 1
			var paint_cells: Array[Vector2i] = _collect_group(cell)
			for painted in paint_cells:
				board[painted.y][painted.x].color = goal_color
				_update_tile_node(painted)
				_pulse_tile(painted)
			armed_powerup = ""
			fever = min(MAX_FEVER, fever + paint_cells.size() * 2.0)
			_play_sfx("power")
			_flash_status("Painted %d fuzzies" % paint_cells.size())
	_update_hud()


func _create_tile(col: int, row: int, avoid_refill_cluster: bool = false) -> Dictionary:
	var kind := TileKind.NORMAL
	var roll := rng.randf()
	if roll < _stage_blocker_rate():
		kind = TileKind.BLOCKER
	var color := _random_refill_color(col, row, kind) if avoid_refill_cluster else _random_safe_color(col, row, kind)
	return {
		"color": color,
		"kind": kind,
		"hp": 2 if kind == TileKind.BLOCKER else 0,
		"id": Time.get_ticks_usec() + rng.randi()
	}


func _random_safe_color(col: int, row: int, kind: int) -> int:
	if kind == TileKind.BLOCKER:
		return rng.randi_range(0, COLORS.size() - 1)
	var candidates: Array[int] = []
	for i in COLORS.size():
		candidates.append(i)
	candidates.shuffle()
	for color in candidates:
		if not _would_make_opening_cluster(col, row, color):
			return color
	return rng.randi_range(0, COLORS.size() - 1)


func _random_refill_color(col: int, row: int, kind: int) -> int:
	if kind == TileKind.BLOCKER:
		return rng.randi_range(0, COLORS.size() - 1)
	var candidates: Array[int] = []
	for i in COLORS.size():
		candidates.append(i)
	candidates.shuffle()
	for color in candidates:
		if not _would_make_refill_cluster(col, row, color):
			return color
	return candidates[0] if not candidates.is_empty() else 0


func _would_make_refill_cluster(col: int, row: int, color: int) -> bool:
	var visited := {}
	var total := 1
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var near: Vector2i = Vector2i(col, row) + dir
		if visited.has(near):
			continue
		total += _filled_same_color_cluster_size(near, color, visited)
		if total >= 3:
			return true
	return false


func _would_make_opening_cluster(col: int, row: int, color: int) -> bool:
	var total := 1
	var visited := {}
	for dir in [Vector2i.LEFT, Vector2i.UP]:
		var near: Vector2i = Vector2i(col, row) + dir
		if visited.has(near):
			continue
		total += _filled_same_color_cluster_size(near, color, visited)
		if total >= 3:
			return true
	return false


func _filled_same_color_cluster_size(start: Vector2i, color: int, visited: Dictionary) -> int:
	if start.x < 0 or start.x >= BOARD_COLS or start.y < 0 or start.y >= BOARD_ROWS:
		return 0
	var stack: Array[Vector2i] = [start]
	var count := 0
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		if cell.x < 0 or cell.x >= BOARD_COLS or cell.y < 0 or cell.y >= BOARD_ROWS:
			continue
		if cell.y >= board.size() or cell.x >= board[cell.y].size():
			continue
		var tile: Dictionary = board[cell.y][cell.x]
		if tile.is_empty() or int(tile.kind) == TileKind.BLOCKER or int(tile.color) != color:
			continue
		count += 1
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			stack.append(cell + dir)
	return count


func _make_tile_node(tile: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.set_meta("tile", tile)
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = textures[tile.color]
	glow.scale = Vector2(1.02, 1.02)
	glow.modulate = Color(1, 1, 1, 0.0)
	root.add_child(glow)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = textures[tile.color]
	sprite.scale = Vector2(0.92, 0.92)
	root.add_child(sprite)

	var ring := Sprite2D.new()
	ring.name = "Ring"
	ring.visible = false
	root.add_child(ring)

	var badge := Sprite2D.new()
	badge.name = "Badge"
	badge.visible = false
	root.add_child(badge)

	var marker := Label.new()
	marker.name = "Marker"
	marker.position = Vector2(-18, -20)
	marker.size = Vector2(36, 36)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 23)
	marker.add_theme_color_override("font_color", Color.WHITE)
	marker.add_theme_color_override("font_shadow_color", Color.BLACK)
	marker.add_theme_constant_override("shadow_offset_x", 1)
	marker.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(marker)
	return root


func _update_all_tile_nodes() -> void:
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			_update_tile_node(Vector2i(col, row))


func _update_tile_node(cell: Vector2i) -> void:
	var node: Node2D = _tile_node(cell)
	var tile: Dictionary = _tile(cell)
	node.set_meta("tile", tile)
	var glow: Sprite2D = node.get_node("Glow")
	glow.texture = textures[int(tile.color)]
	glow.modulate = Color(1, 1, 1, 0.0)
	var sprite: Sprite2D = node.get_node("Sprite")
	sprite.texture = textures[int(tile.color)]
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(0.92, 0.92)
	var marker: Label = node.get_node("Marker")
	var badge: Sprite2D = node.get_node("Badge")
	var ring: Sprite2D = node.get_node("Ring")
	badge.visible = false
	ring.visible = false
	match int(tile.kind):
		TileKind.BOMB:
			marker.text = "*"
			sprite.scale = Vector2(1.0, 1.0)
			glow.modulate = Color(1.0, 0.58, 0.16, 0.5)
			badge.texture = badge_textures[TileKind.BOMB]
			badge.visible = true
			ring.texture = badge_textures[TileKind.BOMB]
			ring.scale = Vector2(1.85, 1.85)
			ring.modulate = Color(1.0, 0.42, 0.2, 0.35)
			ring.visible = true
		TileKind.ROW_CLEAR:
			marker.text = ">"
			glow.modulate = Color(0.35, 0.9, 1.0, 0.35)
			badge.texture = badge_textures[TileKind.ROW_CLEAR]
			badge.visible = true
			ring.texture = badge_textures[TileKind.ROW_CLEAR]
			ring.scale = Vector2(1.7, 1.7)
			ring.modulate = Color(0.35, 0.95, 1.0, 0.28)
			ring.visible = true
		TileKind.COLUMN_CLEAR:
			marker.text = "v"
			glow.modulate = Color(0.35, 0.9, 1.0, 0.35)
			badge.texture = badge_textures[TileKind.COLUMN_CLEAR]
			badge.visible = true
			ring.texture = badge_textures[TileKind.COLUMN_CLEAR]
			ring.scale = Vector2(1.7, 1.7)
			ring.modulate = Color(0.35, 0.95, 1.0, 0.28)
			ring.visible = true
		TileKind.RAINBOW:
			marker.text = "+"
			sprite.modulate = Color("#fff7a8")
			glow.modulate = Color(1.0, 0.95, 0.3, 0.55)
			badge.texture = badge_textures[TileKind.RAINBOW]
			badge.visible = true
			ring.texture = badge_textures[TileKind.RAINBOW]
			ring.scale = Vector2(1.82, 1.82)
			ring.modulate = Color(1.0, 0.95, 0.25, 0.36)
			ring.visible = true
		TileKind.BLOCKER:
			var blocker_hp: int = int(tile.get("hp", 2))
			marker.text = ""
			sprite.texture = blocker_textures["full"] if blocker_hp > 1 else blocker_textures["damaged"]
			sprite.modulate = Color.WHITE
			sprite.scale = _texture_fit_scale(sprite.texture, TILE_SIZE * 0.96)
			glow.texture = sprite.texture
			glow.scale = _texture_fit_scale(glow.texture, TILE_SIZE * 1.08)
			glow.modulate = Color(1.0, 0.55, 0.24, 0.28)
			ring.texture = badge_textures[TileKind.BLOCKER]
			ring.scale = Vector2(1.9, 1.9)
			ring.modulate = Color(1.0, 0.48, 0.18, 0.28) if blocker_hp > 1 else Color(1.0, 0.16, 0.10, 0.35)
			ring.visible = true
		_:
			marker.text = ""


func _try_pop(cell: Vector2i) -> void:
	if not _valid_cell(cell):
		return
	var target: Dictionary = _tile(cell)
	if target.kind == TileKind.BLOCKER:
		_play_sfx("bad")
		_shake(cell)
		_flash_status("Break blockers with nearby pops")
		return
	var group := _collect_group(cell)
	if target.kind == TileKind.RAINBOW:
		group = _collect_color(int(target.color))
	if group.size() < 2 and target.kind == TileKind.NORMAL:
		_play_sfx("bad")
		_shake(cell)
		combo = 0
		_update_hud()
		return
	var cells := _expand_specials(group)
	await _resolve_cells(cells)


func _resolve_cells(cells: Array[Vector2i], spend_move: bool = true, keep_busy: bool = false) -> void:
	busy = true
	if cells.is_empty():
		if not keep_busy:
			busy = false
		return
	var score_before := score
	var goal_before := goal_collected
	var blocker_before := blocker_cleared
	var fever_before := fever
	var resolved_cells := _resolve_blocker_hits(cells)
	cells = resolved_cells["clear"]
	if spend_move:
		moves = max(0, moves - 1)
	combo += 1
	var gained: int = cells.size() * cells.size() * 10 + max(0, combo - 1) * 50
	var goal_gain := _count_goal_cells(cells)
	var goal_cells := _goal_cells_in(cells)
	goal_collected = min(goal_target, goal_collected + goal_gain)
	fever = min(MAX_FEVER, fever + cells.size() * 4.0 + max(0, combo - 1) * 2.0)
	if cells.size() >= 7:
		_play_sfx("mega")
		gained += cells.size() * 25
		if cells.size() >= 10:
			blast_charges += 1
			_flash_status("Mega pop! BLAST +1")
		elif cells.size() >= 8:
			shuffle_charges += 1
			_flash_status("Mega pop! REMIX +1")
		else:
			_flash_status("Mega pop!")
		_board_bump()
	elif goal_gain > 0:
		_play_sfx("pop")
		_flash_status("Goal +%d" % goal_gain)
	else:
		_play_sfx("pop")
	score += gained
	_spawn_score_text(_center_of_cells(cells), "+%d" % gained)
	if goal_gain > 0:
		_spawn_goal_collection_trails(goal_cells)
	_check_milestones(score_before, goal_before, blocker_before, fever_before)
	for damaged in resolved_cells["damaged"]:
		_update_tile_node(damaged)
		_pulse_tile(damaged)
		_spawn_crate_splinters(damaged)
		_spawn_milestone_text(board_origin + _tile_position(damaged.x, damaged.y), "CRACK", Color("#ffb6f2"))
	await _pop_cells(cells)
	_apply_gravity()
	_refill_board()
	await _animate_drop()
	_update_hud()
	_maybe_goal_assist()
	if fever >= MAX_FEVER:
		_trigger_fever_reward()
	if _stage_complete():
		await _end_game()
		return
	if not _has_any_move():
		status_label.text = "Fresh Mix!"
		_remix_board()
		await _animate_drop()
	if moves <= 0:
		await _end_game()
	if not keep_busy:
		busy = false


func _count_goal_cells(cells: Array[Vector2i]) -> int:
	var total := 0
	for cell in cells:
		if _valid_cell(cell) and int(_tile(cell).color) == goal_color and int(_tile(cell).kind) != TileKind.BLOCKER:
			total += 1
	return total


func _goal_cells_in(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if _valid_cell(cell) and int(_tile(cell).color) == goal_color and int(_tile(cell).kind) != TileKind.BLOCKER:
			result.append(cell)
	return result


func _collect_group(start: Vector2i) -> Array[Vector2i]:
	var target: Dictionary = _tile(start)
	var target_color: int = target.color
	var visited := {}
	var stack: Array[Vector2i] = [start]
	var group: Array[Vector2i] = []
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		if not _valid_cell(cell):
			continue
		var tile: Dictionary = _tile(cell)
		if tile.kind == TileKind.BLOCKER:
			continue
		if tile.color != target_color and tile.kind != TileKind.RAINBOW:
			continue
		group.append(cell)
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			stack.append(cell + dir)
	return group


func _collect_color(color_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			if int(board[row][col].color) == color_index and int(board[row][col].kind) != TileKind.BLOCKER:
				cells.append(Vector2i(col, row))
	return cells


func _expand_specials(seed_cells: Array[Vector2i]) -> Array[Vector2i]:
	var result := {}
	var force_clear := {}
	for cell in seed_cells:
		result[cell] = true
	for cell in seed_cells:
		var tile: Dictionary = _tile(cell)
		match int(tile.kind):
			TileKind.BOMB:
				for y in range(cell.y - 1, cell.y + 2):
					for x in range(cell.x - 1, cell.x + 2):
						var near := Vector2i(x, y)
						if _valid_cell(near):
							result[near] = true
							force_clear[near] = true
			TileKind.ROW_CLEAR:
				for x in BOARD_COLS:
					result[Vector2i(x, cell.y)] = true
					force_clear[Vector2i(x, cell.y)] = true
			TileKind.COLUMN_CLEAR:
				for y in BOARD_ROWS:
					result[Vector2i(cell.x, y)] = true
					force_clear[Vector2i(cell.x, y)] = true
			TileKind.RAINBOW:
				var color: int = int(_tile(cell).color)
				for same in _collect_color(color):
					result[same] = true
					force_clear[same] = true
	var cells: Array[Vector2i] = []
	for key in result.keys():
		cells.append(key)
		if force_clear.has(key):
			_tile(key).force_clear = true
	return cells


func _resolve_blocker_hits(cells: Array[Vector2i]) -> Dictionary:
	var clear_cells: Array[Vector2i] = []
	var damaged_cells: Array[Vector2i] = []
	var hit_blockers := {}
	for cell in cells:
		if not _valid_cell(cell):
			continue
		var tile: Dictionary = _tile(cell)
		if int(tile.kind) != TileKind.BLOCKER:
			clear_cells.append(cell)
			continue
		hit_blockers[cell] = true
		_apply_blocker_hit(cell, tile, clear_cells, damaged_cells)
	for cell in clear_cells.duplicate():
		for neighbor in _orthogonal_neighbors(cell):
			if hit_blockers.has(neighbor):
				continue
			if _valid_cell(neighbor) and int(_tile(neighbor).kind) == TileKind.BLOCKER:
				hit_blockers[neighbor] = true
				_apply_blocker_hit(neighbor, _tile(neighbor), clear_cells, damaged_cells)
	return {
		"clear": clear_cells,
		"damaged": damaged_cells
	}


func _apply_blocker_hit(cell: Vector2i, tile: Dictionary, clear_cells: Array[Vector2i], damaged_cells: Array[Vector2i]) -> void:
	var force_clear := bool(tile.get("force_clear", false))
	tile.erase("force_clear")
	var hp: int = int(tile.get("hp", 2))
	if force_clear or hp <= 1:
		clear_cells.append(cell)
		blocker_cleared = min(blocker_target, blocker_cleared + 1)
	else:
		tile.hp = hp - 1
		damaged_cells.append(cell)


func _orthogonal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1)
	]


func _pop_cells(cells: Array[Vector2i]) -> void:
	_play_pop_flash(cells)
	await get_tree().create_timer(0.07).timeout
	for cell in cells:
		var node: Node2D = _tile_node(cell)
		_spawn_pop(cell, int(_tile(cell).color))
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(node, "scale", Vector2(1.28, 1.28), 0.06)
		tween.tween_property(node, "scale", Vector2.ZERO, 0.14)
		tween.parallel().tween_property(node, "modulate:a", 0.0, 0.14)
	if cells.size() >= 5:
		_board_bump()
	await get_tree().create_timer(0.23).timeout
	for cell in cells:
		board[cell.y][cell.x] = {}
		_tile_node(cell).visible = false


func _play_pop_flash(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var node: Node2D = _tile_node(cell)
		var glow: Sprite2D = node.get_node("Glow")
		glow.modulate = Color(1.0, 0.95, 0.45, 0.65)
		var tween := create_tween()
		tween.tween_property(node, "scale", Vector2(1.16, 1.16), 0.05)
		tween.parallel().tween_property(glow, "scale", Vector2(1.34, 1.34), 0.05)
		tween.tween_property(glow, "modulate:a", 0.0, 0.12)


func _apply_gravity() -> void:
	for col in BOARD_COLS:
		var write_row := BOARD_ROWS - 1
		for row in range(BOARD_ROWS - 1, -1, -1):
			if not board[row][col].is_empty():
				if write_row != row:
					board[write_row][col] = board[row][col]
					_tile_node(Vector2i(col, write_row)).set_meta("fall_from", row)
					board[row][col] = {}
				write_row -= 1
		for row in range(write_row, -1, -1):
			board[row][col] = {}


func _refill_board() -> void:
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			if board[row][col].is_empty():
				board[row][col] = _create_tile(col, row, true)
				var node := _tile_node(Vector2i(col, row))
				node.position = _tile_position(col, -rng.randi_range(2, 7))
				node.visible = true
				node.scale = Vector2.ONE
				node.modulate.a = 1.0
				_update_tile_node(Vector2i(col, row))


func _animate_drop() -> void:
	if is_instance_valid(board_bump_tween):
		board_bump_tween.kill()
	board_layer.position = board_origin
	var tween := create_tween()
	tween.set_parallel(true)
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			var node: Node2D = _tile_node(Vector2i(col, row))
			node.visible = true
			node.scale = Vector2.ONE
			node.modulate.a = 1.0
			_update_tile_node(Vector2i(col, row))
			tween.tween_property(node, "position", _tile_position(col, row), 0.20).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	board_layer.position = board_origin


func _remix_board() -> void:
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			board[row][col] = _create_tile(col, row)
			_tile_node(Vector2i(col, row)).position = _tile_position(col, row - BOARD_ROWS)
			_update_tile_node(Vector2i(col, row))
	_stabilize_opening_board()


func _preview_shift_origin(cell: Vector2i) -> void:
	_clear_shift_preview()
	drag_origin = cell
	drag_axis = ""
	drag_steps = 0
	_highlight_shift_line("row", cell.y, Color(1.0, 0.95, 0.35, 0.18))
	_highlight_shift_line("col", cell.x, Color(0.35, 0.95, 1.0, 0.18))
	status_label.text = "Drag row or column"


func _update_line_drag_preview(pos: Vector2) -> void:
	var delta: Vector2 = pos - drag_start_pos
	if drag_axis.is_empty():
		if delta.length() < TILE_SIZE * content_scale * 0.38:
			return
		drag_axis = "row" if abs(delta.x) >= abs(delta.y) else "col"
		_clear_shift_preview(false)
	var step_px := (TILE_SIZE + TILE_GAP) * content_scale
	var raw_step_float: float = (delta.x if drag_axis == "row" else delta.y) / step_px
	var raw_steps := _steps_from_drag(raw_step_float)
	var size := BOARD_COLS if drag_axis == "row" else BOARD_ROWS
	drag_steps = _wrap_cycle_steps(raw_steps, size)
	var offset_amount := (delta.x if drag_axis == "row" else delta.y) / content_scale
	_apply_shift_preview(drag_origin, drag_axis, offset_amount)
	var arrow := ("<" if drag_steps < 0 else ">") if drag_axis == "row" else ("^" if drag_steps < 0 else "v")
	status_label.text = "%s Shift %s %s%d" % [arrow, ("row" if drag_axis == "row" else "column"), ("+" if drag_steps >= 0 else ""), drag_steps]


func _apply_shift_preview(origin: Vector2i, axis: String, offset_amount: float) -> void:
	_clear_shift_preview(false, axis, origin.y if axis == "row" else origin.x)
	preview_axis = axis
	preview_index = origin.y if axis == "row" else origin.x
	if axis == "row":
		for col in BOARD_COLS:
			var cell := Vector2i(col, origin.y)
			var node := _tile_node(cell)
			var pos := _tile_position(col, origin.y)
			pos.x += offset_amount
			pos.x = _wrap_line_coordinate(pos.x, BOARD_PADDING + TILE_SIZE * 0.5, BOARD_COLS)
			node.position = pos
			node.z_index = 4
			_set_node_drag_glow(node, Color(1.0, 0.95, 0.35, 0.34))
	else:
		for row in BOARD_ROWS:
			var cell := Vector2i(origin.x, row)
			var node := _tile_node(cell)
			var pos := _tile_position(origin.x, row)
			pos.y += offset_amount
			pos.y = _wrap_line_coordinate(pos.y, BOARD_PADDING + TILE_SIZE * 0.5, BOARD_ROWS)
			node.position = pos
			node.z_index = 4
			_set_node_drag_glow(node, Color(0.35, 0.95, 1.0, 0.34))


func _clear_shift_preview(reset_status: bool = true, keep_axis: String = "", keep_index: int = -1) -> void:
	if not preview_axis.is_empty() and preview_index >= 0:
		_reset_shift_line(preview_axis, preview_index)
	preview_axis = keep_axis
	preview_index = keep_index
	if keep_axis.is_empty():
		_reset_shift_line("row", drag_origin.y)
		_reset_shift_line("col", drag_origin.x)
	if reset_status:
		status_label.text = ""


func _reset_shift_line(axis: String, index: int) -> void:
	if index < 0:
		return
	if axis == "row":
		if index >= BOARD_ROWS:
			return
		for col in BOARD_COLS:
			var cell := Vector2i(col, index)
			var node: Node2D = _tile_node(cell)
			node.position = _tile_position(col, index)
			node.z_index = 0
			_update_tile_node(cell)
	else:
		if index >= BOARD_COLS:
			return
		for row in BOARD_ROWS:
			var cell := Vector2i(index, row)
			var node: Node2D = _tile_node(cell)
			node.position = _tile_position(index, row)
			node.z_index = 0
			_update_tile_node(cell)


func _highlight_shift_line(axis: String, index: int, color: Color) -> void:
	if axis == "row":
		for col in BOARD_COLS:
			var node := _tile_node(Vector2i(col, index))
			node.z_index = 2
			_set_node_drag_glow(node, color)
	else:
		for row in BOARD_ROWS:
			var node := _tile_node(Vector2i(index, row))
			node.z_index = 2
			_set_node_drag_glow(node, color)


func _set_node_drag_glow(node: Node2D, color: Color) -> void:
	var glow: Sprite2D = node.get_node("Glow")
	glow.modulate = color
	var sprite: Sprite2D = node.get_node("Sprite")
	var tile: Dictionary = node.get_meta("tile", {})
	if int(tile.get("kind", TileKind.NORMAL)) == TileKind.BLOCKER:
		sprite.scale = _texture_fit_scale(sprite.texture, TILE_SIZE * 1.02)
		glow.scale = _texture_fit_scale(glow.texture, TILE_SIZE * 1.14)
	else:
		sprite.scale = Vector2(0.98, 0.98)


func _wrap_cycle_steps(raw_steps: int, size: int) -> int:
	if size <= 0:
		return 0
	var direction := 1 if raw_steps > 0 else -1 if raw_steps < 0 else 0
	var wrapped: int = abs(raw_steps) % size
	return direction * wrapped


func _steps_from_drag(raw_step_float: float) -> int:
	var magnitude: float = abs(raw_step_float)
	if magnitude < 0.28:
		return 0
	var direction: int = 1 if raw_step_float > 0.0 else -1
	return direction * max(1, int(floor(magnitude + 0.35)))


func _wrap_line_coordinate(value: float, first_center: float, count: int) -> float:
	var pitch := TILE_SIZE + TILE_GAP
	var span := count * pitch
	var half_pitch := pitch * 0.5
	return first_center - half_pitch + fposmod(value - first_center + half_pitch, span)


func _commit_line_shift(origin: Vector2i, axis: String, steps: int) -> void:
	if steps == 0:
		return
	busy = true
	var preview_positions := _capture_shift_preview_positions(origin, axis, steps)
	if axis == "row":
		_shift_row(origin.y, steps)
	else:
		_shift_col(origin.x, steps)
	if _find_matches().is_empty():
		if axis == "row":
			_shift_row(origin.y, -steps)
		else:
			_shift_col(origin.x, -steps)
		await _animate_shift_rebound(origin, axis, preview_positions)
		busy = false
		return
	moves = max(0, moves - 1)
	combo = 0
	_update_shifted_line_nodes(origin, axis)
	await _animate_shift_snap(origin, axis, preview_positions)
	_update_all_tile_nodes()
	await _resolve_matches_after_shift()
	if not ended:
		busy = false


func _update_shifted_line_nodes(origin: Vector2i, axis: String) -> void:
	if axis == "row":
		for col in BOARD_COLS:
			_update_tile_node(Vector2i(col, origin.y))
	else:
		for row in BOARD_ROWS:
			_update_tile_node(Vector2i(origin.x, row))


func _capture_shift_preview_positions(origin: Vector2i, axis: String, steps: int) -> Dictionary:
	var positions := {}
	if axis == "row":
		for col in BOARD_COLS:
			var source_col := posmod(col - steps, BOARD_COLS)
			positions[Vector2i(col, origin.y)] = _tile_node(Vector2i(source_col, origin.y)).position
	else:
		for row in BOARD_ROWS:
			var source_row := posmod(row - steps, BOARD_ROWS)
			positions[Vector2i(origin.x, row)] = _tile_node(Vector2i(origin.x, source_row)).position
	return positions


func _animate_shift_snap(origin: Vector2i, axis: String, preview_positions: Dictionary) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	if axis == "row":
		for col in BOARD_COLS:
			var cell := Vector2i(col, origin.y)
			var node := _tile_node(cell)
			node.visible = true
			node.position = preview_positions.get(cell, _tile_position(col, origin.y))
			node.z_index = 4
			_set_node_drag_glow(node, Color(1.0, 0.95, 0.35, 0.34))
			tween.tween_property(node, "position", _tile_position(col, origin.y), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		for row in BOARD_ROWS:
			var cell := Vector2i(origin.x, row)
			var node := _tile_node(cell)
			node.visible = true
			node.position = preview_positions.get(cell, _tile_position(origin.x, row))
			node.z_index = 4
			_set_node_drag_glow(node, Color(0.35, 0.95, 1.0, 0.34))
			tween.tween_property(node, "position", _tile_position(origin.x, row), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	_clear_shift_preview(false)


func _animate_shift_rebound(origin: Vector2i, axis: String, preview_positions: Dictionary) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	if axis == "row":
		for col in BOARD_COLS:
			var cell := Vector2i(col, origin.y)
			var node := _tile_node(cell)
			node.visible = true
			node.position = preview_positions.get(cell, _tile_position(col, origin.y))
			node.z_index = 4
			_set_node_drag_glow(node, Color(1.0, 0.55, 0.45, 0.32))
			tween.tween_property(node, "position", _tile_position(col, origin.y), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		for row in BOARD_ROWS:
			var cell := Vector2i(origin.x, row)
			var node := _tile_node(cell)
			node.visible = true
			node.position = preview_positions.get(cell, _tile_position(origin.x, row))
			node.z_index = 4
			_set_node_drag_glow(node, Color(1.0, 0.55, 0.45, 0.32))
			tween.tween_property(node, "position", _tile_position(origin.x, row), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_clear_shift_preview(false)


func _shift_row(row: int, steps: int) -> void:
	var shifted := []
	for col in BOARD_COLS:
		var source_col := posmod(col - steps, BOARD_COLS)
		shifted.append(board[row][source_col])
	for col in BOARD_COLS:
		board[row][col] = shifted[col]


func _shift_col(col: int, steps: int) -> void:
	var shifted := []
	for row in BOARD_ROWS:
		var source_row := posmod(row - steps, BOARD_ROWS)
		shifted.append(board[source_row][col])
	for row in BOARD_ROWS:
		board[row][col] = shifted[row]


func _resolve_matches_after_shift() -> void:
	var matches := _find_matches()
	last_resolution_chain_count = 0
	if matches.is_empty():
		combo = 0
		_flash_status("No match")
		_update_hud()
		if moves <= 0:
			await _end_game()
		else:
			busy = false
		return
	while not matches.is_empty():
		last_resolution_chain_count += 1
		await _resolve_cells(matches, false, true)
		if ended:
			return
		matches = _find_matches()
	board_layer.position = board_origin
	busy = false


func _find_matches() -> Array[Vector2i]:
	var visited := {}
	var found := {}
	for row in BOARD_ROWS:
		for col in BOARD_COLS:
			var cell := Vector2i(col, row)
			if visited.has(cell):
				continue
			var cluster := _collect_same_color_cluster(cell, visited)
			if cluster.size() >= 3:
				for clustered in cluster:
					found[clustered] = true
	var cells: Array[Vector2i] = []
	for key in found.keys():
		cells.append(key)
	return _expand_specials(cells)


func _collect_same_color_cluster(start: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	if not _valid_cell(start):
		return cluster
	var start_tile: Dictionary = _tile(start)
	if int(start_tile.kind) == TileKind.BLOCKER:
		visited[start] = true
		return cluster
	var color: int = int(start_tile.color)
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if visited.has(cell):
			continue
		if not _valid_cell(cell):
			continue
		var tile: Dictionary = _tile(cell)
		if int(tile.kind) == TileKind.BLOCKER or int(tile.color) != color:
			continue
		visited[cell] = true
		cluster.append(cell)
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			stack.append(cell + dir)
	return cluster


func _avoid_opening_dead_board() -> void:
	if _has_any_move():
		return
	_seed_guaranteed_shift_match()


func _stabilize_opening_board() -> void:
	for attempt in 20:
		_clear_opening_matches()
		if not _has_any_move():
			_seed_guaranteed_shift_match()
		if _find_matches().is_empty() and _has_any_move():
			return


func _clear_opening_matches() -> void:
	for attempt in 20:
		var matches := _find_matches()
		if matches.is_empty():
			return
		for cell in matches:
			_reroll_opening_cell(cell)


func _reroll_opening_cell(cell: Vector2i) -> void:
	if not _valid_cell(cell) or int(_tile(cell).kind) == TileKind.BLOCKER:
		return
	var old_color: int = int(_tile(cell).color)
	var candidates: Array[int] = []
	for color in COLORS.size():
		if color != old_color:
			candidates.append(color)
	candidates.shuffle()
	for color in candidates:
		_tile(cell).color = color
		if not _cell_has_match(cell):
			return
	_tile(cell).color = old_color


func _cell_has_match(cell: Vector2i) -> bool:
	if not _valid_cell(cell) or int(_tile(cell).kind) == TileKind.BLOCKER:
		return false
	var visited := {}
	return _collect_same_color_cluster(cell, visited).size() >= 3


func _has_any_move() -> bool:
	return not _find_shift_hint().is_empty()


func _seed_guaranteed_shift_match() -> void:
	if BOARD_COLS < 3:
		return
	for row in range(BOARD_ROWS - 1, -1, -1):
		for seed_color in COLORS.size():
			_prepare_cluster_shift_match(row, seed_color, seed_color + 1)
			if _find_matches().is_empty():
				return


func _preview_group(cell: Vector2i) -> void:
	_clear_selection()
	if not _valid_cell(cell):
		return
	var tile: Dictionary = _tile(cell)
	selected_cells = _collect_group(cell)
	if tile.kind == TileKind.RAINBOW:
		selected_cells = _collect_color(int(tile.color))
	if selected_cells.size() < 2 and tile.kind == TileKind.NORMAL:
		return
	for selected in selected_cells:
		var node: Node2D = _tile_node(selected)
		var sprite: Sprite2D = node.get_node("Sprite")
		sprite.scale = Vector2(1.06, 1.06)
		sprite.modulate = Color("#fff7bd")
		node.position = _tile_position(selected.x, selected.y) + Vector2(0, -2)
	status_label.text = "%d fuzzies" % selected_cells.size()


func _clear_selection() -> void:
	for cell in selected_cells:
		if _valid_cell(cell):
			_tile_node(cell).position = _tile_position(cell.x, cell.y)
			_update_tile_node(cell)
	selected_cells.clear()
	status_label.text = ""


func _show_hint() -> void:
	if busy:
		return
	var hint := _find_shift_hint()
	if hint.is_empty():
		status_label.text = "No obvious shift"
		return
	var axis: String = hint["axis"]
	var index: int = int(hint["index"])
	var steps: int = int(hint["steps"])
	_highlight_line(axis, index)
	status_label.text = "Try %s %d %+d" % [axis, index + 1, steps]
	mission_label.text = "Rotate the highlighted line to make 3+."


func _find_shift_hint() -> Dictionary:
	for row in BOARD_ROWS:
		for steps in [-2, -1, 1, 2]:
			if _shift_would_match("row", row, steps):
				return {"axis": "row", "index": row, "steps": steps}
	for col in BOARD_COLS:
		for steps in [-2, -1, 1, 2]:
			if _shift_would_match("col", col, steps):
				return {"axis": "col", "index": col, "steps": steps}
	return {}


func _shift_would_match(axis: String, index: int, steps: int) -> bool:
	if axis == "row":
		_shift_row(index, steps)
	else:
		_shift_col(index, steps)
	var has_match := not _find_matches().is_empty()
	if axis == "row":
		_shift_row(index, -steps)
	else:
		_shift_col(index, -steps)
	return has_match


func _highlight_line(axis: String, index: int) -> void:
	_clear_selection()
	if axis == "row":
		for col in BOARD_COLS:
			selected_cells.append(Vector2i(col, index))
	else:
		for row in BOARD_ROWS:
			selected_cells.append(Vector2i(index, row))
	for cell in selected_cells:
		var node: Node2D = _tile_node(cell)
		var tween := create_tween()
		tween.set_loops(3)
		tween.tween_property(node, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(node, "scale", Vector2.ONE, 0.12)


func _shake(cell: Vector2i) -> void:
	var node: Node2D = _tile_node(cell)
	var start: Vector2 = node.position
	var tween := create_tween()
	tween.tween_property(node, "position", start + Vector2(5, 0), 0.04)
	tween.tween_property(node, "position", start - Vector2(5, 0), 0.04)
	tween.tween_property(node, "position", start, 0.04)


func _end_game() -> void:
	busy = true
	ended = true
	var win := _stage_complete()
	var verification_mode := _is_verification_mode()
	if not verification_mode:
		best_score = max(best_score, score)
	if win:
		var stars := _star_count()
		if not verification_mode:
			if stars >= 3:
				bonus_blast_next += 1
			elif stars >= 2:
				bonus_paint_next += 1
	if not verification_mode:
		_save_progress()
	status_label.text = ""
	mission_label.text = ""
	_update_hud()
	_play_sfx("win" if win else "fail")
	var end_text := _make_result_card(win)
	var tween := create_tween()
	end_text.scale = Vector2.ZERO
	tween.tween_property(end_text, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	busy = false


func _show_start_card() -> void:
	busy = true
	var card := _make_overlay_card(
		"STAGE %d" % stage,
		"%s\n%s" % [_stage_brief_line(), _stage_rule_line()],
		"Goal color and score both count"
	)
	overlay_layer.add_child(card)
	card.position = Vector2(54, 320)
	card.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.35).timeout
	var out := create_tween()
	out.tween_property(card, "modulate:a", 0.0, 0.22)
	await out.finished
	card.queue_free()
	busy = false


func _make_result_card(win: bool) -> Control:
	var stars := _star_count()
	var footer := _failure_tip() if not win else "%s %s  %s" % [_star_string(stars), _star_rank_name(stars), _stage_reward_line(stars)]
	var result_line := "Moves left %d" % moves if win else _failure_reason()
	var body := _result_body(result_line)
	var card := _make_overlay_card("STAGE CLEAR" if win else "OUT OF MOVES", body, footer)
	card.position = Vector2(44, 344)
	overlay_layer.add_child(card)
	var primary := _make_overlay_button("NEXT" if win else "RETRY", Vector2(128, 526), func() -> void:
		if win:
			_next_stage()
		else:
			_clear_overlay()
			_new_game()
	)
	var menu := _make_overlay_button("MENU", Vector2(232, 526), func() -> void:
		_clear_overlay()
		_show_pause_menu()
	)
	overlay_layer.add_child(primary)
	overlay_layer.add_child(menu)
	return card


func _make_overlay_card(title: String, body: String, footer: String) -> Control:
	var panel := Control.new()
	panel.size = Vector2(360, 218)
	var rect := ColorRect.new()
	rect.color = Color("#090714")
	rect.size = panel.size
	panel.add_child(rect)
	var border := Control.new()
	border.size = panel.size
	panel.add_child(border)
	border.draw.connect(func() -> void:
		border.draw_rect(Rect2(Vector2.ZERO, panel.size), Color("#ffda36"), false, 4.0)
		border.draw_rect(Rect2(Vector2(6, 6), panel.size - Vector2(12, 12)), Color("#48e9ff"), false, 2.0)
	)
	var title_label_local := Label.new()
	title_label_local.text = title
	title_label_local.position = Vector2(18, 18)
	title_label_local.size = Vector2(324, 38)
	title_label_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label_local.add_theme_font_size_override("font_size", 28)
	title_label_local.add_theme_color_override("font_color", Color("#fff2a2"))
	panel.add_child(title_label_local)
	var body_label := Label.new()
	body_label.text = body
	body_label.position = Vector2(28, 64)
	body_label.size = Vector2(304, 70)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color("#f7f1ff"))
	panel.add_child(body_label)
	var footer_label := Label.new()
	footer_label.text = footer
	footer_label.position = Vector2(18, 146)
	footer_label.size = Vector2(324, 30)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 17)
	footer_label.add_theme_color_override("font_color", Color("#93fff1"))
	panel.add_child(footer_label)
	return panel


func _star_count() -> int:
	if score >= high_score * 1.25 and _objectives_complete():
		return 3
	if _stage_complete():
		return 2
	if _objectives_complete() or score >= high_score:
		return 1
	return 0


func _star_string(count: int) -> String:
	var text := ""
	for i in 3:
		text += "*" if i < count else "-"
	return text


func _star_rank_name(count: int) -> String:
	match count:
		3:
			return "MASTER"
		2:
			return "CLEAR"
		1:
			return "SCRAPPY"
		_:
			return "TRY AGAIN"


func _stage_reward_line(stars: int) -> String:
	if stars >= 3:
		return "Next: BLAST +1"
	if stars >= 2:
		return "Next: PAINT +1"
	return "Best %d" % best_score


func _special_reward_name(kind: int) -> String:
	match kind:
		TileKind.BOMB:
			return "BOMB"
		TileKind.ROW_CLEAR:
			return "ROW"
		TileKind.COLUMN_CLEAR:
			return "COLUMN"
		TileKind.RAINBOW:
			return "RAINBOW"
		_:
			return "SPECIAL"


func _failure_tip() -> String:
	if blocker_target > 0 and blocker_cleared < blocker_target:
		return "Tip: specials crush blockers faster"
	if goal_collected < goal_target and paint_charges <= 0:
		return "Tip: save PAINT for the goal color"
	if score < high_score:
		return "Tip: longer matches score much more"
	return "Tip: crack blockers beside matches"


func _result_body(result_line: String) -> String:
	if blocker_target > 0:
		return "Goal %d/%d  Blockers %d/%d\nScore %d/%d\n%s" % [goal_collected, goal_target, blocker_cleared, blocker_target, score, high_score, result_line]
	return "Goal %d/%d\nScore %d/%d\n%s" % [goal_collected, goal_target, score, high_score, result_line]


func _current_objective_nudge() -> String:
	if armed_powerup == POWERUP_BLAST:
		return "BLAST armed: choose the most crowded 3x3."
	if armed_powerup == POWERUP_PAINT:
		return "PAINT armed: convert a group to goal color."
	if _stage_complete():
		return "Stage target complete. Finish the shift!"
	if moves <= 5 and not _stage_complete():
		return "Final moves: rotate toward goal matches."
	if blocker_target > 0 and blocker_cleared < blocker_target:
		return "Crack blockers to clear the stage objective."
	if goal_collected >= goal_target:
		return "Goal complete. Make long matches for score."
	if score >= high_score:
		return "Score complete. Hunt the goal color."
	return _stage_mission_line()


func _stage_complete() -> bool:
	return score >= high_score and _objectives_complete()


func _objectives_complete() -> bool:
	if goal_collected < goal_target:
		return false
	if blocker_target > 0 and blocker_cleared < blocker_target:
		return false
	return true


func _stage_blocker_target() -> int:
	if stage < 4:
		return 0
	return min(6 + (stage - 4) * 2, 14)


func _stage_brief_line() -> String:
	var text := "Collect %d goal fuzzies  Score %d" % [goal_target, high_score]
	if blocker_target > 0:
		text += "\nClear %d blockers" % blocker_target
	return text


func _pause_goal_line() -> String:
	if blocker_target > 0:
		return "Goals: fuzzies, blockers, score"
	return "Goals: fuzzies and score"


func _stage_rule_line() -> String:
	var blocker_rate := _stage_blocker_rate()
	if blocker_rate <= 0.0:
		return "Rotate rows and columns to make 3+ connected groups"
	if blocker_target > 0:
		return "Blocker mission: cracked blockers count when destroyed"
	return "Blockers %.0f%%: crack them beside matches" % (blocker_rate * 100.0)


func _stage_mission_line() -> String:
	if blocker_target > 0:
		return "Collect %d goal fuzzies. Clear %d blockers." % [goal_target, blocker_target]
	if stage >= 2:
		return "Rotate rows/columns. Crack wood crates beside matches."
	return "Rotate rows/columns to connect 3+ goal fuzzies."


func _stage_blocker_rate() -> float:
	if stage < 2:
		return 0.0
	return min(0.018 + stage * 0.003, 0.045)


func _failure_reason() -> String:
	var missing: Array[String] = []
	if goal_collected < goal_target:
		missing.append("Need %d more goal" % (goal_target - goal_collected))
	if blocker_target > 0 and blocker_cleared < blocker_target:
		missing.append("Need %d blockers" % (blocker_target - blocker_cleared))
	if score < high_score:
		missing.append("Need %d more score" % (high_score - score))
	if missing.is_empty():
		return "One more match would have done it"
	return " / ".join(missing)


func _hud_goal_text() -> String:
	if blocker_target > 0:
		return "GOAL\n%d/%d  CRATE %d/%d" % [goal_collected, goal_target, blocker_cleared, blocker_target]
	return "GOAL\n%d/%d" % [goal_collected, goal_target]


func _objective_progress_value() -> int:
	return goal_collected + blocker_cleared


func _objective_progress_target() -> int:
	return goal_target + blocker_target


func _objective_progress_text() -> String:
	if blocker_target > 0:
		return "%d/%d + Crate %d/%d" % [goal_collected, goal_target, blocker_cleared, blocker_target]
	return "%d/%d" % [goal_collected, goal_target]


func _update_hud() -> void:
	score_label.text = "%d/%d" % [score, high_score]
	var score_percent: float = clamp(float(score) / max(1.0, float(high_score)), 0.0, 1.0)
	moves_label.text = "MOVES\n%02d" % moves
	goal_label.text = _hud_goal_text()
	combo_label.text = "COMBO x%d" % max(1, combo)
	level_label.text = "STAGE %d" % stage
	if is_instance_valid(best_label):
		best_label.text = "BEST %d" % best_score
	target_bar.value = min(score, high_score)
	if is_instance_valid(score_progress_label):
		score_progress_label.text = "%d%%" % int(round(score_percent * 100.0))
		score_progress_label.add_theme_color_override("font_color", Color("#b8fff2") if score >= high_score else Color("#ffe9d2"))
	if is_instance_valid(goal_bar):
		goal_bar.max_value = _objective_progress_target()
		goal_bar.tint_progress = COLORS[goal_color]
		goal_bar.value = _objective_progress_value()
	if is_instance_valid(goal_progress_value_label):
		goal_progress_value_label.text = _objective_progress_text()
		goal_progress_value_label.add_theme_color_override("font_color", Color("#b8fff2") if _objectives_complete() else Color("#fff4ad"))
	fever_bar.value = fever
	if is_instance_valid(fever_value_label):
		fever_value_label.text = "%d%%" % int(round(fever))
		fever_value_label.add_theme_color_override("font_color", Color("#fff36d") if fever >= 80.0 else Color("#ffb6c7"))
	if is_instance_valid(shuffle_button):
		shuffle_button.text = "REMIX %d" % shuffle_charges
		shuffle_button.disabled = shuffle_charges <= 0
		_style_powerup_button(shuffle_button, _powerup_accent(POWERUP_SHUFFLE), false, shuffle_button.disabled)
	if is_instance_valid(blast_button):
		blast_button.text = ("AIM NOW" if armed_powerup == POWERUP_BLAST else "BLAST %d" % blast_charges)
		blast_button.disabled = blast_charges <= 0
		_style_powerup_button(blast_button, _powerup_accent(POWERUP_BLAST), armed_powerup == POWERUP_BLAST, blast_button.disabled)
	if is_instance_valid(paint_button):
		paint_button.text = ("PICK ONE" if armed_powerup == POWERUP_PAINT else "PAINT %d" % paint_charges)
		paint_button.disabled = paint_charges <= 0
		_style_powerup_button(paint_button, _powerup_accent(POWERUP_PAINT), armed_powerup == POWERUP_PAINT, paint_button.disabled)
	if not busy and not ended and is_instance_valid(mission_label):
		mission_label.text = _current_objective_nudge()
	if is_instance_valid(backdrop):
		backdrop.queue_redraw()


func _flash_status(text: String) -> void:
	status_label.text = text
	if is_instance_valid(mission_label):
		mission_label.text = _current_objective_nudge()
	var tween := create_tween()
	status_label.modulate = Color("#ffffff")
	tween.tween_property(status_label, "modulate", Color("#d8fff9"), 0.28)


func _play_sfx(kind: String) -> void:
	if not is_instance_valid(sfx_player):
		return
	var frequency := 440.0
	var duration := 0.08
	var volume := 0.18
	match kind:
		"pop":
			frequency = 620.0
			duration = 0.07
		"mega":
			frequency = 260.0
			duration = 0.18
			volume = 0.24
		"bad":
			frequency = 160.0
			duration = 0.10
		"power":
			frequency = 820.0
			duration = 0.12
		"win":
			frequency = 920.0
			duration = 0.26
			volume = 0.26
		"fail":
			frequency = 120.0
			duration = 0.22
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = duration + 0.05
	sfx_player.stream = stream
	sfx_player.volume_db = linear_to_db(volume)
	sfx_player.play()
	var playback := sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames: int = int(stream.mix_rate * duration)
	for i in frames:
		var t: float = float(i) / stream.mix_rate
		var envelope: float = 1.0 - float(i) / max(1, frames)
		var wave: float = sin(TAU * frequency * t) * envelope
		if kind == "mega" or kind == "win":
			wave += sin(TAU * frequency * 1.5 * t) * envelope * 0.35
		playback.push_frame(Vector2(wave, wave))


func _pulse_tile(cell: Vector2i) -> void:
	var node := _tile_node(cell)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)


func _board_bump() -> void:
	if is_instance_valid(board_bump_tween):
		board_bump_tween.kill()
	board_layer.position = board_origin
	board_bump_tween = create_tween()
	board_bump_tween.tween_property(board_layer, "position", board_origin + Vector2(4, 0), 0.035)
	board_bump_tween.tween_property(board_layer, "position", board_origin - Vector2(4, 0), 0.045)
	board_bump_tween.tween_property(board_layer, "position", board_origin, 0.045)


func _trigger_fever_reward() -> void:
	fever = 0.0
	if rng.randf() < 0.55:
		blast_charges += 1
		_flash_status("FEVER! BLAST +1")
		_spawn_milestone_text(Vector2(224, 796), "FEVER BLAST +1", Color("#ff7a9e"), 26)
	else:
		paint_charges += 1
		_flash_status("FEVER! PAINT +1")
		_spawn_milestone_text(Vector2(224, 796), "FEVER PAINT +1", Color("#68f3ff"), 26)
	_play_sfx("power")
	_board_bump()
	_pulse_fever_console()
	_update_hud()


func _pulse_fever_console() -> void:
	if not is_instance_valid(fever_bar):
		return
	var tween := create_tween()
	fever_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_property(fever_bar, "modulate", Color(1.0, 0.55, 0.72, 1.0), 0.08)
	tween.tween_property(fever_bar, "modulate", Color.WHITE, 0.16)


func _maybe_goal_assist() -> void:
	if assist_given:
		return
	if moves > 12:
		return
	var progress: float = float(goal_collected) / max(1.0, float(goal_target))
	if progress >= 0.45:
		return
	assist_given = true
	paint_charges += 1
	_flash_status("Goal Assist! PAINT +1")
	_play_sfx("power")
	_update_hud()


func _check_milestones(score_before: int, goal_before: int, blocker_before: int, fever_before: float) -> void:
	if not goal_milestone_shown and goal_before < goal_target and goal_collected >= goal_target:
		goal_milestone_shown = true
		_spawn_milestone_text(Vector2(224, 652), "GOAL COMPLETE", Color("#b8fff2"), 30)
		_flash_status("Goal complete! Build score now.")
		_board_bump()
	if blocker_target > 0 and not blocker_milestone_shown and blocker_before < blocker_target and blocker_cleared >= blocker_target:
		blocker_milestone_shown = true
		_spawn_milestone_text(Vector2(224, 652), "BLOCKERS CLEAR", Color("#ffb6f2"), 28)
		_flash_status("Blocker objective complete!")
		_board_bump()
	if not score_milestone_shown and score_before < high_score and score >= high_score:
		score_milestone_shown = true
		_spawn_milestone_text(Vector2(224, 120), "SCORE READY", Color("#fff36d"), 28)
		_flash_status("Score ready! Finish the goal color.")
	if not fever_warning_shown and fever_before < 80.0 and fever >= 80.0 and fever < MAX_FEVER:
		fever_warning_shown = true
		_spawn_milestone_text(Vector2(224, 796), "FEVER HOT", Color("#ff7a9e"), 26)


func _spawn_milestone_text(pos: Vector2, text: String, color: Color, font_size: int = 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos - Vector2(130, 24)
	label.size = Vector2(260, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("#130719"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	content_root.add_child(label)
	var tween := create_tween()
	label.scale = Vector2(0.82, 0.82)
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 34, 0.42)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.42)
	tween.finished.connect(label.queue_free)


func _spawn_score_text(pos: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = board_origin + pos - Vector2(54, 20)
	label.size = Vector2(108, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("#fff36d"))
	label.add_theme_color_override("font_shadow_color", Color("#26172e"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	content_root.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.52)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.52)
	tween.finished.connect(label.queue_free)


func _spawn_pop(cell: Vector2i, color_index: int) -> void:
	var center: Vector2 = _tile_position(cell.x, cell.y)
	for i in 14:
		var dot := ColorRect.new()
		dot.color = COLORS[color_index].lightened(0.38) if i % 3 != 0 else Color("#fff7bd")
		var particle_size := rng.randf_range(4.0, 8.0)
		dot.size = Vector2(particle_size, particle_size)
		dot.position = board_origin + center + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		content_root.add_child(dot)
		var tween := create_tween()
		tween.tween_property(dot, "position", dot.position + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(28, 76), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(dot, "scale", Vector2(0.1, 0.1), 0.34)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.34)
		tween.finished.connect(dot.queue_free)


func _spawn_crate_splinters(cell: Vector2i) -> void:
	var center: Vector2 = board_origin + _tile_position(cell.x, cell.y)
	for i in 10:
		var shard := ColorRect.new()
		shard.color = Color("#b97942") if i % 2 == 0 else Color("#f0b36f")
		shard.size = Vector2(rng.randf_range(4.0, 9.0), rng.randf_range(2.0, 5.0))
		shard.position = center + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		shard.rotation = rng.randf_range(-0.6, 0.6)
		content_root.add_child(shard)
		var tween := create_tween()
		tween.tween_property(shard, "position", shard.position + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(18, 48), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shard, "rotation", shard.rotation + rng.randf_range(-2.8, 2.8), 0.30)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.30)
		tween.finished.connect(shard.queue_free)


func _spawn_goal_collection_trails(cells: Array[Vector2i]) -> void:
	var cap: int = min(cells.size(), 8)
	var target := Vector2(318, 128)
	for i in cap:
		var cell: Vector2i = cells[i]
		var start: Vector2 = board_origin + _tile_position(cell.x, cell.y)
		var dot := ColorRect.new()
		dot.color = COLORS[goal_color].lightened(0.28)
		dot.size = Vector2(10, 10)
		dot.position = start - dot.size * 0.5
		content_root.add_child(dot)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_interval(i * 0.025)
		tween.tween_property(dot, "position", target - dot.size * 0.5 + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9)), 0.34).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(dot, "scale", Vector2(0.45, 0.45), 0.34)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.34)
		tween.finished.connect(dot.queue_free)
	if cells.size() > 0 and is_instance_valid(goal_label):
		var pulse := create_tween()
		pulse.tween_property(goal_label, "scale", Vector2(1.08, 1.08), 0.10)
		pulse.tween_property(goal_label, "scale", Vector2.ONE, 0.16)


func _center_of_cells(cells: Array[Vector2i]) -> Vector2:
	var sum := Vector2.ZERO
	for cell in cells:
		sum += _tile_position(cell.x, cell.y)
	return sum / max(1, cells.size())


func _nearest_cell_to_center(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i(BOARD_COLS / 2, BOARD_ROWS / 2)
	var center := Vector2.ZERO
	for cell in cells:
		center += Vector2(cell.x, cell.y)
	center /= cells.size()
	var best := cells[0]
	var best_dist := INF
	for cell in cells:
		var dist := Vector2(cell.x, cell.y).distance_squared_to(center)
		if dist < best_dist:
			best = cell
			best_dist = dist
	return best


func _cell_from_position(pos: Vector2) -> Vector2i:
	var design_pos: Vector2 = (pos - content_offset) / content_scale
	var local: Vector2 = design_pos - board_origin - Vector2(BOARD_PADDING, BOARD_PADDING)
	var step: float = TILE_SIZE + TILE_GAP
	var col: int = int(floor(local.x / step))
	var row: int = int(floor(local.y / step))
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var within_x := fmod(local.x, step) <= TILE_SIZE
	var within_y := fmod(local.y, step) <= TILE_SIZE
	if not within_x or not within_y:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _screen_position_for_cell(cell: Vector2i) -> Vector2:
	return content_offset + (board_origin + _tile_position(cell.x, cell.y)) * content_scale


func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_COLS and cell.y >= 0 and cell.y < BOARD_ROWS and not _tile(cell).is_empty()


func _tile_position(col: int, row: int) -> Vector2:
	return Vector2(
		BOARD_PADDING + col * (TILE_SIZE + TILE_GAP) + TILE_SIZE * 0.5,
		BOARD_PADDING + row * (TILE_SIZE + TILE_GAP) + TILE_SIZE * 0.5
	)


func _clear_tiles() -> void:
	for line in tile_nodes:
		for node in line:
			if is_instance_valid(node):
				node.queue_free()
	tile_nodes.clear()


func _tile(cell: Vector2i) -> Dictionary:
	return board[cell.y][cell.x] as Dictionary


func _tile_node(cell: Vector2i) -> Node2D:
	return tile_nodes[cell.y][cell.x] as Node2D


func _create_textures() -> void:
	textures.clear()
	for color in COLORS:
		textures.append(_make_fuzzy_texture(color))
	badge_textures[TileKind.BOMB] = _make_badge_texture(Color("#ff5b35"))
	badge_textures[TileKind.ROW_CLEAR] = _make_badge_texture(Color("#42e8ff"))
	badge_textures[TileKind.COLUMN_CLEAR] = _make_badge_texture(Color("#42e8ff"))
	badge_textures[TileKind.RAINBOW] = _make_badge_texture(Color("#ffe456"))
	badge_textures[TileKind.BLOCKER] = _make_badge_texture(Color("#6f6a7a"))
	blocker_textures["full"] = _load_png_texture(BLOCKER_CRATE_FULL_PATH)
	blocker_textures["damaged"] = _load_png_texture(BLOCKER_CRATE_DAMAGED_PATH)


func _make_fuzzy_texture(base: Color) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var p := Vector2(x - 32, y - 32)
			var dist := p.length()
			var angle_noise := sin(p.angle() * 12.0 + dist * 0.33) * 2.5
			var radius := 27.0 + angle_noise + rng.randf_range(-1.2, 1.2)
			if dist > radius:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var shade: float = clamp(1.0 - dist / 38.0, 0.35, 1.0)
			var c := base.lerp(Color.WHITE, 0.16 + shade * 0.16)
			if dist > radius - 2.2:
				c = base.darkened(0.45)
			elif dist < 14.0:
				c = c.lightened(0.13)
			if rng.randf() < 0.12:
				c = c.darkened(rng.randf_range(0.08, 0.22))
			image.set_pixel(x, y, c)
	_draw_disc(image, Vector2(23, 22), 8, Color(1, 1, 1, 0.18))
	for eye_x in [23, 41]:
		_draw_disc(image, Vector2(eye_x, 29), 7, Color.WHITE)
		_draw_disc(image, Vector2(eye_x + 1, 31), 3, Color("#191124"))
		_draw_disc(image, Vector2(eye_x + 2, 29), 1, Color.WHITE)
	_draw_arc_mouth(image, base.darkened(0.55))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	return texture


func _make_badge_texture(base: Color) -> Texture2D:
	var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var p := Vector2(x - 14, y - 14)
			var dist := p.length()
			if dist > 12.5:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := base
			if dist > 10.5:
				c = Color("#ffffff")
			elif dist < 6.0:
				c = base.lightened(0.22)
			else:
				c = base.darkened(0.15)
			image.set_pixel(x, y, c)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _draw_disc(image: Image, center: Vector2, radius: int, color: Color) -> void:
	for y in range(int(center.y) - radius, int(center.y) + radius + 1):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)


func _draw_arc_mouth(image: Image, color: Color) -> void:
	for i in 17:
		var t := float(i) / 16.0
		var x: float = lerp(24.0, 40.0, t)
		var y: float = 43.0 + sin(t * PI) * 4.0
		_draw_disc(image, Vector2(x, y), 1, color)


func _draw_backdrop(backdrop: Control) -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(448, 960))
	backdrop.draw_rect(rect, Color(0.02, 0.015, 0.035, 0.46))
	backdrop.draw_rect(Rect2(Vector2(10, 40), Vector2(428, 132)), Color(0.03, 0.02, 0.07, 0.92))
	backdrop.draw_rect(Rect2(Vector2(12, 42), Vector2(424, 128)), Color("#251339"), false, 3.0)
	backdrop.draw_rect(Rect2(Vector2(16, 98), Vector2(88, 62)), Color(0.17, 0.09, 0.27, 0.92))
	backdrop.draw_rect(Rect2(Vector2(300, 98), Vector2(132, 62)), Color(0.17, 0.09, 0.27, 0.92))
	var goal_center := Vector2(318, 128)
	backdrop.draw_circle(goal_center, 13, COLORS[goal_color])
	backdrop.draw_circle(goal_center, 13, Color.WHITE, false, 2.0)
	var board_rect := Rect2(board_origin - Vector2(9, 9), board_size + Vector2(18, 18))
	backdrop.draw_rect(board_rect, Color("#ffda36"))
	backdrop.draw_rect(board_rect.grow(-4), Color("#fb5228"))
	backdrop.draw_rect(board_rect.grow(-9), Color("#27dce5"))
	backdrop.draw_rect(board_rect.grow(-14), Color("#07101e"))
	backdrop.draw_rect(board_rect, Color("#ffffff"), false, 2.0)
	backdrop.draw_rect(Rect2(Vector2(16, 702), Vector2(416, 188)), Color(0.03, 0.02, 0.07, 0.95))
	backdrop.draw_rect(Rect2(Vector2(22, 708), Vector2(404, 176)), Color("#241334"), false, 2.0)
	backdrop.draw_rect(Rect2(Vector2(34, 714), Vector2(380, 24)), Color("#150c22"))
	backdrop.draw_rect(Rect2(Vector2(34, 738), Vector2(380, 1)), Color("#4c2a68"))
	backdrop.draw_rect(Rect2(Vector2(72, 752), Vector2(328, 14)), Color("#090612"))
	backdrop.draw_rect(Rect2(Vector2(72, 752), Vector2(328, 14)), Color("#6f5f88"), false, 1.5)
	backdrop.draw_rect(Rect2(Vector2(72, 780), Vector2(328, 22)), Color("#090612"))
	backdrop.draw_rect(Rect2(Vector2(72, 780), Vector2(328, 22)), Color("#80586e"), false, 1.5)
	for i in 3:
		var slot := Rect2(Vector2(38 + i * 132, 817), Vector2(122, 44))
		backdrop.draw_rect(slot, Color("#150c22"))


func _draw_prize_orb(holder: Control) -> void:
	var center := Vector2(48, 45)
	holder.draw_circle(center + Vector2(0, 6), 36, Color("#5c3b25"))
	holder.draw_circle(center, 35, Color("#ffc936"))
	holder.draw_circle(center + Vector2(-9, -9), 17, Color("#fff39a"))
	holder.draw_arc(center, 20, 0.15 * PI, 0.85 * PI, 24, Color("#7e5517"), 5.0)
