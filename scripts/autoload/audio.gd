extends Node
## Central audio: looping background music with crossfades, and a pooled,
## variant-randomised SFX layer. Everything routes through the Music / SFX buses
## (see default_bus_layout.tres) so the options sliders already control it.
##
## Design goals:
##  - Scenes stay audio-agnostic where possible: money/buy/sell sounds ride
##    EventBus, and EVERY button plays a click via a global node_added hook, so
##    the menus needed no per-button wiring.
##  - Variant sounds (chip/coin/card…) pick a random file AND a slight random
##    pitch each time, so repeated actions never sound like a machine gun.
##  - Runs with PROCESS_MODE_ALWAYS so pause-menu clicks and music keep working
##    while get_tree().paused is true.

const DIR: String = "res://assets/sounds/"

## Logical name → interchangeable variant files. play_sfx() picks one at random.
const SFX := {
	&"ui_click": ["button press 1.wav", "Button Press 2.wav", "click.wav"],
	&"ui_cancel": ["cancel.wav"],
	&"card": ["card flick.wav", "card flick 2.wav", "card flick 3.wav"],
	&"card_slide": ["card slide.wav"],
	&"chip": ["chip.wav", "chip 2.wav", "chip 3.wav"],
	&"coin": ["coin.wav", "coin 2.wav", "coin 3.wav"],
	&"point": ["point.wav"],
	&"multihit": ["multihit multipoints.wav"],
	&"clock": ["clock tick 1.wav", "Clock tick 2.wav"],
	&"crumple": ["crumple.wav", "crumple 2.wav", "crumple 3.wav"],
	&"jimbo": ["Jimbo Speak 01.wav", "Jimbo Speak 02.wav", "Jimbo Speak 03.wav",
		"Jimbo Speak 04.wav", "Jimbo Speak 05.wav"],
	&"speech": ["speech bubble 1.wav", "speech bubble 2.wav", "speech bubble 3.wav",
		"speech bubble 4.wav"],
}

const MUSIC := {
	&"menu": "Smooth as the cards I play(test).mp3",
	&"round": "Card Game Final.mp3",
	&"shop": "Card Game SHOP MODE.mp3",
}

const SFX_VOICES: int = 10
const MUSIC_DB: float = -6.0          # headroom so music sits under the SFX
const FADE_TIME: float = 0.6
const SILENT_DB: float = -60.0

var _sfx_streams: Dictionary = {}     # name → Array[AudioStream]
var _last_variant: Dictionary = {}    # name → last variant index played
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

## Random pitch spread applied to every cue (±), so repeats never sound identical.
const PITCH_SPREAD: float = 0.11

# Two music players so a change crossfades instead of hard-cutting.
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_streams: Dictionary = {}   # name → AudioStream (loop = true)
var _current_track: StringName = &""

var _last_money: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_load_sfx()
	_build_voices()
	_build_music()
	_connect_events()


# --- SFX --------------------------------------------------------------------

func _load_sfx() -> void:
	for name: StringName in SFX:
		var streams: Array = []
		for file: String in SFX[name]:
			var s: AudioStream = load(DIR + file)
			if s != null:
				streams.append(s)
			else:
				push_warning("Audio: missing SFX file %s" % file)
		_sfx_streams[name] = streams


func _build_voices() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices.append(p)


## Play a sound by logical name. `pitch` is the centre pitch; a small random
## spread is added so repeats feel alive. `volume_db` trims individual cues.
func play_sfx(name: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var streams: Array = _sfx_streams.get(name, [])
	if streams.is_empty():
		return
	var idx: int = _pick_variant(name, streams.size())
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = streams[idx]
	voice.pitch_scale = clampf(pitch + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD), 0.1, 4.0)
	voice.volume_db = volume_db
	voice.play()


## Choose a variant index, never the same one twice in a row for a given sound —
## consecutive repeats are exactly what makes randomisation sound like no
## randomisation. With one variant there's nothing to vary, so return it.
func _pick_variant(name: StringName, count: int) -> int:
	if count <= 1:
		return 0
	var last: int = int(_last_variant.get(name, -1))
	var idx: int = _rng.randi_range(0, count - 2)
	if idx >= last:
		idx += 1   # skip the last-played index, so every other stays equally likely
	_last_variant[name] = idx
	return idx


# --- music ------------------------------------------------------------------

func _build_music() -> void:
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	for name: StringName in MUSIC:
		var s: AudioStream = load(DIR + MUSIC[name])
		if s == null:
			push_warning("Audio: missing music file %s" % MUSIC[name])
			continue
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		_music_streams[name] = s


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.volume_db = SILENT_DB
	add_child(p)
	return p


## Crossfade to a named track (menu / round / shop). A no-op if it's already
## the current one, so scenes can call it freely on every _ready.
func play_music(track: StringName) -> void:
	if track == _current_track:
		return
	if not _music_streams.has(track):
		return
	_current_track = track

	# _music_a is always the live player; swap so the new track fades in on the
	# fresh one while the old fades out.
	var incoming: AudioStreamPlayer = _music_b
	var outgoing: AudioStreamPlayer = _music_a
	_music_a = incoming
	_music_b = outgoing

	incoming.stream = _music_streams[track]
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade(incoming, MUSIC_DB)
	if outgoing.playing:
		_fade(outgoing, SILENT_DB, true)


func stop_music() -> void:
	_current_track = &""
	_fade(_music_a, SILENT_DB, true)
	_fade(_music_b, SILENT_DB, true)


func _fade(player: AudioStreamPlayer, to_db: float, stop_after: bool = false) -> void:
	var t: Tween = create_tween()
	t.tween_property(player, "volume_db", to_db, FADE_TIME)
	if stop_after:
		t.tween_callback(player.stop)


# --- gameplay event cues ----------------------------------------------------

func _connect_events() -> void:
	# _last_money starts at -1 so the first money_changed (the run's opening
	# balance) just sets the baseline instead of jingling.
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.card_bought.connect(func(_j) -> void: play_sfx(&"card_slide"))
	EventBus.card_sold.connect(func(_j) -> void: play_sfx(&"crumple"))


## Coin jingle only when money goes UP — resets and purchases (which lower it)
## stay quiet, so the coin means "you got paid".
func _on_money_changed(amount: int) -> void:
	if _last_money >= 0 and amount > _last_money:
		play_sfx(&"coin")
	_last_money = amount
