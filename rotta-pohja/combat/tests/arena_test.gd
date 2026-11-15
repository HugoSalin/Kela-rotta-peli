extends SceneTree

# Tests the combat arena by pressing keys. Run from the repository root; exits with 1 on a failure:
#   timeout 30 godot --headless --path rotta-pohja --script res://combat/tests/arena_test.gd

const KEYS := {"W": "combat_up", "S": "combat_down", "A": "combat_left", "D": "combat_right", "E": "ui_accept", "1": "combat_ability_1", "2": "combat_ability_2", "3": "combat_ability_3", "4": "combat_ability_4"}
const FAR := Vector2i(8, 6)
const STAGES := preload("res://combat/loop_prototype.gd").STAGES

var arena: Arena
var results: Array[bool] = []
var checks := 0
var fails := 0


func check(what: String, actual, expected) -> void:
	checks += 1
	if actual != expected:
		fails += 1
		print("FAIL %s | expected %s | actual %s" % [what, expected, actual])


func setup(player: Vector2i, rival_cells: Array) -> void:
	if arena:
		arena.free()
	arena = load("res://combat/arena.tscn").instantiate()
	root.add_child(arena)
	arena.combat_finished.connect(func(won): results.append(won))
	results.clear()
	arena.player.cell = player
	arena.selection.point = arena.selection.cell_to_point(player)
	for cell in rival_cells:
		arena.add(Rival.new(cell))
	arena.view.finish()


func desks() -> Array:
	return arena.entities.filter(func(entity): return entity is Desk).map(func(entity): return entity.cell)


func set_desks(cells: Array) -> void:
	replace(Desk, cells)


func set_pillars(cells: Array) -> void:
	replace(Pillar, cells)


# Removes every entity of the kind and puts one on each of the cells.
func replace(kind: Script, cells: Array) -> void:
	for entity in arena.entities.duplicate():
		if is_instance_of(entity, kind):
			arena.remove(entity)
	for cell in cells:
		arena.add(kind.new(cell))


func press_one(key: String) -> void:
	var event := InputEventAction.new()
	event.action = KEYS[key]
	event.pressed = true
	arena.selection._unhandled_input(event)


# Presses the keys and skips the animation of the last turn.
func press(keys: String) -> void:
	for key in keys:
		press_one(key)
	arena.view.finish()


# The cursor's position relative to the player's start cell, and whether it is on a seam.
func cursor_after(player: Vector2i, reach: int, keys: String) -> Array:
	setup(player, [])
	arena.selection.ability.reaches[0] = reach
	press(keys)
	return [arena.selection.point_position(arena.selection.point) - arena.grid.map_to_local(player), arena.selection.is_seam(arena.selection.point)]


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	test_grid()
	test_layout()
	test_cursor()
	test_turns()
	test_queue_number()
	test_dash()
	test_shove()
	test_danger()
	test_throw_paper()
	test_throw_desk()
	test_dash_ability()
	await test_signals()
	test_several_rivals()
	test_stages_can_be_won()
	await test_loop()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails else 0)


func test_grid() -> void:
	setup(Vector2i(4, 3), [])
	var wrong_points := 0
	var wrong_distances := 0
	for cell in arena.grid.cells:
		var point := arena.selection.cell_to_point(cell)
		if arena.selection.is_seam(point) or arena.selection.point_to_cell(point) != cell or arena.selection.point_position(point) != arena.grid.map_to_local(cell):
			wrong_points += 1
		for neighbor in arena.grid.get_surrounding_cells(cell):
			if arena.grid.distance(cell, neighbor) != 1:
				wrong_distances += 1
	check("cells whose lattice point is wrong", wrong_points, 0)
	check("neighbors not at distance 1", wrong_distances, 0)
	check("distance corner to corner", arena.grid.distance(Vector2i(0, 0), Vector2i(8, 6)), 10)
	check("cells to pick in the middle: the neighbors and the player's own", arena.selection.action_cells().size(), 7)
	setup(Vector2i(0, 0), [])
	check("cells to pick in a corner", arena.selection.action_cells().size(), 3)


func test_layout() -> void:
	setup(Vector2i(4, 3), [])
	press("3")
	var shown := arena.view.bounds()
	var text_bottom := arena.view.ability_label.position.y + arena.view.ability_label.get_minimum_size().y
	check("a two-line prompt stays inside what the arena shows", [arena.view.ability_label.text.count("\n"), text_bottom <= shown.end.y], [1, true])
	check("which is centered and no taller than the game's window", [arena.position + shown.get_center(), shown.size.y <= ProjectSettings.get_setting("display/window/size/viewport_height")], [root.get_visible_rect().size / 2, true])


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
	check("right edge", arena.selection.point, arena.selection.cell_to_point(Vector2i(8, 3)))
	cursor_after(Vector2i(4, 3), 99, "WWWWWWWWWWWW")
	check("top edge", arena.selection.point, arena.selection.cell_to_point(Vector2i(4, 0)))
	check("bottom row, odd column: D goes to the only cell", cursor_after(Vector2i(5, 6), 1, "D"), [Vector2(60, -35), false])
	check("bottom row: S does nothing", cursor_after(Vector2i(4, 6), 1, "S"), [Vector2(0, 0), false])
	check("corner: A does nothing", cursor_after(Vector2i(0, 0), 1, "A"), [Vector2(0, 0), false])


func test_turns() -> void:
	setup(Vector2i(4, 3), [FAR])
	press("DE")
	check("confirm on a seam: no move, no turn", [arena.player.cell, arena.rivals()[0].cell], [Vector2i(4, 3), FAR])
	press("AE")
	check("confirm on own cell: no move, the turn passes", [arena.player.cell, arena.grid.distance(arena.rivals()[0].cell, FAR), arena.rivals()[0].turns_until_dash], [Vector2i(4, 3), 1, 2])
	press("2DDE")
	check("confirm on a cell in reach that can't be picked: no turn", [arena.selection.point, arena.selection.ability.title, arena.rivals()[0].turns_until_dash], [arena.selection.cell_to_point(Vector2i(6, 3)), "Throw paperwork", 2])

	setup(Vector2i(4, 3), [FAR])
	press("DWE")
	check("move to a neighbor", arena.player.cell, Vector2i(5, 2))
	check("cursor on the player after a move", arena.selection.point, arena.selection.cell_to_point(Vector2i(5, 2)))
	check("rival steps one closer", arena.grid.distance(arena.rivals()[0].cell, Vector2i(5, 2)), arena.grid.distance(FAR, Vector2i(5, 2)) - 1)
	check("not finished", [arena.finished, results], [false, []])

	setup(Vector2i(4, 3), [Vector2i(4, 2)])
	press("WWE")
	check("confirm on a rival's cell: no move, no turn", [arena.player.cell, arena.finished], [Vector2i(4, 3), false])

	setup(Vector2i(4, 3), [Vector2i(6, 3)])
	press("DSE")
	check("ending a turn next to a rival loses", [arena.player.cell, arena.finished, results], [Vector2i(5, 3), true, [false]])
	check("loss text", arena.view.status_label.text, "A rival took your form.")
	press("AWE")
	check("no input after the end", [arena.player.cell, arena.selection.point, results], [Vector2i(5, 3), arena.selection.cell_to_point(Vector2i(5, 3)), [false]])

	setup(Vector2i(4, 3), [Vector2i(6, 3)])
	for key in "DSE":
		press_one(key)
	check("the ending waits for the animation", [arena.finished, results, arena.view.status_label.text], [true, [], ""])
	check("the player is still drawn on the old cell", arena.view.position_of(arena.player), arena.grid.map_to_local(Vector2i(4, 3)))
	arena.view.finish()
	arena.view.finish()
	check("the ending is announced once", results, [false])

	setup(Vector2i(7, 3), [Vector2i(5, 3)])
	arena.goal_cell = Vector2i(8, 3)
	arena.goal_name = "HR desk"
	arena.view.finish()
	check("objective text for a place", arena.view.status_label.text, "Reach the HR desk.")
	press("DWE")
	check("reaching the goal wins", [arena.player.cell, arena.finished, results], [Vector2i(8, 3), true, [true]])
	check("win text", arena.view.status_label.text, "You reached the HR desk.")
	check("rival does not act after a win", arena.rivals()[0].cell, Vector2i(5, 3))

	setup(Vector2i(0, 3), [Vector2i(6, 2), Vector2i(6, 3)])
	var shared := 0
	for keys in ["WWE", "SSE", "WWE", "SSE"]:
		press(keys)
		if arena.rivals()[0].cell == arena.rivals()[1].cell:
			shared += 1
	check("turns where two rivals share a cell", shared, 0)
	check("pieces are drawn on their cells after the animation", [arena.view.position_of(arena.player), arena.view.position_of(arena.rivals()[0])], [arena.grid.map_to_local(arena.player.cell), arena.grid.map_to_local(arena.rivals()[0].cell)])
	check("both rivals came closer", [arena.grid.distance(arena.rivals()[0].cell, arena.player.cell) < 6, arena.grid.distance(arena.rivals()[1].cell, arena.player.cell) < 6], [true, true])


func test_queue_number() -> void:
	setup(Vector2i(4, 3), [])
	arena.turns_left = 2
	arena.view.finish()
	check("objective text for the queue", arena.view.status_label.text, "Your number is called in 2 turns.")
	press("WWE")
	check("one turn waited", [arena.turns_left, arena.finished, arena.view.status_label.text], [1, false, "Your number is called in 1 turn."])
	press("SSE")
	check("the queue number wins", [arena.finished, results, arena.view.status_label.text], [true, [true], "Your number was called."])

	setup(Vector2i(4, 3), [Vector2i(6, 3)])
	arena.turns_left = 1
	press("DSE")
	check("a grab on the last turn still loses", results, [false])


func test_dash() -> void:
	setup(Vector2i(0, 3), [Vector2i(8, 3)])
	var steps: Array[int] = []
	var warnings: Array[bool] = []
	for keys in ["WWE", "SSE", "WWE", "SSE", "WWE"]:
		var before := arena.rivals()[0].cell
		press(keys)
		steps.append(arena.grid.distance(before, arena.rivals()[0].cell))
		warnings.append(arena.rivals()[0].turns_until_dash == 1)
	check("a rival moves two cells on every third turn", steps, [1, 1, 2, 1, 1])
	check("the warning shows on the turn before a dash", warnings, [false, true, false, false, true])

	var dash_start := arena.rivals()[0].cell
	var side: int = arena.rivals()[0].dash_side
	check("the dash line is fixed when the warning starts", side != HexGrid.NO_SIDE, true)
	check("the preview shows the line", arena.rivals()[0].dash_cells(), [arena.grid.get_neighbor_cell(dash_start, side), arena.grid.get_neighbor_cell(arena.grid.get_neighbor_cell(dash_start, side), side)])
	press("SSE")
	check("the dash follows the line whatever the player did", arena.rivals()[0].cell, arena.grid.get_neighbor_cell(arena.grid.get_neighbor_cell(dash_start, side), side))
	check("no line after the dash", arena.rivals()[0].dash_side, HexGrid.NO_SIDE)

	for c in [
		["past a player who steps off the line", Vector2i(4, 3), "DSE", [], Vector2i(4, 2), []],
		["onto a player on the line", Vector2i(4, 3), "WWE", [], Vector2i(4, 1), [false]],
		["and grabs a player next to where it ends", Vector2i(4, 3), "DWE", [], Vector2i(4, 2), [false]],
		["up to a desk", Vector2i(4, 5), "DSE", [Vector2i(4, 2)], Vector2i(4, 1), []],
	]:
		setup(c[1], [Vector2i(4, 0)])
		set_desks(c[3])
		arena.rivals()[0].turns_until_dash = 1
		arena.rivals()[0].dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
		press(c[2])
		check("a dash goes %s" % c[0], [arena.rivals()[0].cell, results], [c[4], c[5]])

	setup(Vector2i(4, 5), [Vector2i(4, 0)])
	arena.rivals()[0].dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	check("the grab preview is the cells around the dash's end", [arena.rivals()[0].dash_cells(), arena.rivals()[0].grab_cells().size(), Vector2i(4, 3) in arena.rivals()[0].grab_cells(), Vector2i(4, 1) in arena.rivals()[0].grab_cells()], [[Vector2i(4, 1), Vector2i(4, 2)], 5, true, false])

	setup(Vector2i(4, 1), [Vector2i(4, 0)])
	arena.rivals()[0].dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	check("a player on the line does not shorten the preview", [arena.rivals()[0].dash_cells(), arena.rivals()[0].grab_cells().size()], [[Vector2i(4, 1), Vector2i(4, 2)], 5])

	setup(Vector2i(4, 4), [Vector2i(4, 1)])
	set_desks([Vector2i(4, 2)])
	press("SSE")
	check("a rival walks around a desk", arena.rivals()[0].cell in [Vector2i(3, 1), Vector2i(5, 1)], true)
	press("SSE")
	press("AWE")
	press("DWE")
	check("and reaches the player's side of it", arena.rivals()[0].cell.y >= 2, true)


func test_shove() -> void:
	setup(Vector2i(4, 3), [Vector2i(4, 2)])
	press("WWE")
	var rival := arena.rivals()[0]
	check("shove into free floor: pushed back, no motivation lost, skips one turn", [arena.player.cell, rival.motivation, rival.stunned_turns, rival.turns_until_dash, rival.cell], [Vector2i(4, 3), 3, 0, 3, Vector2i(4, 1)])
	press("SSSSE")
	check("then it acts again", [rival.cell, rival.turns_until_dash], [Vector2i(4, 2), 2])

	for blocked in ["desk", "edge"]:
		var player := Vector2i(4, 1) if blocked == "edge" else Vector2i(4, 3)
		var cell := player + Vector2i.UP
		setup(player, [cell])
		if blocked == "desk":
			set_desks([cell + Vector2i.UP])
		rival = arena.rivals()[0]
		press("WWE")
		check("shove into the %s: stays, loses motivation, stunned for two turns" % blocked, [rival.cell, rival.motivation, rival.stunned_turns, rival.turns_until_dash], [cell, 2, 1, 3])
		press("SSSSE")
		check("second stunned turn (%s)" % blocked, [rival.cell, rival.stunned_turns, rival.turns_until_dash, arena.finished], [cell, 0, 3, false])
		press("SSE")
		check("then it acts again (%s)" % blocked, [rival.cell != cell, rival.turns_until_dash], [true, 2])

	setup(Vector2i(4, 4), [Vector2i(4, 3), Vector2i(4, 2)])
	press("WWE")
	check("shove into a rival with room behind: both slide back", [arena.rivals()[0].cell, arena.rivals()[0].motivation, arena.rivals()[0].stunned_turns, arena.rivals()[1].motivation, arena.rivals()[1].stunned_turns], [Vector2i(4, 2), 2, 0, 2, 0])
	check("the rival behind was pushed and then acted", arena.grid.distance(arena.rivals()[1].cell, Vector2i(4, 1)) <= 1, true)

	setup(Vector2i(4, 4), [Vector2i(4, 3), Vector2i(4, 2)])
	set_desks([Vector2i(4, 1)])
	press("WWE")
	check("shove into a rival with a desk behind: both stay and lose motivation, the one at the desk is stunned longer", arena.rivals().map(func(r): return [r.cell, r.motivation, r.stunned_turns]), [[Vector2i(4, 3), 2, 0], [Vector2i(4, 2), 2, 1]])

	setup(Vector2i(4, 5), [Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2)])
	press("WWE")
	check("three rivals in a row: the third is not affected", arena.rivals().map(func(r): return [r.cell, r.motivation, r.stunned_turns]).slice(0, 2) + [arena.rivals()[2].motivation], [[Vector2i(4, 4), 2, 0], [Vector2i(4, 3), 2, 0], 3])

	setup(Vector2i(4, 3), [Vector2i(4, 2), FAR])
	arena.rival_starts.assign([Vector2i(4, 2), FAR])
	set_desks([Vector2i(4, 1)])
	arena.rivals()[1].stunned_turns = 99
	press("WWE")
	press("WWE")
	check("a rival can be shoved until its motivation is gone", [arena.rivals().size(), arena.rivals()[0].motivation], [2, 1])
	press("WWE")
	check("then it leaves", [arena.rivals().size(), arena.finished], [1, false])
	arena.player.cell = Vector2i(4, 3)
	arena.rivals()[0].cell = Vector2i(4, 2)
	arena.rivals()[0].motivation = 1
	arena.selection.point = arena.selection.cell_to_point(Vector2i(4, 3))
	press("WWE")
	check("the last rival leaving wins", [arena.rivals().size(), results, arena.view.status_label.text], [0, [true], "Every rival gave up."])

	setup(Vector2i(4, 3), [Vector2i(4, 2)])
	arena.rivals()[0].turns_until_dash = 1
	arena.rivals()[0].dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	press("WWE")
	check("a shoved rival waits with its dash and keeps the line", [arena.rivals()[0].cell, arena.rivals()[0].turns_until_dash, arena.rivals()[0].dash_side, results], [Vector2i(4, 1), 1, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, []])
	press("DE")
	check("then it dashes along it and grabs the player beside its end", [arena.rivals()[0].cell, results], [Vector2i(4, 3), [false]])

	setup(Vector2i(4, 3), [FAR])
	set_desks([Vector2i(4, 2)])
	press("WWE")
	check("no move onto a desk, no turn", [arena.player.cell, arena.rivals()[0].turns_until_dash], [Vector2i(4, 3), 3])


func test_danger() -> void:
	setup(Vector2i(0, 0), [Vector2i(4, 3)])
	var rival := arena.rivals()[0]
	check("a rival that acts normally marks no danger", arena.danger_cells(), [])
	rival.stunned_turns = 1
	check("a stunned rival is harmless", arena.danger_cells(), [])
	rival.stunned_turns = 0
	rival.turns_until_dash = 1
	rival.dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	check("a dashing rival endangers its line and end, not its own neighbors", [arena.danger_cells().size(), Vector2i(4, 2) in arena.danger_cells(), Vector2i(4, 5) in arena.danger_cells()], [7, false, true])
	rival.dash_side = HexGrid.NO_SIDE
	check("a dash without a line endangers the rival's neighbors", arena.danger_cells().size(), 6)

	setup(Vector2i(4, 5), [Vector2i(4, 2)])
	press("DWE")
	check("moving next to a rival loses", [Vector2i(5, 4) in arena.danger_cells(), results], [false, []])
	press("WWE")
	check("and it does", results, [false])


func test_throw_paper() -> void:
	setup(Vector2i(4, 5), [Vector2i(4, 2), Vector2i(4, 0)])
	arena.rivals()[0].stunned_turns = 99
	arena.rivals()[1].stunned_turns = 99
	# The game's abilities have no cooldown; this gives one a cooldown to check the mechanism.
	arena.player.abilities[1].cooldown = 3
	press("2")
	check("key 2 chooses the throw: range 2 to 3, only rivals in range", [arena.selection.ability.title, arena.selection.min_reach(), arena.selection.reach(), arena.selection.action_cells()], ["Throw paperwork", 2, 3, [Vector2i(4, 2)]])
	check("the ability line marks it", arena.view.ability_label.text, "[1] Move / Shove   > [2] Throw paperwork   [3] Throw desk   [4] Dash\nPick a rival.")
	press("1")
	check("key 1 goes back", [arena.selection.ability.title, arena.selection.reach()], ["Move / Shove", 1])
	press("2WWWWWWE")
	check("a throw costs motivation, takes the turn and goes back to moving", [arena.rivals()[0].motivation, arena.rivals()[0].stunned_turns, arena.selection.ability.title, arena.player.abilities[1].turns_until_ready], [2, 98, "Move / Shove", 3])
	check("the cursor returns from outside the range", arena.selection.point, arena.selection.cell_to_point(Vector2i(4, 5)))
	check("the ability line shows the cooldown", arena.view.ability_label.text, "> [1] Move / Shove   [2] Throw paperwork (3)   [3] Throw desk   [4] Dash\n")
	press("2")
	check("it can't be chosen while cooling down", arena.selection.ability.title, "Move / Shove")
	var waits: Array[int] = []
	for keys in ["WWE", "SSE", "WWE"]:
		press(keys)
		waits.append(arena.player.abilities[1].turns_until_ready)
	check("the cooldown counts down each turn", waits, [2, 1, 0])
	press("2")
	check("then it is ready", arena.selection.ability.title, "Throw paperwork")

	setup(Vector2i(4, 5), [Vector2i(4, 2)])
	set_pillars([Vector2i(4, 3)])
	press("2")
	check("a pillar blocks the throw", arena.selection.action_cells(), [])
	set_pillars([])
	set_desks([Vector2i(4, 3)])
	check("a desk does not", arena.selection.action_cells(), [Vector2i(4, 2)])
	check("the range is the cells 2 to 3 away in sight", [Vector2i(4, 2) in arena.selection.range_cells(), Vector2i(6, 5) in arena.selection.range_cells(), Vector2i(4, 1) in arena.selection.range_cells(), Vector2i(4, 4) in arena.selection.range_cells()], [true, true, false, false])
	arena.rivals()[0].cell = Vector2i(4, 4)
	check("a rival next to the player is too near", arena.selection.action_cells(), [])
	set_desks([])
	set_pillars([Vector2i(4, 3)])
	check("not those behind a pillar", Vector2i(4, 2) in arena.selection.range_cells(), false)

	setup(Vector2i(4, 5), [Vector2i(5, 3)])
	set_pillars([Vector2i(5, 4)])
	press("2")
	check("a throw passes along the border of one pillar", arena.selection.action_cells(), [Vector2i(5, 3)])
	set_pillars([Vector2i(5, 4), Vector2i(4, 4)])
	check("but not between two", arena.selection.action_cells(), [])

	setup(Vector2i(4, 5), [Vector2i(4, 3)])
	arena.rivals()[0].motivation = 1
	press("2WWWWE")
	check("a throw that takes the last motivation wins", [arena.rivals().size(), results], [0, [true]])


func test_throw_desk() -> void:
	setup(Vector2i(4, 5), [FAR])
	arena.rivals()[0].stunned_turns = 99
	press("3")
	check("no desk next to the player: nothing to pick", arena.selection.action_cells(), [])
	set_desks([Vector2i(4, 4)])
	set_pillars([Vector2i(5, 4)])
	arena.goal_cell = Vector2i(3, 4)
	check("the desk next to the player can be picked", [arena.selection.reach(), arena.selection.action_cells()], [1, [Vector2i(4, 4)]])
	press("WWE")
	var landing := arena.selection.action_cells()
	check("then where it lands, next to the player, no turn yet", [arena.selection.picks, arena.selection.reach(), arena.rivals()[0].stunned_turns], [[Vector2i(4, 4)], 1, 99])
	check("not on the player, a desk, a pillar or the goal", [Vector2i(4, 5) in landing, Vector2i(4, 4) in landing, Vector2i(5, 4) in landing, Vector2i(3, 4) in landing], [false, false, false, false])
	check("on a free cell next to the player, not farther", [Vector2i(5, 5) in landing, Vector2i(4, 3) in landing], [true, false])
	press("3")
	check("choosing it again starts the picks over", [arena.selection.picks, arena.selection.reach()], [[], 1])
	press("WWESSDSE")
	check("the desk lands on the picked cell and the turn passes", [desks(), arena.rivals()[0].stunned_turns, arena.player.abilities[2].turns_until_ready, arena.selection.ability.title], [[Vector2i(5, 5)], 98, 0, "Move / Shove"])

	setup(Vector2i(4, 5), [Vector2i(5, 5)])
	set_desks([Vector2i(4, 4)])
	press("3WWESSDSE")
	check("a desk thrown at a rival breaks, demotivates and stuns it", [desks(), arena.rivals()[0].motivation, arena.rivals()[0].stunned_turns], [[], 2, 1])

	setup(Vector2i(4, 5), [FAR])
	arena.rivals()[0].stunned_turns = 99
	set_desks([Vector2i(4, 4)])
	check("while moving, a desk next to the player can be picked", Vector2i(4, 4) in arena.selection.action_cells(), true)
	press("WWE")
	check("picking it starts the desk throw with it", [arena.selection.ability.title, arena.selection.picks, arena.rivals()[0].stunned_turns], ["Throw desk", [Vector2i(4, 4)], 99])
	press("1")
	arena.player.desk_throw.turns_until_ready = 2
	check("not while the throw cools down", Vector2i(4, 4) in arena.selection.action_cells(), false)

	setup(Vector2i(4, 3), [FAR])
	arena.rivals()[0].stunned_turns = 99
	set_pillars([Vector2i(4, 2)])
	press("WWE")
	check("no move onto a pillar", [arena.player.cell, arena.rivals()[0].stunned_turns], [Vector2i(4, 3), 99])
	setup(Vector2i(4, 4), [Vector2i(4, 3)])
	set_pillars([Vector2i(4, 2)])
	press("WWE")
	check("a shove into a pillar is a shove into a wall", [arena.rivals()[0].cell, arena.rivals()[0].motivation, arena.rivals()[0].stunned_turns], [Vector2i(4, 3), 2, 1])


func test_dash_ability() -> void:
	setup(Vector2i(4, 3), [Vector2i(4, 2), Vector2i(6, 4)])
	arena.rivals()[0].stunned_turns = 99
	arena.rivals()[1].stunned_turns = 99
	press("4")
	var landings := arena.selection.action_cells()
	check("key 4 chooses the dash: two cells away in the six directions, not onto a rival", [arena.selection.ability.title, arena.selection.reach(), landings.size(), Vector2i(4, 1) in landings, Vector2i(6, 4) in landings, Vector2i(5, 2) in landings], ["Dash", 2, 5, true, false, false])
	set_desks([Vector2i(2, 2)])
	set_pillars([Vector2i(5, 2)])
	check("not onto a desk, not across a pillar", [Vector2i(2, 2) in arena.selection.action_cells(), Vector2i(6, 2) in arena.selection.action_cells()], [false, false])
	set_desks([Vector2i(3, 3)])
	check("not across a desk", Vector2i(2, 4) in arena.selection.action_cells(), false)
	press("WWWWE")
	check("a dash through a rival lands behind it, costs it motivation and starts the cooldown", [arena.player.cell, arena.rivals()[0].motivation, arena.rivals()[0].cell, arena.player.abilities[3].turns_until_ready, arena.selection.ability.title], [Vector2i(4, 1), 2, Vector2i(4, 2), 3, "Move / Shove"])
	setup(Vector2i(0, 0), [])
	press("4")
	check("the corner has only the landings inside the arena", arena.selection.action_cells(), [Vector2i(0, 2), Vector2i(2, 1)])


func test_signals() -> void:
	setup(Vector2i(4, 5), [Vector2i(4, 3)])
	arena.rivals()[0].stunned_turns = 99
	var events: Array[String] = []
	var kind := func(entity: Entity) -> String: return entity.get_script().get_global_name()
	arena.entity_added.connect(func(entity): events.append("added " + kind.call(entity)))
	arena.entity_moved.connect(func(entity, _from, _to): events.append("moved " + kind.call(entity)))
	arena.entity_blocked.connect(func(entity, _toward): events.append("blocked " + kind.call(entity)))
	arena.entity_removed.connect(func(entity): events.append("removed " + kind.call(entity)))
	press("2WWWWE")
	check("a paperwork throw reports the paper added, moved and removed, in that order", events, ["added Paperwork", "moved Paperwork", "removed Paperwork"])

	setup(Vector2i(4, 5), [Vector2i(4, 3)])
	var rival: Entity = arena.rivals()[0]
	for key in "2WWWWE":
		press_one(key)
	check("the view shows a rival's dots as they were while the paper flies", [rival.pips(), arena.view.drawn[rival].look.pips], [2, 3])
	await create_timer(0.3).timeout
	check("and one fewer once it has landed, before the animation is over", [arena.view.drawn[rival].look.pips, arena.view.animation != null], [2, true])
	arena.view.finish()


func test_several_rivals() -> void:
	arena.free()
	arena = load("res://combat/arena.tscn").instantiate()
	arena.rival_starts.assign([FAR, Vector2i(8, 0), Vector2i(8, 3), Vector2i(0, 6)])
	root.add_child(arena)
	check("a stage's rivals start their dash countdowns a turn apart", arena.rivals().map(func(rival): return rival.turns_until_dash), [3, 4, 5, 3])
	test_intern()

	setup(Vector2i(6, 1), [Vector2i(3, 2), Vector2i(4, 0)])
	set_desks([Vector2i(4, 3)])
	var dasher := arena.rivals()[1]
	dasher.turns_until_dash = 1
	dasher.dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	var ends := []
	arena.entity_acted.connect(func(entity): if entity is Player or entity is Rival: ends.append([dasher.dash_cells(), dasher.dash_end()]))
	press("SSE")
	check("a rival that steps onto a dash line keeps the line whole and moves its end, in its own turn", ends.slice(0, 2), [[[Vector2i(4, 1), Vector2i(4, 2)], Vector2i(4, 2)], [[Vector2i(4, 1), Vector2i(4, 2)], Vector2i(4, 1)]])
	check("the dash stops before it and costs it motivation", [dasher.cell, arena.rivals()[0].cell, arena.rivals()[0].motivation], [Vector2i(4, 1), Vector2i(4, 2), 2])

	setup(Vector2i(8, 6), [Vector2i(4, 0), Vector2i(4, 1)])
	arena.rivals()[1].stunned_turns = 99
	arena.rivals()[1].motivation = 1
	arena.rivals()[0].turns_until_dash = 1
	arena.rivals()[0].dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	press("E")
	check("a dash passes through a rival, which here gives up and takes no turn", [arena.rivals().size(), arena.rivals()[0].cell], [1, Vector2i(4, 2)])

	setup(Vector2i(4, 5), [Vector2i(4, 2)])
	arena.rivals()[0].turns_until_dash = 1
	arena.rivals()[0].dash_side = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	press("2WWWWWWE")
	check("thrown paperwork calls off a warned dash: the countdown starts over and the rival steps", [arena.rivals()[0].motivation, arena.rivals()[0].turns_until_dash, arena.rivals()[0].dash_side, arena.rivals()[0].cell, arena.danger_cells(), results], [2, 2, HexGrid.NO_SIDE, Vector2i(4, 3), [], []])

	setup(Vector2i(0, 0), [Vector2i(0, 1), Vector2i(0, 3)])
	set_desks([Vector2i(1, 0)])
	arena.rivals()[0].stunned_turns = 99
	press("E")
	check("a rival with no way around another queues up behind it", arena.rivals()[1].cell, Vector2i(0, 2))


func test_intern() -> void:
	arena.free()
	arena = load("res://combat/arena.tscn").instantiate()
	arena.rival_starts.assign([FAR])
	arena.intern_starts.assign([Vector2i(8, 0)])
	root.add_child(arena)
	check("a stage's interns come after its rivals and join their countdowns", arena.rivals().map(func(rival): return [rival is Intern, rival.turns_until_dash]), [[false, 3], [true, 4]])

	setup(Vector2i(4, 6), [])
	var intern := Intern.new(Vector2i(4, 1))
	arena.add(intern)
	arena.view.finish()
	press("E")
	check("an intern walks two cells a turn", intern.cell, Vector2i(4, 3))
	press("E")
	check("and stops next to the player", [intern.cell, results], [Vector2i(4, 5), []])
	press("E")
	check("where it takes the form", results, [false])

	setup(Vector2i(4, 6), [])
	intern = Intern.new(Vector2i(4, 4))
	arena.add(intern)
	intern.stunned_turns = 99
	arena.view.finish()
	press("2WWWWE")
	press("2WWWWE")
	check("an intern gives up after two throws", [arena.rivals().size(), results], [0, [true]])


# Tries every sequence of moves and shoves (not picking desks), so it fails when a stage can't be won with them.
# The throws are left out: with them the search takes too long, and a stage that can be won
# without them can be won.
func test_stages_can_be_won() -> void:
	for scene in STAGES:
		if arena:
			arena.free()
		arena = scene.instantiate()
		root.add_child(arena)
		var seen := {snapshot(): true}
		var frontier := [snapshot()]
		var can_win := false
		while not frontier.is_empty() and not can_win:
			var next := []
			for state in frontier:
				restore(state)
				for cell in arena.selection.action_cells():
					if arena.is_throwable(cell):
						continue
					restore(state)
					arena.selection.pick(cell)
					if arena.won:
						can_win = true
					elif not arena.finished and not seen.has(snapshot()):
						seen[snapshot()] = true
						next.append(snapshot())
			frontier = next
		check("%s can be won" % scene.resource_path.get_file(), can_win, true)


func snapshot() -> Array:
	return [arena.player.cell, arena.turns_left, desks(), arena.player.abilities.map(func(ability): return ability.turns_until_ready), arena.rivals().map(func(rival): return [rival.get_script(), rival.cell, rival.turns_until_dash, rival.motivation, rival.stunned_turns, rival.dash_side])]


func restore(state: Array) -> void:
	arena.finished = false
	arena.won = false
	arena.announced = false
	arena.player.cell = state[0]
	arena.turns_left = state[1]
	set_desks(state[2])
	for index in arena.player.abilities.size():
		arena.player.abilities[index].turns_until_ready = state[3][index]
	arena.selection.ability = arena.player.abilities[0]
	arena.selection.picks.clear()
	for rival in arena.rivals():
		arena.remove(rival)
	for values in state[4]:
		var rival: Rival = values[0].new(values[1])
		rival.turns_until_dash = values[2]
		rival.motivation = values[3]
		rival.stunned_turns = values[4]
		rival.dash_side = values[5]
		arena.add(rival)


func test_loop() -> void:
	arena.free()
	arena = null
	var loop = load("res://combat/loop_prototype.tscn").instantiate()
	loop.pause = 0.0
	root.add_child(loop)
	check("starts on the first stage", [loop.stage, loop.arena.goal_name, loop.floor_label.text], [0, "HR desk", "Floor 1 of 3"])
	loop.arena.combat_finished.emit(false)
	await create_timer(0.1).timeout
	check("a loss restarts the first stage", [loop.stage, loop.arena.finished], [0, false])
	loop.arena.combat_finished.emit(true)
	await create_timer(0.1).timeout
	check("a win goes to the next stage", [loop.stage, loop.arena.queue_turns, loop.arena.rivals().size(), loop.floor_label.text], [1, 8, 2, "Floor 2 of 3"])
	loop.arena.combat_finished.emit(false)
	await create_timer(0.1).timeout
	check("a loss on the second stage goes back to the first", loop.stage, 0)
	for stage in 3:
		loop.arena.combat_finished.emit(true)
		await create_timer(0.1).timeout
	check("winning the last stage ends the run", [loop.stage, loop.floor_label.text], [2, "You got the job."])
	loop.free()
