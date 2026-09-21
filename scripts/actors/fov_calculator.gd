## Matematyczne pole widzenia — wyłącznie liczby całkowite.
##
## Bez Area2D, CollisionShape2D, RayCast2D, zapytań do serwera fizyki i bez atan2().
## Model L0: stożek o łącznym kącie 90 stopni (45 na stronę).
class_name FovCalculator
extends RefCounted


## Czy obserwator stojący w [param observer], patrzący w kierunku kardynalnym
## [param facing], o zasięgu [param view_range] komórek, widzi [param target].
##
## Warunki, wszystkie całkowitoliczbowe:
## 1. cel w innej komórce niż obserwator,
## 2. kwadrat odległości <= kwadrat zasięgu (granica zasięgu jest widoczna),
## 3. iloczyn skalarny > 0, czyli cel jest przed obserwatorem,
## 4. cross_squared <= dot_squared, czyli cel mieści się w stożku 45 stopni
##    na stronę (granica kąta jest widoczna).
static func is_target_visible(
		observer: Vector2i,
		facing: Vector2i,
		view_range: int,
		target: Vector2i) -> bool:
	var to_target := target - observer

	# Cel na tej samej komórce nie jest poprawnym celem FOV.
	if to_target == Vector2i.ZERO:
		return false

	var distance_squared := to_target.x * to_target.x + to_target.y * to_target.y
	if distance_squared > view_range * view_range:
		return false

	var dot := to_target.x * facing.x + to_target.y * facing.y
	if dot <= 0:
		return false

	var cross := to_target.x * facing.y - to_target.y * facing.x
	return cross * cross <= dot * dot
