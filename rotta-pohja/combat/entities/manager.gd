class_name Manager
extends Rival

# A manager never gives up and can't be shoved, knocked or hit with a desk. Thrown
# paperwork keeps it busy for a while.

const PAPER_STUN := 2


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	shovable = false
	radius = 24.0
	body_color = Color(0.45, 0.25, 0.6)


func knock() -> void:
	pass


func hit_by_paper() -> void:
	stun(PAPER_STUN)


func demotivate() -> void:
	pass


func pips() -> int:
	return 0
