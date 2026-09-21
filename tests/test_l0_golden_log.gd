## Regresja golden log dla scenariusza L0 — obie ścieżki terminalne.
##
## Testy 50/50 dowodzą, że przebiegi są wzajemnie identyczne. Ten plik dowodzi
## czegoś innego: że wynik nadal odpowiada ZATWIERDZONEMU przebiegowi incydentu.
## Zmiana reguł, która konsekwentnie zmieniłaby wszystkie 50 przebiegów tak samo,
## przeszłaby tamten test, a ten złapie ją natychmiast.
##
## Pokryte są dwa zatwierdzone przebiegi:
##   * wykrycie intruza  (INTRUDER_DETECTED) — domyślne dane ScenarioL0.create(),
##   * sukces intruza    (INTRUDER_SUCCESS)  — te same dane z jednym świadomie
##     zmienionym parametrem: mniejszy zasięg widzenia strażnika.
##
## Czysty test rdzenia: zero node'ów, zero scen, zero Timerów, zero inputu,
## zero czasu rzeczywistego. Fixture'y są zatwierdzonymi artefaktami repozytorium
## i NIE są przez ten test nadpisywane.
extends GdUnitTestSuite

const GOLDEN_FIXTURE := "res://tests/fixtures/l0_incident_golden_log.txt"
const SUCCESS_FIXTURE := "res://tests/fixtures/l0_success_golden_log.txt"
const SECTION_EVENT_LOG := "[EVENT_LOG]"
const SECTION_FINAL_STATE := "[FINAL_STATE]"
const HARD_TICK_LIMIT := 500

## Jedyny parametr odrozniajacy wariant sukcesu od danych domyslnych.
## Przy zasiegu 4 straznik dostrzega intruza na jeden tick, gubi cel, wraca do
## patrolu — a intruz konczy trase. Sukces wynika z normalnej pracy silnika.
const SUCCESS_GUARD_VIEW_RANGE := 4


# === wspolne helpery ==========================================================

func _run_scenario_to_terminal(scenario: ScenarioL0) -> Simulation:
	var simulation := Simulation.new()
	simulation.initialize(scenario)
	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1
	return simulation


func _run_to_terminal() -> Simulation:
	return _run_scenario_to_terminal(ScenarioL0.create())


## Swieze dane domyslne z jedna zmieniona wartoscia. Nie mutuje niczego
## wspoldzielonego — ScenarioL0.create() za kazdym razem zwraca nowy obiekt.
func _create_success_scenario() -> ScenarioL0:
	var scenario := ScenarioL0.create()
	scenario.guard_view_range = SUCCESS_GUARD_VIEW_RANGE
	return scenario


func _read_fixture_text(path: String) -> String:
	assert_bool(FileAccess.file_exists(path)) \
		.append_failure_message("brak zatwierdzonego fixture: %s" % path) \
		.is_true()
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text


## Rozdziela fixture na dwie sekcje. Normalizuje konce wierszy, zeby wynik nie
## zalezal od tego, jak Git wymeldowal plik na danej platformie.
func _parse_fixture(text: String) -> Dictionary:
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	var event_lines := PackedStringArray()
	var state_lines := PackedStringArray()
	var current := ""

	for line: String in normalized.split("\n"):
		if line == SECTION_EVENT_LOG:
			current = SECTION_EVENT_LOG
			continue
		if line == SECTION_FINAL_STATE:
			current = SECTION_FINAL_STATE
			continue
		if line.is_empty():
			continue
		if current == SECTION_EVENT_LOG:
			event_lines.append(line)
		elif current == SECTION_FINAL_STATE:
			state_lines.append(line)

	return {"events": event_lines, "state": state_lines}


func _load_fixture(path: String) -> Dictionary:
	return _parse_fixture(_read_fixture_text(path))


func _first_diff_index(expected: PackedStringArray, actual: PackedStringArray) -> int:
	var count := maxi(expected.size(), actual.size())
	for i in range(count):
		var e := expected[i] if i < expected.size() else "<brak wiersza>"
		var a := actual[i] if i < actual.size() else "<brak wiersza>"
		if e != a:
			return i
	return -1


func _describe_diff(
		label: String,
		expected: PackedStringArray,
		actual: PackedStringArray,
		final_state: String) -> String:
	var index := _first_diff_index(expected, actual)
	var expected_line := "<brak wiersza>"
	var actual_line := "<brak wiersza>"
	if index >= 0:
		if index < expected.size():
			expected_line = expected[index]
		if index < actual.size():
			actual_line = actual[index]

	return "\n".join(PackedStringArray([
		"GOLDEN LOG REGRESJA — %s" % label,
		"pierwszy rozniacy sie indeks: %d" % index,
		"  oczekiwano (fixture): %s" % expected_line,
		"  otrzymano  (biezace): %s" % actual_line,
		"dlugosc fixture: %d wierszy" % expected.size(),
		"dlugosc biezaca: %d wierszy" % actual.size(),
		"stan koncowy biezacego przebiegu:",
		final_state,
		"",
		"Jesli ta zmiana jest ZAMIERZONA, zaktualizuj fixture swiadomie i opisz",
		"decyzje w docs/DECISIONS.md. Nigdy nie nadpisuj golden logu automatycznie.",
	]))


## Wspolna kontrola ksztaltu fixture: obie sekcje niepuste i poprawnie zbudowane.
func _assert_fixture_structure(fixture: Dictionary, path: String) -> void:
	var events: PackedStringArray = fixture["events"]
	var state: PackedStringArray = fixture["state"]

	assert_int(events.size()) \
		.append_failure_message("%s: sekcja %s jest pusta" % [path, SECTION_EVENT_LOG]) \
		.is_greater(0)
	assert_int(state.size()) \
		.append_failure_message("%s: sekcja %s jest pusta" % [path, SECTION_FINAL_STATE]) \
		.is_greater(0)

	for line: String in events:
		assert_int(line.split("|").size()) \
			.append_failure_message("%s: wpis logu nie ma czterech pol: %s" % [path, line]) \
			.is_equal(4)
	for line: String in state:
		assert_bool(line.contains("=")) \
			.append_failure_message("%s: pole stanu nie ma postaci klucz=wartosc: %s" % [path, line]) \
			.is_true()


## Fixture musi konczyc sie dokladnie jednym znakiem nowej linii.
func _assert_single_trailing_newline(path: String) -> void:
	var text := _read_fixture_text(path)
	assert_bool(text.ends_with("\n")) \
		.append_failure_message("%s: brak koncowego znaku nowej linii" % path) \
		.is_true()
	assert_bool(text.ends_with("\n\n")) \
		.append_failure_message("%s: wiecej niz jeden koncowy znak nowej linii" % path) \
		.is_false()


func _canonical_lines(text: String) -> PackedStringArray:
	return PackedStringArray(text.split("\n"))


# === sciezka WYKRYCIA (INTRUDER_DETECTED) =====================================

## Incydent musi domykac sie samodzielnie, w kontrolowanym limicie krokow.
func test_incident_reaches_terminal_state_within_limit() -> void:
	var simulation := _run_to_terminal()

	assert_bool(simulation.is_finished()) \
		.append_failure_message("incydent nie domknal sie w %d krokach" % HARD_TICK_LIMIT) \
		.is_true()
	assert_int(simulation.get_tick()).is_less(HARD_TICK_LIMIT)


## Kanoniczny event log musi odpowiadac zatwierdzonemu przebiegowi.
func test_canonical_event_log_matches_golden_fixture() -> void:
	var fixture := _load_fixture(GOLDEN_FIXTURE)
	var expected: PackedStringArray = fixture["events"]

	var simulation := _run_to_terminal()
	var actual := _canonical_lines(simulation.get_canonical_log())

	assert_str("\n".join(actual)) \
		.append_failure_message(_describe_diff(
			"event log (wykrycie)", expected, actual, simulation.get_canonical_snapshot())) \
		.is_equal("\n".join(expected))


## Kanoniczny stan koncowy musi odpowiadac zatwierdzonemu przebiegowi.
func test_canonical_final_state_matches_golden_fixture() -> void:
	var fixture := _load_fixture(GOLDEN_FIXTURE)
	var expected: PackedStringArray = fixture["state"]

	var simulation := _run_to_terminal()
	var actual := _canonical_lines(simulation.get_canonical_snapshot())

	assert_str("\n".join(actual)) \
		.append_failure_message(_describe_diff(
			"stan koncowy (wykrycie)", expected, actual, simulation.get_canonical_snapshot())) \
		.is_equal("\n".join(expected))


func test_golden_fixture_is_well_formed() -> void:
	var fixture := _load_fixture(GOLDEN_FIXTURE)
	_assert_fixture_structure(fixture, GOLDEN_FIXTURE)
	_assert_single_trailing_newline(GOLDEN_FIXTURE)

	var state := Array(fixture["state"] as PackedStringArray)
	assert_array(state) \
		.append_failure_message("fixture wykrycia nie deklaruje outcome=INTRUDER_DETECTED") \
		.contains(["outcome=%s" % SimulationState.OUTCOME_INTRUDER_DETECTED])


# === sciezka SUKCESU (INTRUDER_SUCCESS) =======================================

func test_success_variant_reaches_terminal_state_within_limit() -> void:
	var simulation := _run_scenario_to_terminal(_create_success_scenario())

	assert_bool(simulation.is_finished()) \
		.append_failure_message("wariant sukcesu nie domknal sie w %d krokach" % HARD_TICK_LIMIT) \
		.is_true()
	assert_int(simulation.get_tick()).is_less(HARD_TICK_LIMIT)
	assert_str(simulation.get_outcome()) \
		.append_failure_message("wariant sukcesu nie konczy sie sukcesem intruza") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)


func test_success_variant_canonical_event_log_matches_golden_fixture() -> void:
	var fixture := _load_fixture(SUCCESS_FIXTURE)
	var expected: PackedStringArray = fixture["events"]

	var simulation := _run_scenario_to_terminal(_create_success_scenario())
	var canonical := simulation.get_canonical_log()
	var actual := _canonical_lines(canonical)

	assert_str("\n".join(actual)) \
		.append_failure_message(_describe_diff(
			"event log (sukces)", expected, actual, simulation.get_canonical_snapshot())) \
		.is_equal("\n".join(expected))

	assert_str(canonical) \
		.append_failure_message("brak rzeczywistego zdarzenia sukcesu intruza") \
		.contains("|%s|%s|route_completed" % [ScenarioL0.INTRUDER_ID, IntruderScript.STATE_SUCCESS])
	assert_str(canonical) \
		.append_failure_message("brak zdarzenia konczacego symulacje") \
		.contains("|%s|FINISHED|intruder_success" % Simulation.SUBJECT_SIMULATION)


func test_success_variant_canonical_final_state_matches_golden_fixture() -> void:
	var fixture := _load_fixture(SUCCESS_FIXTURE)
	var expected: PackedStringArray = fixture["state"]

	var simulation := _run_scenario_to_terminal(_create_success_scenario())
	var actual := _canonical_lines(simulation.get_canonical_snapshot())

	assert_str("\n".join(actual)) \
		.append_failure_message(_describe_diff(
			"stan koncowy (sukces)", expected, actual, simulation.get_canonical_snapshot())) \
		.is_equal("\n".join(expected))


func test_success_golden_fixture_is_well_formed() -> void:
	var fixture := _load_fixture(SUCCESS_FIXTURE)
	_assert_fixture_structure(fixture, SUCCESS_FIXTURE)
	_assert_single_trailing_newline(SUCCESS_FIXTURE)

	var events := Array(fixture["events"] as PackedStringArray)
	var state := Array(fixture["state"] as PackedStringArray)

	assert_array(state) \
		.append_failure_message("fixture sukcesu nie deklaruje outcome=INTRUDER_SUCCESS") \
		.contains(["outcome=%s" % SimulationState.OUTCOME_INTRUDER_SUCCESS])

	var joined := "\n".join(fixture["events"] as PackedStringArray)
	assert_str(joined) \
		.append_failure_message("fixture sukcesu nie zawiera zdarzenia SUCCESS") \
		.contains("|%s|%s|route_completed" % [ScenarioL0.INTRUDER_ID, IntruderScript.STATE_SUCCESS])
	assert_str(joined) \
		.append_failure_message("fixture sukcesu nie zawiera zdarzenia FINISHED") \
		.contains("|%s|FINISHED|intruder_success" % Simulation.SUBJECT_SIMULATION)

	assert_int(events.size()) \
		.append_failure_message("fixture sukcesu ma podejrzanie malo zdarzen") \
		.is_greater(1)
	assert_int(state.size()).is_greater(1)


## Wariant sukcesu nie moze przeciekac do danych domyslnych.
func test_success_variant_does_not_mutate_default_scenario() -> void:
	var success_simulation := _run_scenario_to_terminal(_create_success_scenario())
	assert_str(success_simulation.get_outcome()) \
		.is_equal(SimulationState.OUTCOME_INTRUDER_SUCCESS)

	# Swiezy scenariusz domyslny musi byc nietkniety.
	var default_scenario := ScenarioL0.create()
	assert_int(default_scenario.guard_view_range) \
		.append_failure_message("wariant sukcesu zmutowal domyslne dane scenariusza") \
		.is_not_equal(SUCCESS_GUARD_VIEW_RANGE)

	var default_simulation := _run_scenario_to_terminal(default_scenario)
	assert_str(default_simulation.get_outcome()) \
		.append_failure_message("domyslny scenariusz przestal prowadzic do wykrycia intruza") \
		.is_equal(SimulationState.OUTCOME_INTRUDER_DETECTED)


# === ochrona eksportu =========================================================

## Odczyt i eksport logu nie moga mutowac ani logu, ani stanu symulacji.
func test_exporting_event_log_does_not_mutate_simulation() -> void:
	var simulation := _run_to_terminal()

	var log_before := simulation.get_canonical_log()
	var snapshot_before := simulation.get_canonical_snapshot()
	var tick_before := simulation.get_tick()
	var size_before := simulation.get_event_log().size()

	# Wielokrotny odczyt przez wszystkie publiczne sciezki eksportu.
	for i in range(5):
		var entries := simulation.get_event_log()
		var last := simulation.get_last_events(3)
		var snapshot := simulation.get_state_snapshot()
		# Proba mutacji zwroconych kopii nie moze dosiegnac rdzenia.
		entries.clear()
		for entry: Dictionary in last:
			entry["tick"] = -1
			entry["event"] = "TAMPERED"
		snapshot["tick"] = -1
		snapshot["guard_state"] = "TAMPERED"
		var _canonical := simulation.get_canonical_log()
		var _canonical_state := simulation.get_canonical_snapshot()

	assert_str(simulation.get_canonical_log()) \
		.append_failure_message("eksport logu zmutowal log") \
		.is_equal(log_before)
	assert_str(simulation.get_canonical_snapshot()) \
		.append_failure_message("eksport zmutowal stan symulacji") \
		.is_equal(snapshot_before)
	assert_int(simulation.get_tick()).is_equal(tick_before)
	assert_int(simulation.get_event_log().size()).is_equal(size_before)
	assert_bool(simulation.is_finished()).is_true()
