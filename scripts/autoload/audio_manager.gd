extends Node

## Autoload de Audio Procedural (Godot 4):
## - Música ambiental fantástica pentatónica sintetizada en tiempo real (AudioStreamGenerator).
## - Efectos de sonido SFX (AudioStreamWAV 16-bit cacheados) para UI, oro, ataques, críticos y victoria.
## - Botón de silencio global (AudioServer bus Master).

signal mute_changed(muted: bool)

const MIX_RATE: float = 22050.0
const PENTATONIC_HZ: Array[float] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]
const MELODY_PATTERN: Array[int] = [0, 2, 4, 5, 4, 2, 3, 1, 0, 3, 5, 7, 5, 4, 2, 1]

var is_muted: bool = false

var _music_player: AudioStreamPlayer = null
var _music_playback: AudioStreamGeneratorPlayback = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}

var _phase_main: float = 0.0
var _phase_pad: float = 0.0
var _note_timer: float = 0.0
var _note_idx: int = 0
var _note_dur: float = 0.72
var _cur_freq: float = 261.63
var _pad_freq: float = 130.81


func _ready() -> void:
	_setup_sfx_pool()
	_setup_ambient_music()


func _exit_tree() -> void:
	set_process(false)
	_music_playback = null
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
		_music_player = null
	for p: AudioStreamPlayer in _sfx_players:
		if p != null:
			p.stop()
			p.stream = null
	_sfx_players.clear()
	_sfx_cache.clear()


func _setup_sfx_pool() -> void:
	for _i: int in range(4):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)

	_sfx_cache["click"] = _make_tone_wav([680.0, 880.0], 0.055, 0.28)
	_sfx_cache["coin"] = _make_tone_wav([987.77, 1318.51], 0.14, 0.32)
	_sfx_cache["attack"] = _make_sweep_wav(280.0, 85.0, 0.16, 0.40)
	_sfx_cache["crit"] = _make_tone_wav([523.25, 783.99, 1046.50], 0.22, 0.36)
	_sfx_cache["level_up"] = _make_tone_wav([392.0, 493.88, 587.33, 783.99], 0.34, 0.34)
	_sfx_cache["victory"] = _make_tone_wav([523.25, 659.25, 783.99, 1046.50], 0.48, 0.36)
	_sfx_cache["defeat"] = _make_tone_wav([392.0, 349.23, 311.13, 261.63], 0.42, 0.30)
	_sfx_cache["hatch"] = _make_tone_wav([587.33, 739.99, 880.0, 1174.66], 0.36, 0.32)


func _setup_ambient_music() -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.25

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = gen
	_music_player.volume_db = -16.0
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _music_playback == null or is_muted:
		return
	var frames: int = _music_playback.get_frames_available()
	if frames <= 0:
		return

	var dt: float = 1.0 / MIX_RATE
	for _i: int in range(frames):
		_note_timer += dt
		if _note_timer >= _note_dur:
			_note_timer -= _note_dur
			_note_idx = (_note_idx + 1) % MELODY_PATTERN.size()
			_cur_freq = PENTATONIC_HZ[MELODY_PATTERN[_note_idx]]
			_pad_freq = 130.81 if (_note_idx < 8) else 146.83

		var env_t: float = _note_timer / _note_dur
		var env: float = minf(1.0, env_t * 14.0) * pow(maxf(0.0, 1.0 - env_t), 1.6)

		_phase_main = fmod(_phase_main + _cur_freq * dt, 1.0)
		_phase_pad = fmod(_phase_pad + _pad_freq * dt, 1.0)

		var harp: float = (sin(_phase_main * TAU) * 0.72 + sin(_phase_main * TAU * 2.0) * 0.22) * env * 0.28
		var pad: float = sin(_phase_pad * TAU) * 0.14
		var sample: float = clampf(harp + pad, -0.8, 0.8)
		_music_playback.push_frame(Vector2(sample, sample))


func toggle_mute() -> bool:
	set_muted(not is_muted)
	return is_muted


func set_muted(muted: bool) -> void:
	is_muted = muted
	AudioServer.set_bus_mute(0, is_muted)
	mute_changed.emit(is_muted)


func play_sfx(kind: String) -> void:
	if is_muted or not _sfx_cache.has(kind):
		return
	var stream: AudioStreamWAV = _sfx_cache[kind] as AudioStreamWAV
	if stream == null:
		return
	for p: AudioStreamPlayer in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func _make_tone_wav(freqs: Array[float], total_dur: float, amp: float) -> AudioStreamWAV:
	var total_samples: int = maxi(64, int(total_dur * MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)
	var step_samples: int = maxi(1, total_samples / maxi(1, freqs.size()))

	for i: int in range(total_samples):
		var note_i: int = mini(freqs.size() - 1, i / step_samples)
		var local_t: float = float(i % step_samples) / float(step_samples)
		var freq: float = freqs[note_i]
		var env: float = minf(1.0, local_t * 18.0) * (1.0 - local_t * 0.85)
		var t: float = float(i) / MIX_RATE
		var val: float = sin(t * freq * TAU) * env * amp
		var s16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav


func _make_sweep_wav(start_hz: float, end_hz: float, total_dur: float, amp: float) -> AudioStreamWAV:
	var total_samples: int = maxi(64, int(total_dur * MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)
	var phase: float = 0.0

	for i: int in range(total_samples):
		var ratio: float = float(i) / float(total_samples)
		var freq: float = lerpf(start_hz, end_hz, ratio)
		phase += freq / MIX_RATE
		var env: float = (1.0 - ratio) * minf(1.0, ratio * 22.0)
		var val: float = sin(phase * TAU) * env * amp
		var s16: int = clampi(int(val * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav
