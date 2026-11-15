class_name Arena
extends Node2D

# The rules of one combat: what is on the board, the turns, the objective and the ending.
# It reports every change to the board through generic signals.

signal entity_added(entity: Entity)
signal entity_moved(entity: Entity, from: Vector2i, to: Vector2i)
# It tried to move toward that cell and couldn't.
signal entity_blocked(entity: Entity, toward: Vector2i)
signal entity_removed(entity: Entity)
# It has done what it does this turn; what follows may depend on it.
signal entity_acted(entity: Entity)
signal turn_started
signal turn_ended
signal combat_finished(won: bool)

# ---- The stage ----

# A stage is a scene that inherits arena.tscn and sets these.
@export var player_start := Vector2i(0, 3)
@export var enemy_starts: Array[Vector2i] = []
@export var intern_starts: Array[Vector2i] = []
@export var manager_starts: Array[Vector2i] = []
@export var desk_cells: Array[Vector2i] = []
@export var pillar_cells: Array[Vector2i] = []
@export var elevator_cells: Array[Vector2i] = []
@export var chair_cells: Array[Vector2i] = []
@export var keycard_cells: Array[Vector2i] = []
@export var document_cells: Array[Vector2i] = []
@export var wet_cells: Array[Vector2i] = []
# Objective "reach a place": the goal is on this cell. NO_CELL if the stage has none.
@export var goal_cell := HexGrid.NO_CELL
@export var goal_name := ""
# Objective "queue number": the player wins after this many turns. -1 if the stage has none.
@export var queue_turns := -1
# Objective "defeat the rivals": the player wins when every enemy has given up. It may be
# the only objective or stand beside another.
@export var defeat_enemies := false

# ---- Setup ----

@onready var grid: HexGrid = $Grid
@onready var view: ArenaView = $View
@onready var selection: Selection = $Selection

var entities: Array[Entity] = []
var player: Player
var turns_left: int
var finished := false
var won := false
var end_text := ""
var announced := false
# The cells without an obstacle, connected; null until asked for after an obstacle changed.
var paths: AStar2D
# The entities that still act before the player's next action.
var waiting: Array[Entity] = []
# A rehearsal plays coming turns to see what they do: nothing is reported, the game can't
# end, and the board is put back afterwards.
var rehearsing := false
var forecast: Array[Vector2i] = []
# The cells where a dash takes the form before the player's next action. After the
# player's action these are the dashes of this round; after the round, those of the next.
# Worked out when first asked for after the board changed.
var danger: Array[Vector2i]:
	get:
		if danger_is_stale:
			danger_is_stale = false
			danger = danger_cells()
		return danger
var danger_is_stale := true


func _ready() -> void:
	player = Player.new(player_start)
	add(player)
	for cell in desk_cells:
		add(Desk.new(cell))
	for cell in pillar_cells:
		add(Pillar.new(cell))
	for cell in elevator_cells:
		add(Elevator.new(cell))
	for cell in chair_cells:
		add(Chair.new(cell))
	for cell in keycard_cells:
		add(Keycard.new(cell))
	for number in document_cells.size():
		add(Document.new(document_cells[number], number))
	for cell in wet_cells:
		add(WetFloor.new(cell))
	if grid.has(goal_cell):
		add(Goal.new(goal_cell))
	for cell in enemy_starts:
		add_staggered(Enemy.new(cell))
	for cell in intern_starts:
		add_staggered(Intern.new(cell))
	for cell in manager_starts:
		add_staggered(Manager.new(cell))
	# An enemy that dashes on the first turn shows its line from the start.
	for enemy in enemies():
		enemy.aim()
	turns_left = queue_turns
	view.animation_finished.connect(announce)
	get_viewport().size_changed.connect(center_in_viewport)
	center_in_viewport()


# Enemies dash on different turns: each starts its countdown a turn later than the one
# before, within how often it dashes.
func add_staggered(enemy: Enemy) -> void:
	enemy.turns_until_dash += enemies().size() % enemy.dash_every
	add(enemy)


# Centers everything the view shows, labels included, so none of it falls off the screen.
func center_in_viewport() -> void:
	position = get_viewport_rect().size / 2 - view.bounds().get_center()


# ---- Changing the board ----

func add(entity: Entity) -> void:
	entity.arena = self
	entities.append(entity)
	obstacles_changed(entity)
	report(entity_added, [entity])


# The player or an enemy that moves straight onto a wet cell slides on in that direction
# until the cell it is on is dry or the next one is taken.
func move(entity: Entity, to: Vector2i) -> void:
	var from := entity.cell
	entity.cell = to
	obstacles_changed(entity)
	report(entity_moved, [entity, from, to])
	var side := grid.straight_side(from, to)
	if entity.solid and not entity.obstacle and is_wet(to) and side != HexGrid.NO_SIDE and is_free(grid.step(to, side)):
		move(entity, grid.step(to, side))


func block(entity: Entity, toward: Vector2i) -> void:
	report(entity_blocked, [entity, toward])


func remove(entity: Entity) -> void:
	entities.erase(entity)
	obstacles_changed(entity)
	report(entity_removed, [entity])


func obstacles_changed(entity: Entity) -> void:
	if entity.obstacle:
		paths = null


func report(change: Signal, arguments: Array) -> void:
	if not rehearsing:
		change.emit.callv(arguments)


# ---- Asking about the board ----

func entity_at(cell: Vector2i) -> Entity:
	for entity in entities:
		if entity.solid and entity.cell == cell:
			return entity
	return null


func enemy_at(cell: Vector2i) -> Enemy:
	return entity_at(cell) as Enemy


func enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	result.assign(entities.filter(func(entity): return entity is Enemy))
	return result


# Inside the arena with nothing on it.
func is_free(cell: Vector2i) -> bool:
	return grid.has(cell) and entity_at(cell) == null


func is_obstacle(cell: Vector2i) -> bool:
	var entity := entity_at(cell)
	return entity != null and entity.obstacle


func is_throwable(cell: Vector2i) -> bool:
	var entity := entity_at(cell)
	return entity != null and entity.throwable


func is_wet(cell: Vector2i) -> bool:
	return entities.any(func(entity): return entity.slippery and entity.cell == cell)


func goals() -> Array[Entity]:
	return entities.filter(func(entity): return entity.is_goal)


func is_goal(cell: Vector2i) -> bool:
	return goals().any(func(goal): return goal.cell == cell)


func is_goal_locked() -> bool:
	return entities.any(func(entity): return entity.locks_goal)


func is_shovable(cell: Vector2i) -> bool:
	var entity := entity_at(cell)
	return entity != null and entity.shovable


func blocks_sight(cell: Vector2i) -> bool:
	var entity := entity_at(cell)
	return entity != null and entity.blocks_sight


# A line that runs along the border between two cells is blocked only when both block sight.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	for pair in grid.sight_line(from, to):
		if blocks_sight(pair[0]) and blocks_sight(pair[1]):
			return false
	return true


# ---- Turns ----

# The player uses the ability on the picked cells; then every other entity acts.
# The turn is decided at once; the view then shows its changes one after another.
func take_turn(used: Ability, picked: Array[Vector2i]) -> void:
	turn_started.emit()
	used.use.call(picked)
	start_round()
	danger_is_stale = true
	report(entity_acted, [player])
	if is_goal(player.cell) and not is_goal_locked():
		end(true, "You reached the %s." % goal_name)
	elif defeat_enemies and enemies().is_empty():
		end(true, "Every rival gave up.")
	else:
		play_round()
	waiting.clear()
	if not finished and turns_left > 0:
		turns_left -= 1
		if turns_left == 0:
			end(true, "Your number was called.")
	player.cool_down(used)
	danger_is_stale = true
	turn_ended.emit()


func start_round() -> void:
	waiting = entities.filter(func(entity): return entity != player)


# Those waiting act one after another, so one's action can change what the next one does.
func play_round() -> void:
	while not waiting.is_empty() and not finished:
		var entity: Entity = waiting.pop_front()
		if entity in entities:
			entity.take_turn()
			report(entity_acted, [entity])


# An enemy's move takes the form on these cells.
func threaten(cells: Array[Vector2i]) -> void:
	if rehearsing:
		forecast.append_array(cells)
	elif player.cell in cells:
		take_form()


func take_form() -> void:
	end(false, "A rival took your form.")


# Finds the danger by playing the turns still to come, so it shows what the rules will do.
func danger_cells() -> Array[Vector2i]:
	var saved := snapshot()
	rehearsing = true
	forecast = []
	if waiting.is_empty():
		start_round()
	play_round()
	rehearsing = false
	restore(saved)
	return forecast


# The board as it is now: who is on it, each one's state, and who still waits to act.
func snapshot() -> Dictionary:
	return {"board": entities.duplicate(), "states": entities.map(func(entity): return entity.state()), "waiting": waiting.duplicate()}


func restore(saved: Dictionary) -> void:
	entities.assign(saved.board)
	for index in entities.size():
		entities[index].restore(saved.states[index])
	waiting.assign(saved.waiting)


# ---- The ending ----

func end(player_won: bool, text: String) -> void:
	if rehearsing:
		return
	finished = true
	won = player_won
	end_text = text


# Once, when the animation of the last turn is over.
func announce() -> void:
	if finished and not announced:
		announced = true
		combat_finished.emit(won)


func objective_text() -> String:
	var parts: Array[String] = []
	var locks := entities.filter(func(entity): return entity.locks_goal).map(func(entity): return "the " + entity.title())
	if not goals().is_empty():
		parts.append("Reach the %s." % goal_name if locks.is_empty() else "Get %s, then reach the %s." % [listed(locks), goal_name])
	if turns_left > 0:
		parts.append("Your number is called in %d %s." % [turns_left, "turn" if turns_left == 1 else "turns"])
	if defeat_enemies:
		parts.append("Make every rival give up." if parts.is_empty() else "Or make every rival give up.")
	return " ".join(parts)


# The items as a list in a sentence: "a, b and c".
static func listed(items: Array) -> String:
	if items.size() == 1:
		return items[0]
	return ", ".join(items.slice(0, -1)) + " and " + items[-1]


# ---- Paths ----

func cell_id(cell: Vector2i) -> int:
	return cell.x + cell.y * HexGrid.COLUMNS


# The cells without an obstacle, each connected to its neighbors.
func build_paths() -> AStar2D:
	var result := AStar2D.new()
	for cell in grid.cells:
		if not is_obstacle(cell):
			result.add_point(cell_id(cell), grid.map_to_local(cell))
	for cell in grid.cells:
		for neighbor in grid.neighbors(cell):
			if result.has_point(cell_id(cell)) and result.has_point(cell_id(neighbor)):
				result.connect_points(cell_id(cell), cell_id(neighbor))
	return result


# The first cell on the mover's shortest path to `to`, around obstacles and whatever else
# stands in the way. If the others leave no way, the path as if they weren't there, so the
# mover queues up behind them. Its own cell if there is no path at all.
func path_step(mover: Entity, to: Vector2i) -> Vector2i:
	if paths == null:
		paths = build_paths()
	var in_the_way := entities.filter(func(entity): return entity.solid and not entity.obstacle and entity != mover and entity.cell != to)
	for avoided in [in_the_way, []]:
		for entity in avoided:
			paths.set_point_disabled(cell_id(entity.cell), true)
		var path := paths.get_id_path(cell_id(mover.cell), cell_id(to))
		for entity in avoided:
			paths.set_point_disabled(cell_id(entity.cell), false)
		if path.size() >= 2:
			return Vector2i(path[1] % HexGrid.COLUMNS, path[1] / HexGrid.COLUMNS)
	return mover.cell
