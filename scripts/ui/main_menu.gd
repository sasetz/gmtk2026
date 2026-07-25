extends Control
## Front door: Play, Options, Credits, Quit. Button signals are bound in the
## scene (see the [connection] entries in main_menu.tscn). Options and Credits
## open as overlays so "Back" returns exactly here.

const GameScene: String = "res://scenes/game.tscn"
const OptionsScene := preload("res://scenes/options_menu.tscn")
const CreditsScene := preload("res://scenes/credits.tscn")

@onready var _play: Button = $Buttons/Play
@onready var _quit: Button = $Buttons/Quit

var _overlay: Control = null


func _ready() -> void:
	# There's no meaningful "quit" in a browser tab.
	_quit.visible = OS.get_name() != "Web"
	_play.grab_focus()
	Audio.play_music(&"menu")


func _on_play_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	get_tree().change_scene_to_file(GameScene)


func _on_options_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	_open(OptionsScene)


func _on_credits_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	_open(CreditsScene)


func _on_quit_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	get_tree().quit()


func _open(scene: PackedScene) -> void:
	if _overlay != null:
		return
	_overlay = scene.instantiate()
	_overlay.closed.connect(_close_overlay)
	add_child(_overlay)


func _close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null
	_play.grab_focus()
