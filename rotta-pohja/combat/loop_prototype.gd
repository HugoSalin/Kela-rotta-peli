extends Node

# Temporary: plays the combat stages one after another, going up a floor after each win and
# back to the first floor after a loss. The platformer will launch combat instead.

const STAGES: Array[PackedScene] = [
	preload("res://combat/stages/hr_desk.tscn"),
	preload("res://combat/stages/queue_number.tscn"),
	preload("res://combat/stages/elevator.tscn"),
	preload("res://combat/stages/mailroom.tscn"),
	preload("res://combat/stages/waiting_room.tscn"),
	preload("res://combat/stages/managers_office.tscn"),
]

@onready var floor_label: Label = $FloorLabel

var pause := 1.5
var stage := 0
var arena: Node


func _ready() -> void:
	start_stage()


func start_stage() -> void:
	if arena:
		arena.queue_free()
	arena = STAGES[stage].instantiate()
	arena.combat_finished.connect(_on_combat_finished)
	add_child(arena)
	floor_label.text = "Floor %d of %d" % [stage + 1, STAGES.size()]


func _on_combat_finished(won: bool) -> void:
	await get_tree().create_timer(pause).timeout
	if not won:
		stage = 0
	elif stage == STAGES.size() - 1:
		floor_label.text = "You got the job."
		return
	else:
		stage += 1
	start_stage()
