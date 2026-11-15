class_name Goal
extends Entity

# The place the player has to reach: ending an action on it wins, unless something locks it.

const COLOR := Color(0.35, 0.6, 0.95)
const LOCKED_COLOR := Color(0.4, 0.42, 0.5)


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	is_goal = true
	shape = Shape.MARK


func color() -> Color:
	return LOCKED_COLOR if arena.is_goal_locked() else COLOR
