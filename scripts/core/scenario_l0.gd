## Jawne dane jedynego, ręcznie skonfigurowanego incydentu L0.
##
## Żadna wartość nie jest losowana i nie zależy od czasu systemowego.
## Konfiguracja incydentu żyje tutaj, a nie w interaktywnym UI planowania —
## to świadome ograniczenie tej iteracji.
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
