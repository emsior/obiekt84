## Minimalne UI L0: Start, Pauza/Wznów, Restart oraz podgląd stanu i logu.
##
## HUD nie zna FSM ani ticków — wyłącznie wyświetla to, co dostanie ze snapshotu,
## i zgłasza intencję użytkownika sygnałem. Nigdy nie zmienia stanu rdzenia.
class_name Hud
extends Control

signal start_requested
signal pause_toggle_requested
signal restart_requested

const LOG_LINES := 12

@onready var _start_button: Button = $StartButton
@onready var _pause_button: Button = $PauseButton
@onready var _restart_button: Button = $RestartButton
@onready var _status_label: Label = $StatusLabel
@onready var _log_label: Label = $LogLabel


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_pause_button.pressed.connect(func() -> void: pause_toggle_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())


func render(snapshot: Dictionary, events: Array[Dictionary], running: bool, finished: bool) -> void:
	_start_button.disabled = running or finished
	_pause_button.disabled = finished
	_pause_button.text = "Pauza" if running else "Wznów"

	_status_label.text = "\n".join(PackedStringArray([
		"OBIEKT '84 — incydent L0",
		"",
		"tick:      %d  (10 Hz)" % int(snapshot["tick"]),
		"wynik:     %s" % String(snapshot["outcome"]),
		"",
		"strażnik:  %s  %s  wp=%d  widzi=%d" % [
			String(snapshot["guard_state"]),
			_cell_text(snapshot["guard_position"]),
			int(snapshot["guard_waypoint_index"]),
			int(snapshot["guard_visible_streak"]),
		],
		"intruz:    %s  %s  krok=%d/%d" % [
			String(snapshot["intruder_state"]),
			_cell_text(snapshot["intruder_position"]),
			int(snapshot["intruder_route_index"]),
			(snapshot["intruder_route"] as Array).size() - 1,
		],
		"kamera:    %s  zasięg=%d" % [
			_cell_text(snapshot["camera_position"]),
			int(snapshot["camera_range"]),
		],
	]))

	var lines := PackedStringArray(["event log (tick|podmiot|zdarzenie|powód)", ""])
	for entry: Dictionary in events:
		lines.append("%d|%s|%s|%s" % [
			int(entry["tick"]),
			String(entry["subject"]),
			String(entry["event"]),
			String(entry["reason"]),
		])
	_log_label.text = "\n".join(lines)


func _cell_text(cell: Vector2i) -> String:
	return "(%2d,%2d)" % [cell.x, cell.y]
