class_name Chair
extends Entity

# An office chair: shoved, it rolls straight on until something stops it, and a rival it
# rolls into loses motivation. Otherwise it stands in the way like a desk.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	obstacle = true
	shovable = true
	radius = 14.0


func shove(side: int) -> void:
	var next := arena.grid.step(cell, side)
	if not arena.is_free(next):
		arena.block(self, next)
	while arena.is_free(next):
		arena.move(self, next)
		next = arena.grid.step(next, side)
	var rival := arena.rival_at(next)
	if rival:
		rival.demotivate()


func color() -> Color:
	return Color(0.25, 0.6, 0.6)
