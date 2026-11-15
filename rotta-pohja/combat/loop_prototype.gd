extends Node

# Temporary: plays the combat stages one after another, going up a floor after each win and
# back to the first floor after a loss. The platformer will launch combat instead.

const STAGE_FOLDER := "res://combat/stages/"

@onready var floor_label: Label = $FloorLabel

var pause := 1.5
var stages := stage_scenes()
var stage := 0
var arena: Node


# The stages in the order of their file names, which start with a number.
static func stage_scenes() -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var files := Array(ResourceLoader.list_directory(STAGE_FOLDER))
	files.sort()
	for file in files:
		result.append(load(STAGE_FOLDER + file))
	return result


func _ready() -> void:
	start_stage()


func start_stage() -> void:
	if arena:
		arena.queue_free()
	arena = stages[stage].instantiate()
	arena.combat_finished.connect(_on_combat_finished)
	add_child(arena)
	floor_label.text = "Floor %d of %d" % [stage + 1, stages.size()]


func _on_combat_finished(won: bool) -> void:
	await get_tree().create_timer(pause).timeout
	if not won:
		stage = 0
	elif stage == stages.size() - 1:
		floor_label.text = "You got the job."
		return
	else:
		stage += 1
	start_stage()
