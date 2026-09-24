## Testy poziomu jako danych: parser `LevelData`, pliki `levels/*.json`
## i ładowanie planu domyślnego przez edytor.
##
## Rdzeń (`LevelData.parse`) dostaje tekst — plik czyta test albo prezentacja.
## Zero sceny, zero Timerów, zero inputu, zero czasu rzeczywistego.
extends GdUnitTestSuite

const PUZZLE_LEVEL := "res://levels/puzzle_01.json"
const INCIDENT_LEVEL := "res://levels/l0_incident.json"
const INCIDENT_FIXTURE := "res://tests/fixtures/l0_incident_golden_log.txt"
const PUZZLE_FIXTURE := "res://tests/fixtures/l0_puzzle_default_golden_log.txt"
const HARD_TICK_LIMIT := 500


func _read(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	assert_int(FileAccess.get_open_error()) \
		.append_failure_message("nie mozna odczytac %s" % path) \
		.is_equal(OK)
	return text


## Parsuje plik i wymaga pustej listy problemów.
func _parse_file(path: String) -> ScenarioL0:
	var result := LevelData.parse(_read(path))
	assert_array(result["problems"]) \
		.append_failure_message("%s ma problemy: %s" % [path, str(result["problems"])]) \
		.is_empty()
	return result["scenario"] as ScenarioL0


## Świeży słownik poziomu zagadki do psucia w testach błędów.
func _puzzle_dict() -> Dictionary:
	return JSON.parse_string(_read(PUZZLE_LEVEL)) as Dictionary


## Parsuje zmodyfikowany słownik i wymaga odrzucenia z komunikatem o polu.
func _assert_rejected(data: Variant, expected_fragment: String) -> Array:
	return _assert_text_rejected(JSON.stringify(data), expected_fragment)


func _assert_text_rejected(text: String, expected_fragment: String) -> Array:
	var result := LevelData.parse(text)
	var problems: Array = result["problems"]
	assert_object(result["scenario"]) \
		.append_failure_message("odrzucony poziom nie moze dac scenariusza") \
		.is_null()
	assert_str("; ".join(PackedStringArray(problems))) \
		.append_failure_message("brak komunikatu z '%s'" % expected_fragment) \
		.contains(expected_fragment)
	return problems


func _script_property_names(scenario: ScenarioL0) -> PackedStringArray:
	var names := PackedStringArray()
	for property: Dictionary in scenario.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(String(property["name"]))
	return names


## Każde pole skryptu scenariusza z pliku jest równe polu z fabryki — refleksją,
## więc nowe pole w `ScenarioL0` bez odpowiednika w formacie zapali test.
func _assert_equivalent(from_file: ScenarioL0, from_code: ScenarioL0, label: String) -> void:
	var names := _script_property_names(from_code)
	assert_int(names.size()).is_greater(0)
	for name: String in names:
		assert_bool(from_file.get(name) == from_code.get(name)) \
			.append_failure_message("%s: pole '%s' rozni sie: plik %s, kod %s" % [
				label, name, str(from_file.get(name)), str(from_code.get(name))]) \
			.is_true()


## Kanoniczny zapis przebiegu w formacie fixture'u.
func _golden_text(scenario: ScenarioL0) -> String:
	var simulation := Simulation.new()
	simulation.initialize(scenario)
	var steps := 0
	while not simulation.is_finished() and steps < HARD_TICK_LIMIT:
		simulation.step()
		steps += 1
	return "[EVENT_LOG]\n" + simulation.get_canonical_log() \
		+ "\n[FINAL_STATE]\n" + simulation.get_canonical_snapshot() + "\n"


# === pliki poziomów ============================================================

func test_puzzle_level_file_equals_create_puzzle() -> void:
	_assert_equivalent(_parse_file(PUZZLE_LEVEL), ScenarioL0.create_puzzle(), "puzzle_01.json")


func test_incident_level_file_equals_create() -> void:
	_assert_equivalent(_parse_file(INCIDENT_LEVEL), ScenarioL0.create(), "l0_incident.json")


## Przebieg z pliku daje bajt w bajt zatwierdzony golden log (po normalizacji
## końców wierszy, jak w `tests/test_l0_golden_log.gd`).
func test_incident_level_file_reproduces_golden_log() -> void:
	var expected := _read(INCIDENT_FIXTURE).replace("\r\n", "\n")
	assert_str(_golden_text(_parse_file(INCIDENT_LEVEL))).is_equal(expected)


func test_puzzle_level_file_reproduces_golden_log() -> void:
	var expected := _read(PUZZLE_FIXTURE).replace("\r\n", "\n")
	assert_str(_golden_text(_parse_file(PUZZLE_LEVEL))).is_equal(expected)


## Edytor ładuje plan domyślny tą samą funkcją — i bez awaryjnego powrotu do kodu.
func test_plan_editor_loads_default_level_without_fallback() -> void:
	var result := PlanEditor.load_level_file(PlanEditor.DEFAULT_LEVEL_PATH)
	assert_array(result["problems"]) \
		.append_failure_message("edytor wczytalby plan awaryjny z kodu") \
		.is_empty()
	_assert_equivalent(result["scenario"] as ScenarioL0, ScenarioL0.create_puzzle(), "edytor")


func test_missing_level_file_is_reported() -> void:
	var result := PlanEditor.load_level_file("res://levels/nie_ma_takiego.json")
	assert_object(result["scenario"]).is_null()
	assert_str("; ".join(PackedStringArray(result["problems"]))).contains("nie_ma_takiego.json")


# === odrzucenia: struktura i wartości ==========================================

func test_non_integer_coordinate_is_rejected() -> void:
	var data := _puzzle_dict()
	data["guard"]["waypoints"][2][0] = 1.5
	_assert_rejected(data, "guard.waypoints[2][0]: 1.5 nie jest liczbą całkowitą")


## Liczba całkowita zapisana jako float (np. 6.0) to wciąż ta sama liczba.
func test_integral_float_is_accepted() -> void:
	var text := _read(PUZZLE_LEVEL).replace("\"view_range\": 6", "\"view_range\": 6.0")
	assert_str(text).contains("6.0")
	var result := LevelData.parse(text)
	assert_array(result["problems"]).is_empty()
	assert_int((result["scenario"] as ScenarioL0).guard_view_range).is_equal(6)


func test_out_of_range_number_is_rejected() -> void:
	var data := _puzzle_dict()
	data["max_ticks"] = 5000000
	var problems := _assert_rejected(data, "poza zakresem ±1000000")
	assert_str(str(problems[0])).starts_with("max_ticks: ")


func test_missing_field_is_rejected() -> void:
	var data := _puzzle_dict()
	(data["camera"] as Dictionary).erase("range")
	_assert_rejected(data, "camera: brak pola 'range'")


func test_unknown_field_is_rejected() -> void:
	var data := _puzzle_dict()
	data["guard"]["speed"] = 2
	_assert_rejected(data, "guard: nieznane pole 'speed'")


## Nieznane klucze są zgłaszane po posortowaniu, nie w kolejności `Dictionary`.
func test_unknown_fields_are_reported_in_sorted_order() -> void:
	var data := _puzzle_dict()
	data["zeta"] = 1
	data["alpha"] = 1
	var problems := _assert_rejected(data, "nieznane pole")
	var joined := "; ".join(PackedStringArray(problems))
	assert_int(joined.find("'alpha'")).is_less(joined.find("'zeta'"))


func test_unsupported_format_version_is_rejected() -> void:
	var data := _puzzle_dict()
	data["format_version"] = 2
	_assert_rejected(data, "format_version: 2 nieobsługiwany")


## Kierunek niekardynalny przechodzi strukturę, zatrzymuje go `ScenarioL0.validate()`.
func test_non_cardinal_facing_is_rejected_by_validation() -> void:
	var data := _puzzle_dict()
	data["guard"]["facing"] = [1, 1]
	_assert_rejected(data, "guard_facing")


func test_empty_text_is_rejected() -> void:
	_assert_text_rejected("", "pusty")
	_assert_text_rejected("   \n", "pusty")


func test_invalid_json_is_rejected() -> void:
	_assert_text_rejected("{ \"grid\": [20, 20", "niepoprawny JSON")


func test_root_must_be_an_object() -> void:
	_assert_text_rejected("[1, 2]", "korzeń: oczekiwano obiektu")


func test_wrong_waypoint_count_is_rejected() -> void:
	var data := _puzzle_dict()
	(data["guard"]["waypoints"] as Array).pop_back()
	_assert_rejected(data, "guard.waypoints: oczekiwano dokładnie 4 komórek, jest 3")


## Zły typ nigdy nie kończy się błędem skryptu ani cichą konwersją.
func test_wrong_value_types_are_rejected() -> void:
	var as_string := _puzzle_dict()
	as_string["max_ticks"] = "400"
	_assert_rejected(as_string, "max_ticks: oczekiwano liczby całkowitej")

	var as_bool := _puzzle_dict()
	as_bool["camera"]["range"] = true
	_assert_rejected(as_bool, "camera.range: oczekiwano liczby całkowitej")

	var as_null := _puzzle_dict()
	as_null["guard"]["start"] = null
	_assert_rejected(as_null, "guard.start: oczekiwano [x, y]")

	var object_as_list := _puzzle_dict()
	object_as_list["camera"] = [3, 3]
	_assert_rejected(object_as_list, "camera: oczekiwano obiektu")


func test_wrong_coordinate_count_is_rejected() -> void:
	var one := _puzzle_dict()
	one["camera"]["position"] = [10]
	_assert_rejected(one, "camera.position: oczekiwano dwóch współrzędnych [x, y], jest 1")

	var three := _puzzle_dict()
	three["camera"]["position"] = [1, 2, 3]
	_assert_rejected(three, "camera.position: oczekiwano dwóch współrzędnych [x, y], jest 3")


## Skośna para narożników rozwinęłaby się po cichu w zakręt — parser ją odrzuca.
func test_route_corners_off_axis_are_rejected() -> void:
	var data := _puzzle_dict()
	data["intruder"]["route_corners"] = [[18, 18], [1, 12]]
	_assert_rejected(data, "intruder.route_corners[1]: (18,18) → (1,12) nie leżą w jednej osi")
