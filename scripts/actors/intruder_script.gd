## Domenowy intruz: stan FSM i pozycja na jawnej trasie.
##
## Brak node'ów, brak sceny, brak delty. Ruch to przejście do następnej komórki
## jawnej listy — bez pathfindingu, AStar i NavMesh.
class_name IntruderScript
extends RefCounted

const STATE_MOVE := "MOVE"
const STATE_DETECTED := "DETECTED"
const STATE_SUCCESS := "SUCCESS"

var id: String
var state: String
var position: Vector2i
var route_index: int

var _route: Array[Vector2i] = []


func _init(p_id: String, p_route: Array[Vector2i]) -> void:
	id = p_id
	_route = p_route.duplicate()
	reset()


func reset() -> void:
	state = STATE_MOVE
	route_index = 0
	position = _route[0]


func route_size() -> int:
	return _route.size()


func get_route() -> Array[Vector2i]:
	return _route.duplicate()


func is_terminal() -> bool:
	return state == STATE_DETECTED or state == STATE_SUCCESS


## Czy intruz stoi na ostatniej komórce trasy.
func has_reached_route_end() -> bool:
	return route_index >= _route.size() - 1


## Jeden krok ruchu: najwyżej do następnej komórki trasy.
func advance() -> void:
	if state != STATE_MOVE or has_reached_route_end():
		return
	route_index += 1
	position = _route[route_index]
