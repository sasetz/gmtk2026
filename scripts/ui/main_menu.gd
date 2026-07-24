extends Control
## Front door: title, Play, Options, Credits, Quit.
##
## Options and Credits open as overlays on top of the menu rather than as scene
## changes — there's nothing to unload, and "Back" always lands you exactly where
## you were. Play routes through the tutorial, which can be skipped.

const TutorialScene: String = "res://scenes/tutorial.tscn"
const OptionsScene := preload("res://scenes/options_menu.tscn")
const CreditsScene := preload("res://scenes/credits.tscn")

var _overlay: Control = null


func _ready() -> void:
	_add_embers()
	$Buttons/Play.pressed.connect(_on_play)
	$Buttons/Options.pressed.connect(_open.bind(OptionsScene))
	$Buttons/Credits.pressed.connect(_open.bind(CreditsScene))
	$Buttons/Quit.pressed.connect(func() -> void: get_tree().quit())
	# There's no meaningful "quit" in a browser tab.
	$Buttons/Quit.visible = OS.get_name() != "Web"
	$Buttons/Play.grab_focus()
	Audio.play_music(&"menu")


## Slow warm embers drifting up the whole screen behind the UI.
func _add_embers() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var embers: CPUParticles2D = Fx.embers(vp.x, vp.y)
	embers.position = vp * 0.5
	embers.z_index = -1
	add_child(embers)
	move_child(embers, 1)   # above the Felt, below the UI


func _on_play() -> void:
	get_tree().change_scene_to_file(TutorialScene)


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
	$Buttons/Play.grab_focus()
