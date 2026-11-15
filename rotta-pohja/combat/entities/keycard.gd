class_name Keycard
extends Entity

# A key card: the goal stays locked until the player has picked it up by ending an action
# on its cell.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	locks_goal = true
	radius = 9.0


func take_turn() -> void:
	if arena.player.cell == cell:
		arena.remove(self)


func color() -> Color:
	return Color(0.95, 0.8, 0.25)
