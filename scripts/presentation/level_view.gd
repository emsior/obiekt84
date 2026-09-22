## Wizualizacja poziomu L0.
##
## Rysuje planszę, trasę intruza, waypointy, cel i stożki widzenia wyłącznie na
## podstawie snapshotu rdzenia. Nic tutaj nie zmienia stanu domenowego i nic nie
## liczy na potrzeby logiki — widok jest tylko odbiciem tego, co policzył core.
##
## Origin planszy i skala komórki są deterministyczne: komórka (x, y) trafia
## zawsze na piksel (x * CELL_SIZE, y * CELL_SIZE) względem tego node'a.
## W L0 nie ma danych o ścianach ani polach zablokowanych, więc granicą planszy
## jest obrys siatki.
class_name LevelView
extends Node2D

const CELL_SIZE := 28

const COLOR_FLOOR := Color(0.10, 0.11, 0.13, 1.0)
const COLOR_GRID := Color(0.17, 0.19, 0.22, 1.0)
const COLOR_GRID_BORDER := Color(0.45, 0.49, 0.56, 1.0)
const COLOR_ROUTE_CELL := Color(0.18, 0.28, 0.38, 1.0)
const COLOR_ROUTE_LINE := Color(0.34, 0.50, 0.66, 1.0)
const COLOR_ROUTE_DONE := Color(0.24, 0.38, 0.30, 1.0)
const COLOR_WAYPOINT := Color(0.58, 0.52, 0.24, 1.0)
const COLOR_GOAL := Color(0.95, 0.90, 0.40, 1.0)
const COLOR_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.92)
## Turkus, nie niebieski: trasa intruza jest niebieska i przy tym samym odcieniu
## stożek kamery zlewał się z nią wzrokowo.
const COLOR_CAMERA_CONE := Color(0.18, 0.72, 0.76, 0.20)
const COLOR_GUARD_CONE := Color(0.80, 0.65, 0.20, 0.18)
const COLOR_GUARD_CONE_SUSPICION := Color(0.95, 0.70, 0.20, 0.28)
const COLOR_GUARD_CONE_ALARM := Color(0.85, 0.25, 0.20, 0.34)

const COLOR_CAMERA := Color(0.40, 0.75, 0.90, 1.0)
const COLOR_INTRUDER := Color(0.45, 0.85, 0.50, 1.0)
const COLOR_INTRUDER_DETECTED := Color(0.90, 0.35, 0.30, 1.0)
const COLOR_INTRUDER_SUCCESS := Color(0.95, 0.90, 0.40, 1.0)

@onready var _guard_view: ActorView = $GuardView
@onready var _intruder_view: ActorView = $IntruderView
@onready var _camera_view: ActorView = $CameraView

var _snapshot: Dictionary = {}
var _overlay_visible := true
var _highlight_cells: Array[Vector2i] = []


## Jedyne wejście warstwy widoku: snapshot odczytany z rdzenia oraz lista
## komórek do wyróżnienia. Widok nie decyduje, co jest warte podświetlenia —
## dostaje gotową listę od koordynatora.
func render(snapshot: Dictionary, highlight_cells: Array[Vector2i] = []) -> void:
	_snapshot = snapshot
	_highlight_cells = highlight_cells

	_guard_view.apply_state(
		snapshot["guard_position"], snapshot["guard_facing"], CELL_SIZE)
	_guard_view.set_body_color(_guard_color(String(snapshot["guard_state"])))

	_intruder_view.apply_state(snapshot["intruder_position"], Vector2i.ZERO, CELL_SIZE)
	_intruder_view.set_body_color(_intruder_color(String(snapshot["intruder_state"])))

	_camera_view.apply_state(
		snapshot["camera_position"], snapshot["camera_facing"], CELL_SIZE)
	_camera_view.set_body_color(COLOR_CAMERA)

	queue_redraw()


## Przełącznik debugowej nakładki: stożki widzenia kamery i strażnika.
func set_overlay_visible(value: bool) -> void:
	_overlay_visible = value
	queue_redraw()


func is_overlay_visible() -> bool:
	return _overlay_visible


## Rozmiar planszy w pikselach — używany do wyśrodkowania widoku w scenie.
func board_size() -> Vector2:
	if _snapshot.is_empty():
		return Vector2.ZERO
	var grid_size: Vector2i = _snapshot["grid_size"]
	return Vector2(grid_size * CELL_SIZE)


func _draw() -> void:
	if _snapshot.is_empty():
		return

	var grid_size: Vector2i = _snapshot["grid_size"]
	_draw_floor(grid_size)
	_draw_route()
	if _overlay_visible:
		_draw_cones()
	_draw_waypoints()
	_draw_goal()
	_draw_grid(grid_size)
	_draw_highlights()


## Wyróżnienie komórek, w których w tym ticku coś się wydarzyło.
## Rysowane na samym końcu, żeby nic go nie zasłaniało.
func _draw_highlights() -> void:
	for cell: Vector2i in _highlight_cells:
		var top_left := Vector2(cell * CELL_SIZE) - Vector2.ONE * 2.0
		var size := Vector2.ONE * (float(CELL_SIZE) + 4.0)
		draw_rect(Rect2(top_left, size), COLOR_HIGHLIGHT, false, 3.0)


func _draw_floor(grid_size: Vector2i) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_size * CELL_SIZE)), COLOR_FLOOR, true)


func _draw_grid(grid_size: Vector2i) -> void:
	var width := float(grid_size.x * CELL_SIZE)
	var height := float(grid_size.y * CELL_SIZE)
	for x in range(grid_size.x + 1):
		var px := float(x * CELL_SIZE)
		draw_line(Vector2(px, 0.0), Vector2(px, height), COLOR_GRID, 1.0)
	for y in range(grid_size.y + 1):
		var py := float(y * CELL_SIZE)
		draw_line(Vector2(0.0, py), Vector2(width, py), COLOR_GRID, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), COLOR_GRID_BORDER, false, 2.0)


## Trasa intruza: subtelnie podświetlone komórki plus linia prowadząca.
## Odcinek już przebyty ma inny odcień, żeby widać było postęp.
func _draw_route() -> void:
	var route: Array = _snapshot["intruder_route"]
	if route.is_empty():
		return

	var passed := int(_snapshot["intruder_route_index"])
	for i in route.size():
		var cell: Vector2i = route[i]
		var color := COLOR_ROUTE_DONE if i <= passed else COLOR_ROUTE_CELL
		draw_rect(Rect2(Vector2(cell * CELL_SIZE) + Vector2.ONE, Vector2.ONE * (CELL_SIZE - 2.0)), color, true)

	if route.size() >= 2:
		var points := PackedVector2Array()
		for cell: Vector2i in route:
			points.append(_cell_center(cell))
		draw_polyline(points, COLOR_ROUTE_LINE, 2.0)


func _draw_waypoints() -> void:
	var waypoints: Array = _snapshot["guard_waypoints"]
	var active := int(_snapshot["guard_waypoint_index"])
	for i in waypoints.size():
		var cell: Vector2i = waypoints[i]
		var top_left := Vector2(cell * CELL_SIZE) + Vector2.ONE * 4.0
		var size := Vector2.ONE * (float(CELL_SIZE) - 8.0)
		var thickness := 3.0 if i == active else 1.5
		draw_rect(Rect2(top_left, size), COLOR_WAYPOINT, false, thickness)


## Cel intruza to ostatnia komórka jego trasy.
func _draw_goal() -> void:
	var route: Array = _snapshot["intruder_route"]
	if route.is_empty():
		return
	var goal: Vector2i = route[route.size() - 1]
	var center := _cell_center(goal)
	var half := float(CELL_SIZE) * 0.34
	draw_rect(Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0), COLOR_GOAL, false, 2.5)
	draw_line(center - Vector2(half, half), center + Vector2(half, half), COLOR_GOAL, 1.5)
	draw_line(center - Vector2(-half, half), center + Vector2(-half, half), COLOR_GOAL, 1.5)


## Stożki widzenia rysowane komórka po komórce tą samą regułą, której używa
## rdzeń. To wyłącznie ilustracja — widok nie liczy niczego na potrzeby logiki
## i nie ma własnej implementacji FOV.
func _draw_cones() -> void:
	_draw_cone(
		_snapshot["camera_position"],
		_snapshot["camera_facing"],
		int(_snapshot["camera_range"]),
		COLOR_CAMERA_CONE)
	_draw_cone(
		_snapshot["guard_position"],
		_snapshot["guard_facing"],
		int(_snapshot["guard_view_range"]),
		_guard_cone_color(String(_snapshot["guard_state"])))


func _draw_cone(origin: Vector2i, facing: Vector2i, view_range: int, color: Color) -> void:
	var grid_size: Vector2i = _snapshot["grid_size"]
	for dx in range(-view_range, view_range + 1):
		for dy in range(-view_range, view_range + 1):
			var cell := origin + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
				continue
			if not FovCalculator.is_target_visible(origin, facing, view_range, cell):
				continue
			draw_rect(Rect2(Vector2(cell * CELL_SIZE), Vector2.ONE * float(CELL_SIZE)), color, true)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL_SIZE) + Vector2.ONE * (float(CELL_SIZE) * 0.5)


func _guard_color(state: String) -> Color:
	match state:
		GuardFsm.STATE_SUSPICION:
			return Color(0.95, 0.75, 0.25, 1.0)
		GuardFsm.STATE_ALARM:
			return Color(0.95, 0.30, 0.25, 1.0)
		GuardFsm.STATE_RETURN:
			return Color(0.70, 0.70, 0.75, 1.0)
		_:
			return Color(0.85, 0.85, 0.90, 1.0)


func _guard_cone_color(state: String) -> Color:
	match state:
		GuardFsm.STATE_SUSPICION:
			return COLOR_GUARD_CONE_SUSPICION
		GuardFsm.STATE_ALARM:
			return COLOR_GUARD_CONE_ALARM
		_:
			return COLOR_GUARD_CONE


func _intruder_color(state: String) -> Color:
	match state:
		IntruderScript.STATE_DETECTED:
			return COLOR_INTRUDER_DETECTED
		IntruderScript.STATE_SUCCESS:
			return COLOR_INTRUDER_SUCCESS
		_:
			return COLOR_INTRUDER
