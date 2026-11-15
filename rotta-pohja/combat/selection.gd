class_name Selection
extends Node

# What the player is choosing with the keyboard: an ability, the cells it is used on, and
# the cursor that picks them.

signal changed

const CURSOR_STEPS: Dictionary[String, Vector2i] = {
	"combat_up": Vector2i.UP,
	"combat_down": Vector2i.DOWN,
	"combat_left": Vector2i.LEFT,
	"combat_right": Vector2i.RIGHT,
}

@onready var arena: Arena = get_parent()
@onready var grid: HexGrid = $"../Grid"

var ability: Ability
# The cells picked so far for the chosen ability.
var picks: Array[Vector2i] = []
# The cursor: a point on a square lattice, Vector2i(column, half_row). Hex centers lie on
# every second point; the points between are seams, where no cell is selected.
var point: Vector2i


func _ready() -> void:
	arena.ready.connect(start)
	arena.turn_ended.connect(select.bind(0))


func start() -> void:
	point = cell_to_point(arena.player.cell)
	select(0)


# ---- Input ----

func _unhandled_input(event: InputEvent) -> void:
	if arena.finished:
		return
	for action in CURSOR_STEPS:
		if event.is_action_pressed(action):
			move(CURSOR_STEPS[action])
	for index in arena.player.abilities.size():
		if event.is_action_pressed("combat_ability_%d" % (index + 1)):
			select(index)
	if event.is_action_pressed("ui_accept") and not is_seam(point) and point_to_cell(point) in action_cells():
		pick(point_to_cell(point))


# ---- Ability and picks ----

# Choosing an ability again starts its picks over; one that is cooling down can't be chosen.
func select(index: int) -> void:
	if arena.player.abilities[index].turns_until_ready == 0:
		ability = arena.player.abilities[index]
		picks.clear()
		update()


# Picking a desk starts the desk throw with it, whatever ability was chosen.
func pick(cell: Vector2i) -> void:
	if picks.is_empty() and arena.is_throwable(cell):
		ability = arena.player.desk_throw
	picks.append(cell)
	if picks.size() < ability.reaches.size():
		update()
	else:
		var picked := picks.duplicate()
		picks.clear()
		arena.take_turn(ability, picked)


# A cursor left outside the next pick's reach returns to the player.
func update() -> void:
	if not is_point_allowed(point):
		point = cell_to_point(arena.player.cell)
	changed.emit()


# How far from the player the next pick of the chosen ability may be; the cursor stays within it.
func reach() -> int:
	return ability.reaches[picks.size()]


# How near the player it may be. The cursor may still rest nearer.
func min_reach() -> int:
	return ability.min_reaches[picks.size()]


# The cells the next pick reaches: in range and in sight of the player, and on a straight
# line from the player if the ability goes straight.
func range_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in grid.cells:
		var distance := grid.distance(arena.player.cell, cell)
		var on_line := not ability.straight or grid.is_straight(arena.player.cell, cell)
		if distance >= min_reach() and distance <= reach() and on_line and arena.has_line_of_sight(arena.player.cell, cell):
			result.append(cell)
	return result


# The cells the player can pick next for the chosen ability.
func action_cells() -> Array[Vector2i]:
	return range_cells().filter(func(cell): return ability.can_pick.call(picks, cell))


# ---- Cursor ----

# One step. When that point isn't allowed, the cursor goes on to the point beside it,
# if exactly one of the two is allowed: the diagonal cell.
func move(step: Vector2i) -> void:
	var next := point + step
	if not is_point_allowed(next):
		var side := Vector2i(step.y, step.x)
		if is_point_allowed(next + side) == is_point_allowed(next - side):
			return
		next += side if is_point_allowed(next + side) else -side
	point = next
	changed.emit()


# A seam is allowed when the cells above and below it both are.
func is_point_allowed(lattice_point: Vector2i) -> bool:
	if is_seam(lattice_point):
		return is_cell_allowed(point_to_cell(lattice_point + Vector2i.UP)) and is_cell_allowed(point_to_cell(lattice_point + Vector2i.DOWN))
	return is_cell_allowed(point_to_cell(lattice_point))


func is_cell_allowed(cell: Vector2i) -> bool:
	return grid.has(cell) and grid.distance(arena.player.cell, cell) <= reach()


# ---- The lattice ----

func cell_to_point(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x, 2 * cell.y + (cell.x & 1))


# Only for points that are not seams.
func point_to_cell(lattice_point: Vector2i) -> Vector2i:
	return Vector2i(lattice_point.x, (lattice_point.y - (lattice_point.x & 1)) / 2)


func is_seam(lattice_point: Vector2i) -> bool:
	return (lattice_point.x + lattice_point.y) & 1 == 1


func point_position(lattice_point: Vector2i) -> Vector2:
	var origin := grid.map_to_local(Vector2i.ZERO)
	return Vector2(grid.map_to_local(Vector2i(lattice_point.x, 0)).x, origin.y + lattice_point.y * grid.tile_set.tile_size.y / 2.0)
