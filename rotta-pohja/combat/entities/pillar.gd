class_name Pillar
extends Entity

# Blocks movement and the line of sight of throws.


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	obstacle = true
	blocks_sight = true
	shape = Shape.HEX


func card() -> Card:
	return Card.new("Pillar", "Blocks the way and the line of sight of your throws. It can't be moved, and a rival's dash stops at it.", color())


func color() -> Color:
	return Color(0.15, 0.15, 0.17)
