class_name Keycard
extends Entity

# A key card: the goal stays locked until the player has picked it up by ending an action
# on its cell.

var called := "key card"


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


func card() -> Card:
	return Card.new("Key card", "The goal stays locked until you pick this up: end your action on its cell.", color())


func color() -> Color:
	return Color(0.95, 0.8, 0.25)
