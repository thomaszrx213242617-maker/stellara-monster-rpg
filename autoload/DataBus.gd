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

var type_chart: Variant
var creatures: Dictionary = {}   # id -> 数据字典
var moves: Dictionary = {}        # id -> 数据字典
var items: Dictionary = {}        # id -> 数据字典

func _ready() -> void:
	type_chart = TypeChartScript.new()
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

## 属性对应的主题色(与 Combatant._apply_color 保持一致), 供 UI(御三家/进化演出)复用
func type_color(type: String) -> Color:
	var colors := {
		"炎": Color(0.9, 0.3, 0.2), "水": Color(0.2, 0.4, 0.9), "木": Color(0.3, 0.7, 0.3),
		"雷": Color(0.9, 0.9, 0.2), "岩": Color(0.6, 0.5, 0.4), "风": Color(0.7, 0.9, 0.8),
		"光": Color(1.0, 0.95, 0.6), "暗": Color(0.3, 0.2, 0.4), "械": Color(0.7, 0.7, 0.75),
		"灵": Color(0.8, 0.6, 0.9), "金": Color(0.72, 0.75, 0.82), "冰": Color(0.6, 0.85, 0.95)
	}
	return colors.get(type, Color(0.8, 0.8, 0.8))

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
