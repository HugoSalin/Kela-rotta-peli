extends Node2D

# Cells are Vector2i(column, row) on the TileMapLayer's flat-top hex grid.

signal combat_finished(won: bool)


class Rival:
	var cell: Vector2i
	var position: Vector2

	func _init(start_cell: Vector2i) -> void:
		cell = start_cell


const COLUMNS := 9
const ROWS := 7

const FLOOR_COLOR := Color(0.2, 0.22, 0.26)
const LINE_COLOR := Color(0.45, 0.48, 0.55)
const REACHABLE_COLOR := Color(0.3, 0.5, 0.35)
const PLAYER_COLOR := Color(0.9, 0.85, 0.6)
const RIVAL_COLOR := Color(0.85, 0.3, 0.3)
const GOAL_COLOR := Color(0.35, 0.6, 0.95)
const SELECTION_COLOR := Color.WHITE

const STEP_TIME := 0.2
const NO_CELL := Vector2i(-1, -1)

const CURSOR_STEPS: Dictionary[String, Vector2i] = {
	"combat_up": Vector2i.UP,
	"combat_down": Vector2i.DOWN,
	"combat_left": Vector2i.LEFT,
	"combat_right": Vector2i.RIGHT,
}

# A stage is a scene that inherits arena.tscn and sets these.
@export var player_start := Vector2i(0, 3)
@export var rival_starts: Array[Vector2i] = []
# Objective "reach a place": the player wins on this cell. NO_CELL if the stage has none.
@export var goal_cell := NO_CELL
@export var goal_name := ""
# Objective "queue number": the player wins after this many turns. -1 if the stage has none.
@export var queue_turns := -1

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var status_label: Label = $StatusLabel

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
# The keyboard cursor is a point on a square lattice, Vector2i(column, half_row). Hex centers
# lie on every second point; the points between are seams, where no cell is selected.
var cursor: Vector2i
var action_range := 1


func _ready() -> void:
	for column in COLUMNS:
		for row in ROWS:
			cells[Vector2i(column, row)] = true
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
	if event.is_action_pressed("ui_accept") and not is_seam(cursor) and point_to_cell(cursor) in reachable_cells():
		take_turn(point_to_cell(cursor))


# The turn is decided at once; the animation then shows its moves one after another.
# Acting again before it ends skips the rest of it.
func take_turn(target: Vector2i) -> void:
	finish_animation()
	animation = create_tween()
	player_cell = target
	animation.tween_property(self, "player_position", tile_map.map_to_local(player_cell), STEP_TIME)
	if player_cell == goal_cell:
		end(true, "You reached the %s." % goal_name)
	else:
		take_rival_turns()
	if not finished and turns_left > 0:
		turns_left -= 1
		if turns_left == 0:
			end(true, "Your number was called.")
	animation.tween_callback(finish_animation)


# A rival next to the player grabs the form; otherwise it steps closer.
func take_rival_turns() -> void:
	for rival in rivals:
		if distance(rival.cell, player_cell) == 1:
			end(false, "A rival took your form.")
			return
		for cell in neighbors(rival.cell):
			if rival_at(cell) == null and distance(cell, player_cell) < distance(rival.cell, player_cell):
				rival.cell = cell
		animation.tween_property(rival, "position", tile_map.map_to_local(rival.cell), STEP_TIME)


func end(player_won: bool, text: String) -> void:
	finished = true
	won = player_won
	end_text = text


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
	status_label.text = end_text if finished else objective_text()
	queue_redraw()
	if finished and not announced:
		announced = true
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


func reachable_cells() -> Array[Vector2i]:
	return neighbors(player_cell).filter(func(cell): return rival_at(cell) == null)


# Number of hex steps between two cells; neighbors are 1 apart.
func distance(a: Vector2i, b: Vector2i) -> int:
	var columns := b.x - a.x
	var slanted_rows := (b.y - (b.x - (b.x & 1)) / 2) - (a.y - (a.x - (a.x & 1)) / 2)
	return (abs(columns) + abs(slanted_rows) + abs(columns + slanted_rows)) / 2


func _draw() -> void:
	var reachable := reachable_cells()
	for cell in cells:
		var corners := hex_corners(cell)
		draw_colored_polygon(corners, REACHABLE_COLOR if cell in reachable else FLOOR_COLOR)
		draw_polyline(corners, LINE_COLOR, 2.0)
	if cells.has(goal_cell):
		draw_polyline(hex_corners(goal_cell), GOAL_COLOR, 6.0)
	for rival in rivals:
		draw_circle(rival.position, 20.0, RIVAL_COLOR)
	draw_circle(player_position, 20.0, PLAYER_COLOR)
	if is_seam(cursor):
		draw_circle(point_position(cursor), 6.0, SELECTION_COLOR)
	else:
		draw_polyline(hex_corners(point_to_cell(cursor)), SELECTION_COLOR, 5.0)


# Closed outline: the first corner is repeated at the end.
func hex_corners(cell: Vector2i) -> PackedVector2Array:
	var center := tile_map.map_to_local(cell)
	var half := Vector2(tile_map.tile_set.tile_size) / 2
	return [
		center + Vector2(-half.x, 0),
		center + Vector2(-half.x / 2, -half.y),
		center + Vector2(half.x / 2, -half.y),
		center + Vector2(half.x, 0),
		center + Vector2(half.x / 2, half.y),
		center + Vector2(-half.x / 2, half.y),
		center + Vector2(-half.x, 0),
	]
