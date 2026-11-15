class_name Desk
extends Entity

# Blocks movement but not throws, and can be thrown.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	obstacle = true
	throwable = true
	shape = Shape.HEX


func card() -> Card:
	return Card.new("Desk", "Blocks the way, but not your throws. With Throw desk you move a desk next to you to another cell next to you. Thrown onto a rival it breaks: the rival is stunned for 2 turns and loses 1 motivation.", color())


func color() -> Color:
	return Color(0.42, 0.3, 0.2)
