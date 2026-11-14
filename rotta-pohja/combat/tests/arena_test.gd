extends SceneTree

# Tests the combat arena by pressing keys. Run from the repository root; exits with 1 on a failure:
#   timeout 30 godot --headless --path rotta-pohja --script res://combat/tests/arena_test.gd

const Arena := preload("res://combat/arena.gd")
const KEYS := {"W": "combat_up", "S": "combat_down", "A": "combat_left", "D": "combat_right", "E": "ui_accept"}
const FAR := Vector2i(8, 6)

var arena: Arena
var results: Array[bool] = []
var checks := 0
var fails := 0


func check(what: String, actual, expected) -> void:
	checks += 1
	if actual != expected:
		fails += 1
		print("FAIL %s | expected %s | actual %s" % [what, expected, actual])


func setup(player: Vector2i, reach: int, rival_cells: Array) -> void:
	if arena:
		arena.free()
	arena = load("res://combat/arena.tscn").instantiate()
	root.add_child(arena)
	arena.combat_finished.connect(func(won): results.append(won))
	results.clear()
	arena.player_cell = player
	arena.cursor = arena.cell_to_point(player)
	arena.action_range = reach
	for cell in rival_cells:
		arena.rivals.append(Arena.Rival.new(cell))


func press_one(key: String) -> void:
	var event := InputEventAction.new()
	event.action = KEYS[key]
	event.pressed = true
	arena._unhandled_input(event)


# Presses the keys and skips the animation of the last turn.
func press(keys: String) -> void:
	for key in keys:
		press_one(key)
	arena.finish_animation()


# The cursor's position relative to the player's start cell, and whether it is on a seam.
func cursor_after(player: Vector2i, reach: int, keys: String) -> Array:
	setup(player, reach, [])
	press(keys)
	return [arena.point_position(arena.cursor) - arena.tile_map.map_to_local(player), arena.is_seam(arena.cursor)]


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	test_grid()
	test_cursor()
	test_turns()
	test_queue_number()
	test_dash()
	await test_loop()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails else 0)


func test_grid() -> void:
	setup(Vector2i(4, 3), 1, [])
	var wrong_points := 0
	var wrong_distances := 0
	for cell in arena.cells:
		var point := arena.cell_to_point(cell)
		if arena.is_seam(point) or arena.point_to_cell(point) != cell or arena.point_position(point) != arena.tile_map.map_to_local(cell):
			wrong_points += 1
		for neighbor in arena.tile_map.get_surrounding_cells(cell):
			if arena.distance(cell, neighbor) != 1:
				wrong_distances += 1
	check("cells whose lattice point is wrong", wrong_points, 0)
	check("neighbors not at distance 1", wrong_distances, 0)
	check("distance corner to corner", arena.distance(Vector2i(0, 0), Vector2i(8, 6)), 10)
	check("reachable cells in the middle", arena.reachable_cells().size(), 6)
	setup(Vector2i(0, 0), 1, [])
	check("reachable cells in a corner", arena.reachable_cells().size(), 2)


func test_cursor() -> void:
	for start in [Vector2i(4, 3), Vector2i(3, 3)]:
		for c in [
			# Seams and the cells beside them
			[1, "D", Vector2(60, 0), true], [1, "DW", Vector2(60, -35), false], [1, "DS", Vector2(60, 35), false],
			[1, "A", Vector2(-60, 0), true], [1, "AW", Vector2(-60, -35), false], [1, "AS", Vector2(-60, 35), false],
			[1, "W", Vector2(0, -35), true], [1, "WW", Vector2(0, -70), false], [1, "WD", Vector2(60, -35), false],
			[1, "S", Vector2(0, 35), true], [1, "SS", Vector2(0, 70), false], [1, "SA", Vector2(-60, 35), false],
			[1, "DWAS", Vector2(0, 0), false], [1, "WWS", Vector2(0, -35), true], [1, "SSW", Vector2(0, 35), true],
			# Points that aren't allowed
			[1, "DD", Vector2(60, 0), true], [1, "WWW", Vector2(0, -70), false], [1, "DWD", Vector2(60, -35), false],
			[3, "DD", Vector2(120, 0), false], [3, "DDD", Vector2(180, 0), true], [3, "DDDD", Vector2(180, 0), true],
			[3, "DDDW", Vector2(180, -35), false], [3, "DDDWWD", Vector2(180, -70), true],
			[3, "WWWWWW", Vector2(0, -210), false], [3, "DSSSSS", Vector2(60, 175), false],
			# On to the diagonal cell when exactly one is allowed
			[1, "WWD", Vector2(60, -35), false], [1, "WWA", Vector2(-60, -35), false], [1, "SSD", Vector2(60, 35), false],
			[1, "DSS", Vector2(0, 70), false], [1, "ASS", Vector2(0, 70), false], [1, "DWW", Vector2(0, -70), false],
			[1, "AWW", Vector2(0, -70), false], [3, "WWWWWWD", Vector2(60, -175), false],
			[3, "DSSSSSS", Vector2(0, 210), false],
		]:
			check("%s range %d %s" % [start, c[0], c[1]], cursor_after(start, c[0], c[1]), [c[2], c[3]])
	cursor_after(Vector2i(4, 3), 99, "DDDDDDDDDDDD")
	check("right edge", arena.cursor, arena.cell_to_point(Vector2i(8, 3)))
	cursor_after(Vector2i(4, 3), 99, "WWWWWWWWWWWW")
	check("top edge", arena.cursor, arena.cell_to_point(Vector2i(4, 0)))
	check("bottom row, odd column: D goes to the only cell", cursor_after(Vector2i(5, 6), 1, "D"), [Vector2(60, -35), false])
	check("bottom row: S does nothing", cursor_after(Vector2i(4, 6), 1, "S"), [Vector2(0, 0), false])
	check("corner: A does nothing", cursor_after(Vector2i(0, 0), 1, "A"), [Vector2(0, 0), false])


func test_turns() -> void:
	for keys in ["E", "DE"]:
		setup(Vector2i(4, 3), 1, [FAR])
		press(keys)
		check("confirm on own cell or seam: no move, no turn", [arena.player_cell, arena.rivals[0].cell], [Vector2i(4, 3), FAR])
	setup(Vector2i(4, 3), 3, [FAR])
	press("DDE")
	check("confirm on a cell out of reach", arena.player_cell, Vector2i(4, 3))

	setup(Vector2i(4, 3), 1, [FAR])
	press("DWE")
	check("move to a neighbor", arena.player_cell, Vector2i(5, 2))
	check("cursor on the player after a move", arena.cursor, arena.cell_to_point(Vector2i(5, 2)))
	check("rival steps one closer", arena.distance(arena.rivals[0].cell, Vector2i(5, 2)), arena.distance(FAR, Vector2i(5, 2)) - 1)
	check("not finished", [arena.finished, results], [false, []])

	setup(Vector2i(4, 3), 1, [Vector2i(4, 2)])
	press("WWE")
	check("confirm on a rival's cell: no move, no turn", [arena.player_cell, arena.finished], [Vector2i(4, 3), false])

	setup(Vector2i(4, 3), 1, [Vector2i(6, 3)])
	press("DSE")
	check("ending a turn next to a rival loses", [arena.player_cell, arena.finished, results], [Vector2i(5, 3), true, [false]])
	check("loss text", arena.status_label.text, "A rival took your form.")
	press("AWE")
	check("no input after the end", [arena.player_cell, arena.cursor, results], [Vector2i(5, 3), arena.cell_to_point(Vector2i(5, 3)), [false]])

	setup(Vector2i(4, 3), 1, [Vector2i(6, 3)])
	for key in "DSE":
		press_one(key)
	check("the ending waits for the animation", [arena.finished, results, arena.status_label.text], [true, [], ""])
	check("the player is still drawn on the old cell", arena.player_position, arena.tile_map.map_to_local(Vector2i(4, 3)))
	arena.finish_animation()
	arena.finish_animation()
	check("the ending is announced once", results, [false])

	setup(Vector2i(7, 3), 1, [Vector2i(5, 3)])
	arena.goal_cell = Vector2i(8, 3)
	arena.goal_name = "HR desk"
	arena.finish_animation()
	check("objective text for a place", arena.status_label.text, "Reach the HR desk.")
	press("DWE")
	check("reaching the goal wins", [arena.player_cell, arena.finished, results], [Vector2i(8, 3), true, [true]])
	check("win text", arena.status_label.text, "You reached the HR desk.")
	check("rival does not act after a win", arena.rivals[0].cell, Vector2i(5, 3))

	setup(Vector2i(0, 3), 1, [Vector2i(6, 2), Vector2i(6, 3)])
	var shared := 0
	for keys in ["WWE", "SSE", "WWE", "SSE"]:
		press(keys)
		if arena.rivals[0].cell == arena.rivals[1].cell:
			shared += 1
	check("turns where two rivals share a cell", shared, 0)
	check("pieces are drawn on their cells after the animation", [arena.player_position, arena.rivals[0].position], [arena.tile_map.map_to_local(arena.player_cell), arena.tile_map.map_to_local(arena.rivals[0].cell)])
	check("both rivals came closer", [arena.distance(arena.rivals[0].cell, arena.player_cell) < 6, arena.distance(arena.rivals[1].cell, arena.player_cell) < 6], [true, true])


func test_queue_number() -> void:
	setup(Vector2i(4, 3), 1, [])
	arena.turns_left = 2
	arena.finish_animation()
	check("objective text for the queue", arena.status_label.text, "Your number is called in 2 turns.")
	press("WWE")
	check("one turn waited", [arena.turns_left, arena.finished, arena.status_label.text], [1, false, "Your number is called in 1 turn."])
	press("SSE")
	check("the queue number wins", [arena.finished, results, arena.status_label.text], [true, [true], "Your number was called."])

	setup(Vector2i(4, 3), 1, [Vector2i(6, 3)])
	arena.turns_left = 1
	press("DSE")
	check("a grab on the last turn still loses", results, [false])


func test_loop() -> void:
	arena.free()
	arena = null
	var loop = load("res://combat/loop_prototype.tscn").instantiate()
	loop.pause = 0.0
	root.add_child(loop)
	check("starts on the first stage", [loop.stage, loop.arena.goal_name, loop.floor_label.text], [0, "HR desk", "Floor 1 of 2"])
	loop.arena.combat_finished.emit(false)
	await create_timer(0.1).timeout
	check("a loss restarts the first stage", [loop.stage, loop.arena.finished], [0, false])
	loop.arena.combat_finished.emit(true)
	await create_timer(0.1).timeout
	check("a win goes to the next stage", [loop.stage, loop.arena.queue_turns, loop.arena.rivals.size(), loop.floor_label.text], [1, 8, 2, "Floor 2 of 2"])
	loop.arena.combat_finished.emit(false)
	await create_timer(0.1).timeout
	check("a loss on the second stage goes back to the first", loop.stage, 0)
	loop.arena.combat_finished.emit(true)
	await create_timer(0.1).timeout
	loop.arena.combat_finished.emit(true)
	await create_timer(0.1).timeout
	check("winning the last stage ends the run", [loop.stage, loop.floor_label.text], [1, "You got the job."])
	loop.free()


func test_dash() -> void:
	setup(Vector2i(0, 3), 1, [Vector2i(8, 3)])
	var steps: Array[int] = []
	var warnings: Array[bool] = []
	for keys in ["WWE", "SSE", "WWE", "SSE", "WWE"]:
		var before := arena.rivals[0].cell
		press(keys)
		steps.append(arena.distance(before, arena.rivals[0].cell))
		warnings.append(arena.rivals[0].turns_until_dash == 1)
	check("a rival moves two cells on every third turn", steps, [1, 1, 2, 1, 1])
	check("the warning shows on the turn before a dash", warnings, [false, true, false, false, true])

	setup(Vector2i(4, 3), 1, [Vector2i(7, 3)])
	arena.rivals[0].turns_until_dash = 1
	press("WWE")
	check("a dash from three cells away ends next to the player", [arena.distance(arena.rivals[0].cell, arena.player_cell), arena.finished], [1, false])

	setup(Vector2i(4, 3), 1, [Vector2i(6, 3)])
	arena.rivals[0].turns_until_dash = 1
	press("WWE")
	check("a dash from two cells away steps and grabs", [arena.distance(arena.rivals[0].cell, arena.player_cell), results], [1, [false]])
