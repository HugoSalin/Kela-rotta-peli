class_name Paperwork
extends Entity

# Thrown paperwork: on the board only while it flies.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	radius = 12.0


func color() -> Color:
	return Color(0.95, 0.95, 0.9)
