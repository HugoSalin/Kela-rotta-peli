class_name WetFloor
extends Entity

# A wet cell: whoever moves onto it slides on in the same direction, as far as the wet
# floor reaches.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	slippery = true
	shape = Shape.MARK


func card() -> Card:
	return Card.new("Wet floor", "Whoever steps straight onto it slides on in the same direction, until the floor is dry or something is in the way. Rivals slide too.", color())


func color() -> Color:
	return Color(0.45, 0.75, 0.95)
