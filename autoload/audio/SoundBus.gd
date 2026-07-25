extends Node

## 音效自动加载(原创, 程序化合成, 规避任天堂/宝可梦版权)。
## 与 MusicBus 互补: 这里是一发即止的「音效」(攻击/命中/收服/治疗/升级/濒死/菜单...),
## 用一次性 AudioStreamWAV 合成 + 4 路播放池(简单复音), 不占用 BGM 的连续 push 循环。
## 对外 API: play_sfx(name) / set_sfx_enabled(bool) / set_sfx_volume(0..1)。
## 全部音高/波形为程序生成, 无任何外部版权素材。headless(无音频设备)下安全: 仅不发声。

const BUS_NAME := "SFX"
const POOL := 4

var _players: Array = []
var _wav_cache: Dictionary = {}
var _mix_rate: float = 44100.0

## 音效定义: 每个 = 一段或多段 [起始频率Hz, 结束频率Hz, 时长秒, 波形(0正弦1方波2三角3锯齿), 增益, 噪声增益(可选)]
## 频率 0 表示该段为纯噪声(打击感)。
var _sounds: Dictionary = {
	"select":          [[880, 880, 0.05, 1, 0.45]],
	"attack":          [[660, 220, 0.12, 3, 0.50, 0.18]],
	"hit":             [[0, 0, 0.09, 1, 0.0, 0.65]],
	"capture":         [[523, 523, 0.06, 1, 0.50], [659, 659, 0.06, 1, 0.50], [784, 784, 0.11, 1, 0.55]],
	"capture_success": [[523, 523, 0.12, 2, 0.45], [659, 659, 0.12, 2, 0.45], [784, 784, 0.32, 2, 0.55]],
	"heal":            [[440, 880, 0.30, 0, 0.50]],
	"levelup":         [[523, 523, 0.05, 1, 0.50], [659, 659, 0.05, 1, 0.50], [784, 784, 0.05, 1, 0.50], [1047, 1047, 0.20, 1, 0.55]],
	"faint":           [[440, 110, 0.40, 3, 0.50]],
	"error":           [[120, 120, 0.15, 1, 0.50]],
	"evolve":          [[330, 1320, 0.55, 2, 0.45]],
}

func _ready() -> void:
	_ensure_bus()
	_mix_rate = float(AudioServer.get_mix_rate())
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAME
		add_child(p)
		_players.append(p)
	_build_all()

func _ensure_bus() -> void:
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == BUS_NAME:
			return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)

## ---------- 对外 API ----------

func play_sfx(name: String) -> void:
	if not GameState.sfx_on:
		return
	var wav: AudioStreamWAV = _get_wav(name)
	if wav == null:
		return
	var p: AudioStreamPlayer = _free_player()
	p.stream = wav
	p.volume_db = linear_to_db(max(GameState.sfx_volume, 0.0001))
	p.play()

func set_sfx_enabled(on: bool) -> void:
	if "sfx_on" in GameState:
		GameState.sfx_on = on

func set_sfx_volume(v: float) -> void:
	v = clamp(v, 0.0, 1.0)
	if "sfx_volume" in GameState:
		GameState.sfx_volume = v

## ---------- 内部 ----------

func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _build_all() -> void:
	for name in _sounds.keys():
		_get_wav(name)

func _get_wav(name: String) -> AudioStreamWAV:
	if _wav_cache.has(name):
		return _wav_cache[name]
	var segs: Array = _sounds.get(name, [])
	if segs.is_empty():
		return null
	var w := _render(segs)
	_wav_cache[name] = w
	return w

func _render(segments: Array) -> AudioStreamWAV:
	var sr := int(_mix_rate)
	var total := 0.0
	for seg in segments:
		total += float(seg[2])
	var n := int(total * sr)
	if n <= 0:
		n = 1
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var idx := 0
	for seg in segments:
		var f0 := float(seg[0])
		var f1 := float(seg[1])
		var dur: float = max(float(seg[2]), 0.001)
		var wave := int(seg[3])
		var gain := float(seg[4])
		var noise_g := 0.0
		if seg.size() >= 6:
			noise_g = float(seg[5])
		var ns := int(dur * sr)
		if ns <= 0:
			ns = 1
		var ph := 0.0
		for i in ns:
			var lt := float(i) / float(ns - 1)
			var freq := lerpf(f0, f1, lt)
			ph = fmod(ph + freq / sr, 1.0)
			var v := _wave(ph, wave) * gain
			var att: float = min(float(i) / sr / 0.005, 1.0)
			var rel: float = min((dur - float(i) / sr) / 0.02, 1.0)
			var env: float = clamp(min(att, rel), 0.0, 1.0)
			v *= env
			if noise_g > 0.0:
				v += (randf() * 2.0 - 1.0) * noise_g * env
			v = clamp(v, -1.0, 1.0)
			var s16 := int(v * 32767.0)
			pcm[idx] = s16 & 0xFF
			pcm[idx + 1] = (s16 >> 8) & 0xFF
			idx += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = pcm
	return wav

static func _wave(ph: float, w: int) -> float:
	match w:
		0: return sin(ph * TAU)
		1: return -1.0 if sin(ph * TAU) < 0.0 else 1.0
		2: return 2.0 * abs(2.0 * ph - 1.0) - 1.0
		3: return 2.0 * ph - 1.0
		_: return sin(ph * TAU)
