## Test integracyjny sceny głównej.
##
## To jedyne miejsce w zestawie testów (obok `test_plan_editor.gd`), w którym
## powstają node'y — i jedyne odpowiedzialne za kontrolę orphan nodes. Rdzeń
## nie tworzy node'ów w ogóle.
##
## Ticki są wyzwalane przez jawną emisję sygnału Timera, a nie przez czekanie na
## czas rzeczywisty: kontrakt adaptera brzmi "jeden timeout to jeden step()".
##
## Scena startuje w fazie PLAN z planem domyślnym zagadki L1-A
## (`ScenarioL0.create_puzzle()`), który przegrywa w 40 ticku: strażnik dostrzega
## intruza w 32, gubi w 33, wraca do patrolu w 34.
extends GdUnitTestSuite

const MAIN_SCENE := "res://scenes/main.tscn"
const RESTART_CYCLES := 20
const TICKS_PER_CYCLE := 5

## Rozmiar viewportu z project.godot i lewa krawedz slupka HUD z main.tscn.
const VIEWPORT_WIDTH := 1280.0
const VIEWPORT_HEIGHT := 800.0
const HUD_COLUMN_LEFT := 620.0

## Przebieg planu domyslnego (tests/fixtures/l0_puzzle_default_golden_log.txt).
const PUZZLE_TERMINAL_TICK := 40
const PUZZLE_DECISION_TICKS: Array[int] = [32, 33, 34, 40]
const PUZZLE_SUSPICION_TICK := 32

## Indeksy faz (enum Phase w simulation_runner.gd).
const PHASE_PLAN := 0
const PHASE_RUN := 1


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _simulation_of(scene: Node) -> Simulation:
	return scene.get("_simulation") as Simulation


func _fire_ticks(scene: Node, count: int) -> void:
	var timer := scene.get_node("StepTimer") as Timer
	for i in range(count):
		timer.timeout.emit()


## Uruchomienie nocy i natychmiastowa pauza — testy krokują ręcznie.
func _enter_run_paused(scene: Node) -> void:
	scene.call("start_run")
	scene.call("pause")


func _press_key(scene: Node, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	scene.call("_unhandled_input", key)


func test_main_scene_starts_in_plan_phase() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_PLAN)
	assert_object(_simulation_of(scene)) \
		.append_failure_message("w fazie planowania nie powinno byc symulacji nocy") \
		.is_null()
	assert_bool(bool(scene.get("_running"))).is_false()
	assert_bool((scene.get_node("PlanEditor") as PlanEditor).visible).is_true()

	var status := scene.get_node("HudLayer/Hud/StatusLabel") as Label
	assert_str(status.text).contains("FAZA: PLAN")
	var legend := scene.get_node("HudLayer/Hud/LegendLabel") as Label
	assert_str(legend.text).contains("przeciągnij węzeł — patrol")
	assert_str(legend.text).contains("Spacja — uruchom noc")

	var outcome := scene.get_node("HudLayer/Hud/OutcomeLabel") as Label
	assert_str(outcome.text).is_not_empty()


## Podgląd planu to snapshot ticka 0 na danych draftu — plansza pokazuje to,
## co rdzeń dostanie na starcie nocy.
func test_plan_preview_matches_puzzle_start_state() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	var puzzle := ScenarioL0.create_puzzle()
	var snapshot: Dictionary = scene.call("plan_preview_snapshot")
	assert_int(int(snapshot["tick"])).is_equal(0)
	assert_array(snapshot["guard_waypoints"]).is_equal(puzzle.guard_waypoints)
	assert_vector(snapshot["guard_position"]).is_equal(puzzle.guard_start)
	assert_vector(snapshot["camera_position"]).is_equal(puzzle.camera_position)
	assert_vector(snapshot["camera_facing"]).is_equal(puzzle.camera_facing)
	assert_array(snapshot["intruder_route"]).is_equal(puzzle.intruder_route)


func test_start_pause_resume_restart_controls() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

	# Przycisk "Uruchom noc" przechodzi do RUN i od razu uruchamia przebieg.
	hud.run_requested.emit()
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_RUN)
	assert_bool(bool(scene.get("_running"))) \
		.append_failure_message("uruchomienie nocy nie wystartowalo odtwarzania") \
		.is_true()
	var simulation := _simulation_of(scene)
	assert_int(simulation.get_tick()).is_equal(0)

	_fire_ticks(scene, 3)
	assert_int(simulation.get_tick()).is_equal(3)

	hud.pause_toggle_requested.emit()
	assert_bool(bool(scene.get("_running"))) \
		.append_failure_message("Pauza nie zatrzymala odtwarzania") \
		.is_false()

	# W pauzie timeout nie moze wykonac kroku.
	_fire_ticks(scene, 3)
	assert_int(simulation.get_tick()) \
		.append_failure_message("krok wykonany mimo pauzy") \
		.is_equal(3)

	hud.pause_toggle_requested.emit()
	assert_bool(bool(scene.get("_running"))).is_true()
	_fire_ticks(scene, 2)
	assert_int(simulation.get_tick()).is_equal(5)

	# Restart podstawia swieza instancje Simulation na tym samym planie,
	# wiec stan trzeba odczytac ponownie ze sceny.
	hud.restart_requested.emit()
	var after_restart := _simulation_of(scene)
	assert_bool(bool(scene.get("_running"))).is_false()
	assert_int(after_restart.get_tick()).is_equal(0)
	assert_array(after_restart.get_event_log()).is_empty()
	assert_bool(after_restart.is_finished()).is_false()

	# Start z HUD w pauzie wznawia przebieg.
	hud.start_requested.emit()
	assert_bool(bool(scene.get("_running"))).is_true()


## 20 cykli Start/Pauza/Restart: stan po każdym resecie musi być identyczny
## ze stanem początkowym, a liczba node'ów sceny nie może rosnąć.
func test_twenty_restart_cycles_are_stable() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

	_enter_run_paused(scene)
	var initial_snapshot := _simulation_of(scene).get_canonical_snapshot()
	var initial_node_count := _count_nodes(scene)

	for cycle in range(RESTART_CYCLES):
		hud.start_requested.emit()
		_fire_ticks(scene, TICKS_PER_CYCLE)
		hud.pause_toggle_requested.emit()
		hud.restart_requested.emit()

		# Po restarcie scena trzyma nowa instancje Simulation.
		var simulation := _simulation_of(scene)
		assert_int(simulation.get_tick()) \
			.append_failure_message("cykl %d: tick po resecie" % cycle) \
			.is_equal(0)
		assert_str(simulation.get_canonical_snapshot()) \
			.append_failure_message("cykl %d: snapshot po resecie rozni sie od poczatkowego" % cycle) \
			.is_equal(initial_snapshot)
		assert_array(simulation.get_event_log()) \
			.append_failure_message("cykl %d: log nie zostal wyczyszczony" % cycle) \
			.is_empty()
		assert_int(_count_nodes(scene)) \
			.append_failure_message("cykl %d: liczba node'ow sceny wzrosla" % cycle) \
			.is_equal(initial_node_count)

	await runner.simulate_frames(1)


## Dymny test: jeden tick musi być widoczny w HUD.
func test_single_step_updates_hud() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var status := scene.get_node("HudLayer/Hud/StatusLabel") as Label

	_enter_run_paused(scene)
	var before := status.text
	scene.call("single_step")

	assert_int(_simulation_of(scene).get_tick()).is_equal(1)
	assert_str(status.text) \
		.append_failure_message("HUD nie odswiezyl sie po ticku") \
		.is_not_equal(before)


## Dymny test: wynik terminalny zatrzymuje automatyczny przebieg, a komunikat
## mówi z perspektywy obrońcy — plan domyślny przegrywa.
func test_terminal_outcome_stops_auto_run() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

	hud.run_requested.emit()
	assert_bool(bool(scene.get("_running"))).is_true()

	# Plan domyslny konczy sie w 40 ticku; dajemy zapas timeoutow.
	_fire_ticks(scene, 60)

	var simulation := _simulation_of(scene)
	assert_bool(simulation.is_finished()) \
		.append_failure_message("noc nie domknela sie") \
		.is_true()
	assert_bool(bool(scene.get("_running"))) \
		.append_failure_message("automatyczny przebieg nie zatrzymal sie po wyniku terminalnym") \
		.is_false()

	var status := scene.get_node("HudLayer/Hud/StatusLabel") as Label
	assert_str(status.text).contains(Hud.STATUS_FINISHED)

	var outcome := scene.get_node("HudLayer/Hud/OutcomeLabel") as Label
	assert_str(outcome.text) \
		.append_failure_message("komunikat przegranej obroncy nie pojawil sie w HUD") \
		.is_equal("DANE WYKRADZIONE  —  tick %d  ·  wróć do planu [P]" % PUZZLE_TERMINAL_TICK)
	assert_that(outcome.get_theme_color("font_color")).is_equal(Hud.COLOR_BREACHED)


## Dymny test: przełączniki prezentacji zmieniają stan widoku, nie rdzenia.
func test_overlay_and_log_toggles_change_presentation_state() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var level_view := scene.get_node("LevelL0") as LevelView
	var log_label := scene.get_node("HudLayer/Hud/LogLabel") as Label
	_enter_run_paused(scene)
	var tick_before := _simulation_of(scene).get_tick()

	assert_bool(level_view.is_overlay_visible()).is_true()
	scene.call("toggle_overlay")
	assert_bool(level_view.is_overlay_visible()).is_false()
	scene.call("toggle_overlay")
	assert_bool(level_view.is_overlay_visible()).is_true()

	assert_bool(log_label.visible).is_true()
	scene.call("toggle_log")
	assert_bool(log_label.visible).is_false()
	scene.call("toggle_log")
	assert_bool(log_label.visible).is_true()

	assert_int(_simulation_of(scene).get_tick()) \
		.append_failure_message("przelacznik prezentacji ruszyl symulacje") \
		.is_equal(tick_before)


## Restart nocy odtwarza ten sam plan gracza, nie wraca do planu domyślnego.
func test_restart_preserves_player_plan() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud
	var editor := scene.get_node("PlanEditor") as PlanEditor

	assert_bool(editor.begin_drag(Vector2i(16, 8))).is_true()
	editor.drag_to(Vector2i(16, 10))
	assert_bool(editor.end_drag()).is_true()

	_enter_run_paused(scene)
	scene.call("single_step")
	scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(2)

	hud.restart_requested.emit()

	var snapshot := _simulation_of(scene).get_state_snapshot()
	assert_int(int(snapshot["tick"])).is_equal(0)
	assert_vector((snapshot["guard_waypoints"] as Array)[2]) \
		.append_failure_message("restart zgubil plan gracza") \
		.is_equal(Vector2i(16, 10))
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_RUN)
	assert_bool(bool(scene.get("_running"))).is_false()


## Dymny test: tempo startuje na 1x i przelicza interwal prezentacji.
## Sprawdzamy konfiguracje i interwal Timera, nigdy realnego czasu wall-clock.
func test_playback_speed_defaults_to_normal_and_updates_runner() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var timer := scene.get_node("StepTimer") as Timer

	assert_float(float(scene.call("playback_speed"))) \
		.append_failure_message("domyslne tempo nie wynosi 1x") \
		.is_equal_approx(1.0, 0.0001)
	assert_float(timer.wait_time).is_equal_approx(0.1, 0.0001)

	scene.call("set_playback_speed", 0.5)
	assert_float(float(scene.call("playback_speed"))).is_equal_approx(0.5, 0.0001)
	assert_float(timer.wait_time) \
		.append_failure_message("tempo 0,5x powinno dac interwal 0,2 s") \
		.is_equal_approx(0.2, 0.0001)

	scene.call("set_playback_speed", 2.0)
	assert_float(float(scene.call("playback_speed"))).is_equal_approx(2.0, 0.0001)
	assert_float(timer.wait_time) \
		.append_failure_message("tempo 2x powinno dac interwal 0,05 s") \
		.is_equal_approx(0.05, 0.0001)

	# Krancowe wartosci nie wychodza poza zakres.
	scene.call("step_speed", 1)
	assert_float(float(scene.call("playback_speed"))).is_equal_approx(2.0, 0.0001)
	scene.call("set_playback_speed", 0.5)
	scene.call("step_speed", -1)
	assert_float(float(scene.call("playback_speed"))).is_equal_approx(0.5, 0.0001)


## Dymny test: zmiana tempa nie rusza ticka, fazy ani logu.
func test_playback_speed_preserves_tick_phase_and_event_log() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	_enter_run_paused(scene)
	for i in range(8):
		scene.call("single_step")

	var before := _simulation_of(scene)
	var tick_before := before.get_tick()
	var log_before := before.get_canonical_log()
	assert_int(tick_before).is_equal(8)
	assert_str(log_before).is_not_empty()

	scene.call("set_playback_speed", 2.0)

	var after := _simulation_of(scene)
	assert_bool(before == after) \
		.append_failure_message("zmiana tempa utworzyla nowa instancje Simulation") \
		.is_true()
	assert_int(after.get_tick()) \
		.append_failure_message("zmiana tempa zresetowala tick") \
		.is_equal(tick_before)
	assert_str(after.get_canonical_log()) \
		.append_failure_message("zmiana tempa wyczyscila event log") \
		.is_equal(log_before)
	assert_int(int(scene.call("current_phase"))) \
		.append_failure_message("zmiana tempa przelaczyla faze") \
		.is_equal(PHASE_RUN)

	# Pojedynczy krok nadal zwieksza tick dokladnie o 1, niezaleznie od tempa.
	scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(tick_before + 1)


## Dymny test: restart i przejścia PLAN ↔ RUN zachowują wybrane tempo.
func test_restart_and_phase_changes_preserve_playback_speed() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud
	var timer := scene.get_node("StepTimer") as Timer

	scene.call("set_playback_speed", 0.5)

	_enter_run_paused(scene)
	hud.restart_requested.emit()
	assert_float(float(scene.call("playback_speed"))) \
		.append_failure_message("restart zgubil wybrane tempo") \
		.is_equal_approx(0.5, 0.0001)
	assert_float(timer.wait_time).is_equal_approx(0.2, 0.0001)

	scene.call("return_to_plan")
	assert_float(float(scene.call("playback_speed"))) \
		.append_failure_message("powrot do planu zgubil wybrane tempo") \
		.is_equal_approx(0.5, 0.0001)

	scene.call("start_run")
	assert_float(float(scene.call("playback_speed"))).is_equal_approx(0.5, 0.0001)
	assert_float(timer.wait_time).is_equal_approx(0.2, 0.0001)
	assert_int(_simulation_of(scene).get_tick()).is_equal(0)


## Dymny test: wyróżniane są wyłącznie ticki, w których zapadła decyzja
## albo wynik — rutynowe mijanie waypointów nie miga.
func test_only_decision_ticks_are_highlighted() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	# W fazie planowania nie ma czego wyrozniac.
	assert_array(scene.call("notable_events")).is_empty()
	assert_array(scene.call("highlight_cells")).is_empty()

	_enter_run_paused(scene)
	# Tick 31 to zwykle minięcie waypointu.
	for i in range(PUZZLE_SUSPICION_TICK - 1):
		scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(PUZZLE_SUSPICION_TICK - 1)
	assert_array(scene.call("notable_events")) \
		.append_failure_message("rutynowy waypoint nie powinien byc wyrozniony") \
		.is_empty()
	assert_array(scene.call("highlight_cells")).is_empty()

	# Tick 32 to przejscie straznika w SUSPICION.
	scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(PUZZLE_SUSPICION_TICK)

	var notable: Array = scene.call("notable_events")
	assert_int(notable.size()) \
		.append_failure_message("przejscie FSM powinno byc wyroznione") \
		.is_equal(1)
	assert_str(String(notable[0]["event"])).is_equal(GuardFsm.STATE_SUSPICION)
	assert_array(scene.call("highlight_cells")) \
		.append_failure_message("wyrozniona komorka straznika powinna byc wskazana") \
		.contains([_simulation_of(scene).get_state_snapshot()["guard_position"]])


## Dymny test: oś czasu znaczy ticki decyzji i zakończenie przebiegu.
func test_timeline_marks_decision_ticks_and_terminal_tick() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	_enter_run_paused(scene)

	assert_array(scene.call("timeline_event_ticks")).is_empty()
	assert_int(int(scene.call("terminal_tick"))) \
		.append_failure_message("przed startem nie ma ticka terminalnego") \
		.is_equal(-1)

	for i in range(60):
		scene.call("single_step")

	assert_bool(_simulation_of(scene).is_finished()).is_true()
	assert_array(scene.call("timeline_event_ticks")) \
		.append_failure_message("os czasu powinna znaczyc ticki decyzji, bez waypointow") \
		.is_equal(PUZZLE_DECISION_TICKS)
	assert_int(int(scene.call("terminal_tick"))).is_equal(PUZZLE_TERMINAL_TICK)


## Dymny test: cofanie działa dzięki determinizmowi rdzenia — odtworzenie
## przebiegu do tego samego ticka daje identyczny log i snapshot.
func test_step_back_replays_run_deterministically() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	_enter_run_paused(scene)

	for i in range(60):
		scene.call("single_step")
	var terminal_log := _simulation_of(scene).get_canonical_log()
	assert_int(_simulation_of(scene).get_tick()).is_equal(PUZZLE_TERMINAL_TICK)

	# Cofniecie odblokowuje dalsza gre: stan przestaje byc terminalny.
	scene.call("step_back")
	assert_int(_simulation_of(scene).get_tick()).is_equal(PUZZLE_TERMINAL_TICK - 1)
	assert_bool(_simulation_of(scene).is_finished()) \
		.append_failure_message("po cofnieciu przebieg nie powinien byc zakonczony") \
		.is_false()
	assert_bool(bool(scene.get("_running"))).is_false()

	# Ponowne dojscie do konca musi dac dokladnie ten sam log.
	scene.call("single_step")
	assert_str(_simulation_of(scene).get_canonical_log()) \
		.append_failure_message("odtworzony przebieg rozni sie od oryginalnego") \
		.is_equal(terminal_log)

	# seek_to_tick(n) jest rownowazne n pojedynczym krokom.
	scene.call("seek_to_tick", 20)
	var seek_snapshot := _simulation_of(scene).get_canonical_snapshot()
	scene.call("seek_to_tick", 0)
	for i in range(20):
		scene.call("single_step")
	assert_str(_simulation_of(scene).get_canonical_snapshot()) \
		.append_failure_message("seek_to_tick rozni sie od krokow po jednym ticku") \
		.is_equal(seek_snapshot)

	# Na ticku 0 cofanie jest bezpiecznym no-op.
	scene.call("seek_to_tick", 0)
	scene.call("step_back")
	assert_int(_simulation_of(scene).get_tick()).is_equal(0)


## Dymny test: oś czasu odwzorowuje piksel na tick i przewija po kliknięciu.
## Trafienie liczone jest matematyką prostokąta, bez Area2D i kolizji.
func test_timeline_click_seeks_to_tick() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var timeline := scene.get_node("Timeline") as TimelineView
	var origin: Vector2 = timeline.global_position
	_enter_run_paused(scene)

	assert_int(timeline.horizon()).is_equal(40)
	assert_int(timeline.tick_at_global_point(origin + Vector2(0.0, 13.0))).is_equal(0)
	assert_int(timeline.tick_at_global_point(
		origin + Vector2(TimelineView.WIDTH * 0.5, 13.0))).is_equal(20)
	assert_int(timeline.tick_at_global_point(
		origin + Vector2(TimelineView.WIDTH, 13.0))).is_equal(40)

	assert_bool(timeline.contains_global_point(origin + Vector2(280.0, 13.0))).is_true()
	assert_bool(timeline.contains_global_point(origin + Vector2(280.0, 200.0))) \
		.append_failure_message("punkt daleko pod paskiem nie moze byc trafieniem") \
		.is_false()

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.global_position = origin + Vector2(TimelineView.WIDTH * 0.5, 13.0)
	scene.call("_unhandled_input", click)

	assert_int(_simulation_of(scene).get_tick()) \
		.append_failure_message("klikniecie w os czasu powinno przewinac przebieg") \
		.is_equal(20)
	assert_bool(bool(scene.get("_running"))).is_false()

	# Klikniecie poza osia nie rusza przebiegu.
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.global_position = origin + Vector2(280.0, 200.0)
	scene.call("_unhandled_input", outside)
	assert_int(_simulation_of(scene).get_tick()).is_equal(20)


## Dymny test: Home wraca na początek, End dociąga do wyniku terminalnego.
## W fazie planowania przewijanie nie ma czego przewijać.
func test_seek_to_end_reaches_terminal_outcome() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	scene.call("seek_to_end")
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_PLAN)
	assert_object(_simulation_of(scene)).is_null()

	_enter_run_paused(scene)
	scene.call("seek_to_end")
	assert_bool(_simulation_of(scene).is_finished()).is_true()
	assert_int(_simulation_of(scene).get_tick()).is_equal(PUZZLE_TERMINAL_TICK)
	assert_str(_simulation_of(scene).get_outcome()) \
		.is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)

	scene.call("seek_to_tick", 0)
	assert_int(_simulation_of(scene).get_tick()).is_equal(0)
	assert_bool(_simulation_of(scene).is_finished()).is_false()


## Klawisze faz: Spacja uruchamia noc, P wraca do planu, R w planie przywraca
## plan domyślny, a w nocy restartuje ją na tym samym planie.
func test_phase_keys_switch_between_plan_and_run() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor

	assert_bool(editor.begin_drag(Vector2i(16, 8))).is_true()
	editor.drag_to(Vector2i(16, 10))
	editor.end_drag()

	_press_key(scene, KEY_SPACE)
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_RUN)
	assert_bool(bool(scene.get("_running"))).is_true()

	# W nocy Spacja to pauza, a R restartuje noc na tym samym planie.
	_press_key(scene, KEY_SPACE)
	assert_bool(bool(scene.get("_running"))).is_false()
	scene.call("single_step")
	_press_key(scene, KEY_R)
	assert_int(_simulation_of(scene).get_tick()).is_equal(0)
	assert_vector((editor.draft().guard_waypoints)[2]).is_equal(Vector2i(16, 10))

	_press_key(scene, KEY_P)
	assert_int(int(scene.call("current_phase"))).is_equal(PHASE_PLAN)
	assert_bool(bool(scene.get("_running"))).is_false()

	# R w planie: plan domyslny zagadki.
	_press_key(scene, KEY_R)
	assert_array(editor.draft().guard_waypoints) \
		.is_equal(ScenarioL0.create_puzzle().guard_waypoints)


## Mysz w fazie planowania: naciśnięcie na waypoincie, ruch, puszczenie.
## Koordynator zamienia piksele na komórki; edytor dostaje wyłącznie komórki.
func test_mouse_drag_on_board_moves_waypoint() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor
	var board_origin := (scene.get_node("LevelL0") as Node2D).global_position
	var half_cell := Vector2.ONE * float(LevelView.CELL_SIZE) * 0.5

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = board_origin + Vector2(Vector2i(16, 8) * LevelView.CELL_SIZE) + half_cell
	scene.call("_unhandled_input", press)
	assert_bool(editor.is_dragging()).is_true()

	var motion := InputEventMouseMotion.new()
	motion.global_position = board_origin + Vector2(Vector2i(16, 11) * LevelView.CELL_SIZE) + half_cell
	scene.call("_unhandled_input", motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = motion.global_position
	scene.call("_unhandled_input", release)

	assert_bool(editor.is_dragging()).is_false()
	assert_vector(editor.draft().guard_waypoints[2]).is_equal(Vector2i(16, 11))
	var preview: Dictionary = scene.call("plan_preview_snapshot")
	assert_vector((preview["guard_waypoints"] as Array)[2]) \
		.append_failure_message("podglad planu nie pokazuje przesunietego waypointu") \
		.is_equal(Vector2i(16, 11))


## Ta sama operacja co wyżej, ale przez prawdziwą ścieżkę wejścia viewportu
## (`push_input`): najpierw GUI, dopiero potem `_unhandled_input`. Test wyżej
## woła `_unhandled_input` wprost, więc nie widzi Controla, który po drodze
## zjada kliknięcie — w buildzie Web plansza była przez to martwa dla myszy.
func test_board_mouse_input_reaches_runner_through_viewport() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor
	var viewport := scene.get_viewport()
	var board_origin := (scene.get_node("LevelL0") as Node2D).global_position
	var half_cell := Vector2.ONE * float(LevelView.CELL_SIZE) * 0.5
	var from := board_origin + Vector2(Vector2i(16, 8) * LevelView.CELL_SIZE) + half_cell
	var to := board_origin + Vector2(Vector2i(16, 11) * LevelView.CELL_SIZE) + half_cell

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	viewport.push_input(press, true)
	assert_bool(editor.is_dragging()) \
		.append_failure_message("klikniecie w wezel nie dotarlo do koordynatora - cos w scenie lapie mysz") \
		.is_true()

	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	viewport.push_input(motion, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	viewport.push_input(release, true)

	assert_bool(editor.is_dragging()).is_false()
	assert_vector(editor.draft().guard_waypoints[2]).is_equal(Vector2i(16, 11))

## Pełnoekranowy korzeń HUD nie może łapać myszy, a przyciski nie mogą
## przechwytywać Spacji fokusem — inaczej gry nie da się obsłużyć myszą i Spacją.
func test_hud_does_not_steal_mouse_or_space() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Control

	assert_int(hud.mouse_filter) \
		.append_failure_message("korzen HUD przechwytuje mysz nad plansza") \
		.is_equal(Control.MOUSE_FILTER_IGNORE)
	for child in hud.get_children():
		if child is Button:
			assert_int((child as Button).focus_mode) \
				.append_failure_message("przycisk %s moze przejac Spacje fokusem" % child.name) \
				.is_equal(Control.FOCUS_NONE)


## Układ HUD musi mieścić się w viewporcie i nie może się nakładać.
##
## To jedyny test, który łapie wady widoczne wyłącznie na ekranie. Etykiety
## rozpychają się ponad zdefiniowane offsety, gdy tekst jest szerszy albo wyższy
## niż przewidziano, więc sam .tscn niczego nie gwarantuje. Stan po `seek_to_end`
## jest najgorszym przypadkiem nocy: najdłuższy komunikat końcowy i pełny panel
## zdarzeń. W planowaniu najgorszy jest widoczny komunikat odrzuconej edycji.
func test_hud_layout_fits_viewport_without_overlaps() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var editor := scene.get_node("PlanEditor") as PlanEditor

	# Plan: odrzucone upuszczenie kamery na trase intruza.
	assert_bool(editor.begin_drag(Vector2i(3, 3))).is_true()
	editor.drag_to(Vector2i(1, 15))
	assert_bool(editor.end_drag()).is_false()
	assert_str(String(scene.call("plan_message"))).is_not_empty()
	await runner.simulate_frames(1)
	_assert_hud_layout(scene, "PLAN")

	_enter_run_paused(scene)
	scene.call("seek_to_end")
	await runner.simulate_frames(1)
	_assert_hud_layout(scene, "NOC")


func _assert_hud_layout(scene: Node, phase_label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
	var hud := scene.get_node("HudLayer/Hud") as Control

	var names: Array[String] = []
	var rects: Array[Rect2] = []
	for child in hud.get_children():
		if child is Control:
			var control := child as Control
			names.append(String(control.name))
			rects.append(Rect2(control.position, control.size))

	assert_int(rects.size()) \
		.append_failure_message("HUD nie ma kontrolek — test bylby pusty") \
		.is_greater(10)

	for i in rects.size():
		assert_bool(viewport.encloses(rects[i])) \
			.append_failure_message("%s: %s wychodzi poza viewport: %s" % [
				phase_label, names[i], str(rects[i])]) \
			.is_true()

	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_bool(rects[i].intersects(rects[j])) \
				.append_failure_message("%s: %s naklada sie na %s: %s x %s" % [
					phase_label, names[i], names[j], str(rects[i]), str(rects[j])]) \
				.is_false()


## Plansza i oś czasu nie mogą na siebie wchodzić ani wjeżdżać w słupek HUD.
func test_board_and_timeline_do_not_collide() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	var board_size := float(LevelView.CELL_SIZE * 20)
	var board := Rect2((scene.get_node("LevelL0") as Node2D).position,
		Vector2(board_size, board_size))

	var timeline := scene.get_node("Timeline") as TimelineView
	var timeline_rect := Rect2(
		timeline.position + Vector2(0.0, -TimelineView.HIT_PADDING),
		Vector2(TimelineView.WIDTH, TimelineView.HEIGHT + TimelineView.HIT_PADDING * 2.0))

	var viewport := Rect2(Vector2.ZERO, Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
	assert_bool(viewport.encloses(board)).is_true()
	assert_bool(viewport.encloses(timeline_rect)) \
		.append_failure_message("os czasu wychodzi poza viewport: %s" % str(timeline_rect)) \
		.is_true()
	assert_bool(board.intersects(timeline_rect)) \
		.append_failure_message("plansza naklada sie na os czasu") \
		.is_false()

	var hud_column := Rect2(Vector2(HUD_COLUMN_LEFT, 0.0),
		Vector2(VIEWPORT_WIDTH - HUD_COLUMN_LEFT, VIEWPORT_HEIGHT))
	assert_bool(board.intersects(hud_column)) \
		.append_failure_message("plansza wjezdza w slupek HUD") \
		.is_false()
	assert_bool(timeline_rect.intersects(hud_column)) \
		.append_failure_message("os czasu wjezdza w slupek HUD") \
		.is_false()

	# Edytor planu lezy dokladnie na planszy — komorka to ten sam piksel.
	assert_vector((scene.get_node("PlanEditor") as Node2D).position) \
		.is_equal((scene.get_node("LevelL0") as Node2D).position)


## Panele wyrównują kolumny spacjami, więc czcionka musi mieć stałą szerokość.
func test_hud_panels_use_fixed_width_font() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	for path: String in ["StatusLabel", "LegendLabel", "LogLabel"]:
		var label := scene.get_node("HudLayer/Hud/%s" % path) as Label
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font")
		var narrow := font.get_string_size(
			"iiiiiiiiii", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var wide := font.get_string_size(
			"MMMMMMMMMM", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_float(narrow) \
			.append_failure_message(
				"%s nie uzywa czcionki o stalej szerokosci: 'i'=%.1f 'M'=%.1f" % [
					path, narrow, wide]) \
			.is_equal_approx(wide, 0.5)


## Warstwa prezentacji nie może zawierać fizyki: żadnych ciał, obszarów,
## kształtów kolizji, raycastów ani agentów nawigacji. Dotyczy to także
## edytora planu — trafienie w komórkę to arytmetyka, nie kolizja.
func test_presentation_contains_no_physics_nodes() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	assert_object(scene.get_node_or_null("PlanEditor")) \
		.append_failure_message("edytor planu powinien byc czescia sprawdzanej sceny") \
		.is_not_null()

	var forbidden := [
		"Area2D", "CollisionShape2D", "CollisionPolygon2D", "RayCast2D", "ShapeCast2D",
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "AnimatableBody2D",
		"NavigationAgent2D",
	]
	_assert_no_forbidden_nodes(scene, forbidden)


func _assert_no_forbidden_nodes(node: Node, forbidden: Array) -> void:
	for type_name: String in forbidden:
		assert_bool(node.is_class(type_name)) \
			.append_failure_message("node '%s' jest typu %s" % [node.name, type_name]) \
			.is_false()
	for child in node.get_children():
		_assert_no_forbidden_nodes(child, forbidden)


## Widok czyta snapshot i nie może go modyfikować w rdzeniu.
func test_view_cannot_mutate_core_state() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	_enter_run_paused(scene)
	var simulation := _simulation_of(scene)
	var level_view := scene.get_node("LevelL0") as LevelView

	var snapshot := simulation.get_state_snapshot()
	snapshot["guard_position"] = Vector2i(0, 0)
	snapshot["guard_state"] = GuardFsm.STATE_ALARM
	level_view.render(snapshot)

	var fresh := simulation.get_state_snapshot()
	assert_vector(fresh["guard_position"]).is_equal(ScenarioL0.create_puzzle().guard_start)
	assert_str(String(fresh["guard_state"])).is_equal(GuardFsm.STATE_PATROL)
	assert_int(simulation.get_tick()).is_equal(0)
