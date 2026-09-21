## Rdzeń symulacji incydentu L0.
##
## Klasa domenowa: bez node'ów, bez SceneTree, bez get_tree(), bez get_node(),
## bez NodePath, bez inputu, bez Timerów, bez fizyki Godota, bez await,
## bez sygnałów sterujących kolejnością logiki, bez delty i bez losowości.
##
## Stała kolejność faz jednego ticka — nigdy nie zależy od Scene Tree:
##   1. zwiększenie numeru ticka,
##   2. ruch intruza,
##   3. ruch strażnika,
##   4. FOV kamery,
##   5. FOV strażnika,
##   6. aktualizacja FSM (najpierw strażnik, potem intruz),
##   7. rozstrzygnięcie wyniku terminalnego,
##   8. dopisanie zdarzeń do logu w stabilnej kolejności,
##   9. udostępnienie nowego snapshotu warstwie prezentacji.
##
## Gdy w tym samym ticku wykryją intruza kamera i strażnik, priorytet ma kamera.
class_name Simulation
extends RefCounted

## Stała częstotliwość logiczna. Timer prezentacji nie jest zegarem domenowym.
const TICKS_PER_SECOND := 10
const SECONDS_PER_TICK := 1.0 / float(TICKS_PER_SECOND)

const SUBJECT_SIMULATION := "simulation"

const REASON_CAMERA := "camera_detection"
const REASON_GUARD_ALARM := "guard_alarm"

var _scenario: ScenarioL0 = null
var _state: SimulationState = null
var _event_log: EventLog = null
var _pending_events: Array[Dictionary] = []


## Przygotowuje rdzeń na podstawie jawnych danych scenariusza.
## Przechowywana jest niezależna kopia — późniejsza zmiana przekazanego
## obiektu nie może wpłynąć na przebieg.
func initialize(scenario: ScenarioL0) -> void:
	_scenario = scenario.duplicate_data()
	_state = SimulationState.new(_scenario)
	_event_log = EventLog.new()
	_pending_events.clear()


## Przywraca dokładny stan początkowy i kasuje log poprzedniego przebiegu.
func reset() -> void:
	assert(_state != null, "reset() przed initialize()")
	_state.reset()
	_event_log.clear()
	_pending_events.clear()


## Przetwarza dokładnie jeden pełny tick.
## Po osiągnięciu stanu terminalnego jest bezpiecznym no-op: nie zwiększa ticka,
## nie zmienia stanu i nie dopisuje zdarzeń.
func step() -> void:
	assert(_state != null, "step() przed initialize()")
	if is_finished():
		return

	_pending_events.clear()

	# Faza 1 — numer ticka rośnie dokładnie raz, na początku kroku.
	_state.tick += 1

	# Faza 2 — ruch intruza.
	_state.intruder.advance()

	# Faza 3 — ruch strażnika.
	var reached_waypoint := _state.guard.move_step()
	if reached_waypoint >= 0:
		_queue(_state.guard.id, "WAYPOINT_REACHED", "waypoint_%d" % reached_waypoint)

	# Faza 4 — FOV kamery. Kamera ma priorytet nad strażnikiem.
	var detection_reason := ""
	if _state.intruder.state == IntruderScript.STATE_MOVE:
		var camera_sees := FovCalculator.is_target_visible(
			_state.camera_position,
			_state.camera_facing,
			_state.camera_range,
			_state.intruder.position)
		if camera_sees:
			_queue(_state.camera_id, "DETECTION", "intruder_in_camera_fov")
			detection_reason = REASON_CAMERA

	# Faza 5 — FOV strażnika.
	var guard_sees := FovCalculator.is_target_visible(
		_state.guard.position,
		_state.guard.facing,
		_state.guard.view_range,
		_state.intruder.position)

	# Faza 6 — FSM w stabilnej kolejności: najpierw strażnik, potem intruz.
	for transition: Dictionary in _state.guard.update_state(guard_sees):
		_queue(_state.guard.id, String(transition["to"]), String(transition["reason"]))
	if _state.guard.state == GuardFsm.STATE_ALARM and detection_reason == "":
		detection_reason = REASON_GUARD_ALARM

	if _state.intruder.state == IntruderScript.STATE_MOVE:
		if detection_reason != "":
			_state.intruder.state = IntruderScript.STATE_DETECTED
			_queue(_state.intruder.id, IntruderScript.STATE_DETECTED, detection_reason)
		elif _state.intruder.has_reached_route_end():
			_state.intruder.state = IntruderScript.STATE_SUCCESS
			_queue(_state.intruder.id, IntruderScript.STATE_SUCCESS, "route_completed")

	# Faza 7 — rozstrzygnięcie wyniku terminalnego.
	_resolve_outcome()

	# Faza 8 — dopisanie zdarzeń w stabilnej kolejności.
	_flush_events()

	# Faza 9 — nowy snapshot jest dostępny przez get_state_snapshot().


func is_finished() -> bool:
	return _state != null and _state.is_finished()


func get_tick() -> int:
	return _state.tick


func get_outcome() -> String:
	return _state.outcome


## Kopia pełnego stanu dla warstwy prezentacji i testów.
func get_state_snapshot() -> Dictionary:
	return _state.to_snapshot()


## Kanoniczna, jawnie uporządkowana reprezentacja stanu.
func get_canonical_snapshot() -> String:
	return _state.to_canonical()


## Kopia wpisów logu.
func get_event_log() -> Array[Dictionary]:
	return _event_log.get_entries()


## Kanoniczna serializacja logu: "tick|subject|event|reason" w wierszach.
func get_canonical_log() -> String:
	return _event_log.to_canonical()


func get_last_events(count: int) -> Array[Dictionary]:
	return _event_log.get_last_entries(count)


func _resolve_outcome() -> void:
	if _state.intruder.state == IntruderScript.STATE_DETECTED:
		_state.outcome = SimulationState.OUTCOME_INTRUDER_DETECTED
	elif _state.intruder.state == IntruderScript.STATE_SUCCESS:
		_state.outcome = SimulationState.OUTCOME_INTRUDER_SUCCESS
	elif _state.tick >= _state.max_ticks:
		_state.outcome = SimulationState.OUTCOME_TICK_LIMIT

	if _state.is_finished():
		_queue(SUBJECT_SIMULATION, "FINISHED", _state.outcome.to_lower())


func _queue(subject: String, event: String, reason: String) -> void:
	_pending_events.append({
		"subject": subject,
		"event": event,
		"reason": reason,
	})


func _flush_events() -> void:
	for pending: Dictionary in _pending_events:
		_event_log.append(
			_state.tick,
			String(pending["subject"]),
			String(pending["event"]),
			String(pending["reason"]))
	_pending_events.clear()
