extends Node
class_name DataBus

## 全局数据总线 (autoload)。负责加载 data/*.json 并对外提供查询。
## 同时提供静态 load_json 供其他脚本使用。

const TYPE_CHART_PATH := "res://data/type_chart.json"
const CREATURES_PATH := "res://data/creatures.json"
const MOVES_PATH := "res://data/moves.json"
const ITEMS_PATH := "res://data/items.json"

const TypeChartScript := preload("res://core/type_chart.gd")
const CombatScript := preload("res://core/combat.gd")
const TypeRegistryScript := preload("res://core/type_registry.gd")

var type_chart: Variant
var _type_registry: TypeRegistry
var creatures: Dictionary = {}   # id -> 数据字典
var moves: Dictionary = {}        # id -> 数据字典
var items: Dictionary = {}        # id -> 数据字典

func _ready() -> void:
	type_chart = TypeChartScript.new()
	_type_registry = TypeRegistryScript.new()
	_load_data()

## 静态 JSON 加载器 (供任意脚本调用, 无需实例)
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data: 找不到数据文件 " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)

func _load_data() -> void:
	var cd: Dictionary = load_json(CREATURES_PATH)
	if cd:
		for c in cd["creatures"]:
			creatures[c["id"]] = c
	var md: Dictionary = load_json(MOVES_PATH)
	if md:
		for m in md["moves"]:
			moves[m["id"]] = m
	var itd: Dictionary = load_json(ITEMS_PATH)
	if itd:
		for it in itd["items"]:
			items[it["id"]] = it

func get_creature(id: String) -> Dictionary:
	return creatures.get(id, {})

func get_move(id: String) -> Dictionary:
	return moves.get(id, {})

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

## 属性对应的主题色(数据驱动, 委托 TypeRegistry 单一来源), 供 UI/Combatant 复用
func type_color(type: String) -> Color:
	return _type_registry.color(type)

## 全部属性(按展示顺序)
func all_types() -> Array:
	return _type_registry.all_types()

## 属性说明文字(图鉴/教学用)
func type_description(type: String) -> String:
	return _type_registry.description(type)

## 由灵兽名反查 id(用于进化演出按名定位数据)
func creature_id_by_name(name: String) -> String:
	for cid in creatures.keys():
		if creatures[cid].get("name", "") == name:
			return cid
	return ""

## 攻击属性对防御属性的克制倍率
func multiplier(atk_type: String, def_type: String) -> float:
	return type_chart.multiplier(atk_type, def_type)

## 由种族值字典 + 等级计算实际属性 (实时战斗中即移动/攻防)
func compute_stats(creature_data: Dictionary, level: int) -> Dictionary:
	var b: Dictionary = creature_data["base"]
	var s: Dictionary = {}
	s["max_hp"] = CombatScript.stat_at_level(int(b["hp"]), level, true)
	for k in ["atk", "def", "spatk", "spdef", "spd"]:
		s[k] = CombatScript.stat_at_level(int(b[k]), level, false)
	return s

## ===================== 数据层门面(数值/收服/养成) =====================
## 经验/等级数值曲线 —— 委托 Growth(数据驱动, 与 GameState.exp_needed 同源)
func exp_cost(level: int) -> int:
	return Growth.exp_cost(level)

## 达到某等级所需的「累计经验」(level=1 时为 0)
func exp_total(level: int) -> int:
	return Growth.cumulative(level)

## 给定累计经验, 返回当前等级
func level_from_exp(exp: int) -> int:
	return Growth.level_from_exp(exp)

## 距下一级还差多少经验
func exp_to_next(level: int, current_total_exp: int) -> int:
	return Growth.exp_to_next(level, current_total_exp)

## 击败灵兽获得的经验(野生公式)
func exp_from_battle(defeated_level: int, defeated_base_hp: int = 0, participants: int = 1) -> int:
	return Growth.exp_from_battle(defeated_level, defeated_base_hp, participants)

func level_cap() -> int:
	return Growth.level_cap()

## 收服流水线 —— 委托 Capture(数据驱动单一来源, 与 Combat.capture_chance 公式一致且增加状态修正)
func capture_chance(creature_data: Dictionary, current_hp: float, max_hp: float, ball_id: String, status_name: String) -> float:
	return Capture.chance(creature_data, current_hp, max_hp, ball_id, status_name)

func capture_chance_by_id(id: String, current_hp: float, max_hp: float, ball_id: String, status_name: String) -> float:
	return Capture.chance_by_id(id, current_hp, max_hp, ball_id, status_name)

## 灵兽个体(养成): 创建一只指定物种/等级的满血个体
func make_instance(species_id: String, level: int, nickname: String = "") -> CreatureInstance:
	return CreatureInstance.create(species_id, level, nickname)
