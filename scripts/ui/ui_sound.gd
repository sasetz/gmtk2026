class_name UiSound
extends Object
## Gives every button on a screen a press sound in one line, so no button can be
## forgotten. A screen calls UiSound.attach(self) in _ready.
##
## This is deliberately per-screen and explicit rather than a global hook on the
## tree: the screens that opt in are visible in their own code, and a button that
## already plays its own sound can be left out with `skip`.


## Connect every button under `root` to `cue`. Buttons whose name is in `skip`
## are left alone - those play something of their own.
static func attach(root: Node, cue: StringName = &"ui_click", skip: Array = []) -> void:
	for button: BaseButton in _buttons(root):
		if skip.has(button.name):
			continue
		play_on(button, cue)


## Give one button a press sound.
static func play_on(button: BaseButton, cue: StringName) -> void:
	button.pressed.connect(func() -> void: Audio.play_sfx(cue))


static func _buttons(node: Node) -> Array[BaseButton]:
	var found: Array[BaseButton] = []
	if node is BaseButton:
		found.append(node as BaseButton)
	for child: Node in node.get_children():
		found.append_array(_buttons(child))
	return found
