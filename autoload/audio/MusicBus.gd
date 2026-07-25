extends Node

## 背景音乐自动加载(原创, 程序化合成, 规避任天堂/宝可梦版权)。
## 用 AudioStreamGenerator 实时合成「旋律 + 低音」简单循环, 按场景切换曲目。
## 若 res://audio/<track>.ogg|.mp3|.wav 存在则优先播放该真实文件(你以后可放入自己的音乐替换)。
## 对外 API: play_track(name) / stop() / set_music_enabled(bool) / set_music_volume(0..1)。
## headless(无音频设备)下安全: 不报错, 仅不发声。

const BUS_NAME := "Music"

var player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback = null          # AudioStreamGeneratorPlayback
var mode := "procedural"     # "procedural" | "file"
var current_track := ""
var is_playing := false

# 曲目定义: bpm / wave(0正弦 1方波 2三角 3锯齿) / gain / 旋律 / 低音
# 音高用 MIDI 编号(60=C4, 0=休止), 时长用拍数。
var _tracks: Dictionary = {
	"title": {
		"bpm": 100, "wave": 2, "gain": 0.30,
		"melody": [[72,1],[76,1],[79,1],[76,1],[69,1],[72,1],[76,1],[72,1],[74,2],[72,2]],
		"bass":   [[48,4],[45,4],[41,4],[43,4]],
	},
	"overworld": {
		"bpm": 122, "wave": 1, "gain": 0.26,
		"melody": [[72,1],[74,1],[76,1],[72,1],[77,1],[76,1],[74,1],[72,1],[79,2],[76,2]],
		"bass":   [[48,4],[55,4],[53,4],[48,4]],
	},
	"battle": {
		"bpm": 152, "wave": 3, "gain": 0.30,
		"melody": [[69,1],[72,1],[76,1],[72,1],[74,1],[77,1],[81,1],[77,1],[76,2],[72,2]],
		"bass":   [[45,4],[45,4],[41,4],[43,4]],
	},
	"raid": {
		"bpm": 144, "wave": 1, "gain": 0.30,
		"melody": [[76,1],[79,1],[83,1],[79,1],[81,1],[84,1],[88,1],[84,1],[83,2],[79,2]],
		"bass":   [[52,4],[52,4],[47,4],[48,4]],
	},
	"finale": {
		"bpm": 130, "wave": 3, "gain": 0.32,
		"melody": [[69,1],[72,1],[76,2],[74,1],[77,1],[81,2],[79,1],[76,1],[72,2],[67,2]],
		"bass":   [[45,4],[43,4],[41,4],[43,4]],
	},
	"ending": {
		"bpm": 92, "wave": 2, "gain": 0.30,
		"melody": [[72,2],[76,2],[79,2],[76,1],[72,1],[69,2],[67,2],[69,2]],
		"bass":   [[48,4],[43,4],[45,4],[41,4]],
	},
}

var _mix_rate: float = 44100.0
var _melody := Voice.new()
var _bass := Voice.new()

func _ready() -> void:
	_ensure_bus()
	_mix_rate = float(AudioServer.get_mix_rate())
	generator = AudioStreamGenerator.new()
	generator.mix_rate = int(_mix_rate)
	player = AudioStreamPlayer.new()
	player.stream = generator
	player.bus = BUS_NAME
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	_apply_volume()
	_apply_track("title")
	is_playing = true

func _ensure_bus() -> void:
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == BUS_NAME:
			return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)

## ---------- 对外 API ----------

func play_track(name: String) -> void:
	if name == current_track and is_playing:
		return
	current_track = name
	var path := _find_file(name)
	if path != "":
		_play_file(path)
	else:
		_apply_track(name)

func stop() -> void:
	is_playing = false
	current_track = ""
	if player != null and player.playing:
		player.stop()

func set_music_enabled(on: bool) -> void:
	if "music_on" in GameState:
		GameState.music_on = on
	_apply_volume()

func set_music_volume(v: float) -> void:
	v = clamp(v, 0.0, 1.0)
	if "music_volume" in GameState:
		GameState.music_volume = v
	_apply_volume()

## ---------- 内部 ----------

func _apply_track(name: String) -> void:
	mode = "procedural"
	var t: Dictionary = _tracks.get(name, _tracks["title"])
	var bpm: float = float(t.get("bpm", 120))
	var wave: int = int(t.get("wave", 0))
	var gain: float = float(t.get("gain", 0.3))
	_melody.set_seq(t.get("melody", []), bpm, _mix_rate, wave, gain)
	_bass.set_seq(t.get("bass", []), bpm, _mix_rate, 0, gain * 0.6)
	if player.stream != generator:
		player.stream = generator
		player.play()
		playback = player.get_stream_playback()
	elif not player.playing:
		player.play()
		playback = player.get_stream_playback()
	is_playing = true

func _find_file(name: String) -> String:
	for ext in ["ogg", "mp3", "wav"]:
		var p: String = "res://audio/" + name + "." + ext
		if FileAccess.file_exists(p):
			return p
	return ""

func _play_file(path: String) -> void:
	var res = load(path)
	if res == null or not (res is AudioStream):
		_apply_track(current_track)
		return
	mode = "file"
	player.stream = res
	player.play()
	playback = null
	is_playing = true

func _apply_volume() -> void:
	if player == null:
		return
	var on := true
	var vol := 0.6
	if "music_on" in GameState:
		on = GameState.music_on
	if "music_volume" in GameState:
		vol = GameState.music_volume
	player.volume_db = (linear_to_db(max(vol, 0.0001)) if on else -80.0)

func _process(_delta: float) -> void:
	if not is_playing or mode != "procedural":
		return
	if playback == null:
		playback = player.get_stream_playback()
		if playback == null:
			return
	var frames: int = playback.get_frames_available()
	if frames <= 0:
		return
	frames = min(frames, 4096)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var s := _melody.sample() + _bass.sample()
		s = clamp(s, -0.95, 0.95)
		buf[i] = Vector2(s, s)
	playback.push_buffer(buf)

## 单声部合成器: 维护自身音符序列与振荡相位。
class Voice:
	var seq: Array = []
	var idx: int = 0
	var pos: float = 0.0
	var dur: float = 0.0
	var phase: float = 0.0
	var wave: int = 0
	var gain: float = 0.2
	var spb: float = 0.5
	var mix_rate: float = 44100.0

	func set_seq(s: Array, bpm: float, mix: float, w: int, g: float) -> void:
		seq = s
		wave = w
		gain = g
		spb = 60.0 / bpm
		mix_rate = mix
		idx = 0
		pos = 0.0
		phase = 0.0
		_recompute_dur()

	func _recompute_dur() -> void:
		var beats: float = 1.0
		if idx < seq.size() and seq[idx].size() >= 2:
			beats = float(seq[idx][1])
		dur = max(1.0, beats * spb * mix_rate)

	func advance() -> void:
		if seq.is_empty():
			return
		idx = (idx + 1) % seq.size()
		pos = 0.0
		phase = 0.0
		_recompute_dur()

	func sample() -> float:
		if seq.is_empty():
			return 0.0
		var note: Array = seq[idx]
		var midi: int = int(note[0]) if note.size() >= 1 else 0
		var val := 0.0
		if midi > 0:
			var freq: float = 440.0 * pow(2.0, (midi - 69) / 12.0)
			phase = fmod(phase + freq / mix_rate, 1.0)
			val = _wave_val(phase, wave)
			var att: float = min(pos, mix_rate * 0.012) / (mix_rate * 0.012)
			var rel: float = min(dur - pos, mix_rate * 0.04) / (mix_rate * 0.04)
			val *= clamp(min(att, rel), 0.0, 1.0) * gain
		pos += 1.0
		if pos >= dur:
			advance()
		return val

	func _wave_val(ph: float, w: int) -> float:
		match w:
			0: return sin(ph * TAU)
			1: return -1.0 if sin(ph * TAU) < 0.0 else 1.0
			2: return 2.0 * abs(2.0 * ph - 1.0) - 1.0
			3: return 2.0 * ph - 1.0
			_: return sin(ph * TAU)
