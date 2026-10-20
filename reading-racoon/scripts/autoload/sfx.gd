extends Node
## Small synthesized sound effects (autoload "Sfx"), so no audio files are needed yet.
## Wrong answers get a soft low "boop", never a buzzer (D-007). FR-20 (SFX part).

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_streams = {
		"correct": _tone([784.0, 1175.0], 0.11, 0.35),
		"wrong": _tone([330.0, 262.0], 0.14, 0.22),
		"tap": _tone([660.0], 0.05, 0.2),
		"pop": _tone([523.0, 784.0], 0.06, 0.25),
		"fanfare": _tone([523.0, 659.0, 784.0, 1047.0], 0.12, 0.3),
		"coin": _tone([988.0, 1319.0], 0.07, 0.25),
	}
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String) -> void:
	if not _streams.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.play()
			return


## Notes played one after another, each with a quick attack and a soft decay.
func _tone(freqs: Array, note_len: float, volume: float) -> AudioStreamWAV:
	var n := int(RATE * note_len)
	var data := PackedByteArray()
	data.resize(n * freqs.size() * 2)
	var off := 0
	for f in freqs:
		for i in n:
			var t := float(i) / RATE
			var env := minf(1.0, i / (RATE * 0.005)) * pow(1.0 - float(i) / n, 1.5)
			var v := (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * volume
			data.encode_s16(off, int(clampf(v, -1.0, 1.0) * 32767.0))
			off += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
