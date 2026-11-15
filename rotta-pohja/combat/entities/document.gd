class_name Document
extends Key

# A paper the player has to collect; a stage has several. A stage's documents are named in
# the order it lists them.

const NAMES: Array[String] = ["application", "CV", "tax card"]


func _init(start_cell: Vector2i, number: int) -> void:
	super(start_cell)
	called = NAMES[number % NAMES.size()]
	body_color = Color(0.93, 0.93, 0.88)


func card() -> Card:
	return Card.new("Documents", "The goal stays locked until you have collected every document on the floor, in any order: end your action on a document's cell to pick it up.", color())
