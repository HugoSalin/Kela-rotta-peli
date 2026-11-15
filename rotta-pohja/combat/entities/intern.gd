class_name Intern
extends Rival

# An eager rival: it never walks but dashes every turn, and it gives up sooner.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	speed = 0
	dash_every = 1
	turns_until_dash = 1
	motivation = 2
	radius = 16.0
	body_color = Color(0.95, 0.55, 0.2)
