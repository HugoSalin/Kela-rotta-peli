class_name Entity
extends RefCounted

# Anything on the board. A kind extends this and sets what differs.

enum Shape { HEX, CIRCLE, MARK }

# ---- On the board ----

var arena: Arena
var cell: Vector2i
# Nothing else can be on its cell.
var solid := true
# A fixed thing: a wall for shoves and dashes, and paths go around it.
var obstacle := false
var blocks_sight := false
var throwable := false
var shovable := false
# Whoever moves onto its cell slides on.
var slippery := false
# The goal can't be reached while it is on the board.
var locks_goal := false

# ---- How it is shown ----

var motion := Motion.new()
# A hex fills the cell; a circle has `radius`; a mark is an outline on the cell's floor,
# for what others can stand on.
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


# ---- In the objective ----

# What the objective calls it, for a kind the objective names.
func title() -> String:
	return ""


# ---- Its card ----

# What the player is told when first meeting its kind; null for a kind that needs no words.
func card() -> Card:
	return null


# ---- What the player does to it ----

# The player shoves it toward that side.
func shove(_side: int) -> void:
	pass


# ---- Its turn ----

# What it does after the player's action.
func take_turn() -> void:
	pass


# ---- Its state ----

# The names of each kind's variables, found once.
static var variables: Dictionary[Script, Array] = {}


# Its variables as they are now, to put it back as it was.
func state() -> Dictionary:
	var kind: Script = get_script()
	if not variables.has(kind):
		variables[kind] = get_property_list().filter(func(property): return property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE).map(func(property): return property.name)
	var result := {}
	for variable in variables[kind]:
		result[variable] = get(variable)
	return result


func restore(saved: Dictionary) -> void:
	for property in saved:
		set(property, saved[property])
