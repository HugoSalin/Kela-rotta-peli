class_name Kinds

# Every kind of piece a stage can paint. A tile of the stage tile set carries a kind's
# name as its custom data `kind`. Add a kind at the end: a painted stage refers to a tile
# by its place in this list.

static var ALL: Dictionary[String, Dictionary] = {
	"player": {type = Player},
	"enemy": {type = Enemy},
	"intern": {type = Intern},
	"manager": {type = Manager},
	"desk": {type = Desk},
	"pillar": {type = Pillar},
	"chair": {type = Chair},
	"keycard": {type = Keycard},
	"wet_floor": {type = WetFloor},
	"elevator": {type = Elevator},
	"goal": {type = Goal},
}
const FLOOR_TILE := Vector2i(0, 0)


# A piece of that kind: its type, with the properties the kind sets.
static func create(kind: String, cell: Vector2i) -> Entity:
	var entity: Entity = ALL[kind].type.new(cell)
	var properties: Dictionary = ALL[kind].get("properties", {})
	for property in properties:
		entity.set(property, properties[property])
	return entity


# Where the kind's tile is in the tile set's image: the kinds fill the row under the floor.
static func tile(kind: String) -> Vector2i:
	return Vector2i(ALL.keys().find(kind), 1)
