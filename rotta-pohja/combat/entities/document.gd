class_name Document
extends Keycard

# A paper the player has to collect: as with a key card, the goal stays locked until every
# one is picked up. A stage's documents are named in the order it lists them.

const NAMES: Array[String] = ["application", "CV", "tax card"]


func _init(start_cell: Vector2i, number: int) -> void:
	super(start_cell)
	called = NAMES[number % NAMES.size()]


func card() -> Card:
	return Card.new("Documents", "The goal stays locked until you have collected every document on the floor, in any order: end your action on a document's cell to pick it up.", color())


func color() -> Color:
	return Color(0.93, 0.93, 0.88)
