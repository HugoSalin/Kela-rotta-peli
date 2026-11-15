class_name Rival
extends Entity

# A rival rat that hunts the player's form.

# On every third turn a rival dashes: up to DASH_LENGTH cells in a straight line.
const DASH_EVERY := 3
const DASH_LENGTH := 2
const START_MOTIVATION := 3
const COLOR := Color(0.85, 0.3, 0.3)
const STUNNED_COLOR := Color(0.5, 0.5, 0.55)

var turns_until_dash := DASH_EVERY
var motivation := START_MOTIVATION
# How many cells it walks on a turn.
var speed := 1
var body_color := COLOR
# How many of its next turns it skips.
var stunned_turns := 0
# The side its next dash goes; set when the dash warning starts. NO_SIDE before.
var dash_side := HexGrid.NO_SIDE


# ---- Its turn ----

# A stunned rival skips its turn. On every third turn it dashes along the line fixed when the
# warning started, through other rivals, and takes the form if the player is on the line or
# next to where it ends.
# Otherwise it takes the form if it is next to the player, or else walks along the shortest
# path to the player, as far as its speed and the free cells allow.
func take_turn() -> void:
	if stunned_turns > 0:
		stunned_turns -= 1
		return
	turns_until_dash -= 1
	if turns_until_dash == 0:
		dash()
	elif is_next_to_player():
		grab()
	else:
		hunt()


# It moves over the free cells of its line; a rival on the line loses motivation.
func dash() -> void:
	turns_until_dash = DASH_EVERY
	var line := dash_cells()
	dash_side = HexGrid.NO_SIDE
	for step in line:
		var rival := arena.rival_at(step)
		if step == arena.player.cell:
			grab()
			return
		elif rival:
			rival.demotivate()
		else:
			arena.move(self, step)
	if is_next_to_player():
		grab()


func hunt() -> void:
	for walked in speed:
		var step := arena.path_step(self, arena.player.cell)
		if arena.is_free(step):
			arena.move(self, step)
	if turns_until_dash == 1:
		dash_side = arena.grid.side_between(cell, arena.path_step(self, arena.player.cell))


func grab() -> void:
	arena.end(false, "A rival took your form.")


func is_next_to_player() -> bool:
	return arena.grid.distance(cell, arena.player.cell) == 1


# ---- Its dash ----

# The cells its dash would cross now: it stops before an obstacle or the edge. Rivals and
# the player don't shorten it, so the preview shows the whole line.
func dash_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var step := cell
	while dash_side != HexGrid.NO_SIDE and result.size() < DASH_LENGTH:
		step = arena.grid.step(step, dash_side)
		if not arena.grid.has(step) or arena.is_obstacle(step):
			break
		result.append(step)
	return result


# Where its dash would end now: the last cell of the line without a rival, or its own cell.
func dash_end() -> Vector2i:
	var end := cell
	for step in dash_cells():
		if arena.rival_at(step) == null:
			end = step
	return end


# The cells next to where its dash would end now, apart from the line itself.
func grab_cells() -> Array[Vector2i]:
	var line := dash_cells()
	return arena.grid.neighbors(dash_end()).filter(func(near): return near not in line and near != cell and not arena.is_obstacle(near))


# Only a dash is marked: its line and around its end. A stunned rival is harmless.
func danger_cells() -> Array[Vector2i]:
	if stunned_turns > 0 or turns_until_dash != 1:
		return []
	return dash_cells() + grab_cells()


# ---- What the player does to it ----

func stun(turns: int) -> void:
	stunned_turns = turns


# A dash it warns of is called off, and its countdown starts over.
func cancel_dash() -> void:
	if has_warning():
		turns_until_dash = DASH_EVERY
		dash_side = HexGrid.NO_SIDE


# A rival without motivation gives up and leaves.
func demotivate() -> void:
	motivation -= 1
	if motivation <= 0:
		arena.remove(self)


# ---- How it is shown ----

func color() -> Color:
	return STUNNED_COLOR if stunned_turns > 0 else body_color


# One Z for each turn it still skips.
func label() -> String:
	return "Z".repeat(stunned_turns)


func pips() -> int:
	return motivation


func has_warning() -> bool:
	return turns_until_dash == 1


func warning_cells() -> Array[Vector2i]:
	return dash_cells()
