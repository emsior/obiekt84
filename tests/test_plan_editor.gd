## Testy edytora fazy planowania L1-A.
##
## Metody edytora są wołane bezpośrednio (`begin_drag` / `drag_to` / `end_drag`),
## bez `InputEvent` — mapowanie myszy na komórki sprawdza `test_main_scene.gd`.
##
## Pierwsza część to testy samego edytora na node'zie spoza drzewa sceny
## (`auto_free`, zero orphanów). Druga część sprawdza kontrakt z koordynatorem:
## edycja zmienia draft, a nigdy działającą `Simulation`, plan przeżywa noc,
## a R przywraca plan domyślny.
extends GdUnitTestSuite

const MAIN_SCENE := "res://scenes/main.tscn"

## Indeksy faz (enum Phase w simulation_runner.gd).
const PHASE_PLAN := 0
const PHASE_RUN := 1

## Komórki planu domyślnego (`ScenarioL0.create_puzzle()`).
const PUZZLE_CAMERA := Vector2i(3, 3)
const PUZZLE_WAYPOINT_2 := Vector2i(16, 7)

## Plan referencyjny z `tests/test_l0_golden_log.gd`: węzeł 3 o wiersz niżej
## i kamera nad korytarzem. Każda z tych zmian osobno przegrywa (L1-C).
const SOLUTION_WAYPOINT_2 := Vector2i(16, 8)
const SOLUTION_CAMERA_POSITION := Vector2i(12, 9)
const SOLUTION_TERMINAL_TICK := 32


func _new_editor() -> PlanEditor:
	return auto_free(PlanEditor.new()) as PlanEditor


## Przeciągnięcie od [param from] do [param to] tak, jak robi to mysz.
func _drag(editor: PlanEditor, from: Vector2i, to: Vector2i) -> bool:
	assert_bool(editor.begin_drag(from)) \
		.append_failure_message("w komorce %s nie ma elementu do przeciagniecia" % str(from)) \
		.is_true()
	editor.drag_to(to)
	return editor.end_drag()


## Kliknięcie: podniesienie i upuszczenie w tej samej komórce.
func _click(editor: PlanEditor, cell: Vector2i) -> bool:
	assert_bool(editor.begin_drag(cell)).is_true()
	return editor.end_drag()


## Pola, którymi plan gracza może się różnić — porównanie bez refleksji,
## żeby komunikat wskazywał konkretne pole.
func _assert_same_plan(actual: ScenarioL0, expected: ScenarioL0, label: String) -> void:
	assert_array(actual.guard_waypoints) \
		.append_failure_message("%s: waypointy" % label) \
		.is_equal(expected.guard_waypoints)
	assert_vector(actual.guard_start) \
		.append_failure_message("%s: start straznika" % label) \
		.is_equal(expected.guard_start)
	assert_vector(actual.camera_position) \
		.append_failure_message("%s: pozycja kamery" % label) \
		.is_equal(expected.camera_position)
	assert_vector(actual.camera_facing) \
		.append_failure_message("%s: kierunek kamery" % label) \
		.is_equal(expected.camera_facing)


func _simulation_of(scene: Node) -> Simulation:
	return scene.get("_simulation") as Simulation


# === sam edytor ===============================================================

func test_editor_starts_with_puzzle_draft() -> void:
	var editor := _new_editor()
	_assert_same_plan(editor.draft(), ScenarioL0.create_puzzle(), "draft poczatkowy")
	assert_bool(editor.is_dragging()).is_false()


func test_moving_waypoint_changes_draft() -> void:
	var editor := _new_editor()
	var changes := [0]
	editor.draft_changed.connect(func() -> void: changes[0] += 1)

	assert_bool(_drag(editor, PUZZLE_WAYPOINT_2, Vector2i(16, 11))).is_true()

	var draft := editor.draft()
	assert_vector(draft.guard_waypoints[2]).is_equal(Vector2i(16, 11))
	assert_bool(draft.is_valid()).is_true()
	assert_int(int(changes[0])) \
		.append_failure_message("zaakceptowana zmiana powinna ogłosic draft_changed dokladnie raz") \
		.is_equal(1)


## Samo przesuwanie kursora nie zmienia draftu — zmiana zapada przy upuszczeniu.
func test_drag_without_drop_does_not_change_draft() -> void:
	var editor := _new_editor()
	assert_bool(editor.begin_drag(PUZZLE_WAYPOINT_2)).is_true()
	editor.drag_to(Vector2i(16, 11))

	assert_bool(editor.is_dragging()).is_true()
	assert_vector(editor.draft().guard_waypoints[2]).is_equal(PUZZLE_WAYPOINT_2)

	editor.cancel_drag()
	assert_bool(editor.is_dragging()).is_false()
	assert_vector(editor.draft().guard_waypoints[2]).is_equal(PUZZLE_WAYPOINT_2)


func test_moving_camera_changes_draft() -> void:
	var editor := _new_editor()
	assert_bool(_drag(editor, PUZZLE_CAMERA, SOLUTION_CAMERA_POSITION)).is_true()

	var draft := editor.draft()
	assert_vector(draft.camera_position).is_equal(SOLUTION_CAMERA_POSITION)
	assert_vector(draft.camera_facing) \
		.append_failure_message("przeniesienie kamery nie moze jej obracac") \
		.is_equal(ScenarioL0.create_puzzle().camera_facing)


## Odrzucone upuszczenie: draft bez zmian, gracz dostaje pierwszy komunikat
## walidacji. Poza siatką odrzuca ta sama walidacja co resztę.
func test_rejected_drop_outside_grid_keeps_draft() -> void:
	var editor := _new_editor()
	var before := editor.draft()
	var messages: Array[String] = []
	var changes := [0]
	editor.edit_rejected.connect(func(message: String) -> void: messages.append(message))
	editor.draft_changed.connect(func() -> void: changes[0] += 1)

	assert_bool(_drag(editor, Vector2i(16, 4), Vector2i(20, 4))).is_false()

	_assert_same_plan(editor.draft(), before, "po odrzuceniu")
	assert_int(int(changes[0])).is_equal(0)
	assert_int(messages.size()).is_equal(1)
	assert_str(messages[0]).contains("guard_waypoints[1]")
	assert_str(messages[0]).contains("poza siatką")
	assert_str(messages[0]) \
		.append_failure_message("komunikat powinien byc pierwszym problemem z validate()") \
		.is_equal(_first_problem_after_moving_waypoint(1, Vector2i(20, 4)))


func test_rejected_drop_on_forbidden_cells_keeps_draft() -> void:
	var editor := _new_editor()
	var before := editor.draft()
	var messages: Array[String] = []
	editor.edit_rejected.connect(func(message: String) -> void: messages.append(message))

	# Kamera na trasie intruza.
	var route_cell: Vector2i = before.intruder_route[20]
	assert_bool(_drag(editor, PUZZLE_CAMERA, route_cell)).is_false()
	# Waypoint na kamerze.
	assert_bool(_drag(editor, PUZZLE_WAYPOINT_2, PUZZLE_CAMERA)).is_false()

	_assert_same_plan(editor.draft(), before, "po odrzuceniach")
	assert_int(messages.size()).is_equal(2)
	assert_str(messages[0]).contains("trasie intruza")
	assert_str(messages[1]).contains("guard_waypoints[2]")


## Strażnik zawsze startuje na pierwszym waypoincie — także po jego przesunięciu.
func test_guard_start_follows_first_waypoint() -> void:
	var editor := _new_editor()
	assert_bool(_drag(editor, Vector2i(10, 4), Vector2i(9, 6))).is_true()

	var draft := editor.draft()
	assert_vector(draft.guard_waypoints[0]).is_equal(Vector2i(9, 6))
	assert_vector(draft.guard_start) \
		.append_failure_message("start straznika nie podazyl za waypointem 0") \
		.is_equal(Vector2i(9, 6))

	# Przesunięcie innego waypointu nie rusza startu.
	assert_bool(_drag(editor, PUZZLE_WAYPOINT_2, Vector2i(16, 11))).is_true()
	assert_vector(editor.draft().guard_start).is_equal(Vector2i(9, 6))


## Klik w kamerę obraca ją o 90° zgodnie z ruchem wskazówek zegara na ekranie.
## Cztery kliknięcia przechodzą cztery różne kierunki kardynalne i wracają.
func test_camera_click_cycles_through_four_directions() -> void:
	var editor := _new_editor()
	var start := editor.draft().camera_facing
	var seen: Array[Vector2i] = [start]

	for i in range(4):
		assert_bool(_click(editor, PUZZLE_CAMERA)).is_true()
		var facing := editor.draft().camera_facing
		assert_int(absi(facing.x) + absi(facing.y)) \
			.append_failure_message("kierunek %s nie jest kardynalny" % str(facing)) \
			.is_equal(1)
		assert_vector(facing) \
			.append_failure_message("obrot nie jest zgodny z ruchem wskazowek zegara") \
			.is_equal(PlanEditor.rotated_clockwise(seen[seen.size() - 1]))
		if i < 3:
			assert_bool(seen.has(facing)) \
				.append_failure_message("obrot %d powtorzyl kierunek %s" % [i + 1, str(facing)]) \
				.is_false()
		seen.append(facing)

	assert_vector(seen[4]).is_equal(start)
	assert_vector(editor.draft().camera_position) \
		.append_failure_message("obrot przesunal kamere") \
		.is_equal(PUZZLE_CAMERA)

	# Kierunki na ekranie: dół → lewo → góra → prawo.
	assert_array(seen).is_equal([
		Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN,
	] as Array[Vector2i])


func test_click_on_waypoint_or_empty_cell_changes_nothing() -> void:
	var editor := _new_editor()
	var before := editor.draft()

	assert_bool(_click(editor, PUZZLE_WAYPOINT_2)).is_false()
	assert_bool(editor.begin_drag(Vector2i(0, 0))) \
		.append_failure_message("pusta komorka nie moze rozpoczac przeciagania") \
		.is_false()
	assert_bool(editor.end_drag()).is_false()

	_assert_same_plan(editor.draft(), before, "po kliknieciach bez efektu")


## Draft na zewnątrz to kopia — nikt nie ominie walidacji, zmieniając go wprost.
func test_draft_accessor_returns_independent_copy() -> void:
	var editor := _new_editor()
	var copy := editor.draft()
	copy.guard_waypoints[2] = Vector2i(0, 0)
	copy.camera_position = Vector2i(0, 1)

	_assert_same_plan(editor.draft(), ScenarioL0.create_puzzle(), "po zmianie kopii")


func test_reset_to_puzzle_restores_default_plan() -> void:
	var editor := _new_editor()
	_drag(editor, PUZZLE_WAYPOINT_2, Vector2i(16, 11))
	_drag(editor, PUZZLE_CAMERA, SOLUTION_CAMERA_POSITION)
	_click(editor, SOLUTION_CAMERA_POSITION)

	editor.reset_to_puzzle()
	_assert_same_plan(editor.draft(), ScenarioL0.create_puzzle(), "po R")


func _first_problem_after_moving_waypoint(index: int, cell: Vector2i) -> String:
	var candidate := ScenarioL0.create_puzzle()
	candidate.guard_waypoints[index] = cell
	candidate.guard_start = candidate.guard_waypoints[0]
	return candidate.validate()[0]


# === edytor w scenie ==========================================================

## Edycja zmienia draft, a nie działającą symulację. Edytor wołany wprost
## w trakcie nocy — gdyby miał jakąkolwiek ścieżkę do `Simulation`, snapshot,
## log albo dane nocy by się zmieniły.
func test_editing_changes_draft_not_running_simulation() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor

	scene.call("start_run")
	scene.call("pause")
	for i in range(5):
		scene.call("single_step")
	var simulation := _simulation_of(scene)
	var snapshot_before := simulation.get_canonical_snapshot()
	var log_before := simulation.get_canonical_log()

	assert_bool(_drag(editor, PUZZLE_WAYPOINT_2, Vector2i(16, 11))).is_true()
	assert_bool(_drag(editor, PUZZLE_CAMERA, SOLUTION_CAMERA_POSITION)).is_true()
	assert_vector(editor.draft().guard_waypoints[2]).is_equal(Vector2i(16, 11))

	assert_bool(_simulation_of(scene) == simulation) \
		.append_failure_message("edycja podmienila instancje Simulation") \
		.is_true()
	assert_str(simulation.get_canonical_snapshot()) \
		.append_failure_message("edycja zmienila stan dzialajacej symulacji") \
		.is_equal(snapshot_before)
	assert_str(simulation.get_canonical_log()).is_equal(log_before)
	var running_snapshot := simulation.get_state_snapshot()
	assert_vector((running_snapshot["guard_waypoints"] as Array)[2]).is_equal(PUZZLE_WAYPOINT_2)
	assert_vector(running_snapshot["camera_position"]).is_equal(PUZZLE_CAMERA)

	# Restart nocy odtwarza dane z chwili uruchomienia, nie bieżący draft.
	scene.call("_on_restart_requested")
	var restarted := _simulation_of(scene).get_state_snapshot()
	assert_vector((restarted["guard_waypoints"] as Array)[2]) \
		.append_failure_message("noc przejela edycje wykonana w jej trakcie") \
		.is_equal(PUZZLE_WAYPOINT_2)
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_RUN)


## PLAN → RUN → PLAN: plan przeżywa noc — i zakończoną, i przerwaną.
func test_plan_survives_run_and_return() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor

	_drag(editor, PUZZLE_WAYPOINT_2, Vector2i(16, 11))
	_click(editor, PUZZLE_CAMERA)
	var planned := editor.draft()

	scene.call("start_run")
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_RUN)
	var night := _simulation_of(scene).get_state_snapshot()
	assert_array(night["guard_waypoints"]) \
		.append_failure_message("noc nie dostala planu gracza") \
		.is_equal(planned.guard_waypoints)
	assert_vector(night["camera_facing"]).is_equal(planned.camera_facing)

	# Powrót w trakcie nocy.
	scene.call("return_to_plan")
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_PLAN)
	assert_bool(bool(scene.get("_running"))).is_false()
	_assert_same_plan(editor.draft(), planned, "po powrocie w trakcie nocy")

	# Powrót po wyniku terminalnym.
	scene.call("start_run")
	scene.call("seek_to_end")
	assert_bool(_simulation_of(scene).is_finished()).is_true()
	scene.call("return_to_plan")
	_assert_same_plan(editor.draft(), planned, "po powrocie z wyniku")

	var preview: Dictionary = scene.call("plan_preview_snapshot")
	assert_array(preview["guard_waypoints"]).is_equal(planned.guard_waypoints)
	assert_vector(preview["camera_facing"]).is_equal(planned.camera_facing)


func test_reset_plan_restores_puzzle_only_in_plan_phase() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor
	var hud := scene.get_node("HudLayer/Hud") as Hud

	_drag(editor, PUZZLE_WAYPOINT_2, Vector2i(16, 11))
	var planned := editor.draft()

	# W nocy przycisk planu domyslnego nie rusza draftu.
	scene.call("start_run")
	hud.default_plan_requested.emit()
	_assert_same_plan(editor.draft(), planned, "R w nocy")

	scene.call("return_to_plan")
	hud.default_plan_requested.emit()
	_assert_same_plan(editor.draft(), ScenarioL0.create_puzzle(), "R w planie")


## Odrzucona edycja: czerwony komunikat z validate() w HUD przez 2 s,
## potem powrót do podtytułu fazy. Timer prezentacji wyzwalamy jawnie.
func test_rejected_edit_shows_message_until_timer_expires() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor
	var subtitle := scene.get_node("HudLayer/Hud/ScenarioLabel") as Label
	var timer := scene.get_node("MessageTimer") as Timer

	assert_bool(_drag(editor, Vector2i(16, 4), Vector2i(20, 4))).is_false()

	var message := String(scene.call("plan_message"))
	assert_str(message).contains("poza siatką")
	assert_str(subtitle.text).contains(message)
	assert_that(subtitle.get_theme_color("font_color")).is_equal(Hud.COLOR_REJECTED)
	assert_bool(timer.is_stopped()).is_false()
	assert_float(timer.wait_time).is_equal_approx(2.0, 0.0001)

	timer.timeout.emit()
	assert_str(String(scene.call("plan_message"))).is_empty()
	assert_str(subtitle.text).is_equal(Hud.SUBTITLE_PLAN)
	assert_that(subtitle.get_theme_color("font_color")).is_equal(Hud.COLOR_SUBTITLE)


## Pełna pętla gry: plan domyślny przegrywa; sama kamera przeniesiona nad
## korytarz nadal przegrywa, bo kamera tylko namierza; dopiero wydłużony patrol
## razem z kamerą kończy noc obroną obiektu (L1-C).
func test_player_can_turn_loss_into_win_through_editor() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor
	var outcome := scene.get_node("HudLayer/Hud/OutcomeLabel") as Label

	scene.call("start_run")
	scene.call("seek_to_end")
	assert_str(_simulation_of(scene).get_outcome()).is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)
	assert_str(outcome.text).contains("DANE WYKRADZIONE")

	scene.call("return_to_plan")
	assert_bool(_drag(editor, PUZZLE_CAMERA, SOLUTION_CAMERA_POSITION)).is_true()
	scene.call("start_run")
	scene.call("seek_to_end")
	assert_str(_simulation_of(scene).get_outcome()) \
		.append_failure_message("sama kamera nie powinna wygrywac") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)
	assert_str(outcome.text).contains("DANE WYKRADZIONE")

	scene.call("return_to_plan")
	assert_bool(_drag(editor, PUZZLE_WAYPOINT_2, SOLUTION_WAYPOINT_2)).is_true()
	scene.call("start_run")
	scene.call("seek_to_end")

	assert_str(_simulation_of(scene).get_outcome()) \
		.append_failure_message("plan referencyjny ustawiony w edytorze nie wygrywa") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_DETECTED)
	assert_int(_simulation_of(scene).get_tick()).is_equal(SOLUTION_TERMINAL_TICK)
	assert_str(outcome.text).is_equal("OBIEKT ZABEZPIECZONY  —  tick %d" % SOLUTION_TERMINAL_TICK)
	assert_that(outcome.get_theme_color("font_color")).is_equal(Hud.COLOR_DEFENDED)
