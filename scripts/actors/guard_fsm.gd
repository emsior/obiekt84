## Domenowa maszyna stanów strażnika wraz z jego deterministycznym ruchem.
##
## Licznik kolejnych ticków widoczności intruza należy do tego stanu domenowego,
## nie do żadnego node'a. Ruch między waypointami: najpierw oś X, potem oś Y,
## najwyżej jedna komórka na tick, bez omijania przeszkód.
class_name GuardFsm
extends RefCounted

const STATE_PATROL := "PATROL"
const STATE_SUSPICION := "SUSPICION"
const STATE_ALARM := "ALARM"
const STATE_RETURN := "RETURN"

const ALL_STATES: Array[String] = [STATE_PATROL, STATE_SUSPICION, STATE_ALARM, STATE_RETURN]

## Jedyne dozwolone przejścia FSM strażnika. Test opiera się na tej tabeli.
const ALLOWED_TRANSITIONS: Dictionary = {
	STATE_PATROL: [STATE_SUSPICION],
	STATE_SUSPICION: [STATE_ALARM, STATE_RETURN],
	STATE_RETURN: [STATE_PATROL, STATE_SUSPICION],
	STATE_ALARM: [],
}

## Liczba kolejnych ticków widoczności, po której strażnik wszczyna alarm.
const ALARM_STREAK := 2

var id: String
var state: String
var position: Vector2i
var facing: Vector2i
var waypoint_index: int
var visible_streak: int
var resume_point: Vector2i
var view_range: int

var _start_position: Vector2i
var _start_facing: Vector2i
var _waypoints: Array[Vector2i] = []


func _init(
		p_id: String,
		p_start: Vector2i,
		p_facing: Vector2i,
		p_waypoints: Array[Vector2i],
		p_view_range: int) -> void:
	id = p_id
	_start_position = p_start
	_start_facing = p_facing
	_waypoints = p_waypoints.duplicate()
	view_range = p_view_range
	reset()


func reset() -> void:
	state = STATE_PATROL
	position = _start_position
	facing = _start_facing
	waypoint_index = 0
	visible_streak = 0
	resume_point = _start_position


func get_waypoints() -> Array[Vector2i]:
	return _waypoints.duplicate()


func current_waypoint() -> Vector2i:
	return _waypoints[waypoint_index]


func is_terminal() -> bool:
	return state == STATE_ALARM


static func is_transition_allowed(from_state: String, to_state: String) -> bool:
	if not ALLOWED_TRANSITIONS.has(from_state):
		return false
	var targets: Array = ALLOWED_TRANSITIONS[from_state]
	return targets.has(to_state)


## Faza ruchu strażnika. Zwraca indeks osiągniętego waypointu albo -1.
## PATROL idzie po waypointach, RETURN wraca do punktu wznowienia,
## SUSPICION i ALARM stoją w miejscu.
func move_step() -> int:
	match state:
		STATE_PATROL:
			var reached := -1
			if position == _waypoints[waypoint_index]:
				reached = waypoint_index
				waypoint_index = (waypoint_index + 1) % _waypoints.size()
			_step_towards(_waypoints[waypoint_index])
			return reached
		STATE_RETURN:
			_step_towards(resume_point)
			return -1
		_:
			return -1


## Faza aktualizacji FSM. Zwraca listę przejść w stabilnej kolejności;
## każde przejście to {"from": String, "to": String, "reason": String}.
func update_state(sees_intruder: bool) -> Array[Dictionary]:
	var transitions: Array[Dictionary] = []

	match state:
		STATE_PATROL:
			if sees_intruder:
				visible_streak = 1
				resume_point = position
				transitions.append(_transition(STATE_SUSPICION, "intruder_visible"))
		STATE_SUSPICION:
			if sees_intruder:
				visible_streak += 1
				if visible_streak >= ALARM_STREAK:
					transitions.append(_transition(STATE_ALARM, "intruder_visible_consecutive_ticks"))
			else:
				visible_streak = 0
				transitions.append(_transition(STATE_RETURN, "target_lost"))
		STATE_RETURN:
			if sees_intruder:
				visible_streak = 1
				resume_point = position
				transitions.append(_transition(STATE_SUSPICION, "intruder_reacquired"))
			elif position == resume_point:
				transitions.append(_transition(STATE_PATROL, "resume_point_reached"))
		STATE_ALARM:
			pass

	return transitions


## Ruch o najwyżej jedną komórkę: najpierw oś X, potem oś Y.
## Kierunek patrzenia zawsze pozostaje kardynalny.
func _step_towards(target: Vector2i) -> void:
	if position.x != target.x:
		var dx := signi(target.x - position.x)
		facing = Vector2i(dx, 0)
		position.x += dx
	elif position.y != target.y:
		var dy := signi(target.y - position.y)
		facing = Vector2i(0, dy)
		position.y += dy


func _transition(to_state: String, reason: String) -> Dictionary:
	var from_state := state
	state = to_state
	return {"from": from_state, "to": to_state, "reason": reason}
