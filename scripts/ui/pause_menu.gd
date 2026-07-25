extends CanvasLayer
## Global pause overlay (autoloaded, so it sits above whatever scene is running).
##
## Esc pauses gameplay and offers Resume / Options / Main Menu. It only arms
## itself for scenes in the "gameplay" group, so Esc in the menus doesn't put up
## a pause screen over a menu. The whole layer runs with PROCESS_MODE_ALWAYS so
## it keeps responding while `get_tree().paused` is true.

const OptionsScene := preload("res://scenes/options_menu.tscn")
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"

@onready var _root: Control = $Root
@onready var _resume: Button = $Root/Panel/Box/Resume

var _options: Control = null


func _ready() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


## Pause is only meaningful over an actual round — menus opt out by simply not
## being in the "gameplay" group.
func _can_pause() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.is_in_group("gameplay")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"cancel"):
		return
	# While the options overlay is up it owns Esc (it closes back to pause).
	if _options != null:
		return
	if is_open():
		get_viewport().set_input_as_handled()
		close()
	elif _can_pause():
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	if is_open():
		return
	_root.visible = true
	get_tree().paused = true
	_resume.grab_focus()


## Bound in the scene: Resume button.
func _on_resume_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	close()


func close() -> void:
	_close_options()
	_root.visible = false
	get_tree().paused = false


## Bound in the scene: Options button.
func _on_options_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	if _options != null:
		return
	_options = OptionsScene.instantiate()
	_options.closed.connect(_close_options)
	add_child(_options)


func _close_options() -> void:
	if _options == null:
		return
	_options.queue_free()
	_options = null
	if is_open():
		_resume.grab_focus()


## Bound in the scene: Main Menu button.
func _on_main_menu_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	_close_options()
	_root.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
