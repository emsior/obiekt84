## Adapter czasu między Godotem a rdzeniem.
##
## Timer jest wyłącznie tempem wizualnym — nie jest zegarem domenowym.
## Każdy timeout wywołuje najwyżej jeden jawny step(). Jitter Timera nie może
## zmienić wyniku logicznego, bo rdzeń nie widzi delty ani czasu rzeczywistego.
extends Node2D

@onready var _level_view: LevelView = $LevelL0
@onready var _hud: Hud = $HudLayer/Hud
@onready var _step_timer: Timer = $StepTimer

var _simulation: Simulation = null
var _running := false


func _ready() -> void:
	_simulation = Simulation.new()
	_simulation.initialize(ScenarioL0.create())

	_step_timer.wait_time = Simulation.SECONDS_PER_TICK
	_step_timer.one_shot = false
	_step_timer.timeout.connect(_on_step_timeout)

	_hud.start_requested.connect(_on_start_requested)
	_hud.pause_toggle_requested.connect(_on_pause_toggle_requested)
	_hud.restart_requested.connect(_on_restart_requested)

	_render()


## Jeden timeout to dokładnie jedno wywołanie step().
func _on_step_timeout() -> void:
	if not _running:
		return
	if _simulation.is_finished():
		_stop()
		_render()
		return

	_simulation.step()
	_render()

	if _simulation.is_finished():
		_stop()
		_render()


func _on_start_requested() -> void:
	if _simulation.is_finished() or _running:
		return
	_running = true
	_step_timer.start()
	_render()


func _on_pause_toggle_requested() -> void:
	if _simulation.is_finished():
		return
	if _running:
		_stop()
	else:
		_running = true
		_step_timer.start()
	_render()


## Restart przywraca rdzeń do identycznego stanu początkowego i zatrzymuje
## odtwarzanie, żeby tester widział dokładnie stan wyjściowy.
func _on_restart_requested() -> void:
	_stop()
	_simulation.reset()
	_render()


func _stop() -> void:
	_running = false
	_step_timer.stop()


## Widok i HUD czytają wyłącznie snapshot oraz kopię logu.
func _render() -> void:
	var snapshot := _simulation.get_state_snapshot()
	_level_view.render(snapshot)
	_hud.render(
		snapshot,
		_simulation.get_last_events(Hud.LOG_LINES),
		_running,
		_simulation.is_finished())
