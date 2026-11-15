class_name Lunger
extends Enemy

# An enemy that never walks: it dashes every turn.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	speed = 0
	dash_every = 1
	turns_until_dash = 1
