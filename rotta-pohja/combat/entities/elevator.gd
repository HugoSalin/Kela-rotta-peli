class_name Elevator
extends Entity

# Keeps bringing enemies: one steps out every few turns, when nothing stands on it.

const EVERY := 4

var turns_until_enemy := EVERY


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	shape = Shape.MARK


func take_turn() -> void:
	turns_until_enemy = max(0, turns_until_enemy - 1)
	if turns_until_enemy == 0 and arena.is_free(cell):
		turns_until_enemy = EVERY
		arena.add_staggered(Enemy.new(cell))


func card() -> Card:
	return Card.new("Elevator", "A new rival steps out every 4 turns; the number counts down. Nothing comes out while someone stands on it.", color())


func color() -> Color:
	return Color(0.75, 0.75, 0.85)


# The turns until the next enemy.
func label() -> String:
	return str(turns_until_enemy)
