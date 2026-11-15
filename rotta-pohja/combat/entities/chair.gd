class_name Chair
extends Entity

# An office chair: shoved, it rolls straight on and pushes the first enemy it meets ahead
# of it. An enemy pushed into something is stunned, and a chair that met an enemy is used up.
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
	var enemy: Enemy = null
	for rolled in REACH:
		var next := arena.grid.step(cell, side)
		if enemy == null:
			enemy = arena.enemy_at(next)
		if enemy:
			var behind := arena.grid.step(enemy.cell, side)
			if not arena.is_free(behind):
				arena.block(enemy, behind)
				enemy.stun(STUN)
				break
			arena.move(enemy, behind)
		if not arena.is_free(next):
			arena.block(self, next)
			break
		arena.move(self, next)
	if enemy:
		arena.remove(self)


func card() -> Card:
	return Card.new("Office chair", "Shove it and it rolls up to 10 cells in a straight line. The first rival it meets is pushed along, and stunned for 4 turns when it hits something. That uses the chair up.", color())


func color() -> Color:
	return Color(0.25, 0.6, 0.6)
