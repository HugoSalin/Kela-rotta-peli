class_name HexGrid
extends TileMapLayer

# The room's cells, which are the painted ones, and their geometry. A cell is
# Vector2i(column, row) on the flat-top hex grid; other code asks here instead of doing
# arithmetic on cells.

const NO_CELL := Vector2i(-1, -1)
const NO_SIDE := -1
const SIDES: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
]

# Each cell with its number: its place among the cells, by column and then row.
var cells: Dictionary[Vector2i, int] = {}


# ---- Cells ----

func _ready() -> void:
	var painted := get_used_cells()
	painted.sort()
	for cell in painted:
		cells[cell] = cells.size()


func has(cell: Vector2i) -> bool:
	return cells.has(cell)


func id_of(cell: Vector2i) -> int:
	return cells[cell]


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	return get_surrounding_cells(cell).filter(has)


# ---- Directions ----

# The cell next to `cell` on that side; it may lie outside the arena.
func step(cell: Vector2i, side: int) -> Vector2i:
	return get_neighbor_cell(cell, side as TileSet.CellNeighbor)


# The side of cell `from` that cell `to` lies on, or NO_SIDE if they are not neighbors.
func side_between(from: Vector2i, to: Vector2i) -> int:
	for side in SIDES:
		if get_neighbor_cell(from, side) == to:
			return side
	return NO_SIDE


# The side on which steps from `from` lead straight to `to`, or NO_SIDE if none does.
func straight_side(from: Vector2i, to: Vector2i) -> int:
	for side in SIDES:
		var cell := from
		for index in distance(from, to):
			cell = step(cell, side)
		if cell == to and cell != from:
			return side
	return NO_SIDE


# ---- Distances and lines ----

# Number of hex steps between two cells; neighbors are 1 apart.
func distance(a: Vector2i, b: Vector2i) -> int:
	var columns := b.x - a.x
	var slanted_rows := (b.y - (b.x - (b.x & 1)) / 2) - (a.y - (a.x - (a.x & 1)) / 2)
	return (abs(columns) + abs(slanted_rows) + abs(columns + slanted_rows)) / 2


# What a straight line between two cell centers crosses, one entry per hex step between
# them: a pair of cells, which differ where the line runs along the border between two.
func sight_line(from: Vector2i, to: Vector2i) -> Array[Array]:
	var start := map_to_local(from)
	var end := map_to_local(to)
	var aside := (end - start).orthogonal().normalized()
	var steps := distance(from, to)
	var result: Array[Array] = []
	for index in range(1, steps):
		var point := start.lerp(end, float(index) / steps)
		result.append([local_to_map(point + aside), local_to_map(point - aside)])
	return result
