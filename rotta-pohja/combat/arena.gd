extends Node2D

# Cells are Vector2i(column, row) on the TileMapLayer's flat-top hex grid.

signal combat_finished(won: bool)


class Rival:
	var cell: Vector2i
	var position: Vector2
	var turns_until_dash := DASH_EVERY
	var motivation := START_MOTIVATION
	# How many of its next turns it skips.
	var stunned_turns := 0
	# The TileSet.CellNeighbor its next dash goes; set when the dash warning starts. NO_SIDE before.
	var dash_side := NO_SIDE

	func _init(start_cell: Vector2i) -> void:
		cell = start_cell


# Something the player can do on a turn, chosen with a number key.
class Ability:
	var title: String
	# Turns to wait after using it.
	var cooldown: int
	var turns_until_ready := 0
	# One entry per cell the player picks, in order: how far from the player it may be, and
	# what the player is asked for.
	var reaches: Array[int]
	var prompts: Array[String]
	# (picked: Array[Vector2i], cell: Vector2i) -> bool: may `cell` be the next pick?
	var can_pick: Callable
	# (picked: Array[Vector2i]): does it, once every cell is picked.
	var use: Callable

	func _init(a_title: String, a_cooldown: int, a_reaches: Array[int], a_prompts: Array[String], a_can_pick: Callable, a_use: Callable) -> void:
		title = a_title
		cooldown = a_cooldown
		reaches = a_reaches
		prompts = a_prompts
		can_pick = a_can_pick
		use = a_use


const COLUMNS := 9
const ROWS := 7

const FLOOR_COLOR := Color(0.2, 0.22, 0.26)
const LINE_COLOR := Color(0.45, 0.48, 0.55)
const ACTION_COLOR := Color(0.3, 0.5, 0.35)
const RANGE_COLOR := Color(0.23, 0.33, 0.28)
const DESK_COLOR := Color(0.42, 0.3, 0.2)
const PILLAR_COLOR := Color(0.1, 0.1, 0.11)
const PAPER_COLOR := Color(0.95, 0.95, 0.9)
const PLAYER_COLOR := Color(0.9, 0.85, 0.6)
const RIVAL_COLOR := Color(0.85, 0.3, 0.3)
const STUNNED_COLOR := Color(0.5, 0.5, 0.55)
const GOAL_COLOR := Color(0.35, 0.6, 0.95)
const DASH_WARNING_COLOR := Color(1.0, 0.85, 0.2)
const DANGER_COLOR := Color(0.45, 0.1, 0.1)
const SELECTION_COLOR := Color.WHITE

const STEP_TIME := 0.2
# On every third turn a rival dashes: up to DASH_LENGTH cells in a straight line.
const DASH_EVERY := 3
const DASH_LENGTH := 2
# Turns a shoved rival skips: after hitting a desk or the arena's edge, and otherwise.
const WALL_STUN := 2
const SHOVE_STUN := 1
const PAPER_RANGE := 3
const DESK_THROW_RANGE := 2
const THROW_COOLDOWN := 3
const NO_SIDE := -1
const START_MOTIVATION := 3
const NO_CELL := Vector2i(-1, -1)
const SIDES: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
]

const CURSOR_STEPS: Dictionary[String, Vector2i] = {
	"combat_up": Vector2i.UP,
	"combat_down": Vector2i.DOWN,
	"combat_left": Vector2i.LEFT,
	"combat_right": Vector2i.RIGHT,
}

# A stage is a scene that inherits arena.tscn and sets these.
@export var player_start := Vector2i(0, 3)
@export var rival_starts: Array[Vector2i] = []
# Desks and pillars block movement. Desks can be thrown; pillars also block throws.
@export var desk_cells: Array[Vector2i] = []
@export var pillar_cells: Array[Vector2i] = []
# Objective "reach a place": the player wins on this cell. NO_CELL if the stage has none.
@export var goal_cell := NO_CELL
@export var goal_name := ""
# Objective "queue number": the player wins after this many turns. -1 if the stage has none.
@export var queue_turns := -1

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var status_label: Label = $StatusLabel
@onready var ability_label: Label = $AbilityLabel

var cells: Dictionary[Vector2i, bool] = {}
var player_cell: Vector2i
var rivals: Array[Rival] = []
var turns_left: int
var finished := false
var won := false
var end_text := ""
var announced := false
# Where the player is drawn; like Rival.position it catches up with the cell during the animation.
var player_position: Vector2
var animation: Tween
var paths: AStar2D
# The keyboard cursor is a point on a square lattice, Vector2i(column, half_row). Hex centers
# lie on every second point; the points between are seams, where no cell is selected.
var cursor: Vector2i
var action_range := 1
var abilities: Array[Ability] = [
	Ability.new("Move / Shove", 0, [1], [""], can_move_or_shove, move_or_shove),
	Ability.new("Throw paperwork", THROW_COOLDOWN, [PAPER_RANGE], ["Pick a rival."], can_throw_paper, throw_paper),
	Ability.new("Throw desk", THROW_COOLDOWN, [1, DESK_THROW_RANGE], ["Pick a desk next to you.", "Pick where it lands."], can_throw_desk, throw_desk),
]
var ability := abilities[0]
var desk_throw := abilities[2]
# The cells picked so far for the chosen ability.
var picks: Array[Vector2i] = []
# A thrown thing, drawn while it flies.
var projectile_position: Vector2
var projectile_color: Color
var projectile_visible := false


func _ready() -> void:
	for column in COLUMNS:
		for row in ROWS:
			cells[Vector2i(column, row)] = true
	desk_cells = desk_cells.duplicate()
	player_cell = player_start
	cursor = cell_to_point(player_cell)
	for cell in rival_starts:
		rivals.append(Rival.new(cell))
	turns_left = queue_turns
	get_viewport().size_changed.connect(center_in_viewport)
	center_in_viewport()
	finish_animation()


func _process(_delta: float) -> void:
	if animation:
		queue_redraw()


func center_in_viewport() -> void:
	var first := tile_map.map_to_local(Vector2i.ZERO)
	var last := tile_map.map_to_local(Vector2i(COLUMNS - 1, ROWS - 1))
	position = get_viewport_rect().size / 2 - (first + last) / 2


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	for action in CURSOR_STEPS:
		if event.is_action_pressed(action):
			move_cursor(CURSOR_STEPS[action])
	for index in abilities.size():
		if event.is_action_pressed("combat_ability_%d" % (index + 1)):
			select_ability(index)
	if event.is_action_pressed("ui_accept") and not is_seam(cursor) and point_to_cell(cursor) in action_cells():
		pick(point_to_cell(cursor))


# Choosing an ability again starts its picks over; one that is cooling down can't be chosen.
func select_ability(index: int) -> void:
	if abilities[index].turns_until_ready == 0:
		ability = abilities[index]
		picks.clear()
		update_selection()


# Picking a desk starts the desk throw with it, whatever ability was chosen.
func pick(cell: Vector2i) -> void:
	if picks.is_empty() and cell in desk_cells:
		ability = desk_throw
	picks.append(cell)
	if picks.size() < ability.reaches.size():
		update_selection()
	else:
		var picked := picks.duplicate()
		picks.clear()
		take_turn(ability, picked)


# The cursor's range follows the next pick; a cursor left outside it returns to the player.
func update_selection() -> void:
	action_range = ability.reaches[picks.size()]
	if not is_point_allowed(cursor):
		cursor = cell_to_point(player_cell)
	update_labels()
	queue_redraw()


# The player uses the ability on the picked cells; then the rivals act.
# The turn is decided at once; the animation then shows its moves one after another.
# Acting again before it ends skips the rest of it.
func take_turn(used: Ability, picked: Array[Vector2i]) -> void:
	finish_animation()
	animation = create_tween()
	used.use.call(picked)
	if player_cell == goal_cell:
		end(true, "You reached the %s." % goal_name)
	elif rivals.is_empty() and not rival_starts.is_empty():
		end(true, "Every rival gave up.")
	else:
		take_rival_turns()
	if not finished and turns_left > 0:
		turns_left -= 1
		if turns_left == 0:
			end(true, "Your number was called.")
	for other in abilities:
		other.turns_until_ready = max(0, other.turns_until_ready - 1)
	used.turns_until_ready = used.cooldown
	select_ability(0)
	animation.tween_callback(finish_animation)


func can_move_or_shove(_picked: Array[Vector2i], cell: Vector2i) -> bool:
	return is_free(cell) or rival_at(cell) != null or (cell in desk_cells and desk_throw.turns_until_ready == 0)


func move_or_shove(picked: Array[Vector2i]) -> void:
	var rival := rival_at(picked[0])
	if rival:
		shove(rival)
	else:
		player_cell = picked[0]
		animation.tween_property(self, "player_position", tile_map.map_to_local(player_cell), STEP_TIME)


func can_throw_paper(_picked: Array[Vector2i], cell: Vector2i) -> bool:
	return rival_at(cell) != null


func throw_paper(picked: Array[Vector2i]) -> void:
	animate_projectile(player_cell, picked[0], PAPER_COLOR)
	demotivate(rival_at(picked[0]))


# First the desk, then where it lands. It can't land on a desk, a pillar, the goal or the player.
func can_throw_desk(picked: Array[Vector2i], cell: Vector2i) -> bool:
	if picked.is_empty():
		return cell in desk_cells
	return cell != player_cell and cell != goal_cell and not is_obstacle(cell)


# The desk moves to the cell. Landing on a rival, it breaks: the rival loses motivation and
# is stunned as if shoved into a desk.
func throw_desk(picked: Array[Vector2i]) -> void:
	animate_projectile(picked[0], picked[1], DESK_COLOR)
	desk_cells.erase(picked[0])
	var rival := rival_at(picked[1])
	if rival:
		rival.stunned_turns = WALL_STUN
		demotivate(rival)
	else:
		desk_cells.append(picked[1])


# A rival without motivation gives up and leaves.
func demotivate(rival: Rival) -> void:
	rival.motivation -= 1
	if rival.motivation <= 0:
		rivals.erase(rival)


func animate_projectile(from: Vector2i, to: Vector2i, color: Color) -> void:
	projectile_position = tile_map.map_to_local(from)
	projectile_color = color
	projectile_visible = true
	animation.tween_property(self, "projectile_position", tile_map.map_to_local(to), STEP_TIME)
	animation.tween_callback(func(): projectile_visible = false)


# Pillars block throws; desks and rivals don't. A line that runs along the border between
# two cells is blocked only when both are pillars.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var start := tile_map.map_to_local(from)
	var end := tile_map.map_to_local(to)
	var aside := (end - start).orthogonal().normalized()
	var steps := distance(from, to)
	for step in range(1, steps):
		var point := start.lerp(end, float(step) / steps)
		if tile_map.local_to_map(point + aside) in pillar_cells and tile_map.local_to_map(point - aside) in pillar_cells:
			return false
	return true


# Pushes the rival one cell straight away from the player and stuns it. If something is
# behind it, it stays and loses motivation; hitting a desk or the arena's edge stuns longer.
# A rival behind it loses motivation too: both slide back one cell if there is room,
# otherwise that rival is stunned as well.
func shove(rival: Rival) -> void:
	var side := side_between(player_cell, rival.cell) as TileSet.CellNeighbor
	var behind := tile_map.get_neighbor_cell(rival.cell, side)
	var other := rival_at(behind)
	rival.stunned_turns = SHOVE_STUN if is_free(behind) or other else WALL_STUN
	if is_free(behind):
		move_rival(rival, behind)
		return
	var bumped: Array[Rival] = [rival]
	if other:
		var far := tile_map.get_neighbor_cell(behind, side)
		if is_free(far):
			move_rival(other, far)
			move_rival(rival, behind)
			bumped.clear()
		else:
			other.stunned_turns = SHOVE_STUN if rival_at(far) else WALL_STUN
			bumped.append(other)
	var bump := (tile_map.map_to_local(behind) - tile_map.map_to_local(rival.cell)) * 0.3
	for hit in bumped:
		animation.tween_property(hit, "position", hit.position + bump, STEP_TIME / 2)
		animation.tween_property(hit, "position", hit.position, STEP_TIME / 2)
	for hit in [rival, other]:
		if hit:
			demotivate(hit)


# A stunned rival skips its turn. On every third turn it dashes along the line fixed when the
# warning started, and takes the form if the player is on the line or next to where it ends.
# Otherwise it takes the form if it is next to the player, or else steps along the shortest
# path to the player.
func take_rival_turns() -> void:
	paths = build_paths()
	for rival in rivals:
		if rival.stunned_turns > 0:
			rival.stunned_turns -= 1
			continue
		rival.turns_until_dash -= 1
		if rival.turns_until_dash == 0:
			rival.turns_until_dash = DASH_EVERY
			for cell in dash_cells(rival):
				if cell == player_cell:
					end(false, "A rival took your form.")
					return
				move_rival(rival, cell)
			rival.dash_side = NO_SIDE
			if distance(rival.cell, player_cell) == 1:
				end(false, "A rival took your form.")
				return
			continue
		if distance(rival.cell, player_cell) == 1:
			end(false, "A rival took your form.")
			return
		move_rival(rival, next_step(rival))
		if rival.turns_until_dash == 1:
			rival.dash_side = side_between(rival.cell, next_step(rival))


func move_rival(rival: Rival, cell: Vector2i) -> void:
	if cell != rival.cell:
		rival.cell = cell
		animation.tween_property(rival, "position", tile_map.map_to_local(cell), STEP_TIME)


# The cells the rival's dash would cross now: it stops before a desk, a rival or the edge.
# The player doesn't shorten it, so the preview stays whole while the player stands on it.
func dash_cells(rival: Rival) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cell := rival.cell
	while rival.dash_side != NO_SIDE and result.size() < DASH_LENGTH:
		cell = tile_map.get_neighbor_cell(cell, rival.dash_side as TileSet.CellNeighbor)
		if cell != player_cell and not is_free(cell):
			break
		result.append(cell)
	return result


# The cells where ending the turn loses the form: next to a rival that acts normally, and on
# the line and around the end of a rival that dashes. A stunned rival is harmless.
func danger_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for rival in rivals:
		if rival.stunned_turns > 0:
			continue
		if rival.turns_until_dash == 1:
			result.append_array(dash_cells(rival))
			result.append_array(dash_grab_cells(rival))
		else:
			result.append_array(neighbors(rival.cell))
	return result


# The cells next to where the rival's dash would end now, apart from the line itself.
func dash_grab_cells(rival: Rival) -> Array[Vector2i]:
	var line := dash_cells(rival)
	var last: Vector2i = rival.cell if line.is_empty() else line[-1]
	return neighbors(last).filter(func(cell): return cell not in line and cell != rival.cell and not is_obstacle(cell))


# The side of cell `from` that cell `to` lies on, or NO_SIDE if they are not neighbors.
func side_between(from: Vector2i, to: Vector2i) -> int:
	for side in SIDES:
		if tile_map.get_neighbor_cell(from, side) == to:
			return side
	return NO_SIDE


func cell_id(cell: Vector2i) -> int:
	return cell.x + cell.y * COLUMNS


func build_paths() -> AStar2D:
	var result := AStar2D.new()
	for cell in cells:
		if not is_obstacle(cell):
			result.add_point(cell_id(cell), tile_map.map_to_local(cell))
	for cell in cells:
		for neighbor in neighbors(cell):
			if result.has_point(cell_id(cell)) and result.has_point(cell_id(neighbor)):
				result.connect_points(cell_id(cell), cell_id(neighbor))
	return result


# The first cell on the rival's shortest path to the player around desks and other rivals;
# its own cell if there is no path.
func next_step(rival: Rival) -> Vector2i:
	for other in rivals:
		paths.set_point_disabled(cell_id(other.cell), other != rival)
	var path := paths.get_id_path(cell_id(rival.cell), cell_id(player_cell))
	for other in rivals:
		paths.set_point_disabled(cell_id(other.cell), false)
	return rival.cell if path.size() < 2 else Vector2i(path[1] % COLUMNS, path[1] / COLUMNS)


func end(player_won: bool, text: String) -> void:
	finished = true
	won = player_won
	end_text = text


func update_labels() -> void:
	status_label.text = end_text if announced else objective_text()
	var entries: Array[String] = []
	for index in abilities.size():
		var entry := "[%d] %s" % [index + 1, abilities[index].title]
		if abilities[index].turns_until_ready > 0:
			entry += " (%d)" % abilities[index].turns_until_ready
		entries.append("> " + entry if abilities[index] == ability else entry)
	ability_label.text = "   ".join(entries) + "\n" + ability.prompts[picks.size()]


func objective_text() -> String:
	var parts: Array[String] = []
	if cells.has(goal_cell):
		parts.append("Reach the %s." % goal_name)
	if turns_left > 0:
		parts.append("Your number is called in %d %s." % [turns_left, "turn" if turns_left == 1 else "turns"])
	return " ".join(parts)


# Puts everything where the turn left it and, once, announces the ending.
func finish_animation() -> void:
	if animation:
		animation.kill()
		animation = null
	player_position = tile_map.map_to_local(player_cell)
	for rival in rivals:
		rival.position = tile_map.map_to_local(rival.cell)
	projectile_visible = false
	var announce := finished and not announced
	announced = finished
	update_labels()
	queue_redraw()
	if announce:
		combat_finished.emit(won)


func rival_at(cell: Vector2i) -> Rival:
	for rival in rivals:
		if rival.cell == cell:
			return rival
	return null


func cell_to_point(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x, 2 * cell.y + (cell.x & 1))


# Only for points that are not seams.
func point_to_cell(point: Vector2i) -> Vector2i:
	return Vector2i(point.x, (point.y - (point.x & 1)) / 2)


func is_seam(point: Vector2i) -> bool:
	return (point.x + point.y) & 1 == 1


func point_position(point: Vector2i) -> Vector2:
	var origin := tile_map.map_to_local(Vector2i.ZERO)
	return Vector2(tile_map.map_to_local(Vector2i(point.x, 0)).x, origin.y + point.y * tile_map.tile_set.tile_size.y / 2.0)


# One step. When that point isn't allowed, the cursor goes on to the point beside it,
# if exactly one of the two is allowed: the diagonal cell.
func move_cursor(step: Vector2i) -> void:
	var point := cursor + step
	if not is_point_allowed(point):
		var side := Vector2i(step.y, step.x)
		if is_point_allowed(point + side) == is_point_allowed(point - side):
			return
		point += side if is_point_allowed(point + side) else -side
	cursor = point
	queue_redraw()


# A seam is allowed when the cells above and below it both are.
func is_point_allowed(point: Vector2i) -> bool:
	if is_seam(point):
		return is_cell_allowed(point_to_cell(point + Vector2i.UP)) and is_cell_allowed(point_to_cell(point + Vector2i.DOWN))
	return is_cell_allowed(point_to_cell(point))


func is_cell_allowed(cell: Vector2i) -> bool:
	return cells.has(cell) and distance(player_cell, cell) <= action_range


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	return tile_map.get_surrounding_cells(cell).filter(func(neighbor): return cells.has(neighbor))


func is_obstacle(cell: Vector2i) -> bool:
	return cell in desk_cells or cell in pillar_cells


# Inside the arena with no desk, pillar, rival or player on it.
func is_free(cell: Vector2i) -> bool:
	return cells.has(cell) and not is_obstacle(cell) and rival_at(cell) == null and cell != player_cell


# The cells the next pick of the chosen ability reaches: in range and in sight of the player.
func range_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if distance(player_cell, cell) <= ability.reaches[picks.size()] and has_line_of_sight(player_cell, cell):
			result.append(cell)
	return result


# The cells the player can pick next for the chosen ability.
func action_cells() -> Array[Vector2i]:
	return range_cells().filter(func(cell): return ability.can_pick.call(picks, cell))


# Number of hex steps between two cells; neighbors are 1 apart.
func distance(a: Vector2i, b: Vector2i) -> int:
	var columns := b.x - a.x
	var slanted_rows := (b.y - (b.x - (b.x & 1)) / 2) - (a.y - (a.x - (a.x & 1)) / 2)
	return (abs(columns) + abs(slanted_rows) + abs(columns + slanted_rows)) / 2


func _draw() -> void:
	var actions := action_cells()
	var in_range := range_cells()
	var danger := danger_cells()
	for cell in cells:
		var color := FLOOR_COLOR
		if cell in pillar_cells:
			color = PILLAR_COLOR
		elif cell in desk_cells:
			color = DESK_COLOR
		elif cell in danger:
			color = DANGER_COLOR
		# What the player can pick is green, the rest of the ability's range a darker green:
		# the whole cell on plain floor, a smaller hex inside a desk or a dangerous cell.
		var mark := color
		if cell in actions:
			mark = ACTION_COLOR
		elif cell in in_range and not is_obstacle(cell):
			mark = RANGE_COLOR
		draw_colored_polygon(hex_corners(cell), mark if color == FLOOR_COLOR else color)
		draw_polyline(hex_corners(cell), LINE_COLOR, 2.0)
		if color != FLOOR_COLOR and mark != color:
			draw_colored_polygon(hex_corners(cell, 0.6), mark)
	if cells.has(goal_cell):
		draw_polyline(hex_corners(goal_cell), GOAL_COLOR, 6.0)
	for rival in rivals:
		var line := dash_cells(rival)
		if not line.is_empty():
			draw_line(tile_map.map_to_local(rival.cell), tile_map.map_to_local(line[-1]), DASH_WARNING_COLOR, 6.0)
			draw_circle(tile_map.map_to_local(line[-1]), 9.0, DASH_WARNING_COLOR)
	for rival in rivals:
		draw_circle(rival.position, 20.0, STUNNED_COLOR if rival.stunned_turns > 0 else RIVAL_COLOR)
		# One Z for each turn the rival still skips.
		draw_string(ThemeDB.fallback_font, rival.position + Vector2(-20.0, 8.0), "Z".repeat(rival.stunned_turns), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, SELECTION_COLOR)
		for i in rival.motivation:
			draw_circle(rival.position + Vector2((i - (rival.motivation - 1) / 2.0) * 10.0, -28.0), 3.5, SELECTION_COLOR)
		if rival.turns_until_dash == 1:
			draw_arc(rival.position, 26.0, 0.0, TAU, 32, DASH_WARNING_COLOR, 4.0)
	draw_circle(player_position, 20.0, PLAYER_COLOR)
	for cell in picks:
		draw_polyline(hex_corners(cell, 0.8), SELECTION_COLOR, 3.0)
	if projectile_visible:
		draw_circle(projectile_position, 12.0, projectile_color)
	if is_seam(cursor):
		draw_circle(point_position(cursor), 6.0, SELECTION_COLOR)
	else:
		draw_polyline(hex_corners(point_to_cell(cursor)), SELECTION_COLOR, 5.0)


# Closed outline: the first corner is repeated at the end.
func hex_corners(cell: Vector2i, scale := 1.0) -> PackedVector2Array:
	var center := tile_map.map_to_local(cell)
	var half := Vector2(tile_map.tile_set.tile_size) / 2 * scale
	return [
		center + Vector2(-half.x, 0),
		center + Vector2(-half.x / 2, -half.y),
		center + Vector2(half.x / 2, -half.y),
		center + Vector2(half.x, 0),
		center + Vector2(half.x / 2, half.y),
		center + Vector2(-half.x / 2, half.y),
		center + Vector2(-half.x, 0),
	]
