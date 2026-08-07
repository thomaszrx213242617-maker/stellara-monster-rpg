class_name Capture
extends RefCounted

## 收服(养成)数据层: 收服成功率流水线 + 判定。
## 公式(与 Combat.capture_chance 一致, 但改为从数据聚合, 单一来源):
##   chance = clamp( catch_rate * ball_mod * status_mod * (hp_base + (1 - hp_ratio*0.8)*hp_weight), min, max )

const BALANCE_PATH := "res://data/balance.json"

static var _cfg: Dictionary = {}
static var _loaded: bool = false

static func _ensure() -> void:
	if _loaded:
		return
	var text := FileAccess.get_file_as_string(BALANCE_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_loaded = true

## 计算收服成功率
##   creature_data: Data.get_creature(id)
##   current_hp / max_hp: 当前/最大血量
##   ball_id: 球道具 id(读 items.json 的 catch_mod)
##   status_name: 当前异常状态(睡眠/冰冻/麻痹/中毒/灼烧/空)
static func chance(creature_data: Dictionary, current_hp: float, max_hp: float, ball_id: String, status_name: String) -> float:
	_ensure()
	if creature_data.is_empty():
		return 0.0
	var cap: Dictionary = _cfg.get("capture", {})
	var hp_base: float = float(cap.get("hp_base", 0.4))
	var hp_weight: float = float(cap.get("hp_weight", 1.0))
	var lo: float = float(cap.get("min", 0.01))
	var hi: float = float(cap.get("max", 0.99))
	var status_mods: Dictionary = cap.get("status_mods", {})
	var ball: Dictionary = Data.get_item(ball_id)
	var ball_mod: float = float(ball.get("catch_mod", 1.0)) if not ball.is_empty() else 1.0
	var status_mod: float = float(status_mods.get(status_name, 1.0))
	var hp_ratio: float = current_hp / max(max_hp, 1.0)
	var hp_factor: float = 1.0 - hp_ratio * 0.8
	var base_rate: float = float(creature_data.get("catch_rate", 0.1))
	return clamp(base_rate * ball_mod * status_mod * (hp_base + hp_factor * hp_weight), lo, hi)

## 由物种 id 直接计算(便捷)
static func chance_by_id(id: String, current_hp: float, max_hp: float, ball_id: String, status_name: String) -> float:
	return chance(Data.get_creature(id), current_hp, max_hp, ball_id, status_name)

## 判定: rng 为 [0,1) 随机; 命中(小于 chance)即成功
static func roll(chance_value: float, rng: float) -> bool:
	return rng < chance_value

## 一次性尝试(便捷)
static func attempt(creature_data: Dictionary, current_hp: float, max_hp: float, ball_id: String, status_name: String, rng: float) -> bool:
	return roll(chance(creature_data, current_hp, max_hp, ball_id, status_name), rng)
