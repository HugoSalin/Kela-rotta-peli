class_name Enemy
extends Entity

# An enemy rat that hunts the player's form.

# A dash goes up to DASH_LENGTH cells in a straight line.
const DASH_LENGTH := 2
const START_HEALTH := 3
# Turns it skips after a shove: when it was knocked against something, and otherwise.
const KNOCK_STUN := 2
const SHOVE_STUN := 1
const COLOR := Color(0.85, 0.3, 0.3)
const STUNNED_COLOR := Color(0.5, 0.5, 0.55)

# It dashes on every third turn.
var dash_every := 3
var turns_until_dash := dash_every
var health := START_HEALTH
# How many cells it walks on a turn without a dash.
var speed := 1
var body_color := COLOR
# How many of its next turns it skips.
var stunned_turns := 0
# The side its next dash goes; set when the dash warning starts. NO_SIDE before.
var dash_side := HexGrid.NO_SIDE


func _init(start_cell: Vector2i) -> void:
	super(start_cell)
	shovable = true


# ---- Its turn ----

# A stunned enemy skips its turn. When its countdown ends it dashes along the line fixed
# when the warning started, through other enemies, and takes the form if the player is on the
# line or next to where it ends.
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
	aim()


# An enemy on the line loses health. It moves over the cells of its line without an enemy,
# also those an enemy just gave up, and takes the form on the line and next to where it ends.
# A slide on wet floor ends the dash where the slide ends.
func dash() -> void:
	turns_until_dash = dash_every
	var line := dash_cells()
	var start := cell
	dash_side = HexGrid.NO_SIDE
	for step in line:
		var enemy := arena.enemy_at(step)
		if enemy:
			enemy.hurt()
		if arena.enemy_at(step) == null:
			arena.move(self, step)
		if cell != step and arena.enemy_at(step) == null:
			break
	arena.threaten(line + arena.grid.neighbors(cell).filter(func(near): return near not in line and near != start and not arena.is_obstacle(near)))


func hunt() -> void:
	for walked in speed:
		var step := arena.path_step(self, arena.player.cell)
		if arena.is_free(step):
			arena.move(self, step)


# Before a turn on which it dashes, the line is fixed: the direction of its next path step.
func aim() -> void:
	if turns_until_dash == 1:
		dash_side = arena.grid.side_between(cell, arena.path_step(self, arena.player.cell))


func grab() -> void:
	arena.take_form()


func is_next_to_player() -> bool:
	return arena.grid.distance(cell, arena.player.cell) == 1


# ---- Its dash ----

# The cells its dash would cross now: it stops before an obstacle or the edge. Enemies and
# the player don't shorten it, so the warning shows the whole line.
func dash_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var step := cell
	while dash_side != HexGrid.NO_SIDE and result.size() < DASH_LENGTH:
		step = arena.grid.step(step, dash_side)
		if not arena.grid.has(step) or arena.is_obstacle(step):
			break
		result.append(step)
	return result


# ---- What the player does to it ----

# A shove pushes it one cell and stuns it. If something is behind it, it stays and is
# knocked; an enemy behind it is knocked too.
func shove(side: int) -> void:
	var behind := arena.grid.step(cell, side)
	if arena.is_free(behind):
		stun(SHOVE_STUN)
		arena.move(self, behind)
		return
	var other := arena.enemy_at(behind)
	arena.block(self, behind)
	knock()
	if other:
		other.knock()


# Hitting something hard stuns it longer and costs health.
func knock() -> void:
	stun(KNOCK_STUN)
	hurt()


func stun(turns: int) -> void:
	stunned_turns = turns


# Thrown paperwork calls off a dash it warns of and costs health.
func hit_by_paper() -> void:
	cancel_dash()
	hurt()


# A dash it warns of is called off, and its countdown starts over.
func cancel_dash() -> void:
	if has_warning():
		turns_until_dash = dash_every
		dash_side = HexGrid.NO_SIDE


# An enemy without health gives up and leaves.
func hurt() -> void:
	health -= 1
	if health <= 0:
		arena.remove(self)


# ---- How it is shown ----

func color() -> Color:
	return STUNNED_COLOR if stunned_turns > 0 else body_color


# One Z for each turn it still skips.
func label() -> String:
	return "Z".repeat(stunned_turns)


func pips() -> int:
	return health


func has_warning() -> bool:
	return turns_until_dash == 1


func warning_cells() -> Array[Vector2i]:
	return dash_cells()


func card() -> Card:
	return Card.new("Rival", "Another job-seeker, after your form. It walks one cell a turn and takes the form if its turn starts next to you. Every third turn it dashes two cells in a straight line: a ring and a yellow line warn you a turn ahead, and on the red cells the dash takes your form. The dots are its motivation; with none left it gives up. Shove it to stun it for a turn. Shove it against something to stun it for 2 turns and cost it 1 motivation.", body_color)
