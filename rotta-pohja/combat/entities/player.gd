class_name Player
extends Entity

# The player's rat and what it can do on a turn: the abilities.

const PAPER_MIN_RANGE := 2
const PAPER_RANGE := 3
const DESK_THROW_RANGE := 1
# The dash lands two cells away; dash_over() relies on it.
const DASH_REACH := 2
const DASH_COOLDOWN := 3

# ---- Abilities ----

var desk_throw := Ability.new("Throw desk", "Pick a desk next to you, then a cell next to you where it lands. Use it to open a way or to close one. On a rival the desk breaks: the rival is stunned for 2 turns and loses 1 motivation.", 0, [1, 1], [1, DESK_THROW_RANGE], ["Pick a desk next to you.", "Pick where it lands."], can_throw_desk, throw_desk)
var abilities: Array[Ability] = [
	Ability.new("Move / Shove", "Move to a free cell next to you, or pick your own cell to wait. Pick a rival next to you to shove it: it moves back a cell and is stunned for a turn. With something behind it, it stays, is stunned for 2 turns and loses 1 motivation. A shoved office chair rolls away. Picking a desk next to you starts Throw desk.", 0, [0], [1], [""], can_move_or_shove, move_or_shove, false, desk_throw),
	Ability.new("Throw paperwork", "Pick a rival 2 or 3 cells away that you can see; pillars block the view. It loses 1 motivation, and a dash it warns of is called off.", 0, [PAPER_MIN_RANGE], [PAPER_RANGE], ["Pick a rival."], can_throw_paper, throw_paper),
	desk_throw,
	Ability.new("Dash", "Land on a free cell two away in a straight line. You can't cross a desk, a chair or a pillar. A rival you go through loses 1 motivation. Ready again after %d turns." % DASH_COOLDOWN, DASH_COOLDOWN, [DASH_REACH], [DASH_REACH], ["Pick where you land."], can_dash, dash, true),
]


# Cooldowns count down once per turn; the ability just used starts its own.
func cool_down(used: Ability) -> void:
	for ability in abilities:
		ability.turns_until_ready = max(0, ability.turns_until_ready - 1)
	used.turns_until_ready = used.cooldown


func color() -> Color:
	return Color(0.9, 0.85, 0.6)


func card() -> Card:
	return Card.new("You", "A rat on benefits, carrying a job application form. Kela says: find a job. Get through each floor without losing the form. If a rival takes it, you start the floor again.", color())


# ---- Move / Shove ----

# The player's own cell is a pick: it waits, and the turn passes.
func can_move_or_shove(_picked: Array[Vector2i], target: Vector2i) -> bool:
	return target == cell or arena.is_free(target) or arena.is_shovable(target)


func move_or_shove(picked: Array[Vector2i]) -> void:
	if arena.is_shovable(picked[0]):
		arena.entity_at(picked[0]).shove(arena.grid.side_between(cell, picked[0]))
	elif picked[0] != cell:
		arena.move(self, picked[0])


# ---- Throw paperwork ----

func can_throw_paper(_picked: Array[Vector2i], target: Vector2i) -> bool:
	return arena.enemy_at(target) != null


func throw_paper(picked: Array[Vector2i]) -> void:
	var paper := Paperwork.new(cell)
	arena.add(paper)
	arena.move(paper, picked[0])
	arena.remove(paper)
	arena.enemy_at(picked[0]).hit_by_paper()


# ---- Throw desk ----

# First the desk, then where it lands. It can't land on a desk, a pillar, the goal or a
# enemy that can't be shoved.
func can_throw_desk(picked: Array[Vector2i], target: Vector2i) -> bool:
	if picked.is_empty():
		return arena.is_throwable(target)
	var enemy := arena.enemy_at(target)
	return target != arena.goal_cell and not arena.is_obstacle(target) and (enemy == null or enemy.shovable)


# The desk moves to the cell. Landing on an enemy, it breaks and knocks the enemy.
func throw_desk(picked: Array[Vector2i]) -> void:
	var desk := arena.entity_at(picked[0])
	var enemy := arena.enemy_at(picked[1])
	arena.move(desk, picked[1])
	if enemy:
		arena.remove(desk)
		enemy.knock()


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


# An enemy it goes through loses health.
func dash(picked: Array[Vector2i]) -> void:
	var enemy := arena.enemy_at(dash_over(picked[0]))
	arena.move(self, picked[0])
	if enemy:
		enemy.hurt()
