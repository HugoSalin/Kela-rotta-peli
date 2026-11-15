class_name Elevator
extends Entity

# Keeps bringing rivals: one steps out every few turns, when nothing stands on it.

const EVERY := 4

var turns_until_rival := EVERY


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	solid = false
	shape = Shape.MARK


func take_turn() -> void:
	turns_until_rival = max(0, turns_until_rival - 1)
	if turns_until_rival == 0 and arena.is_free(cell):
		turns_until_rival = EVERY
		arena.add_staggered(Rival.new(cell))


func color() -> Color:
	return Color(0.75, 0.75, 0.85)


# The turns until the next rival.
func label() -> String:
	return str(turns_until_rival)
