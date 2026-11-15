extends SceneTree

# Makes the tile set stages are painted with: the floor and one tile per kind of piece,
# each drawn as the game draws that piece. Run it from the repository root after adding a
# kind or changing a piece's look, then import the project:
#   godot --headless --path rotta-pohja --script res://combat/tools/make_stage_tiles.gd
#   godot --headless --path rotta-pohja --import

const IMAGE_PATH := "res://combat/stage_tiles.png"
const TILE_SET_PATH := "res://combat/stage_tiles.tres"
const TILE := Vector2i(80, 70)
const FLOOR_LINE := 2.0
const MARK_SIZE := 0.85
const MARK_LINE := 5.0
const NONE := Color(0, 0, 0, 0)

var image: Image


func _initialize() -> void:
	var kinds := Kinds.ALL.keys()
	image = Image.create_empty(TILE.x * kinds.size(), TILE.y * 2, false, Image.FORMAT_RGBA8)
	paint_hex(Kinds.FLOOR_TILE, 1.0, ArenaView.FLOOR_COLOR, ArenaView.LINE_COLOR, FLOOR_LINE)
	# A piece's color may depend on the board, so it gets an empty one.
	var arena := Arena.new()
	for kind in kinds:
		var entity := Kinds.create(kind, Vector2i.ZERO)
		entity.arena = arena
		match entity.shape:
			Entity.Shape.HEX:
				paint_hex(Kinds.tile(kind), 1.0, entity.color(), ArenaView.LINE_COLOR, FLOOR_LINE)
			Entity.Shape.CIRCLE:
				paint_circle(Kinds.tile(kind), entity.radius, entity.color())
			Entity.Shape.MARK:
				paint_hex(Kinds.tile(kind), MARK_SIZE, NONE, entity.color(), MARK_LINE)
	arena.free()
	image.save_png(IMAGE_PATH)
	ResourceSaver.save(tile_set(kinds), TILE_SET_PATH)
	quit()


# ---- The tile set ----

func tile_set(kinds: Array) -> TileSet:
	var result := TileSet.new()
	result.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	result.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	result.tile_size = TILE
	result.add_custom_data_layer()
	result.set_custom_data_layer_name(0, "kind")
	result.set_custom_data_layer_type(0, TYPE_STRING)
	var source := TileSetAtlasSource.new()
	# The tile set refers to the image file instead of holding a copy of it.
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(IMAGE_PATH)
	source.texture = texture
	source.texture_region_size = TILE
	result.add_source(source)
	source.create_tile(Kinds.FLOOR_TILE)
	for kind in kinds:
		source.create_tile(Kinds.tile(kind))
		source.get_tile_data(Kinds.tile(kind), 0).set_custom_data("kind", kind)
	return result


# ---- Painting ----

# A hex of that share of the tile, filled, with a line along its edge.
func paint_hex(tile: Vector2i, size: float, fill: Color, line: Color, line_width: float) -> void:
	var half := Vector2(TILE) / 2
	# How much shorter a step straight toward a slanted edge is than a step sideways.
	var slant := half.y / Vector2(half.x / 2, half.y).length()
	for x in TILE.x:
		for y in TILE.y:
			var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - half).abs()
			var depth: float = min(half.y * size - offset.y, (half.x * size - offset.y * half.x / 2 / half.y - offset.x) * slant)
			if abs(depth) <= line_width / 2:
				image.set_pixel(tile.x * TILE.x + x, tile.y * TILE.y + y, line)
			elif depth > 0 and fill.a > 0:
				image.set_pixel(tile.x * TILE.x + x, tile.y * TILE.y + y, fill)


func paint_circle(tile: Vector2i, radius: float, fill: Color) -> void:
	var half := Vector2(TILE) / 2
	for x in TILE.x:
		for y in TILE.y:
			if (Vector2(x, y) + Vector2(0.5, 0.5) - half).length() <= radius:
				image.set_pixel(tile.x * TILE.x + x, tile.y * TILE.y + y, fill)
