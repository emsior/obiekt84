## Testy rdzenia symulacji: determinizm, reset, limit ticków, no-op po końcu.
##
## Żaden test w tym pliku nie używa Timerów, FPS, sceny, inputu ani czasu
## rzeczywistego. step() jest wywoływany jawnie.
extends GdUnitTestSuite

## Liczba niezależnych przebiegów w teście determinizmu.
const RUN_COUNT := 50
## Twardy limit bezpieczeństwa pętli testowej.
const HARD_TICK_LIMIT := 500


## Jeden pełny, niezależny przebieg. Zwraca wyłącznie kanoniczne łańcuchy —
## instancja symulacji nie opuszcza tej funkcji i jest zwalniana po powrocie.
## [param puzzle] wybiera dane zagadki L1-A zamiast `ScenarioL0.create()`.
func _run_once(puzzle := false) -> Dictionary:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create_puzzle() if puzzle else ScenarioL0.create())

	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1

	return {
		"log": simulation.get_canonical_log(),
		"snapshot": simulation.get_canonical_snapshot(),
		"tick": simulation.get_tick(),
		"outcome": simulation.get_outcome(),
		"finished": simulation.is_finished(),
	}


func _first_diff_line(expected: String, actual: String) -> int:
	var expected_lines := expected.split("\n")
	var actual_lines := actual.split("\n")
	var count := maxi(expected_lines.size(), actual_lines.size())
	for i in range(count):
		var e := expected_lines[i] if i < expected_lines.size() else "<brak wiersza>"
		var a := actual_lines[i] if i < actual_lines.size() else "<brak wiersza>"
		if e != a:
			return i
	return -1


func _describe_diff(run_index: int, label: String, expected: String, actual: String) -> String:
	var index := _first_diff_line(expected, actual)
	if index < 0:
		return "przebieg %d: %s rozni sie, ale nie znaleziono roznicy wierszowej" % [run_index, label]
	var expected_lines := expected.split("\n")
	var actual_lines := actual.split("\n")
	var expected_line := expected_lines[index] if index < expected_lines.size() else "<brak wiersza>"
	var actual_line := actual_lines[index] if index < actual_lines.size() else "<brak wiersza>"
	return "przebieg %d: pierwsza roznica w %s, wiersz %d\n  oczekiwano: %s\n  otrzymano:  %s" % [
		run_index, label, index, expected_line, actual_line]


## 50 niezależnych uruchomień identycznego scenariusza daje identyczny
## kanoniczny event log oraz identyczny końcowy snapshot.
func test_fifty_independent_runs_are_identical() -> void:
	_assert_fifty_independent_runs_are_identical(false)


## To samo dla planu domyślnego L1-A — danych, od których gracz zaczyna.
func test_fifty_independent_puzzle_runs_are_identical() -> void:
	_assert_fifty_independent_runs_are_identical(true)


func _assert_fifty_independent_runs_are_identical(puzzle: bool) -> void:
	var reference := _run_once(puzzle)

	assert_bool(bool(reference["finished"])) \
		.append_failure_message("przebieg referencyjny nie osiagnal stanu terminalnego") \
		.is_true()
	assert_str(String(reference["log"])) \
		.append_failure_message("przebieg referencyjny nie wyprodukowal zadnych zdarzen") \
		.is_not_empty()

	for run_index in range(1, RUN_COUNT):
		var current := _run_once(puzzle)

		assert_str(String(current["log"])) \
			.append_failure_message(_describe_diff(
				run_index, "event logu", String(reference["log"]), String(current["log"]))) \
			.is_equal(String(reference["log"]))

		assert_str(String(current["snapshot"])) \
			.append_failure_message(_describe_diff(
				run_index, "snapshotu koncowego", String(reference["snapshot"]), String(current["snapshot"]))) \
			.is_equal(String(reference["snapshot"]))
		# Referencje do biezacego przebiegu wygasaja tutaj - nie trzymamy
		# ani 50 instancji symulacji, ani 50 pelnych kopii logu.


func test_initial_state_has_tick_zero_and_empty_log() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())

	assert_int(simulation.get_tick()).is_equal(0)
	assert_array(simulation.get_event_log()).is_empty()
	assert_str(simulation.get_canonical_log()).is_empty()
	assert_bool(simulation.is_finished()).is_false()
	assert_str(simulation.get_outcome()).is_equal(SimulationState.OUTCOME_NONE)


## reset() odtwarza dokładnie stan początkowy, kasuje log poprzedniego przebiegu,
## a drugi przebieg na tej samej instancji daje ten sam kanoniczny log.
func test_reset_restores_initial_state_and_replays_identically() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())

	var initial_snapshot := simulation.get_canonical_snapshot()

	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1
	var first_log := simulation.get_canonical_log()
	var first_snapshot := simulation.get_canonical_snapshot()

	assert_bool(simulation.is_finished()).is_true()
	assert_str(first_log).is_not_empty()

	simulation.reset()

	assert_int(simulation.get_tick()).is_equal(0)
	assert_array(simulation.get_event_log()).is_empty()
	assert_str(simulation.get_canonical_log()).is_empty()
	assert_bool(simulation.is_finished()).is_false()
	assert_str(simulation.get_outcome()).is_equal(SimulationState.OUTCOME_NONE)
	assert_str(simulation.get_canonical_snapshot()) \
		.append_failure_message(_describe_diff(
			0, "snapshotu po resecie", initial_snapshot, simulation.get_canonical_snapshot())) \
		.is_equal(initial_snapshot)

	steps = 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1

	assert_str(simulation.get_canonical_log()) \
		.append_failure_message(_describe_diff(
			1, "event logu po resecie", first_log, simulation.get_canonical_log())) \
		.is_equal(first_log)
	assert_str(simulation.get_canonical_snapshot()).is_equal(first_snapshot)


func test_simulation_finishes_within_tick_limit() -> void:
	var scenario := ScenarioL0.create()
	var simulation := Simulation.new()
	simulation.initialize(scenario)

	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1

	assert_bool(simulation.is_finished()) \
		.append_failure_message("symulacja nie zakonczyla sie w %d krokach" % HARD_TICK_LIMIT) \
		.is_true()
	assert_int(simulation.get_tick()) \
		.append_failure_message("incydent L0 powinien konczyc sie dlugo przed limitem scenariusza") \
		.is_less(scenario.max_ticks)
	assert_str(simulation.get_outcome()).is_not_equal(SimulationState.OUTCOME_TICK_LIMIT)


## Po stanie terminalnym step() jest bezpiecznym no-op: nie zwiększa ticka,
## nie zmienia stanu i nie dopisuje zdarzeń.
func test_step_after_terminal_state_is_noop() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())

	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1

	var terminal_tick := simulation.get_tick()
	var terminal_log := simulation.get_canonical_log()
	var terminal_snapshot := simulation.get_canonical_snapshot()
	var terminal_log_size := simulation.get_event_log().size()

	for i in range(10):
		simulation.step()

	assert_int(simulation.get_tick()).is_equal(terminal_tick)
	assert_int(simulation.get_event_log().size()).is_equal(terminal_log_size)
	assert_str(simulation.get_canonical_log()).is_equal(terminal_log)
	assert_str(simulation.get_canonical_snapshot()).is_equal(terminal_snapshot)


## Tick zwiększa się dokładnie raz na krok.
func test_tick_increments_exactly_once_per_step() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())

	var expected_tick := 0
	while not simulation.is_finished() and expected_tick < HARD_TICK_LIMIT:
		simulation.step()
		expected_tick += 1
		assert_int(simulation.get_tick()) \
			.append_failure_message("tick rozjechal sie z liczba wywolan step()") \
			.is_equal(expected_tick)


## Każde zdarzenie ma pełny, stały schemat i rosnący numer ticka.
func test_event_log_entries_follow_fixed_schema() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())
	while not simulation.is_finished():
		simulation.step()

	var entries := simulation.get_event_log()
	assert_array(entries).is_not_empty()

	var previous_tick := 0
	for entry: Dictionary in entries:
		assert_array(entry.keys()).contains(["tick", "subject", "event", "reason"])
		assert_int(int(entry["tick"])).is_greater(0)
		assert_int(int(entry["tick"])) \
			.append_failure_message("event log nie jest uporzadkowany rosnaco po ticku") \
			.is_greater_equal(previous_tick)
		previous_tick = int(entry["tick"])
		assert_str(String(entry["subject"])).is_not_empty()
		assert_str(String(entry["event"])).is_not_empty()
		assert_str(String(entry["reason"])).is_not_empty()


## Rdzeń pracuje na własnej kopii scenariusza — zmiana przekazanego obiektu
## po initialize() nie może wpłynąć na przebieg.
func test_scenario_data_is_copied_on_initialize() -> void:
	var scenario := ScenarioL0.create()
	var simulation := Simulation.new()
	simulation.initialize(scenario)

	scenario.guard_start = Vector2i(0, 0)
	scenario.intruder_route.clear()
	scenario.guard_waypoints.clear()

	var snapshot := simulation.get_state_snapshot()
	assert_vector(snapshot["guard_position"]).is_equal(Vector2i(10, 4))
	assert_array(snapshot["intruder_route"]).is_not_empty()
	assert_array(snapshot["guard_waypoints"]).has_size(4)


## Snapshot jest kopią — modyfikacja zwróconego słownika nie zmienia rdzenia.
func test_snapshot_is_a_copy() -> void:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())

	var snapshot := simulation.get_state_snapshot()
	snapshot["tick"] = 999
	snapshot["guard_state"] = "TAMPERED"

	assert_int(simulation.get_state_snapshot()["tick"]).is_equal(0)
	assert_str(String(simulation.get_state_snapshot()["guard_state"])).is_equal(GuardFsm.STATE_PATROL)


## Tick, w ktorym wykrycie intruza i wyczerpanie limitu zachodza jednoczesnie.
## Przy domyslnych danych wykrycie wypada w 38 ticku, wiec max_ticks = 38 tworzy
## remis: oba warunki terminalne sa w tej samej fazie 7 prawdziwe.
const TIE_MAX_TICKS := 38


## Kontrakt priorytetu wynikow terminalnych: gdy w jednym ticku prawdziwe jest
## i wykrycie intruza, i tick >= max_ticks, wygrywa INTRUDER_DETECTED.
##
## Kolejnosc galezi w Simulation._resolve_outcome() jest jedynym zrodlem tej
## reguly. Golden logi jej nie pilnuja — w zadnym z nich remis nie wystepuje,
## wiec odwrocenie kolejnosci warunkow przeszloby tamte testy niezauwazone.
func test_detection_has_priority_over_tick_limit_on_same_tick() -> void:
	var scenario := ScenarioL0.create()
	scenario.max_ticks = TIE_MAX_TICKS

	var simulation := Simulation.new()
	simulation.initialize(scenario)

	var steps := 0
	while not simulation.is_finished() and steps < TIE_MAX_TICKS:
		simulation.step()
		steps += 1

	# Remis jest rzeczywisty: przebieg zatrzymal sie dokladnie na limicie.
	assert_bool(simulation.is_finished()) \
		.append_failure_message("przebieg nie osiagnal stanu terminalnego") \
		.is_true()
	assert_int(simulation.get_tick()) \
		.append_failure_message("przebieg nie zatrzymal sie na ticku remisu") \
		.is_equal(TIE_MAX_TICKS)
	assert_bool(simulation.get_tick() >= scenario.max_ticks) \
		.append_failure_message("warunek limitu tickow nie byl spelniony, brak remisu") \
		.is_true()

	# Rozstrzygniecie remisu.
	assert_str(simulation.get_outcome()) \
		.append_failure_message("wykrycie intruza musi wyprzedzac limit tickow w tym samym ticku") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_DETECTED)
	assert_str(simulation.get_outcome()) \
		.append_failure_message("limit tickow przejal pierwszenstwo nad wykryciem") \
		.is_not_equal(SimulationState.OUTCOME_TICK_LIMIT)

	var canonical := simulation.get_canonical_log()
	assert_str(canonical) \
		.append_failure_message("log nie zawiera wykrycia intruza") \
		.contains("|%s|%s|" % [ScenarioL0.INTRUDER_ID, IntruderScript.STATE_DETECTED])
	assert_str(canonical) \
		.append_failure_message("brak terminalnego wpisu o wykryciu") \
		.contains("|%s|FINISHED|intruder_detected" % Simulation.SUBJECT_SIMULATION)
	assert_str(canonical) \
		.append_failure_message("log zawiera terminalny wpis limitu tickow") \
		.not_contains("|%s|FINISHED|tick_limit" % Simulation.SUBJECT_SIMULATION)

	# Po rozstrzygnieciu remisu kolejny step() nadal jest no-op.
	var tick_before := simulation.get_tick()
	var log_before := canonical
	var snapshot_before := simulation.get_canonical_snapshot()

	simulation.step()
	simulation.step()

	assert_int(simulation.get_tick()).is_equal(tick_before)
	assert_str(simulation.get_canonical_log()).is_equal(log_before)
	assert_str(simulation.get_canonical_snapshot()).is_equal(snapshot_before)
