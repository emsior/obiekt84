## Wizualny placeholder pojedynczego podmiotu.
##
## Czysta prezentacja: rysuje kółko i znacznik kierunku na podstawie logicznej
## pozycji Vector2i odczytanej ze snapshotu rdzenia. Transformacja tego node'a
## jest wynikiem prezentacji — nie wraca do rdzenia, nie wpływa na FOV, ruch,
## event log ani wynik incydentu i nie jest częścią stanu domenowego.
##
## Brak Area2D, CollisionShape2D, RayCast2D i jakiejkolwiek fizyki.
class_name ActorView
extends Node2D

@export var body_color: Color = Color.WHITE
@export var show_facing: bool = true

var _cell_size: int = 28
var _facing: Vector2i = Vector2i.RIGHT


## Przelicza logiczną komórkę na pozycję w pikselach.
## Kierunek jest rysowany, ale nigdy nie jest odczytywany przez rdzeń.
func apply_state(cell: Vector2i, facing: Vector2i, cell_size: int) -> void:
	_cell_size = cell_size
	_facing = facing
	position = Vector2(cell * cell_size) + Vector2.ONE * (float(cell_size) * 0.5)
	queue_redraw()


func set_body_color(color: Color) -> void:
	if body_color != color:
		body_color = color
		queue_redraw()


func _draw() -> void:
	var radius := float(_cell_size) * 0.34
	draw_circle(Vector2.ZERO, radius, body_color)

	if show_facing and _facing != Vector2i.ZERO:
		var direction := Vector2(_facing)
		draw_line(
			direction * radius,
			direction * (radius + float(_cell_size) * 0.42),
			body_color,
			2.0)
