## Stan domenowy symulacji — jedyne źródło prawdy.
##
## Scene Tree nie przechowuje żadnej z tych wartości. Warstwa prezentacji czyta
## wyłącznie snapshot i nigdy nie zapisuje niczego z powrotem.
class_name SimulationState
extends RefCounted

const OUTCOME_NONE := "NONE"
const OUTCOME_INTRUDER_DETECTED := "INTRUDER_DETECTED"
const OUTCOME_INTRUDER_SUCCESS := "INTRUDER_SUCCESS"
const OUTCOME_TICK_LIMIT := "TICK_LIMIT"

var tick: int
var outcome: String

var grid: Grid
var guard: GuardFsm
var intruder: IntruderScript

var camera_id: String
var camera_position: Vector2i
var camera_facing: Vector2i
var camera_range: int

var max_ticks: int


func _init(scenario: ScenarioL0) -> void:
	grid = Grid.new(scenario.grid_width, scenario.grid_height)
	guard = GuardFsm.new(
		ScenarioL0.GUARD_ID,
		scenario.guard_start,
		scenario.guard_facing,
		scenario.guard_waypoints,
		scenario.guard_view_range)
	intruder = IntruderScript.new(ScenarioL0.INTRUDER_ID, scenario.intruder_route)
	camera_id = ScenarioL0.CAMERA_ID
	camera_position = scenario.camera_position
	camera_facing = scenario.camera_facing
	camera_range = scenario.camera_range
	max_ticks = scenario.max_ticks
	reset()


func reset() -> void:
	tick = 0
	outcome = OUTCOME_NONE
	guard.reset()
	intruder.reset()


func is_finished() -> bool:
	return outcome != OUTCOME_NONE


## Pełny snapshot dla warstwy prezentacji i testów.
## Zwracany słownik jest kopią — widok nie może przez niego zmienić stanu.
func to_snapshot() -> Dictionary:
	return {
		"tick": tick,
		"outcome": outcome,
		"grid_size": grid.size(),
		"guard_id": guard.id,
		"guard_state": guard.state,
		"guard_position": guard.position,
		"guard_facing": guard.facing,
		"guard_view_range": guard.view_range,
		"guard_waypoint_index": guard.waypoint_index,
		"guard_visible_streak": guard.visible_streak,
		"guard_resume_point": guard.resume_point,
		"guard_waypoints": guard.get_waypoints(),
		"intruder_id": intruder.id,
		"intruder_state": intruder.state,
		"intruder_position": intruder.position,
		"intruder_route_index": intruder.route_index,
		"intruder_route": intruder.get_route(),
		"camera_id": camera_id,
		"camera_position": camera_position,
		"camera_facing": camera_facing,
		"camera_range": camera_range,
	}


## Kanoniczna reprezentacja stanu: jawnie zdefiniowana, stała kolejność pól.
## Nie opieramy porównań na domyślnej serializacji Dictionary.
func to_canonical() -> String:
	var lines := PackedStringArray([
		"tick=%d" % tick,
		"outcome=%s" % outcome,
		"grid_size=%s" % _cell(grid.size()),
		"guard_id=%s" % guard.id,
		"guard_state=%s" % guard.state,
		"guard_position=%s" % _cell(guard.position),
		"guard_facing=%s" % _cell(guard.facing),
		"guard_waypoint_index=%d" % guard.waypoint_index,
		"guard_visible_streak=%d" % guard.visible_streak,
		"guard_resume_point=%s" % _cell(guard.resume_point),
		"intruder_id=%s" % intruder.id,
		"intruder_state=%s" % intruder.state,
		"intruder_position=%s" % _cell(intruder.position),
		"intruder_route_index=%d" % intruder.route_index,
		"camera_id=%s" % camera_id,
		"camera_position=%s" % _cell(camera_position),
		"camera_facing=%s" % _cell(camera_facing),
		"camera_range=%d" % camera_range,
	])
	return "\n".join(lines)


## Nazwy pól snapshotu w kanonicznej kolejności — używane przez testy
## do wskazania pierwszego różniącego się pola.
static func canonical_field_names() -> PackedStringArray:
	return PackedStringArray([
		"tick", "outcome", "grid_size",
		"guard_id", "guard_state", "guard_position", "guard_facing",
		"guard_waypoint_index", "guard_visible_streak", "guard_resume_point",
		"intruder_id", "intruder_state", "intruder_position", "intruder_route_index",
		"camera_id", "camera_position", "camera_facing", "camera_range",
	])


static func _cell(value: Vector2i) -> String:
	return "%d,%d" % [value.x, value.y]
