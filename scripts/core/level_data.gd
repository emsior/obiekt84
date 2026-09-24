## Poziom jako dane: parser pliku `levels/*.json` do [ScenarioL0].
##
## Klasa rdzenia: RefCounted, bez I/O — tekst pliku czyta warstwa prezentacji.
## Parser niczego nie poprawia po cichu. Brak pola, nieznane pole, zły typ,
## liczba niecałkowita albo odcinek trasy spoza jednej osi to problem z pełną
## ścieżką pola, a wynikowy scenariusz istnieje wyłącznie przy pustej liście
## problemów. Na końcu dane przechodzą przez [method ScenarioL0.validate].
##
## `JSON` zwraca każdą liczbę jako float. Konwertujemy ją jawnie na int i
## odrzucamy wartości niecałkowite — float nigdy nie trafia do scenariusza.
## Kolejność komunikatów jest stała: pola sprawdzamy w jawnej kolejności,
## a nieznane klucze po posortowaniu, nie w kolejności `Dictionary`.
class_name LevelData
extends RefCounted

const FORMAT_VERSION := 1
## Edytor planu ma stałą liczbę węzłów patrolu.
const WAYPOINT_COUNT := 4
## Granica bezpieczna dla dokładnej reprezentacji liczb całkowitych we float.
const INT_LIMIT := 1000000

const ROOT_PATH := "korzeń"
const ROOT_KEYS: Array[String] = ["format_version", "grid", "guard", "intruder", "camera", "max_ticks"]
const GUARD_KEYS: Array[String] = ["start", "facing", "view_range", "waypoints"]
const INTRUDER_KEYS: Array[String] = ["route_corners"]
const CAMERA_KEYS: Array[String] = ["position", "facing", "range"]


## Zwraca `{"scenario": ScenarioL0 | null, "problems": Array[String]}`.
## `scenario` jest różny od null wtedy i tylko wtedy, gdy `problems` jest pusta.
static func parse(text: String) -> Dictionary:
	var problems: Array[String] = []
	if text.strip_edges().is_empty():
		problems.append("plik poziomu jest pusty")
		return _result(null, problems)

	var json := JSON.new()
	if json.parse(text) != OK:
		problems.append("niepoprawny JSON, linia %d: %s" % [json.get_error_line(), json.get_error_message()])
		return _result(null, problems)
	if not (json.data is Dictionary):
		problems.append("%s: oczekiwano obiektu JSON" % ROOT_PATH)
		return _result(null, problems)

	var root: Dictionary = json.data
	_check_keys(root, ROOT_PATH, ROOT_KEYS, problems)

	var version: Variant = _read_int_field(root, "format_version", "format_version", problems)
	if version != null and int(version) != FORMAT_VERSION:
		problems.append("format_version: %d nieobsługiwany (obsługiwany: %d)" % [int(version), FORMAT_VERSION])
	var grid: Variant = _read_cell_field(root, "grid", "grid", problems)

	var guard: Variant = _read_object_field(root, "guard", "guard", GUARD_KEYS, problems)
	var guard_start: Variant = null
	var guard_facing: Variant = null
	var guard_view_range: Variant = null
	var guard_waypoints: Variant = null
	if guard != null:
		guard_start = _read_cell_field(guard, "start", "guard.start", problems)
		guard_facing = _read_cell_field(guard, "facing", "guard.facing", problems)
		guard_view_range = _read_int_field(guard, "view_range", "guard.view_range", problems)
		guard_waypoints = _read_cells_field(guard, "waypoints", "guard.waypoints", WAYPOINT_COUNT, problems)

	var intruder: Variant = _read_object_field(root, "intruder", "intruder", INTRUDER_KEYS, problems)
	var route_corners: Variant = null
	if intruder != null:
		route_corners = _read_cells_field(intruder, "route_corners", "intruder.route_corners", -1, problems)
		if route_corners != null:
			_check_corners_share_axis(route_corners, "intruder.route_corners", problems)

	var camera: Variant = _read_object_field(root, "camera", "camera", CAMERA_KEYS, problems)
	var camera_position: Variant = null
	var camera_facing: Variant = null
	var camera_range: Variant = null
	if camera != null:
		camera_position = _read_cell_field(camera, "position", "camera.position", problems)
		camera_facing = _read_cell_field(camera, "facing", "camera.facing", problems)
		camera_range = _read_int_field(camera, "range", "camera.range", problems)

	var max_ticks: Variant = _read_int_field(root, "max_ticks", "max_ticks", problems)

	if not problems.is_empty():
		return _result(null, problems)

	var scenario := ScenarioL0.new()
	scenario.grid_width = (grid as Vector2i).x
	scenario.grid_height = (grid as Vector2i).y
	scenario.guard_start = guard_start
	scenario.guard_facing = guard_facing
	scenario.guard_view_range = guard_view_range
	scenario.guard_waypoints = guard_waypoints
	scenario.intruder_route = ScenarioL0._build_route(route_corners)
	scenario.camera_position = camera_position
	scenario.camera_facing = camera_facing
	scenario.camera_range = camera_range
	scenario.max_ticks = max_ticks

	problems.append_array(scenario.validate())
	return _result(scenario if problems.is_empty() else null, problems)


static func _result(scenario: ScenarioL0, problems: Array[String]) -> Dictionary:
	return {"scenario": scenario, "problems": problems}


## Brakujące pola w jawnej kolejności, nieznane — posortowane.
static func _check_keys(
		object: Dictionary,
		path: String,
		keys: Array[String],
		problems: Array[String]) -> void:
	for key: String in keys:
		if not object.has(key):
			problems.append("%s: brak pola '%s'" % [path, key])
	var unknown: Array[String] = []
	for key: Variant in object.keys():
		if not keys.has(str(key)):
			unknown.append(str(key))
	unknown.sort()
	for key: String in unknown:
		problems.append("%s: nieznane pole '%s'" % [path, key])


## Obiekt zagnieżdżony albo null. Brak pola zgłasza już [method _check_keys].
static func _read_object_field(
		parent: Dictionary,
		key: String,
		path: String,
		keys: Array[String],
		problems: Array[String]) -> Variant:
	if not parent.has(key):
		return null
	var value: Variant = parent[key]
	if not (value is Dictionary):
		problems.append("%s: oczekiwano obiektu, jest %s" % [path, type_string(typeof(value))])
		return null
	_check_keys(value, path, keys, problems)
	return value


static func _read_int_field(parent: Dictionary, key: String, path: String, problems: Array[String]) -> Variant:
	if not parent.has(key):
		return null
	return _read_int(parent[key], path, problems)


static func _read_cell_field(parent: Dictionary, key: String, path: String, problems: Array[String]) -> Variant:
	if not parent.has(key):
		return null
	return _read_cell(parent[key], path, problems)


## Lista komórek `[[x, y], ...]`. [param exact_count] < 0 oznacza „co najmniej jedna”.
static func _read_cells_field(
		parent: Dictionary,
		key: String,
		path: String,
		exact_count: int,
		problems: Array[String]) -> Variant:
	if not parent.has(key):
		return null
	var value: Variant = parent[key]
	if not (value is Array):
		problems.append("%s: oczekiwano listy komórek, jest %s" % [path, type_string(typeof(value))])
		return null
	var items: Array = value
	if exact_count >= 0 and items.size() != exact_count:
		problems.append("%s: oczekiwano dokładnie %d komórek, jest %d" % [path, exact_count, items.size()])
		return null
	if items.is_empty():
		problems.append("%s: lista komórek jest pusta" % path)
		return null
	var cells: Array[Vector2i] = []
	var ok := true
	for i in items.size():
		var cell: Variant = _read_cell(items[i], "%s[%d]" % [path, i], problems)
		if cell == null:
			ok = false
		else:
			cells.append(cell)
	return cells if ok else null


## Komórka `[x, y]` — dokładnie dwie liczby całkowite.
static func _read_cell(value: Variant, path: String, problems: Array[String]) -> Variant:
	if not (value is Array):
		problems.append("%s: oczekiwano [x, y], jest %s" % [path, type_string(typeof(value))])
		return null
	var pair: Array = value
	if pair.size() != 2:
		problems.append("%s: oczekiwano dwóch współrzędnych [x, y], jest %d" % [path, pair.size()])
		return null
	var x: Variant = _read_int(pair[0], "%s[0]" % path, problems)
	var y: Variant = _read_int(pair[1], "%s[1]" % path, problems)
	if x == null or y == null:
		return null
	return Vector2i(x, y)


## Liczba całkowita z wartości JSON. Float jest przyjmowany wyłącznie wtedy,
## gdy jest dokładnie całkowity i mieści się w zakresie — bez zaokrąglania.
static func _read_int(value: Variant, path: String, problems: Array[String]) -> Variant:
	var kind := typeof(value)
	if kind != TYPE_FLOAT and kind != TYPE_INT:
		problems.append("%s: oczekiwano liczby całkowitej, jest %s" % [path, type_string(kind)])
		return null
	var number := float(value)
	if absf(number) > INT_LIMIT:
		problems.append("%s: %s poza zakresem ±%d" % [path, str(value), INT_LIMIT])
		return null
	if number != floorf(number):
		problems.append("%s: %s nie jest liczbą całkowitą" % [path, str(value)])
		return null
	return int(number)


## Kolejne narożniki trasy muszą leżeć w jednej osi. Inaczej rozwinięcie trasy
## po cichu dopowiedziałoby zakręt, którego autor poziomu nie zapisał.
static func _check_corners_share_axis(corners: Array[Vector2i], path: String, problems: Array[String]) -> void:
	for i in range(1, corners.size()):
		var from := corners[i - 1]
		var to := corners[i]
		if from.x != to.x and from.y != to.y:
			problems.append("%s[%d]: (%d,%d) → (%d,%d) nie leżą w jednej osi" % [
				path, i, from.x, from.y, to.x, to.y])
