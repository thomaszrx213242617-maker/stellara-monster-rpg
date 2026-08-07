class_name Growth
extends RefCounted

## 数值层: 经验/等级曲线(God-agnostic, 纯数据计算)。
## 经验模型: 从 L 级升到 L+1 所需边际经验 = base * L^2 (中速曲线, 与 GameState.exp_needed 一致)。
## 个体存储采用「累计经验」(cumulative), 升级时与阈值比较。

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

## 升级到「下一级」所需的边际经验: 当前 level -> level+1
static func exp_cost(level: int) -> int:
	_ensure()
	var exp: Dictionary = _cfg.get("exp", {})
	var base: float = float(exp.get("base", 1))
	return int(base * float(level) * float(level))

## 达到某等级所需的「累计经验」(level=1 时为 0)
static func cumulative(level: int) -> int:
	var total := 0
	for l in range(1, max(1, level)):
		total += exp_cost(l)
	return total

## 给定累计经验, 返回当前等级
static func level_from_exp(exp: int) -> int:
	var lv := 1
	while lv < level_cap() and cumulative(lv + 1) <= exp:
		lv += 1
	return lv

## 距下一级还差多少经验
static func exp_to_next(level: int, current_total_exp: int) -> int:
	return cumulative(level + 1) - current_total_exp

## 击败一只灵兽获得的经验(野生公式: floor(level*per_level)+flat)
static func exp_from_battle(defeated_level: int, defeated_base_hp: int = 0, participants: int = 1) -> int:
	_ensure()
	var we: Dictionary = _cfg.get("wild_exp", {})
	var per: float = float(we.get("per_level", 8))
	var flat: float = float(we.get("flat", 8))
	return int(floor(float(defeated_level) * per) + flat)

static func level_cap() -> int:
	_ensure()
	return int(_cfg.get("level_cap", 100))
