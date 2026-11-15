class_name Intern
extends Lunger

# An eager lunger that gives up sooner.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	health = 2
	radius = 16.0
	body_color = Color(0.95, 0.55, 0.2)


func card() -> Card:
	return Card.new("Intern", "Eager, but easily discouraged. It never walks: it dashes every turn along its yellow line, so stay off the red cells. It has only 2 motivation, and thrown paperwork calls off its next dash.", body_color)
