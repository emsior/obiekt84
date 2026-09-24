## Testy danych scenariusza: walidacja wejścia i kompletność kopii.
##
## Rdzeń przyjmuje scenariusz jako jawne dane i nigdy ich nie naprawia.
## Te testy pilnują dwóch rzeczy, których nie widać w przebiegu incydentu:
## że błędne dane są zgłaszane jawnie oraz że `duplicate_data()` kopiuje
## wszystko — niedokopiowane pole oznaczałoby współdzielenie stanu między
## przebiegami, czyli cichą utratę determinizmu.
##
## Żaden test w tym pliku nie używa sceny, Timerów, inputu ani czasu
## rzeczywistego.
extends GdUnitTestSuite

## Warianty incydentu z golden logów (`tests/test_l0_golden_log.gd`). Od L1-A
## żyją wyłącznie w testach — UI ich nie oferuje (`docs/DECISIONS.md`, 2026-09-24).
const SUCCESS_GUARD_VIEW_RANGE := 4
const TICK_LIMIT_MAX_TICKS := 20

## Pola, którymi dane zagadki L1-A różnią się od `ScenarioL0.create()`.
const PUZZLE_CHANGED_FIELDS: Array[String] = ["guard_start", "guard_waypoints"]


func _problems_text(scenario: ScenarioL0) -> String:
	return "; ".join(scenario.validate())


## Nazwy pól zadeklarowanych w skrypcie — bez wbudowanych właściwości Object.
func _script_property_names(scenario: ScenarioL0) -> PackedStringArray:
	var names := PackedStringArray()
	for property: Dictionary in scenario.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(String(property["name"]))
	return names


func test_default_scenario_is_valid() -> void:
	var scenario := ScenarioL0.create()
	assert_bool(scenario.is_valid()) \
		.append_failure_message("domyslny scenariusz L0 ma problemy: %s" % _problems_text(scenario)) \
		.is_true()


## Plan domyślny fazy planowania musi dać się uruchomić bez żadnej poprawki.
func test_puzzle_scenario_is_valid() -> void:
	var scenario := ScenarioL0.create_puzzle()
	assert_bool(scenario.is_valid()) 		.append_failure_message("scenariusz zagadki ma problemy: %s" % _problems_text(scenario)) 		.is_true()
	assert_vector(scenario.guard_start) 		.append_failure_message("straznik zagadki nie startuje na pierwszym waypoincie") 		.is_equal(scenario.guard_waypoints[0])


## Zagadka różni się od `create()` wyłącznie patrolem: te same wymiary, trasa,
## kamera i zasięgi. Przegrana ma wynikać z ustawienia patrolu, nie z osłabienia
## strażnika ani z innych danych. Refleksja łapie też przyszłe pola.
func test_puzzle_differs_from_default_only_in_patrol() -> void:
	var puzzle := ScenarioL0.create_puzzle()
	var default := ScenarioL0.create()

	for name: String in _script_property_names(puzzle):
		if PUZZLE_CHANGED_FIELDS.has(name):
			continue
		assert_bool(puzzle.get(name) == default.get(name)) 			.append_failure_message("zagadka zmienia pole '%s': %s zamiast %s" % [
				name, str(puzzle.get(name)), str(default.get(name))]) 			.is_true()

	assert_bool(puzzle.guard_waypoints == default.guard_waypoints) 		.append_failure_message("zagadka ma ten sam patrol co create() - nie byloby czego poprawiac") 		.is_false()


## Warianty golden logów powstają przez zmianę jednej wartości domyślnego scenariusza.
## Jeżeli któraś z tych zmian łamałaby walidację, wariantu nie dałoby się uruchomić.
func test_ui_variants_are_valid() -> void:
	var success := ScenarioL0.create()
	success.guard_view_range = SUCCESS_GUARD_VIEW_RANGE
	assert_bool(success.is_valid()) \
		.append_failure_message("wariant sukcesu ma problemy: %s" % _problems_text(success)) \
		.is_true()

	var tick_limit := ScenarioL0.create()
	tick_limit.max_ticks = TICK_LIMIT_MAX_TICKS
	assert_bool(tick_limit.is_valid()) \
		.append_failure_message("wariant limitu tickow ma problemy: %s" % _problems_text(tick_limit)) \
		.is_true()


func test_waypoint_outside_grid_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.guard_waypoints[2] = Vector2i(20, 12)

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)) \
		.append_failure_message("komunikat nie wskazuje ktory waypoint jest bledny") \
		.contains("guard_waypoints[2]")


func test_empty_waypoints_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.guard_waypoints = [] as Array[Vector2i]

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)).contains("guard_waypoints")


func test_empty_route_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.intruder_route = [] as Array[Vector2i]

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)).contains("intruder_route")


## Dziura w trasie łamie kontrakt "najwyżej jedna komórka na tick".
func test_route_gap_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.intruder_route[3] = scenario.intruder_route[3] + Vector2i(0, 1)

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)) \
		.append_failure_message("przeskok w trasie nie zostal zgloszony") \
		.contains("intruder_route[3]")


## Ruch po skosie też jest przeskokiem: kierunki są wyłącznie kardynalne.
func test_diagonal_route_step_is_reported() -> void:
	var scenario := ScenarioL0.create()
	var route: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(3, 3),
	] as Array[Vector2i]
	scenario.intruder_route = route

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)).contains("intruder_route[1]")


func test_route_outside_grid_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.grid_width = 10

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)) \
		.append_failure_message("trasa wychodzaca poza zwezona siatke nie zostala zgloszona") \
		.contains("poza siatką")


func test_non_cardinal_facing_is_reported() -> void:
	var diagonal := ScenarioL0.create()
	diagonal.guard_facing = Vector2i(1, 1)
	assert_bool(diagonal.is_valid()).is_false()
	assert_str(_problems_text(diagonal)).contains("guard_facing")

	var zero := ScenarioL0.create()
	zero.camera_facing = Vector2i.ZERO
	assert_bool(zero.is_valid()).is_false()
	assert_str(_problems_text(zero)).contains("camera_facing")


func test_negative_view_range_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.guard_view_range = -1
	scenario.camera_range = -1

	var problems := scenario.validate()
	assert_int(problems.size()) \
		.append_failure_message("oba ujemne zasiegi powinny dac dwa komunikaty: %s" % _problems_text(scenario)) \
		.is_equal(2)


func test_non_positive_max_ticks_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.max_ticks = 0

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)).contains("max_ticks")


## Edytor przesuwa waypointy — rozjechany start oznaczałby patrol inny niż
## ten, który gracz widzi na planszy.
func test_guard_start_different_from_first_waypoint_is_reported() -> void:
	var scenario := ScenarioL0.create_puzzle()
	scenario.guard_start = scenario.guard_waypoints[1]

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)) 		.append_failure_message("rozjazd startu i pierwszego waypointu nie zostal zgloszony") 		.contains("guard_start")


## Pusta lista waypointów ma własny komunikat — reguła startu nie może się
## na niej wywrócić ani dublować problemu.
func test_guard_start_rule_skips_empty_waypoints() -> void:
	var scenario := ScenarioL0.create()
	scenario.guard_waypoints = [] as Array[Vector2i]

	var problems := scenario.validate()
	assert_int(problems.size()) 		.append_failure_message("pusta lista waypointow powinna dac jeden komunikat: %s" % _problems_text(scenario)) 		.is_equal(1)
	assert_str(problems[0]).contains("guard_waypoints")


func test_camera_on_intruder_route_is_reported() -> void:
	var scenario := ScenarioL0.create_puzzle()
	scenario.camera_position = scenario.intruder_route[5]

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)) 		.append_failure_message("kamera na trasie intruza nie zostala zgloszona") 		.contains("intruder_route[5]")


func test_camera_on_waypoint_is_reported() -> void:
	var scenario := ScenarioL0.create_puzzle()
	scenario.camera_position = scenario.guard_waypoints[2]

	assert_bool(scenario.is_valid()).is_false()
	assert_str(_problems_text(scenario)) 		.append_failure_message("kamera na waypoincie nie zostala zgloszona") 		.contains("guard_waypoints[2]")


## Przy zerowej siatce walidacja kończy się na wymiarach — dalsze kontrole
## granic nie miałyby o co pytać.
func test_degenerate_grid_is_reported() -> void:
	var scenario := ScenarioL0.create()
	scenario.grid_width = 0

	var problems := scenario.validate()
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("grid_size")


## Walidacja nie zatrzymuje się na pierwszym problemie — raport ma pokazać
## wszystko naraz, żeby poprawka nie wymagała wielu przebiegów.
func test_validation_reports_every_problem_at_once() -> void:
	var scenario := ScenarioL0.create()
	scenario.guard_facing = Vector2i.ZERO
	scenario.camera_position = Vector2i(99, 99)
	scenario.max_ticks = 0

	assert_int(scenario.validate().size()) \
		.append_failure_message("walidacja zgubila czesc problemow: %s" % _problems_text(scenario)) \
		.is_equal(3)


## Refleksja po polach skryptu: nowe pole scenariusza, którego ktoś zapomni
## dopisać do duplicate_data(), zapala ten test zamiast po cichu przeciekać
## między przebiegami. Test nie wykryje wyłącznie pola, którego wartość
## domyślna jest równa wartości ze scenariusza.
func test_duplicate_data_copies_every_script_property() -> void:
	_assert_copies_every_script_property(ScenarioL0.create())


## Edytor planowania startuje od danych zagadki i kopiuje draft przy każdym
## uruchomieniu nocy — kopia musi być kompletna także dla tej fabryki.
func test_duplicate_data_copies_every_script_property_of_puzzle() -> void:
	_assert_copies_every_script_property(ScenarioL0.create_puzzle())


func _assert_copies_every_script_property(original: ScenarioL0) -> void:
	var copy := original.duplicate_data()
	var names := _script_property_names(original)

	assert_int(names.size()) \
		.append_failure_message("refleksja nie znalazla zadnego pola scenariusza") \
		.is_greater(0)

	for name: String in names:
		assert_bool(copy.get(name) == original.get(name)) \
			.append_failure_message("duplicate_data() nie skopiowalo pola '%s': oczekiwano %s, otrzymano %s" % [
				name, str(original.get(name)), str(copy.get(name))]) \
			.is_true()


## Kopia musi mieć własne tablice. Współdzielona tablica oznaczałaby, że jeden
## przebieg może zmienić dane drugiego.
func test_duplicate_data_arrays_are_independent() -> void:
	var original := ScenarioL0.create()
	var copy := original.duplicate_data()

	var waypoints_before := original.guard_waypoints.size()
	var route_before := original.intruder_route.size()

	copy.guard_waypoints.append(Vector2i(0, 0))
	copy.intruder_route.append(Vector2i(0, 0))

	assert_int(original.guard_waypoints.size()) \
		.append_failure_message("guard_waypoints sa wspoldzielone miedzy kopiami") \
		.is_equal(waypoints_before)
	assert_int(original.intruder_route.size()) \
		.append_failure_message("intruder_route jest wspoldzielona miedzy kopiami") \
		.is_equal(route_before)
