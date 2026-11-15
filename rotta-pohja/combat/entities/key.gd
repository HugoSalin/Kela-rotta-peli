class_name Key
extends Entity

# The goal stays locked until the player has picked up every key, each by ending an action
# on its cell.

# What the objective calls it.
var called := "key"
var body_color := Color.WHITE


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	locks_goal = true
	radius = 9.0


func take_turn() -> void:
	if arena.player.cell == cell:
		arena.remove(self)


func title() -> String:
	return called


func color() -> Color:
	return body_color
