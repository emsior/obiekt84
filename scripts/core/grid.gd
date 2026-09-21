## Logiczna siatka symulacji.
##
## Przechowuje wyłącznie wymiary. Siatka nie jest zbiorem node'ów — 400 komórek
## istnieje jako zakres liczbowy, nie jako obiekty w Scene Tree.
class_name Grid
extends RefCounted

var width: int
var height: int


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height


## Czy komórka mieści się w granicach siatki.
func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func size() -> Vector2i:
	return Vector2i(width, height)
