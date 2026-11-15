class_name Player
extends Entity

# The player's rat and what it can do on a turn: the abilities.

# Turns a shoved rival skips: after hitting something behind it, and otherwise.
const WALL_STUN := 2
const SHOVE_STUN := 1
const PAPER_MIN_RANGE := 2
const PAPER_RANGE := 3
const DESK_THROW_RANGE := 1
# The dash lands two cells away; dash_over() relies on it.
const DASH_REACH := 2
const DASH_COOLDOWN := 3

# ---- Abilities ----

var abilities: Array[Ability] = [
	Ability.new("Move / Shove", 0, [0], [1], [""], can_move_or_shove, move_or_shove),
	Ability.new("Throw paperwork", 0, [PAPER_MIN_RANGE], [PAPER_RANGE], ["Pick a rival."], can_throw_paper, throw_paper),
	Ability.new("Throw desk", 0, [1, 1], [1, DESK_THROW_RANGE], ["Pick a desk next to you.", "Pick where it lands."], can_throw_desk, throw_desk),
	Ability.new("Dash", DASH_COOLDOWN, [DASH_REACH], [DASH_REACH], ["Pick where you land."], can_dash, dash, true),
]
var desk_throw := abilities[2]


# Cooldowns count down once per turn; the ability just used starts its own.
func cool_down(used: Ability) -> void:
	for ability in abilities:
		ability.turns_until_ready = max(0, ability.turns_until_ready - 1)
	used.turns_until_ready = used.cooldown


func color() -> Color:
	return Color(0.9, 0.85, 0.6)


# ---- Move / Shove ----

# The player's own cell is a pick: it waits, and the turn passes. A desk next to the player
# is a pick too while the desk throw is ready: it starts the throw.
func can_move_or_shove(_picked: Array[Vector2i], target: Vector2i) -> bool:
	return target == cell or arena.is_free(target) or arena.rival_at(target) != null or (arena.is_throwable(target) and desk_throw.turns_until_ready == 0)


func move_or_shove(picked: Array[Vector2i]) -> void:
	var rival := arena.rival_at(picked[0])
	if rival:
		shove(rival)
	elif picked[0] != cell:
		arena.move(self, picked[0])


# Pushes the rival one cell straight away from the player and stuns it. If something is
# behind it, it stays, is stunned longer and loses motivation; a rival behind it gets the same.
func shove(rival: Rival) -> void:
	var behind := arena.grid.step(rival.cell, arena.grid.side_between(cell, rival.cell))
	if arena.is_free(behind):
		rival.stun(SHOVE_STUN)
		arena.move(rival, behind)
		return
	var other := arena.rival_at(behind)
	arena.block(rival, behind)
	for hit in [rival, other]:
		if hit:
			hit.stun(WALL_STUN)
			hit.demotivate()


# ---- Throw paperwork ----

func can_throw_paper(_picked: Array[Vector2i], target: Vector2i) -> bool:
	return arena.rival_at(target) != null


func throw_paper(picked: Array[Vector2i]) -> void:
	var paper := Paperwork.new(cell)
	arena.add(paper)
	arena.move(paper, picked[0])
	arena.remove(paper)
	var rival := arena.rival_at(picked[0])
	rival.cancel_dash()
	rival.demotivate()


# ---- Throw desk ----

# First the desk, then where it lands. It can't land on a desk, a pillar or the goal.
func can_throw_desk(picked: Array[Vector2i], target: Vector2i) -> bool:
	if picked.is_empty():
		return arena.is_throwable(target)
	return target != arena.goal_cell and not arena.is_obstacle(target)


# The desk moves to the cell. Landing on a rival, it breaks: the rival loses motivation and
# is stunned as if shoved into a desk.
func throw_desk(picked: Array[Vector2i]) -> void:
	var desk := arena.entity_at(picked[0])
	var rival := arena.rival_at(picked[1])
	arena.move(desk, picked[1])
	if rival:
		arena.remove(desk)
		rival.stun(WALL_STUN)
		rival.demotivate()


# ---- Dash ----

# The cell the dash crosses on its way to `target`, two cells away in a straight line;
# NO_CELL if `target` is no such cell.
func dash_over(target: Vector2i) -> Vector2i:
	for side in HexGrid.SIDES:
		var between := arena.grid.step(cell, side)
		if arena.grid.step(between, side) == target:
			return between
	return HexGrid.NO_CELL


# It lands on a free cell and can't cross an obstacle.
func can_dash(_picked: Array[Vector2i], target: Vector2i) -> bool:
	var between := dash_over(target)
	return arena.grid.has(between) and not arena.is_obstacle(between) and arena.is_free(target)


# A rival it goes through loses motivation.
func dash(picked: Array[Vector2i]) -> void:
	var rival := arena.rival_at(dash_over(picked[0]))
	arena.move(self, picked[0])
	if rival:
		rival.demotivate()
