## Edytor fazy planowania L1-A: przeciąganie waypointów patrolu i kamery,
## obrót kamery kliknięciem.
##
## Edytor jest właścicielem **roboczej kopii danych scenariusza (draftu)**.
## Nie zna `Simulation`, nie czyta snapshotu i nigdy nie dotyka stanu domenowego —
## koordynator przekazuje rdzeniowi kopię draftu przez `initialize()`, a edytor
## ogłasza tylko zmianę albo odrzucenie sygnałem.
##
## Każda zmiana powstaje na kopii draftu i przechodzi przez
## `ScenarioL0.validate()`. Dopiero poprawna kopia zastępuje draft, więc draft
## jest zawsze poprawny. Upuszczenie poza siatką odrzuca ta sama walidacja
## („poza siatką”) — nie ma drugiej, własnej definicji granicy planszy.
##
## Wejście nie przychodzi tu z `InputEvent`: koordynator zamienia mysz na komórki
## i woła `begin_drag` / `drag_to` / `end_drag`. Dzięki temu testy wołają te same
## metody bezpośrednio. Rysowanie wyłącznie przez `_draw()`, bez node'ów fizycznych.
class_name PlanEditor
extends Node2D

## Draft zmienił się po zaakceptowanej edycji albo po przywróceniu planu.
signal draft_changed
## Edycja została odrzucona. [param message] to pierwszy komunikat walidacji.
signal edit_rejected(message: String)

## Cel przeciągania: indeks waypointu (0..3), kamera albo nic.
const TARGET_NONE := -2
const TARGET_CAMERA := -1

const COLOR_PATROL_PATH := Color(0.80, 0.70, 0.30, 0.55)
const COLOR_LABEL := Color(0.95, 0.88, 0.45, 1.0)
const COLOR_GHOST := Color(1.0, 1.0, 1.0, 0.85)
const COLOR_GHOST_FILL := Color(1.0, 1.0, 1.0, 0.12)
const LABEL_FONT_SIZE := 13
const COLOR_LABEL_OUTLINE := Color(0.05, 0.06, 0.08, 0.95)

## Plik poziomu, z którego pochodzi plan domyślny zagadki — dane, nie kod
## (`docs/DECISIONS.md`, 2026-09-24, E7).
const DEFAULT_LEVEL_PATH := "res://levels/puzzle_01.json"

var _draft: ScenarioL0 = load_default_level()
var _drag_target := TARGET_NONE
var _drag_origin := Vector2i.ZERO
var _drag_cell := Vector2i.ZERO


## Kopia draftu. Nikt poza edytorem nie może zmienić draftu z pominięciem walidacji.
func draft() -> ScenarioL0:
	return _draft.duplicate_data()


## Podmienia draft na kopię poprawnych danych i przerywa trwające przeciąganie.
func set_draft(scenario: ScenarioL0) -> void:
	var problems := scenario.validate()
	assert(problems.is_empty(), "niepoprawny draft: %s" % "; ".join(problems))
	_draft = scenario.duplicate_data()
	cancel_drag()
	draft_changed.emit()


## Klawisz R w fazie planowania: plan domyślny zagadki.
func reset_to_puzzle() -> void:
	set_draft(load_default_level())


## Czyta plik poziomu i przekazuje tekst parserowi rdzenia. Zwraca to samo co
## `LevelData.parse`, a gdy pliku nie da się otworzyć — problem odczytu.
static func load_level_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var open_error := FileAccess.get_open_error()
	if open_error != OK:
		var problems: Array[String] = ["%s: nie można odczytać pliku (%s)" % [
			path, error_string(open_error)]]
		return {"scenario": null, "problems": problems}
	return LevelData.parse(text)


## Plan domyślny z pliku poziomu. Przy jakimkolwiek problemie — głośny błąd
## i te same dane z kodu (`ScenarioL0.create_puzzle()`), żeby gra wystartowała.
## Równoważność pliku i kodu pilnuje `tests/test_level_data.gd`.
static func load_default_level() -> ScenarioL0:
	var result := load_level_file(DEFAULT_LEVEL_PATH)
	var problems := PackedStringArray(result["problems"])
	if problems.is_empty():
		return result["scenario"]
	push_error("Poziom %s odrzucony, używam ScenarioL0.create_puzzle(): %s" % [
		DEFAULT_LEVEL_PATH, "; ".join(problems)])
	return ScenarioL0.create_puzzle()


func is_dragging() -> bool:
	return _drag_target != TARGET_NONE


## Zaczyna przeciąganie elementu stojącego na [param cell]. Zwraca `false`,
## gdy w komórce nie ma ani kamery, ani waypointu. Walidacja gwarantuje, że
## kamera nie dzieli komórki z waypointem, więc wybór jest jednoznaczny.
func begin_drag(cell: Vector2i) -> bool:
	if cell == _draft.camera_position:
		_drag_target = TARGET_CAMERA
	else:
		var index := _draft.guard_waypoints.find(cell)
		if index < 0:
			return false
		_drag_target = index
	_drag_origin = cell
	_drag_cell = cell
	queue_redraw()
	return true


## Komórka pod kursorem w trakcie przeciągania. Nie zmienia draftu — tylko
## przesuwa ducha elementu na planszy.
func drag_to(cell: Vector2i) -> void:
	if not is_dragging():
		return
	_drag_cell = cell
	queue_redraw()


## Upuszczenie. Kamera upuszczona tam, skąd ją podniesiono, to kliknięcie
## i obraca ją o 90°. Zwraca `true`, gdy draft się zmienił.
func end_drag() -> bool:
	if not is_dragging():
		return false
	var target := _drag_target
	var origin := _drag_origin
	var cell := _drag_cell
	cancel_drag()

	if target == TARGET_CAMERA and cell == origin:
		return rotate_camera()
	if cell == origin:
		return false

	var candidate := _draft.duplicate_data()
	if target == TARGET_CAMERA:
		candidate.camera_position = cell
	else:
		candidate.guard_waypoints[target] = cell
	return _commit(candidate)


func cancel_drag() -> void:
	_drag_target = TARGET_NONE
	queue_redraw()


## Obrót kamery o 90° zgodnie z ruchem wskazówek zegara na ekranie (oś Y w dół):
## góra → prawo → dół → lewo. Kierunki pozostają kardynalne.
func rotate_camera() -> bool:
	var candidate := _draft.duplicate_data()
	candidate.camera_facing = rotated_clockwise(candidate.camera_facing)
	return _commit(candidate)


static func rotated_clockwise(facing: Vector2i) -> Vector2i:
	return Vector2i(-facing.y, facing.x)


## Komórka siatki pod punktem ekranu. Poza planszą daje komórkę spoza siatki —
## odrzuci ją walidacja przy upuszczeniu.
func cell_at_global_point(global_point: Vector2) -> Vector2i:
	var local := to_local(global_point)
	return Vector2i(
		floori(local.x / float(LevelView.CELL_SIZE)),
		floori(local.y / float(LevelView.CELL_SIZE)))


## Strażnik zawsze startuje na pierwszym waypoincie. Kopia z problemem nie
## zastępuje draftu — gracz widzi pierwszy komunikat, draft zostaje bez zmian.
func _commit(candidate: ScenarioL0) -> bool:
	candidate.guard_start = candidate.guard_waypoints[0]
	var problems := candidate.validate()
	if not problems.is_empty():
		queue_redraw()
		edit_rejected.emit(problems[0])
		return false
	_draft = candidate
	queue_redraw()
	draft_changed.emit()
	return true


# === rysowanie ===============================================================

func _draw() -> void:
	_draw_patrol_path()
	_draw_waypoint_labels()
	if is_dragging():
		_draw_ghost()


## Ścieżka patrolu tą samą regułą, którą chodzi strażnik: najpierw oś X, potem
## oś Y. To ilustracja istniejącej reguły ruchu, nie pathfinding.
func _draw_patrol_path() -> void:
	var waypoints := _draft.guard_waypoints
	for i in waypoints.size():
		var from: Vector2i = waypoints[i]
		var to: Vector2i = waypoints[(i + 1) % waypoints.size()]
		var corner := Vector2i(to.x, from.y)
		draw_dashed_line(_cell_center(from), _cell_center(corner), COLOR_PATROL_PATH, 2.0, 6.0)
		draw_dashed_line(_cell_center(corner), _cell_center(to), COLOR_PATROL_PATH, 2.0, 6.0)


## Numery W1–W4 w lewym górnym rogu komórki, żeby nie zasłaniały strażnika.
func _draw_waypoint_labels() -> void:
	var waypoints := _draft.guard_waypoints
	for i in waypoints.size():
		var origin := Vector2(waypoints[i] * LevelView.CELL_SIZE) + Vector2(1.0, float(LABEL_FONT_SIZE) - 2.0)
		var text := "%d" % (i + 1)
		# Ciemny obrys odcina cyfrę od stożka i od strażnika stojącego na węźle 1.
		draw_string_outline(Hud.MONOSPACE_FONT, origin, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, 4, COLOR_LABEL_OUTLINE)
		draw_string(Hud.MONOSPACE_FONT, origin, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COLOR_LABEL)


func _draw_ghost() -> void:
	var top_left := Vector2(_drag_cell * LevelView.CELL_SIZE)
	var size := Vector2.ONE * float(LevelView.CELL_SIZE)
	draw_rect(Rect2(top_left, size), COLOR_GHOST_FILL, true)
	draw_rect(Rect2(top_left, size), COLOR_GHOST, false, 2.0)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * LevelView.CELL_SIZE) + Vector2.ONE * (float(LevelView.CELL_SIZE) * 0.5)
