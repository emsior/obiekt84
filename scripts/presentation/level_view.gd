## Wizualizacja poziomu L0.
##
## Rysuje siatkę, trasę intruza, waypointy i stożki widzenia wyłącznie na
## podstawie snapshotu rdzenia. Nic tutaj nie zmienia stanu domenowego.
## W L0 placeholdery przeskakują między komórkami — interpolacja nie jest
## potrzebna i nie miałaby wpływu na logikę.
class_name LevelView
extends Node2D

const CELL_SIZE := 28

const COLOR_GRID := Color(0.22, 0.24, 0.28, 1.0)
const COLOR_GRID_BORDER := Color(0.42, 0.46, 0.52, 1.0)
const COLOR_ROUTE := Color(0.30, 0.42, 0.55, 1.0)
const COLOR_WAYPOINT := Color(0.55, 0.50, 0.25, 1.0)
const COLOR_CAMERA_CONE := Color(0.25, 0.55, 0.70, 0.22)
const COLOR_GUARD_CONE := Color(0.80, 0.65, 0.20, 0.20)
const COLOR_GUARD_CONE_ALERT := Color(0.85, 0.25, 0.20, 0.30)
const COLOR_CAMERA := Color(0.40, 0.75, 0.90, 1.0)
const COLOR_INTRUDER := Color(0.45, 0.85, 0.50, 1.0)
const COLOR_INTRUDER_DETECTED := Color(0.90, 0.35, 0.30, 1.0)
const COLOR_INTRUDER_SUCCESS := Color(0.95, 0.90, 0.40, 1.0)

@onready var _guard_view: ActorView = $GuardView
@onready var _intruder_view: ActorView = $IntruderView
@onready var _camera_view: ActorView = $CameraView

var _snapshot: Dictionary = {}


## Jedyne wejście warstwy widoku: snapshot odczytany z rdzenia.
func render(snapshot: Dictionary) -> void:
	_snapshot = snapshot

	var guard_position: Vector2i = snapshot["guard_position"]
	var guard_facing: Vector2i = snapshot["guard_facing"]
	_guard_view.apply_state(guard_position, guard_facing, CELL_SIZE)
	_guard_view.set_body_color(_guard_color(String(snapshot["guard_state"])))

	var intruder_position: Vector2i = snapshot["intruder_position"]
	_intruder_view.apply_state(intruder_position, Vector2i.ZERO, CELL_SIZE)
	_intruder_view.set_body_color(_intruder_color(String(snapshot["intruder_state"])))

	var camera_position: Vector2i = snapshot["camera_position"]
	var camera_facing: Vector2i = snapshot["camera_facing"]
	_camera_view.apply_state(camera_position, camera_facing, CELL_SIZE)
	_camera_view.set_body_color(COLOR_CAMERA)

	queue_redraw()


func _draw() -> void:
	if _snapshot.is_empty():
		return

	var grid_size: Vector2i = _snapshot["grid_size"]
	_draw_cones()
	_draw_route()
	_draw_waypoints()
	_draw_grid(grid_size)


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


func _draw_route() -> void:
	var route: Array = _snapshot["intruder_route"]
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for cell: Vector2i in route:
		points.append(_cell_center(cell))
	draw_polyline(points, COLOR_ROUTE, 2.0)


func _draw_waypoints() -> void:
	var waypoints: Array = _snapshot["guard_waypoints"]
	for i in waypoints.size():
		var cell: Vector2i = waypoints[i]
		var top_left := Vector2(cell * CELL_SIZE) + Vector2.ONE * 5.0
		var size := Vector2.ONE * (float(CELL_SIZE) - 10.0)
		draw_rect(Rect2(top_left, size), COLOR_WAYPOINT, false, 2.0)


## Stożki widzenia są rysowane komórka po komórce tą samą, całkowitoliczbową
## regułą, której używa rdzeń. To wyłącznie ilustracja — widok niczego nie liczy
## na potrzeby logiki.
func _draw_cones() -> void:
	var guard_state := String(_snapshot["guard_state"])
	var guard_cone_color := COLOR_GUARD_CONE_ALERT if guard_state != GuardFsm.STATE_PATROL else COLOR_GUARD_CONE

	_draw_cone(
		_snapshot["camera_position"],
		_snapshot["camera_facing"],
		int(_snapshot["camera_range"]),
		COLOR_CAMERA_CONE)
	_draw_cone(
		_snapshot["guard_position"],
		_snapshot["guard_facing"],
		int(_snapshot["guard_view_range"]),
		guard_cone_color)


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


func _intruder_color(state: String) -> Color:
	match state:
		IntruderScript.STATE_DETECTED:
			return COLOR_INTRUDER_DETECTED
		IntruderScript.STATE_SUCCESS:
			return COLOR_INTRUDER_SUCCESS
		_:
			return COLOR_INTRUDER
