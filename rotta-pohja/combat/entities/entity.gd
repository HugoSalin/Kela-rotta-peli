class_name Entity
extends RefCounted

# Anything on the board. A kind extends this and sets what differs.

enum Shape { HEX, CIRCLE }

# ---- On the board ----

var arena: Arena
var cell: Vector2i
# Nothing else can be on its cell.
var solid := true
# A fixed thing: a wall for shoves and dashes, and paths go around it.
var obstacle := false
var blocks_sight := false
var throwable := false

# ---- How it is shown ----

var motion := Motion.new()
# A hex fills the cell; a circle has `radius`.
var shape := Shape.CIRCLE
var radius := 20.0


func _init(start_cell: Vector2i) -> void:
	cell = start_cell


func color() -> Color:
	return Color.WHITE


# A short text drawn on it.
func label() -> String:
	return ""


# The number of dots drawn above it.
func pips() -> int:
	return 0


# Is a ring drawn around it, to warn of its next move?
func has_warning() -> bool:
	return false


# The line of the move it warns of.
func warning_cells() -> Array[Vector2i]:
	return []


# ---- Its turn ----

# What it does after the player's action.
func take_turn() -> void:
	pass


# The cells where ending the turn loses the form to it.
func danger_cells() -> Array[Vector2i]:
	return []
