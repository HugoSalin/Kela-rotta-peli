class_name Chair
extends Entity

# An office chair: shoved, it rolls straight on and pushes the first rival it meets ahead
# of it. A rival pushed into something is stunned, and a chair that met a rival is used up.
# Otherwise it stands in the way like a desk.

# How many cells it rolls at most.
const REACH := 10
const STUN := 4


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	obstacle = true
	shovable = true
	radius = 14.0


func shove(side: int) -> void:
	var rival: Rival = null
	for rolled in REACH:
		var next := arena.grid.step(cell, side)
		if rival == null:
			rival = arena.rival_at(next)
		if rival:
			var behind := arena.grid.step(rival.cell, side)
			if not arena.is_free(behind):
				arena.block(rival, behind)
				rival.stun(STUN)
				break
			arena.move(rival, behind)
		if not arena.is_free(next):
			arena.block(self, next)
			break
		arena.move(self, next)
	if rival:
		arena.remove(self)


func color() -> Color:
	return Color(0.25, 0.6, 0.6)
