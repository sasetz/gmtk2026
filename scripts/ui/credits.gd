extends Control
## Credits: who made it, and where to find them.
##
## The roster is plain data at the top of this file — edit CREDITS/LINKS and the
## page rebuilds itself, no scene surgery. Each person renders as NAME — role on
## one line, with their links/handles beneath. A link with an empty url shows as
## plain text (for Discord handles, which have no public profile URL).

signal closed

## Each entry: {name, role, links:[{label, url}]}. url "" → shown as plain text.
const CREDITS: Array[Dictionary] = [
	{
		"name": "Sasetz", "role": "Team Lead & Coder",
		"links": [
			{"label": "GitHub", "url": "https://github.com/sasetz"},
			{"label": "itch.io", "url": "https://sasetz.itch.io"},
		],
	},
	{
		"name": "Semenchuk Oleh", "role": "Coder",
		"links": [{"label": "LinkedIn", "url": "https://www.linkedin.com/in/oleh-semenchuk/"}],
	},
	{
		"name": "BarbaMan", "role": "Music Composer",
		"links": [{"label": "Instagram @barbaman05", "url": "https://instagram.com/barbaman05"}],
	},
	{
		"name": "Mason Chapman (Mo Memo)", "role": "Sound Designer",
		"links": [{"label": "Instagram @momemo_music", "url": "https://instagram.com/momemo_music"}],
	},
	{
		"name": "Uma Alma", "role": "Artist",
		"links": [{"label": "Discord: uma_alma", "url": ""}],
	},
	{
		"name": "Something", "role": "Artist",
		"links": [{"label": "Discord: eri_2005", "url": ""}],
	},
]

## Project-wide links shown under the roster.
const LINKS: Array[Dictionary] = [
	{"label": "Source — github.com/sasetz/gmtk2026", "url": "https://github.com/sasetz/gmtk2026"},
]

const GOLD := Color(0.98, 0.9, 0.7)
const DIM := Color(0.78, 0.85, 0.88)
const LINK := Color(0.55, 0.85, 0.95)


func _ready() -> void:
	_build()
	$Panel/Box/Back.pressed.connect(func() -> void: closed.emit())
	$Panel/Box/Back.grab_focus()


func _build() -> void:
	var people: VBoxContainer = $Panel/Box/People
	for c: Node in people.get_children():
		c.queue_free()
	for entry: Dictionary in CREDITS:
		people.add_child(_person(entry))

	var links: VBoxContainer = $Panel/Box/Links
	for c: Node in links.get_children():
		c.queue_free()
	for entry: Dictionary in LINKS:
		links.add_child(_link(String(entry["label"]), String(entry["url"])))


## One roster block: NAME — role on top, links/handles on a smaller line below.
func _person(entry: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l := Label.new()
	name_l.text = String(entry.get("name", ""))
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", GOLD)
	head.add_child(name_l)
	var role := Label.new()
	role.text = "— %s" % String(entry.get("role", ""))
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 17)
	role.add_theme_color_override("font_color", DIM)
	head.add_child(role)
	block.add_child(head)

	var links_row := HBoxContainer.new()
	links_row.add_theme_constant_override("separation", 14)
	links_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for l: Dictionary in entry.get("links", []):
		var label: String = String(l.get("label", ""))
		var url: String = String(l.get("url", ""))
		if url.is_empty():
			# Discord (and the like) — a handle, not a page. Show it plainly.
			var handle := Label.new()
			handle.text = label
			handle.add_theme_font_size_override("font_size", 15)
			handle.add_theme_color_override("font_color", DIM)
			links_row.add_child(handle)
		else:
			links_row.add_child(_link(label, url, 15))
	block.add_child(links_row)
	return block


## A clickable external link. LinkButton.uri opens via the OS on desktop and a
## new tab on web exports.
func _link(label: String, url: String, size: int = 17) -> LinkButton:
	var b := LinkButton.new()
	b.text = label
	b.uri = url
	b.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", LINK)
	b.tooltip_text = url
	return b


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
