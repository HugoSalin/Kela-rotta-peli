class_name ArenaView
extends Node2D

# Everything visible of the arena: the cells, the entities, the animation of a turn and the
# labels. It follows the rules through their signals and never changes them.

signal animation_finished

const FLOOR_COLOR := Color(0.2, 0.22, 0.26)
const LINE_COLOR := Color(0.45, 0.48, 0.55)
const ACTION_COLOR := Color(0.3, 0.5, 0.35)
const RANGE_COLOR := Color(0.23, 0.33, 0.28)
const DANGER_COLOR := Color(0.45, 0.1, 0.1)
const GOAL_COLOR := Color(0.35, 0.6, 0.95)
const WARNING_COLOR := Color(1.0, 0.85, 0.2)
const SELECTION_COLOR := Color.WHITE


# Where and whether an entity is drawn; it catches up with the entity during the animation.
class Drawn:
	var position: Vector2
	var visible := true
	# The warning of its next move: the ring and the line.
	var warned := false
	var warning: Array[Vector2i] = []


@onready var arena: Arena = get_parent()
@onready var grid: HexGrid = $"../Grid"
@onready var selection: Selection = $"../Selection"
@onready var status_label: Label = $StatusLabel
@onready var ability_label: Label = $AbilityLabel

var drawn: Dictionary[Entity, Drawn] = {}
# The danger cells as they stood at this point of the animation.
var shown_danger: Array[Vector2i] = []
# The animation of the turn; null when nothing is animating.
var animation: Tween


func _ready() -> void:
	arena.entity_added.connect(_on_entity_added)
	arena.entity_moved.connect(_on_entity_moved)
	arena.entity_blocked.connect(_on_entity_blocked)
	arena.entity_removed.connect(_on_entity_removed)
	arena.entity_acted.connect(show_preview.unbind(1))
	arena.turn_started.connect(_on_turn_started)
	arena.turn_ended.connect(_on_turn_ended)
	selection.changed.connect(refresh)


func _process(_delta: float) -> void:
	if animation:
		queue_redraw()


# ---- Following the rules ----

# A change during a turn joins the turn's animation, in order; outside a turn it shows at once.

func _on_entity_added(entity: Entity) -> void:
	var piece := Drawn.new()
	piece.position = grid.map_to_local(entity.cell)
	drawn[entity] = piece
	if animation:
		piece.visible = false
		animation.tween_callback(func(): piece.visible = true)


func _on_entity_moved(entity: Entity, _from: Vector2i, to: Vector2i) -> void:
	if animation:
		entity.motion.play_move(animation, drawn[entity], grid.map_to_local(to))
	else:
		drawn[entity].position = grid.map_to_local(to)


func _on_entity_blocked(entity: Entity, toward: Vector2i) -> void:
	if animation:
		entity.motion.play_blocked(animation, drawn[entity], grid.map_to_local(entity.cell), grid.map_to_local(toward))


func _on_entity_removed(entity: Entity) -> void:
	if animation:
		animation.tween_callback(func(): drawn.erase(entity))
	else:
		drawn.erase(entity)


# The danger cells and warnings as the rules have them now. During a turn they are shown
# once the animation gets here, so each action's effect on the preview is seen in its turn.
func show_preview() -> void:
	var danger := arena.danger_cells()
	var warnings: Dictionary[Entity, Array] = {}
	for entity in arena.entities:
		warnings[entity] = [entity.has_warning(), entity.warning_cells()]
	var apply := func():
		shown_danger = danger
		for entity in warnings:
			if drawn.has(entity):
				drawn[entity].warned = warnings[entity][0]
				drawn[entity].warning.assign(warnings[entity][1])
	if animation:
		animation.tween_callback(apply)
	else:
		apply.call()


# ---- The animation of a turn ----

# Acting again before the animation ends skips the rest of it.
func _on_turn_started() -> void:
	finish()
	animation = create_tween()


func _on_turn_ended() -> void:
	animation.tween_callback(finish)


# Puts everything where the rules have it.
func finish() -> void:
	if animation:
		animation.kill()
		animation = null
	drawn.clear()
	for entity in arena.entities:
		_on_entity_added(entity)
	animation_finished.emit()
	refresh()


func position_of(entity: Entity) -> Vector2:
	return drawn[entity].position


# The rectangle around everything shown: the cells and the labels.
func bounds() -> Rect2:
	var half := Vector2(grid.tile_set.tile_size) / 2
	var result := status_label.get_rect().merge(ability_label.get_rect())
	for cell in grid.cells:
		result = result.merge(Rect2(grid.map_to_local(cell) - half, half * 2))
	return result


# ---- Labels ----

func refresh() -> void:
	if not animation:
		show_preview()
	status_label.text = arena.end_text if arena.announced else arena.objective_text()
	var abilities := arena.player.abilities
	var entries: Array[String] = []
	for index in abilities.size():
		var entry := "[%d] %s" % [index + 1, abilities[index].title]
		if abilities[index].turns_until_ready > 0:
			entry += " (%d)" % abilities[index].turns_until_ready
		entries.append("> " + entry if abilities[index] == selection.ability else entry)
	ability_label.text = "   ".join(entries) + "\n" + selection.ability.prompts[selection.picks.size()]
	queue_redraw()


# ---- Drawing ----

func _draw() -> void:
	draw_cells()
	if grid.has(arena.goal_cell):
		draw_polyline(hex_corners(grid.map_to_local(arena.goal_cell)), GOAL_COLOR, 6.0)
	for entity in drawn:
		draw_warning(entity)
	for entity in drawn:
		if entity.shape == Entity.Shape.CIRCLE and drawn[entity].visible:
			draw_piece(entity, drawn[entity].position)
	for cell in selection.picks:
		draw_polyline(hex_corners(grid.map_to_local(cell), 0.8), SELECTION_COLOR, 3.0)
	if selection.is_seam(selection.point):
		draw_circle(selection.point_position(selection.point), 6.0, SELECTION_COLOR)
	else:
		draw_polyline(hex_corners(grid.map_to_local(selection.point_to_cell(selection.point))), SELECTION_COLOR, 5.0)


# The floor, then the entities that fill a cell, then the marks on top of both.
# What the player can pick is green, the rest of the ability's range a darker green:
# the whole cell on plain floor, a smaller hex inside an obstacle or a dangerous cell
# (not under the player, whose circle would cover most of it).
func draw_cells() -> void:
	var actions := selection.action_cells()
	var in_range := selection.range_cells()
	var inner_marks: Dictionary[Vector2i, Color] = {}
	for cell in grid.cells:
		var obstacle := arena.is_obstacle(cell)
		var color := DANGER_COLOR if cell in shown_danger and not obstacle else FLOOR_COLOR
		var mark := color
		if cell in actions:
			mark = ACTION_COLOR
		elif cell in in_range and not obstacle:
			mark = RANGE_COLOR
		var plain := color == FLOOR_COLOR and not obstacle
		draw_hex(grid.map_to_local(cell), mark if plain else color)
		if not plain and mark != color and cell != arena.player.cell:
			inner_marks[cell] = mark
	for entity in drawn:
		if entity.shape == Entity.Shape.HEX and drawn[entity].visible:
			draw_hex(drawn[entity].position, entity.color())
	for cell in inner_marks:
		draw_colored_polygon(hex_corners(grid.map_to_local(cell), 0.6), inner_marks[cell])


func draw_hex(center: Vector2, color: Color) -> void:
	draw_colored_polygon(hex_corners(center), color)
	draw_polyline(hex_corners(center), LINE_COLOR, 2.0)


# The line of the move an entity warns of, with a dot at its end.
func draw_warning(entity: Entity) -> void:
	var line := drawn[entity].warning
	if not line.is_empty():
		var end := grid.map_to_local(line[-1])
		draw_line(drawn[entity].position, end, WARNING_COLOR, 6.0)
		draw_circle(end, 9.0, WARNING_COLOR)


func draw_piece(entity: Entity, center: Vector2) -> void:
	draw_circle(center, entity.radius, entity.color())
	draw_string(ThemeDB.fallback_font, center + Vector2(-20.0, 8.0), entity.label(), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, SELECTION_COLOR)
	var pips := entity.pips()
	for index in pips:
		draw_circle(center + Vector2((index - (pips - 1) / 2.0) * 10.0, -28.0), 3.5, SELECTION_COLOR)
	if drawn[entity].warned:
		draw_arc(center, entity.radius + 6.0, 0.0, TAU, 32, WARNING_COLOR, 4.0)


# Closed outline: the first corner is repeated at the end.
func hex_corners(center: Vector2, size := 1.0) -> PackedVector2Array:
	var half := Vector2(grid.tile_set.tile_size) / 2 * size
	return [
		center + Vector2(-half.x, 0),
		center + Vector2(-half.x / 2, -half.y),
		center + Vector2(half.x / 2, -half.y),
		center + Vector2(half.x, 0),
		center + Vector2(half.x / 2, half.y),
		center + Vector2(-half.x / 2, half.y),
		center + Vector2(-half.x, 0),
	]
