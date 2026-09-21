## Regresja golden log dla scenariusza L0.
##
## Testy 50/50 dowodzą, że przebiegi są wzajemnie identyczne. Ten plik dowodzi
## czegoś innego: że wynik nadal odpowiada ZATWIERDZONEMU przebiegowi incydentu.
## Zmiana reguł, która konsekwentnie zmieniłaby wszystkie 50 przebiegów tak samo,
## przeszłaby tamten test, a ten złapie ją natychmiast.
##
## Czysty test rdzenia: zero node'ów, zero scen, zero Timerów, zero inputu,
## zero czasu rzeczywistego. Fixture jest zatwierdzonym artefaktem repozytorium
## i NIE jest przez ten test nadpisywany.
extends GdUnitTestSuite

const GOLDEN_FIXTURE := "res://tests/fixtures/l0_incident_golden_log.txt"
const SECTION_EVENT_LOG := "[EVENT_LOG]"
const SECTION_FINAL_STATE := "[FINAL_STATE]"
const HARD_TICK_LIMIT := 500


func _run_to_terminal() -> Simulation:
	var simulation := Simulation.new()
	simulation.initialize(ScenarioL0.create())
	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1
	return simulation


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


func _load_fixture() -> Dictionary:
	assert_bool(FileAccess.file_exists(GOLDEN_FIXTURE)) \
		.append_failure_message("brak zatwierdzonego fixture'u: %s" % GOLDEN_FIXTURE) \
		.is_true()
	var file := FileAccess.open(GOLDEN_FIXTURE, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return _parse_fixture(text)


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


## Incydent musi domykac sie samodzielnie, w kontrolowanym limicie krokow.
func test_incident_reaches_terminal_state_within_limit() -> void:
	var simulation := _run_to_terminal()

	assert_bool(simulation.is_finished()) \
		.append_failure_message("incydent nie domknal sie w %d krokach" % HARD_TICK_LIMIT) \
		.is_true()
	assert_int(simulation.get_tick()).is_less(HARD_TICK_LIMIT)


## Kanoniczny event log musi odpowiadac zatwierdzonemu przebiegowi.
func test_canonical_event_log_matches_golden_fixture() -> void:
	var fixture := _load_fixture()
	var expected: PackedStringArray = fixture["events"]

	var simulation := _run_to_terminal()
	var actual := PackedStringArray(simulation.get_canonical_log().split("\n"))

	assert_str("\n".join(actual)) \
		.append_failure_message(_describe_diff(
			"event log", expected, actual, simulation.get_canonical_snapshot())) \
		.is_equal("\n".join(expected))


## Kanoniczny stan koncowy musi odpowiadac zatwierdzonemu przebiegowi.
func test_canonical_final_state_matches_golden_fixture() -> void:
	var fixture := _load_fixture()
	var expected: PackedStringArray = fixture["state"]

	var simulation := _run_to_terminal()
	var actual := PackedStringArray(simulation.get_canonical_snapshot().split("\n"))

	assert_str("\n".join(actual)) \
		.append_failure_message(_describe_diff(
			"stan koncowy", expected, actual, simulation.get_canonical_snapshot())) \
		.is_equal("\n".join(expected))


## Fixture musi byc kompletny — obie sekcje niepuste i zgodne co do liczby zdarzen.
func test_golden_fixture_is_well_formed() -> void:
	var fixture := _load_fixture()
	var events: PackedStringArray = fixture["events"]
	var state: PackedStringArray = fixture["state"]

	assert_int(events.size()) \
		.append_failure_message("sekcja %s jest pusta" % SECTION_EVENT_LOG) \
		.is_greater(0)
	assert_int(state.size()) \
		.append_failure_message("sekcja %s jest pusta" % SECTION_FINAL_STATE) \
		.is_greater(0)

	for line: String in events:
		assert_int(line.split("|").size()) \
			.append_failure_message("wpis logu nie ma czterech pol: %s" % line) \
			.is_equal(4)


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
