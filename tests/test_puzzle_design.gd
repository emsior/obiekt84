## Własności projektu zagadki L1-C — sprawdzane wyczerpująco, nie na przykładach.
##
## Cel iteracji: sama kamera nigdy nie wygrywa, plan domyślny przegrywa, a plan
## referencyjny wymaga jednocześnie zmiany patrolu i kamery. Kamera namierza,
## wykrywa wyłącznie strażnik (`docs/DECISIONS.md`, 2026-09-24, L1-C).
##
## Czysty test rdzenia: zero node'ów, zero sceny, zero inputu, zero czasu.
extends GdUnitTestSuite

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

## Wszystkie dozwolone ustawienia kamery przy patrolu domyślnym: komórki poza
## trasą intruza i poza węzłami patrolu, cztery kierunki. Mianownik ze studium L1-C.
const EXPECTED_CAMERA_CONFIGS := 1420

## Plan referencyjny — ten sam, co w `tests/test_l0_golden_log.gd`.
const SOLUTION_WAYPOINT_2 := Vector2i(16, 8)
const SOLUTION_CAMERA_POSITION := Vector2i(12, 9)
const SOLUTION_CAMERA_FACING := Vector2i(0, 1)
const SOLUTION_TERMINAL_TICK := 32


func _outcome(scenario: ScenarioL0) -> String:
	var simulation := Simulation.new()
	simulation.initialize(scenario)
	while not simulation.is_finished():
		simulation.step()
	return simulation.get_outcome()


func test_default_plan_loses_and_guard_never_sees_intruder() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create_puzzle())
	while not simulation.is_finished():
		simulation.step()

	assert_str(simulation.get_outcome()).is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)
	assert_int(simulation.get_tick()).is_equal(40)
	assert_str(simulation.get_canonical_log()) \
		.append_failure_message("straznik planu domyslnego nie powinien widziec intruza") \
		.not_contains("|%s|" % GuardFsm.STATE_SUSPICION)


## Żadne z 1420 dozwolonych ustawień kamery nie wygrywa bez zmiany patrolu.
func test_camera_alone_never_wins_with_default_patrol() -> void:
	var puzzle := ScenarioL0.create_puzzle()
	var configs := 0
	var wins: Array[String] = []
	for x in range(puzzle.grid_width):
		for y in range(puzzle.grid_height):
			var cell := Vector2i(x, y)
			if puzzle.intruder_route.has(cell) or puzzle.guard_waypoints.has(cell):
				continue
			for facing: Vector2i in DIRECTIONS:
				var scenario := ScenarioL0.create_puzzle()
				scenario.camera_position = cell
				scenario.camera_facing = facing
				configs += 1
				if _outcome(scenario) == SimulationState.OUTCOME_INTRUDER_DETECTED:
					wins.append("%s %s" % [str(cell), str(facing)])

	assert_int(configs) \
		.append_failure_message("zmienila sie przestrzen ustawien kamery") \
		.is_equal(EXPECTED_CAMERA_CONFIGS)
	assert_array(wins) \
		.append_failure_message("sama kamera wygrywa bez zmiany patrolu") \
		.is_empty()


## Plan referencyjny wygrywa, a każda jego połowa osobno przegrywa.
func test_reference_solution_requires_both_patrol_and_camera() -> void:
	var both := ScenarioL0.create_puzzle()
	both.guard_waypoints[2] = SOLUTION_WAYPOINT_2
	both.camera_position = SOLUTION_CAMERA_POSITION
	both.camera_facing = SOLUTION_CAMERA_FACING
	var simulation := Simulation.new()
	simulation.initialize(both)
	while not simulation.is_finished():
		simulation.step()
	assert_str(simulation.get_outcome()).is_equal(SimulationState.OUTCOME_INTRUDER_DETECTED)
	assert_int(simulation.get_tick()).is_equal(SOLUTION_TERMINAL_TICK)

	var patrol_only := ScenarioL0.create_puzzle()
	patrol_only.guard_waypoints[2] = SOLUTION_WAYPOINT_2
	assert_str(_outcome(patrol_only)) \
		.append_failure_message("sama zmiana patrolu z planu referencyjnego juz wygrywa") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)

	var camera_only := ScenarioL0.create_puzzle()
	camera_only.camera_position = SOLUTION_CAMERA_POSITION
	camera_only.camera_facing = SOLUTION_CAMERA_FACING
	assert_str(_outcome(camera_only)) \
		.append_failure_message("sama kamera z planu referencyjnego juz wygrywa") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)
