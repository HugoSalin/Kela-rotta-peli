class_name Keycard
extends Key

# A key that looks like a key card.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	called = "key card"
	body_color = Color(0.95, 0.8, 0.25)


func card() -> Card:
	return Card.new("Key card", "The goal stays locked until you pick this up: end your action on its cell.", color())
