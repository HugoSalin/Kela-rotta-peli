extends Node2D

# Cells are Vector2i(column, row) on the TileMapLayer's flat-top hex grid.

const COLUMNS := 9
const ROWS := 7

const FLOOR_COLOR := Color(0.2, 0.22, 0.26)
const LINE_COLOR := Color(0.45, 0.48, 0.55)
const REACHABLE_COLOR := Color(0.3, 0.5, 0.35)
const PLAYER_COLOR := Color(0.9, 0.85, 0.6)
const SELECTION_COLOR := Color.WHITE

const CURSOR_STEPS: Dictionary[String, Vector2i] = {
	"combat_up": Vector2i.UP,
	"combat_down": Vector2i.DOWN,
	"combat_left": Vector2i.LEFT,
	"combat_right": Vector2i.RIGHT,
}

@onready var tile_map: TileMapLayer = $TileMapLayer

var cells: Dictionary[Vector2i, bool] = {}
var player_cell := Vector2i(4, 3)
# The keyboard cursor is a point on a square lattice, Vector2i(column, half_row). Hex centers
# lie on every second point; the points between are seams, where no cell is selected.
var cursor := cell_to_point(player_cell)
var action_range := 3


func _ready() -> void:
	for column in COLUMNS:
		for row in ROWS:
			cells[Vector2i(column, row)] = true
	get_viewport().size_changed.connect(center_in_viewport)
	center_in_viewport()


func center_in_viewport() -> void:
	var first := tile_map.map_to_local(Vector2i.ZERO)
	var last := tile_map.map_to_local(Vector2i(COLUMNS - 1, ROWS - 1))
	position = get_viewport_rect().size / 2 - (first + last) / 2


func _unhandled_input(event: InputEvent) -> void:
	for action in CURSOR_STEPS:
		if event.is_action_pressed(action):
			move_cursor(CURSOR_STEPS[action])
	if event.is_action_pressed("ui_accept") and not is_seam(cursor) and point_to_cell(cursor) in reachable_cells():
		player_cell = point_to_cell(cursor)
		queue_redraw()


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
	return neighbors(player_cell)


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
	draw_circle(tile_map.map_to_local(player_cell), 20.0, PLAYER_COLOR)
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
