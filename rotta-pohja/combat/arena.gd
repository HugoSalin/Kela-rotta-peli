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
@export var rival_starts: Array[Vector2i] = []
@export var desk_cells: Array[Vector2i] = []
@export var pillar_cells: Array[Vector2i] = []
# Objective "reach a place": the player wins on this cell. NO_CELL if the stage has none.
@export var goal_cell := HexGrid.NO_CELL
@export var goal_name := ""
# Objective "queue number": the player wins after this many turns. -1 if the stage has none.
@export var queue_turns := -1

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
var paths: AStar2D


func _ready() -> void:
	for cell in desk_cells:
		add(Desk.new(cell))
	for cell in pillar_cells:
		add(Pillar.new(cell))
	# Rivals dash on different turns: each starts its countdown a turn later than the one before.
	for index in rival_starts.size():
		var rival := Rival.new(rival_starts[index])
		rival.turns_until_dash += index % Rival.DASH_EVERY
		add(rival)
	player = Player.new(player_start)
	add(player)
	turns_left = queue_turns
	view.animation_finished.connect(announce)
	get_viewport().size_changed.connect(center_in_viewport)
	center_in_viewport()


# Centers everything the view shows, labels included, so none of it falls off the screen.
func center_in_viewport() -> void:
	position = get_viewport_rect().size / 2 - view.bounds().get_center()


# ---- Changing the board ----

func add(entity: Entity) -> void:
	entity.arena = self
	entities.append(entity)
	entity_added.emit(entity)


func move(entity: Entity, to: Vector2i) -> void:
	var from := entity.cell
	entity.cell = to
	entity_moved.emit(entity, from, to)


func block(entity: Entity, toward: Vector2i) -> void:
	entity_blocked.emit(entity, toward)


func remove(entity: Entity) -> void:
	entities.erase(entity)
	entity_removed.emit(entity)


# ---- Asking about the board ----

func entity_at(cell: Vector2i) -> Entity:
	for entity in entities:
		if entity.solid and entity.cell == cell:
			return entity
	return null


func rival_at(cell: Vector2i) -> Rival:
	return entity_at(cell) as Rival


func rivals() -> Array[Rival]:
	var result: Array[Rival] = []
	result.assign(entities.filter(func(entity): return entity is Rival))
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


func blocks_sight(cell: Vector2i) -> bool:
	var entity := entity_at(cell)
	return entity != null and entity.blocks_sight


# A line that runs along the border between two cells is blocked only when both block sight.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	for pair in grid.sight_line(from, to):
		if blocks_sight(pair[0]) and blocks_sight(pair[1]):
			return false
	return true


func danger_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entity in entities:
		result.append_array(entity.danger_cells())
	return result


# ---- Turns ----

# The player uses the ability on the picked cells; then every other entity acts, one after
# another, so one's action can change what the next one does.
# The turn is decided at once; the view then shows its changes one after another.
func take_turn(used: Ability, picked: Array[Vector2i]) -> void:
	turn_started.emit()
	used.use.call(picked)
	entity_acted.emit(player)
	if player.cell == goal_cell:
		end(true, "You reached the %s." % goal_name)
	elif rivals().is_empty() and not rival_starts.is_empty():
		end(true, "Every rival gave up.")
	else:
		paths = build_paths()
		for entity in entities.duplicate():
			if finished:
				break
			if entity != player and entity in entities:
				entity.take_turn()
				entity_acted.emit(entity)
	if not finished and turns_left > 0:
		turns_left -= 1
		if turns_left == 0:
			end(true, "Your number was called.")
	player.cool_down(used)
	turn_ended.emit()


# ---- The ending ----

func end(player_won: bool, text: String) -> void:
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
	if grid.has(goal_cell):
		parts.append("Reach the %s." % goal_name)
	if turns_left > 0:
		parts.append("Your number is called in %d %s." % [turns_left, "turn" if turns_left == 1 else "turns"])
	return " ".join(parts)


# ---- Paths ----

func cell_id(cell: Vector2i) -> int:
	return cell.x + cell.y * HexGrid.COLUMNS


# The cells without an obstacle, each connected to its neighbors; rebuilt every turn.
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
