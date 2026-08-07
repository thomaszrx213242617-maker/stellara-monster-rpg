extends Node
class_name DayNight

## 全局昼夜循环 (autoload, 键名 Clock)。
## 驱动光照/天空/雾变化; 并在夜晚强制「黯潮」规则: 禁收服 + 野生灵兽概率狂暴化(攻防/血提升且不可收服)。
## 相位边界、光照预设、夜间规则全部来自 data/daynight.json (单一来源)。

signal phase_changed(is_night: bool)
signal phase_shifted(phase: int)
signal time_changed(time: float)

enum Phase { DAWN, DAY, DUSK, NIGHT }
const PHASE_KEYS := ["dawn", "day", "dusk", "night"]
const PHASE_LABELS := ["黎明", "白昼", "黄昏", "夜晚"]

var day_length: float = 480.0
var time: float = 60.0            ## 当前时间(0..day_length)

## 当前是否夜晚(属性 getter, 直接读 time 推导, 测试直设 time 也即时生效)
var is_night: bool:
	get:
		return phase() == Phase.NIGHT

var _cfg: Dictionary = {}
var _phases: Dictionary = {}
var _night_rules: Dictionary = {}
var _lit: Dictionary = {}        ## phase key -> {sky:Color, light:float, fog:Color, fog_density:float}
var _last_phase: int = -1

func _ready() -> void:
	_load_cfg()
	_last_phase = phase()

# ---------------------------------------------------------------------------
# 配置加载
# ---------------------------------------------------------------------------
func _load_cfg() -> void:
	var path := "res://data/daynight.json"
	if not FileAccess.file_exists(path):
		_defaults()
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_defaults()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_defaults()
		return
	_cfg = parsed
	day_length = float(_cfg.get("day_length", 480.0))
	_phases = _cfg.get("phases", {})
	_night_rules = _cfg.get("night_rules", {})
	var lit_src: Dictionary = _cfg.get("lighting", {})
	for i in range(PHASE_KEYS.size()):
		var k: String = PHASE_KEYS[i]
		var raw: Variant = lit_src.get(k, {})
		var d: Dictionary = {}
		if typeof(raw) == TYPE_DICTIONARY:
			d = raw
		_lit[k] = {
			"sky": _col(d.get("sky", [0.6, 0.75, 0.95])),
			"light": float(d.get("light", 1.0)),
			"fog": _col(d.get("fog", [0.7, 0.8, 0.95])),
			"fog_density": float(d.get("fog_density", 0.01))
		}

func _defaults() -> void:
	day_length = 480.0
	_phases = {
		"dawn":  {"start": 0.00, "end": 0.08},
		"day":   {"start": 0.08, "end": 0.72},
		"dusk":  {"start": 0.72, "end": 0.80},
		"night": {"start": 0.80, "end": 1.00}
	}
	_night_rules = {
		"capture_banned": true,
		"berserk_chance": 0.6,
		"berserk_atk_mult": 1.4,
		"berserk_def_mult": 1.4,
		"berserk_hp_mult": 1.25
	}
	var def := {
		"dawn":  {"sky": [0.95, 0.78, 0.62], "light": 0.85, "fog": [0.88, 0.72, 0.60], "fog_density": 0.010},
		"day":   {"sky": [0.60, 0.75, 0.95], "light": 1.25, "fog": [0.72, 0.83, 0.95], "fog_density": 0.006},
		"dusk":  {"sky": [0.95, 0.55, 0.40], "light": 0.70, "fog": [0.82, 0.50, 0.45], "fog_density": 0.014},
		"night": {"sky": [0.05, 0.05, 0.12], "light": 0.30, "fog": [0.10, 0.08, 0.20], "fog_density": 0.022}
	}
	for i in range(PHASE_KEYS.size()):
		var k: String = PHASE_KEYS[i]
		var d: Dictionary = def[k]
		_lit[k] = {
			"sky": _col(d["sky"]), "light": float(d["light"]),
			"fog": _col(d["fog"]), "fog_density": float(d["fog_density"])
		}

func _col(arr: Variant) -> Color:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return Color(0.6, 0.75, 0.95)

# ---------------------------------------------------------------------------
# 主循环
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	time = fmod(time + delta, day_length)
	var p: int = phase()
	if p != _last_phase:
		_last_phase = p
		phase_shifted.emit(p)
		phase_changed.emit(is_night)
	time_changed.emit(time)

# ---------------------------------------------------------------------------
# 相位 / 时间查询
# ---------------------------------------------------------------------------
func phase() -> int:
	return _phase_at(time)

func _phase_at(t: float) -> int:
	var f: float = clamp(t / day_length, 0.0, 0.999999)
	for i in range(PHASE_KEYS.size()):
		var seg: Variant = _phases.get(PHASE_KEYS[i], {})
		if typeof(seg) != TYPE_DICTIONARY:
			continue
		var s := float(seg.get("start", 0.0))
		var e := float(seg.get("end", 1.0))
		if f >= s and f < e:
			return i
	return Phase.NIGHT

func phase_key() -> String:
	return PHASE_KEYS[phase()]

func phase_label() -> String:
	return PHASE_LABELS[phase()]

## 0..1 的昼夜进度
func day_fraction() -> float:
	return time / day_length

## "HH:MM" 当前时刻(按 24h 折算)
func clock_string() -> String:
	var total_min := int(day_fraction() * 24.0 * 60.0)
	var h := total_min / 60
	var m := total_min % 60
	return "%02d:%02d" % [h, m]

## 当前光照预设(在相邻相位间线性插值), 供 WorldEnvironment 平滑过渡。
## 返回 {sky:Color, light:float, fog:Color, fog_density:float}
func lighting() -> Dictionary:
	var f := day_fraction()
	var idx := phase()
	var cur_key: String = PHASE_KEYS[idx]
	var next_key: String = PHASE_KEYS[(idx + 1) % PHASE_KEYS.size()]
	var seg: Variant = _phases.get(cur_key, {})
	var s := 0.0
	var e := 1.0
	if typeof(seg) == TYPE_DICTIONARY:
		s = float(seg.get("start", 0.0))
		e = float(seg.get("end", 1.0))
	var t := 0.0
	var span := e - s
	if span > 0.001:
		t = clamp((f - s) / span, 0.0, 1.0)
	var a: Dictionary = _lit[cur_key] as Dictionary
	var b: Dictionary = _lit[next_key] as Dictionary
	return {
		"sky": (a["sky"] as Color).lerp(b["sky"] as Color, t),
		"light": lerpf(float(a["light"]), float(b["light"]), t),
		"fog": (a["fog"] as Color).lerp(b["fog"] as Color, t),
		"fog_density": lerpf(float(a["fog_density"]), float(b["fog_density"]), t)
	}

# ---------------------------------------------------------------------------
# 夜间规则
# ---------------------------------------------------------------------------
## 硬规则: 夜间禁止收服(配置 capture_banned 可关闭, 默认开启)
func is_capture_banned() -> bool:
	var banned: Variant = _night_rules.get("capture_banned", true)
	if typeof(banned) == TYPE_BOOL and not banned:
		return false
	return is_night

func can_capture() -> bool:
	return not is_capture_banned()

## 兼容既有调用 (GameState.can_collect -> 此)
func can_battle_collect_points() -> bool:
	return can_capture()

## 夜间狂暴化概率 0..1
func berserk_chance() -> float:
	return float(_night_rules.get("berserk_chance", 0.0))

## 狂暴化倍率 {atk, def, hp}
func berserk_mods() -> Dictionary:
	return {
		"atk": float(_night_rules.get("berserk_atk_mult", 1.0)),
		"def": float(_night_rules.get("berserk_def_mult", 1.0)),
		"hp": float(_night_rules.get("berserk_hp_mult", 1.0))
	}

## 给定随机种子判定本次野生遭遇是否狂暴化(非夜间恒为 false)
func roll_berserk(rng: float) -> bool:
	if not is_night:
		return false
	return rng < berserk_chance()

## 便捷版: 用全局随机数判定
func should_berserk() -> bool:
	return roll_berserk(randf())
