## Test integracyjny sceny głównej.
##
## To jedyne miejsce w zestawie testów, w którym powstają node'y — i jedyne
## odpowiedzialne za kontrolę orphan nodes. Rdzeń nie tworzy node'ów w ogóle.
##
## Ticki są wyzwalane przez jawną emisję sygnału Timera, a nie przez czekanie na
## czas rzeczywisty: kontrakt adaptera brzmi "jeden timeout to jeden step()".
extends GdUnitTestSuite

const MAIN_SCENE := "res://scenes/main.tscn"
const RESTART_CYCLES := 20
const TICKS_PER_CYCLE := 5

## Rozmiar viewportu z project.godot i lewa krawedz slupka HUD z main.tscn.
const VIEWPORT_WIDTH := 1280.0
const VIEWPORT_HEIGHT := 800.0
const HUD_COLUMN_LEFT := 620.0

## Indeksy wariantow incydentu (enum ScenarioVariant w simulation_runner.gd).
const VARIANT_DETECTION := 0
const VARIANT_SUCCESS := 1
const VARIANT_TICK_LIMIT := 2


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


func test_main_scene_instantiates_with_initial_state() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	var simulation := _simulation_of(scene)
	assert_object(simulation).is_not_null()
	assert_int(simulation.get_tick()).is_equal(0)
	assert_bool(simulation.is_finished()).is_false()
	assert_bool(bool(scene.get("_running"))).is_false()

	var status := scene.get_node("HudLayer/Hud/StatusLabel") as Label
	assert_str(status.text).contains("tick:")
	assert_str(status.text).contains(Hud.STATUS_PAUSED)

	# Wynik terminalny ma wlasna etykiete, nie panel statusu.
	var outcome := scene.get_node("HudLayer/Hud/OutcomeLabel") as Label
	assert_str(outcome.text).is_not_empty()


func test_start_pause_resume_restart_controls() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud
	var simulation := _simulation_of(scene)

	hud.start_requested.emit()
	assert_bool(bool(scene.get("_running"))) \
		.append_failure_message("Start nie uruchomil odtwarzania") \
		.is_true()

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

	# Restart podstawia swieza instancje Simulation na swiezym scenariuszu,
	# wiec stan trzeba odczytac ponownie ze sceny.
	hud.restart_requested.emit()
	var after_restart := _simulation_of(scene)
	assert_bool(bool(scene.get("_running"))).is_false()
	assert_int(after_restart.get_tick()).is_equal(0)
	assert_array(after_restart.get_event_log()).is_empty()
	assert_bool(after_restart.is_finished()).is_false()


## 20 cykli Start/Pauza/Restart: stan po każdym resecie musi być identyczny
## ze stanem początkowym, a liczba node'ów sceny nie może rosnąć.
func test_twenty_restart_cycles_are_stable() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

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

	var before := status.text
	scene.call("single_step")

	assert_int(_simulation_of(scene).get_tick()).is_equal(1)
	assert_str(status.text) \
		.append_failure_message("HUD nie odswiezyl sie po ticku") \
		.is_not_equal(before)


## Dymny test: wynik terminalny zatrzymuje automatyczny przebieg.
func test_terminal_outcome_stops_auto_run() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

	hud.start_requested.emit()
	assert_bool(bool(scene.get("_running"))).is_true()

	# Incydent domyslny konczy sie wykryciem; dajemy zapas timeoutow.
	_fire_ticks(scene, 60)

	var simulation := _simulation_of(scene)
	assert_bool(simulation.is_finished()) \
		.append_failure_message("incydent nie domknal sie") \
		.is_true()
	assert_bool(bool(scene.get("_running"))) \
		.append_failure_message("automatyczny przebieg nie zatrzymal sie po wyniku terminalnym") \
		.is_false()

	var status := scene.get_node("HudLayer/Hud/StatusLabel") as Label
	assert_str(status.text).contains(Hud.STATUS_FINISHED)

	var outcome := scene.get_node("HudLayer/Hud/OutcomeLabel") as Label
	assert_str(outcome.text) \
		.append_failure_message("komunikat koncowy nie pojawil sie w HUD") \
		.is_not_empty()


## Dymny test: przełączniki prezentacji zmieniają stan widoku, nie rdzenia.
func test_overlay_and_log_toggles_change_presentation_state() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var level_view := scene.get_node("LevelL0") as LevelView
	var log_label := scene.get_node("HudLayer/Hud/LogLabel") as Label
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


## Dymny test: każdy wariant startuje od świeżych danych o oczekiwanej konfiguracji.
## Warianty to wyłącznie inne dane wejściowe tego samego silnika L0.
func test_selecting_each_variant_restarts_with_expected_configuration() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	var expected := [
		{"variant": VARIANT_DETECTION, "view_range": 6, "max_ticks": 400},
		{"variant": VARIANT_SUCCESS, "view_range": 4, "max_ticks": 400},
		{"variant": VARIANT_TICK_LIMIT, "view_range": 6, "max_ticks": 20},
	]

	for case: Dictionary in expected:
		scene.call("select_variant", case["variant"])
		var snapshot := _simulation_of(scene).get_state_snapshot()

		assert_int(int(snapshot["tick"])) \
			.append_failure_message("wariant %d: tick po wyborze" % int(case["variant"])) \
			.is_equal(0)
		assert_int(int(snapshot["guard_view_range"])) \
			.append_failure_message("wariant %d: zasieg widzenia straznika" % int(case["variant"])) \
			.is_equal(int(case["view_range"]))
		assert_int(int(snapshot["max_ticks"])) \
			.append_failure_message("wariant %d: limit tickow" % int(case["variant"])) \
			.is_equal(int(case["max_ticks"]))
		assert_bool(bool(scene.get("_running"))) \
			.append_failure_message("wariant %d: przebieg nie jest w stanie PAUSED" % int(case["variant"])) \
			.is_false()


## Dymny test: zmiana wariantu kasuje wynik terminalny i panel zdarzeń.
func test_variant_selection_clears_terminal_state_and_event_log() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

	hud.start_requested.emit()
	_fire_ticks(scene, 60)

	var before := _simulation_of(scene)
	assert_bool(before.is_finished()) \
		.append_failure_message("wariant domyslny nie domknal sie") \
		.is_true()
	assert_array(before.get_event_log()).is_not_empty()

	scene.call("select_variant", VARIANT_TICK_LIMIT)
	var after := _simulation_of(scene)

	assert_bool(before == after) \
		.append_failure_message("wybor wariantu nie utworzyl nowej instancji Simulation") \
		.is_false()
	assert_int(after.get_tick()).is_equal(0)
	assert_str(after.get_outcome()).is_equal(SimulationState.OUTCOME_NONE)
	assert_array(after.get_event_log()) \
		.append_failure_message("panel zdarzen nie zostal wyczyszczony") \
		.is_empty()
	assert_bool(bool(scene.get("_running"))).is_false()

	var outcome_label := scene.get_node("HudLayer/Hud/OutcomeLabel") as Label
	assert_str(outcome_label.text) \
		.append_failure_message("komunikat terminalny poprzedniego wariantu nie zniknal") \
		.not_contains("WYKRYTY")


## Dymny test: restart odtwarza wybrany wariant, nie wraca do domyślnego.
func test_restart_preserves_selected_variant() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud

	scene.call("select_variant", VARIANT_SUCCESS)
	scene.call("single_step")
	scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(2)

	hud.restart_requested.emit()

	var snapshot := _simulation_of(scene).get_state_snapshot()
	assert_int(int(snapshot["tick"])).is_equal(0)
	assert_int(int(snapshot["guard_view_range"])) \
		.append_failure_message("restart zgubil parametry wybranego wariantu") \
		.is_equal(4)
	assert_str(String(scene.call("current_variant_name"))) \
		.append_failure_message("restart przelaczyl wariant") \
		.is_equal("SUKCES INTRUZA")
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


## Dymny test: zmiana tempa nie rusza ticka, wariantu ani logu.
func test_playback_speed_preserves_tick_variant_and_event_log() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	scene.call("select_variant", VARIANT_SUCCESS)
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
	assert_str(String(scene.call("current_variant_name"))) \
		.append_failure_message("zmiana tempa przelaczyla wariant") \
		.is_equal("SUKCES INTRUZA")

	# Pojedynczy krok nadal zwieksza tick dokladnie o 1, niezaleznie od tempa.
	scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(tick_before + 1)


## Dymny test: restart i zmiana wariantu zachowują wybrane tempo.
func test_restart_and_variant_selection_preserve_playback_speed() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	var hud := scene.get_node("HudLayer/Hud") as Hud
	var timer := scene.get_node("StepTimer") as Timer

	scene.call("set_playback_speed", 0.5)

	hud.restart_requested.emit()
	assert_float(float(scene.call("playback_speed"))) \
		.append_failure_message("restart zgubil wybrane tempo") \
		.is_equal_approx(0.5, 0.0001)
	assert_float(timer.wait_time).is_equal_approx(0.2, 0.0001)

	scene.call("select_variant", VARIANT_TICK_LIMIT)
	assert_float(float(scene.call("playback_speed"))) \
		.append_failure_message("zmiana wariantu zgubila wybrane tempo") \
		.is_equal_approx(0.5, 0.0001)
	assert_float(timer.wait_time).is_equal_approx(0.2, 0.0001)
	assert_int(_simulation_of(scene).get_tick()).is_equal(0)
	assert_bool(bool(scene.get("_running"))).is_false()


## Dymny test: wyróżniane są wyłącznie ticki, w których zapadła decyzja
## albo wynik — rutynowe mijanie waypointów nie miga.
func test_only_decision_ticks_are_highlighted() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	# Tick 35 to zwykle minięcie waypointu.
	for i in range(35):
		scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(35)
	assert_array(scene.call("notable_events")) \
		.append_failure_message("rutynowy waypoint nie powinien byc wyrozniony") \
		.is_empty()
	assert_array(scene.call("highlight_cells")).is_empty()

	# Tick 37 to przejscie straznika w SUSPICION.
	scene.call("single_step")
	scene.call("single_step")
	assert_int(_simulation_of(scene).get_tick()).is_equal(37)

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

	assert_array(scene.call("timeline_event_ticks")).is_empty()
	assert_int(int(scene.call("terminal_tick"))) \
		.append_failure_message("przed startem nie ma ticka terminalnego") \
		.is_equal(-1)

	for i in range(60):
		scene.call("single_step")

	assert_bool(_simulation_of(scene).is_finished()).is_true()
	assert_array(scene.call("timeline_event_ticks")) \
		.append_failure_message("os czasu powinna znaczyc ticki 37 i 38, bez waypointow") \
		.is_equal([37, 38])
	assert_int(int(scene.call("terminal_tick"))).is_equal(38)


## Dymny test: cofanie działa dzięki determinizmowi rdzenia — odtworzenie
## przebiegu do tego samego ticka daje identyczny log i snapshot.
func test_step_back_replays_run_deterministically() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	for i in range(60):
		scene.call("single_step")
	var terminal_log := _simulation_of(scene).get_canonical_log()
	assert_int(_simulation_of(scene).get_tick()).is_equal(38)

	# Cofniecie odblokowuje dalsza gre: stan przestaje byc terminalny.
	scene.call("step_back")
	assert_int(_simulation_of(scene).get_tick()).is_equal(37)
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
func test_seek_to_end_reaches_terminal_outcome() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

	scene.call("seek_to_end")
	assert_bool(_simulation_of(scene).is_finished()).is_true()
	assert_int(_simulation_of(scene).get_tick()).is_equal(38)

	scene.call("seek_to_tick", 0)
	assert_int(_simulation_of(scene).get_tick()).is_equal(0)
	assert_bool(_simulation_of(scene).is_finished()).is_false()

	# Wariant limitu konczy sie na swoim limicie, nie na 400.
	scene.call("select_variant", VARIANT_TICK_LIMIT)
	scene.call("seek_to_end")
	assert_int(_simulation_of(scene).get_tick()).is_equal(20)
	assert_str(_simulation_of(scene).get_outcome()) \
		.is_equal(SimulationState.OUTCOME_TICK_LIMIT)


## Układ HUD musi mieścić się w viewporcie i nie może się nakładać.
##
## To jedyny test, który łapie wady widoczne wyłącznie na ekranie. Etykiety
## rozpychają się ponad zdefiniowane offsety, gdy tekst jest szerszy albo wyższy
## niż przewidziano, więc sam .tscn niczego nie gwarantuje. Stan po `seek_to_end`
## jest najgorszym przypadkiem: najdłuższe teksty statusu i pełny panel zdarzeń.
func test_hud_layout_fits_viewport_without_overlaps() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()
	scene.call("seek_to_end")
	await runner.simulate_frames(1)

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
			.append_failure_message("%s wychodzi poza viewport: %s" % [names[i], str(rects[i])]) \
			.is_true()

	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_bool(rects[i].intersects(rects[j])) \
				.append_failure_message("%s naklada sie na %s: %s x %s" % [
					names[i], names[j], str(rects[i]), str(rects[j])]) \
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
## kształtów kolizji, raycastów ani agentów nawigacji.
func test_presentation_contains_no_physics_nodes() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var scene := runner.scene()

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
	var simulation := _simulation_of(scene)
	var level_view := scene.get_node("LevelL0") as LevelView

	var snapshot := simulation.get_state_snapshot()
	snapshot["guard_position"] = Vector2i(0, 0)
	snapshot["guard_state"] = GuardFsm.STATE_ALARM
	level_view.render(snapshot)

	var fresh := simulation.get_state_snapshot()
	assert_vector(fresh["guard_position"]).is_equal(Vector2i(10, 4))
	assert_str(String(fresh["guard_state"])).is_equal(GuardFsm.STATE_PATROL)
	assert_int(simulation.get_tick()).is_equal(0)
