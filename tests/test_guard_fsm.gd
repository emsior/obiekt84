## Testy FSM strażnika.
##
## Czysty test rdzenia: FSM jest obiektem RefCounted, nie node'em.
extends GdUnitTestSuite

const WAYPOINTS: Array[Vector2i] = [
	Vector2i(10, 4),
	Vector2i(16, 4),
	Vector2i(16, 12),
	Vector2i(10, 12),
]
const START := Vector2i(10, 4)
const VIEW_RANGE := 6


func _make_guard() -> GuardFsm:
	return GuardFsm.new("guard_01", START, Vector2i(1, 0), WAYPOINTS, VIEW_RANGE)


func test_initial_state_is_patrol() -> void:
	var guard := _make_guard()
	assert_str(guard.state).is_equal(GuardFsm.STATE_PATROL)
	assert_int(guard.visible_streak).is_equal(0)
	assert_int(guard.waypoint_index).is_equal(0)
	assert_vector(guard.position).is_equal(START)


func test_patrol_to_suspicion_on_first_sighting() -> void:
	var guard := _make_guard()
	var transitions := guard.update_state(true)

	assert_int(transitions.size()).is_equal(1)
	assert_str(String(transitions[0]["from"])).is_equal(GuardFsm.STATE_PATROL)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_str(String(transitions[0]["reason"])).is_equal("intruder_visible")
	assert_str(guard.state).is_equal(GuardFsm.STATE_SUSPICION)
	assert_int(guard.visible_streak).is_equal(1)


func test_suspicion_to_alarm_on_second_consecutive_sighting() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	var transitions := guard.update_state(true)

	assert_int(transitions.size()).is_equal(1)
	assert_str(String(transitions[0]["from"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_ALARM)
	assert_str(guard.state).is_equal(GuardFsm.STATE_ALARM)
	assert_int(guard.visible_streak).is_equal(GuardFsm.ALARM_STREAK)
	assert_bool(guard.is_terminal()).is_true()


func test_patrol_never_jumps_directly_to_alarm() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	assert_str(guard.state) \
		.append_failure_message("pierwszy tick widocznosci nie moze wywolac ALARM") \
		.is_not_equal(GuardFsm.STATE_ALARM)


func test_suspicion_to_return_on_target_lost() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	var transitions := guard.update_state(false)

	assert_int(transitions.size()).is_equal(1)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_RETURN)
	assert_str(String(transitions[0]["reason"])).is_equal("target_lost")
	assert_int(guard.visible_streak).is_equal(0)


func test_return_to_patrol_on_resume_point_reached() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	guard.update_state(false)
	assert_str(guard.state).is_equal(GuardFsm.STATE_RETURN)

	# Straznik stoi w punkcie wznowienia, wiec kolejny tick wraca do patrolu.
	var transitions := guard.update_state(false)
	assert_int(transitions.size()).is_equal(1)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_PATROL)
	assert_str(String(transitions[0]["reason"])).is_equal("resume_point_reached")


## RETURN dochodzi do punktu wznowienia deterministycznie: najpierw X, potem Y.
func test_return_walks_deterministically_to_resume_point() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	guard.update_state(false)
	assert_str(guard.state).is_equal(GuardFsm.STATE_RETURN)

	# Przesuwamy punkt wznowienia, zeby sprawdzic sam przejazd powrotny.
	guard.resume_point = Vector2i(12, 6)
	var visited: Array[Vector2i] = []
	for i in range(10):
		guard.move_step()
		visited.append(guard.position)
		var transitions := guard.update_state(false)
		if not transitions.is_empty():
			assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_PATROL)
			break

	# Z (10,4) do (12,6): najpierw os X, potem os Y.
	assert_array(visited).is_equal([
		Vector2i(11, 4),
		Vector2i(12, 4),
		Vector2i(12, 5),
		Vector2i(12, 6),
	] as Array[Vector2i])
	assert_str(guard.state).is_equal(GuardFsm.STATE_PATROL)


func test_return_to_suspicion_on_reacquire() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	guard.update_state(false)
	assert_str(guard.state).is_equal(GuardFsm.STATE_RETURN)

	var transitions := guard.update_state(true)
	assert_int(transitions.size()).is_equal(1)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_int(guard.visible_streak).is_equal(1)


func test_alarm_is_terminal_and_emits_no_further_transitions() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	guard.update_state(true)
	assert_str(guard.state).is_equal(GuardFsm.STATE_ALARM)

	assert_array(guard.update_state(true)).is_empty()
	assert_array(guard.update_state(false)).is_empty()
	assert_str(guard.state).is_equal(GuardFsm.STATE_ALARM)


func test_reset_restores_initial_fsm_state() -> void:
	var guard := _make_guard()
	guard.move_step()
	guard.update_state(true)
	guard.update_state(true)
	assert_str(guard.state).is_equal(GuardFsm.STATE_ALARM)

	guard.reset()
	assert_str(guard.state).is_equal(GuardFsm.STATE_PATROL)
	assert_vector(guard.position).is_equal(START)
	assert_vector(guard.facing).is_equal(Vector2i(1, 0))
	assert_int(guard.waypoint_index).is_equal(0)
	assert_int(guard.visible_streak).is_equal(0)
	assert_vector(guard.resume_point).is_equal(START)


## Patrol obchodzi cztery waypointy: ruch najpierw w osi X, potem w osi Y,
## najwyżej jedna komórka na tick.
func test_patrol_moves_one_cell_per_tick_along_waypoints() -> void:
	var guard := _make_guard()
	var previous := guard.position
	for i in range(28):
		guard.move_step()
		var delta: Vector2i = guard.position - previous
		assert_int(absi(delta.x) + absi(delta.y)) \
			.append_failure_message("tick %d: ruch o wiecej niz jedna komorke" % i) \
			.is_less_equal(1)
		previous = guard.position

	# Pelne okrazenie prostokata 6x8 to 28 ticków - straznik wraca na start.
	assert_vector(guard.position).is_equal(START)


func test_transition_table_rejects_illegal_transitions() -> void:
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_PATROL, GuardFsm.STATE_ALARM)).is_false()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_PATROL, GuardFsm.STATE_RETURN)).is_false()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_ALARM, GuardFsm.STATE_PATROL)).is_false()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_ALARM, GuardFsm.STATE_SUSPICION)).is_false()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_SUSPICION, GuardFsm.STATE_PATROL)).is_false()

	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_PATROL, GuardFsm.STATE_SUSPICION)).is_true()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_SUSPICION, GuardFsm.STATE_ALARM)).is_true()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_SUSPICION, GuardFsm.STATE_RETURN)).is_true()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_RETURN, GuardFsm.STATE_PATROL)).is_true()
	assert_bool(GuardFsm.is_transition_allowed(GuardFsm.STATE_RETURN, GuardFsm.STATE_SUSPICION)).is_true()


## Żadna sekwencja obserwacji nie może wyprowadzić FSM poza tabelę przejść.
func test_no_illegal_transition_occurs_in_any_observation_sequence() -> void:
	var patterns := [
		[true, true],
		[true, false, false, true, true],
		[false, false, true, false, true, true],
		[true, false, true, false, true, true],
	]
	for pattern: Array in patterns:
		var guard := _make_guard()
		for sees: bool in pattern:
			guard.move_step()
			for transition: Dictionary in guard.update_state(sees):
				assert_bool(GuardFsm.is_transition_allowed(
						String(transition["from"]), String(transition["to"]))) \
					.append_failure_message("niedozwolone przejscie %s -> %s" % [
						transition["from"], transition["to"]]) \
					.is_true()
			assert_array(GuardFsm.ALL_STATES) \
				.append_failure_message("stan %s spoza zbioru stanow" % guard.state) \
				.contains([guard.state])


# === namierzenie przez kamerę (L1-C) ==========================================

## Namierzony intruz: pierwsza obserwacja z PATROL daje w tym samym ticku
## SUSPICION, a zaraz po nim ALARM. Strażnik nie przeskakuje SUSPICION.
func test_marked_intruder_first_sighting_raises_alarm_through_suspicion() -> void:
	var guard := _make_guard()
	var transitions := guard.update_state(true, true)

	assert_int(transitions.size()).is_equal(2)
	assert_str(String(transitions[0]["from"])).is_equal(GuardFsm.STATE_PATROL)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_str(String(transitions[0]["reason"])).is_equal("intruder_visible")
	assert_str(String(transitions[1]["from"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_str(String(transitions[1]["to"])).is_equal(GuardFsm.STATE_ALARM)
	assert_str(String(transitions[1]["reason"])).is_equal("intruder_marked_by_camera")
	assert_int(guard.visible_streak).is_equal(1)
	assert_bool(guard.is_terminal()).is_true()


## Ponowne dostrzeżenie w RETURN przy namierzonym intruzie też kończy się alarmem.
func test_marked_intruder_reacquired_from_return_raises_alarm() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	guard.update_state(false)
	assert_str(guard.state).is_equal(GuardFsm.STATE_RETURN)

	var transitions := guard.update_state(true, true)
	assert_int(transitions.size()).is_equal(2)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_str(String(transitions[0]["reason"])).is_equal("intruder_reacquired")
	assert_str(String(transitions[1]["to"])).is_equal(GuardFsm.STATE_ALARM)
	assert_str(String(transitions[1]["reason"])).is_equal("intruder_marked_by_camera")


## Drugi kolejny tick widoczności to alarm z dotychczasowym powodem — także
## wtedy, gdy intruz został namierzony w międzyczasie.
func test_second_consecutive_sighting_keeps_consecutive_reason_when_marked() -> void:
	var guard := _make_guard()
	guard.update_state(true)
	var transitions := guard.update_state(true, true)

	assert_int(transitions.size()).is_equal(1)
	assert_str(String(transitions[0]["to"])).is_equal(GuardFsm.STATE_ALARM)
	assert_str(String(transitions[0]["reason"])).is_equal("intruder_visible_consecutive_ticks")


## Namierzenie bez obserwacji strażnika niczego nie zmienia — kamera sama
## nie podnosi alarmu.
func test_marking_without_guard_sighting_changes_nothing() -> void:
	var guard := _make_guard()
	for i in range(5):
		guard.move_step()
		assert_array(guard.update_state(false, true)).is_empty()
	assert_str(guard.state).is_equal(GuardFsm.STATE_PATROL)
	assert_int(guard.visible_streak).is_equal(0)


## Ścieżki z namierzeniem mieszczą się w tej samej tabeli przejść.
func test_no_illegal_transition_occurs_with_marked_intruder() -> void:
	var patterns := [
		[[true, true]],
		[[false, true], [true, true]],
		[[true, false], [false, true], [true, true]],
		[[true, false], [false, false], [false, true], [true, true]],
	]
	for pattern: Array in patterns:
		var guard := _make_guard()
		for step: Array in pattern:
			guard.move_step()
			for transition: Dictionary in guard.update_state(bool(step[0]), bool(step[1])):
				assert_bool(GuardFsm.is_transition_allowed(
						String(transition["from"]), String(transition["to"]))) \
					.append_failure_message("niedozwolone przejscie %s -> %s" % [
						transition["from"], transition["to"]]) \
					.is_true()
