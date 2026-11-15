class_name Intern
extends Rival

# An eager rival: it walks two cells a turn and gives up sooner.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	speed = 2
	motivation = 2
	radius = 16.0
	body_color = Color(0.95, 0.55, 0.2)
