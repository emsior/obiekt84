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
