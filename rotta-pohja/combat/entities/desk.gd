class_name Desk
extends Entity

# Blocks movement but not throws, and can be thrown.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	obstacle = true
	throwable = true
	shape = Shape.HEX


func color() -> Color:
	return Color(0.42, 0.3, 0.2)
