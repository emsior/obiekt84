## Jawne dane jedynego, ręcznie skonfigurowanego incydentu L0.
##
## Żadna wartość nie jest losowana i nie zależy od czasu systemowego.
## Edytor planowania (warstwa prezentacji) zmienia wyłącznie roboczą kopię
## tych danych i przekazuje ją rdzeniowi przez `Simulation.initialize()`.
class_name ScenarioL0
extends RefCounted

const GUARD_ID := "guard_01"
const INTRUDER_ID := "intruder_01"
const CAMERA_ID := "camera_01"

var grid_width: int
var grid_height: int

var guard_start: Vector2i
var guard_facing: Vector2i
var guard_view_range: int
var guard_waypoints: Array[Vector2i] = []

var intruder_route: Array[Vector2i] = []

var camera_position: Vector2i
var camera_facing: Vector2i
var camera_range: int

## Twardy limit bezpieczeństwa. Incydent L0 kończy się naturalnie dużo wcześniej.
var max_ticks: int


## Świeże, niezależne dane scenariusza. Każde wywołanie zwraca nowy obiekt
## z własnymi tablicami — nic nie jest współdzielone między przebiegami.
static func create() -> ScenarioL0:
	var scenario := ScenarioL0.new()

	scenario.grid_width = 20
	scenario.grid_height = 20

	scenario.guard_start = Vector2i(10, 4)
	scenario.guard_facing = Vector2i.RIGHT
	scenario.guard_view_range = 6
	scenario.guard_waypoints = [
		Vector2i(10, 4),
		Vector2i(16, 4),
		Vector2i(16, 12),
		Vector2i(10, 12),
	] as Array[Vector2i]

	# Kompletna trasa punkt po punkcie. Zgodna z regułą ruchu o jedną komórkę
	# na tick: wzdłuż dolnej krawędzi na zachód, na północ, potem na wschód.
	scenario.intruder_route = _build_route([
		Vector2i(18, 18),
		Vector2i(1, 18),
		Vector2i(1, 12),
		Vector2i(18, 12),
	] as Array[Vector2i])

	scenario.camera_position = Vector2i(3, 3)
	scenario.camera_facing = Vector2i.DOWN
	scenario.camera_range = 5

	scenario.max_ticks = 400

	return scenario


## Dane zagadki L1-A: plan domyślny, który gracz dostaje w fazie planowania.
##
## Te same wymiary, trasa intruza, kamera i zasięgi co [method create] — inny jest
## wyłącznie patrol. Dolny bok prostokąta leży za wysoko: strażnik dostrzega
## intruza w 32 ticku, gubi go w następnym, wraca do patrolu, a intruz kończy
## trasę w 40 ticku. Przegrana wynika z ustawienia patrolu, nie z osłabienia
## strażnika. `create()` zostaje nietknięte — chroni zatwierdzone golden logi.
static func create_puzzle() -> ScenarioL0:
	var scenario := create()
	scenario.guard_waypoints = [
		Vector2i(10, 4),
		Vector2i(16, 4),
		Vector2i(16, 8),
		Vector2i(10, 8),
	] as Array[Vector2i]
	scenario.guard_start = scenario.guard_waypoints[0]
	return scenario


## Niezależna kopia — żaden przebieg nie może zmodyfikować danych innego.
func duplicate_data() -> ScenarioL0:
	var copy := ScenarioL0.new()
	copy.grid_width = grid_width
	copy.grid_height = grid_height
	copy.guard_start = guard_start
	copy.guard_facing = guard_facing
	copy.guard_view_range = guard_view_range
	copy.guard_waypoints = guard_waypoints.duplicate()
	copy.intruder_route = intruder_route.duplicate()
	copy.camera_position = camera_position
	copy.camera_facing = camera_facing
	copy.camera_range = camera_range
	copy.max_ticks = max_ticks
	return copy


## Rozwija listę punktów zwrotnych do pełnej, jawnej listy komórek.
## Kolejne komórki różnią się dokładnie o jeden krok w osi X albo Y.
static func _build_route(corners: Array[Vector2i]) -> Array[Vector2i]:
	var route: Array[Vector2i] = [corners[0]]
	for i in range(1, corners.size()):
		var from: Vector2i = route[route.size() - 1]
		var to: Vector2i = corners[i]
		while from.x != to.x:
			from.x += signi(to.x - from.x)
			route.append(from)
		while from.y != to.y:
			from.y += signi(to.y - from.y)
			route.append(from)
	return route


## Lista problemów w danych scenariusza. Pusta lista oznacza dane poprawne.
##
## Rdzeń nie ma pathfindingu i nie koryguje błędnych danych. Gdyby waypoint
## wypadł poza siatkę albo trasa przeskakiwała komórkę, przebieg nadal byłby
## deterministyczny — tylko bez sensu. Walidacja zamienia taki błąd w jawny
## komunikat, zamiast cichego dziwnego przebiegu.
func validate() -> Array[String]:
	var problems: Array[String] = []

	if grid_width < 1 or grid_height < 1:
		problems.append("grid_size=%d,%d: wymiary siatki muszą być dodatnie" % [
			grid_width, grid_height])
		# Bez poprawnych wymiarów dalsze kontrole granic nie mają sensu.
		return problems

	var grid := Grid.new(grid_width, grid_height)

	if not grid.is_inside(guard_start):
		problems.append("guard_start=%s poza siatką" % _cell_text(guard_start))
	if not _is_cardinal(guard_facing):
		problems.append("guard_facing=%s nie jest kierunkiem kardynalnym" % _cell_text(guard_facing))
	if guard_view_range < 0:
		problems.append("guard_view_range=%d jest ujemny" % guard_view_range)

	if guard_waypoints.is_empty():
		problems.append("guard_waypoints: pusta lista — strażnik nie miałby dokąd iść")
	for i in guard_waypoints.size():
		if not grid.is_inside(guard_waypoints[i]):
			problems.append("guard_waypoints[%d]=%s poza siatką" % [
				i, _cell_text(guard_waypoints[i])])
	# Strażnik startuje na pierwszym waypoincie. Edytor przesuwa waypointy,
	# więc rozjechany start oznaczałby patrol inny niż ten na planszy.
	if not guard_waypoints.is_empty() and guard_start != guard_waypoints[0]:
		problems.append("guard_start=%s różni się od guard_waypoints[0]=%s" % [
			_cell_text(guard_start), _cell_text(guard_waypoints[0])])

	if intruder_route.is_empty():
		problems.append("intruder_route: pusta trasa — intruz nie miałby pozycji startowej")
	for i in intruder_route.size():
		if not grid.is_inside(intruder_route[i]):
			problems.append("intruder_route[%d]=%s poza siatką" % [
				i, _cell_text(intruder_route[i])])
	# Kontrakt ruchu: najwyżej jedna komórka na tick, wyłącznie w osi.
	for i in range(1, intruder_route.size()):
		var step: Vector2i = intruder_route[i] - intruder_route[i - 1]
		if not _is_cardinal(step):
			problems.append("intruder_route[%d]: krok %s to nie jedna komórka w osi" % [
				i, _cell_text(step)])

	if not grid.is_inside(camera_position):
		problems.append("camera_position=%s poza siatką" % _cell_text(camera_position))
	if not _is_cardinal(camera_facing):
		problems.append("camera_facing=%s nie jest kierunkiem kardynalnym" % _cell_text(camera_facing))
	if camera_range < 0:
		problems.append("camera_range=%d jest ujemny" % camera_range)
	# Kamera jest obiektem na planszy: nie stoi na drodze intruza ani na węźle patrolu.
	var route_index := intruder_route.find(camera_position)
	if route_index >= 0:
		problems.append("camera_position=%s stoi na trasie intruza (intruder_route[%d])" % [
			_cell_text(camera_position), route_index])
	for i in guard_waypoints.size():
		if guard_waypoints[i] == camera_position:
			problems.append("camera_position=%s stoi na guard_waypoints[%d]" % [
				_cell_text(camera_position), i])

	if max_ticks < 1:
		problems.append("max_ticks=%d musi być dodatnie" % max_ticks)

	return problems


func is_valid() -> bool:
	return validate().is_empty()


## Kierunek kardynalny: dokładnie jedna oś, dokładnie o jedną komórkę.
static func _is_cardinal(value: Vector2i) -> bool:
	return absi(value.x) + absi(value.y) == 1


static func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]
