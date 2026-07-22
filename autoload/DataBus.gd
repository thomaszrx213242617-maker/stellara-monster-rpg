extends Node
class_name DataBus

## 全局数据总线 (autoload)。负责加载 data/*.json 并对外提供查询。
## 同时提供静态 load_json 供其他脚本使用。

const TYPE_CHART_PATH := "res://data/type_chart.json"
const CREATURES_PATH := "res://data/creatures.json"
const MOVES_PATH := "res://data/moves.json"
const ITEMS_PATH := "res://data/items.json"

var type_chart: TypeChart
var creatures: Dictionary = {}   # id -> 数据字典
var moves: Dictionary = {}        # id -> 数据字典
var items: Dictionary = {}        # id -> 数据字典

func _ready() -> void:
    type_chart = TypeChart.new()
    _load_data()

## 静态 JSON 加载器 (供任意脚本调用, 无需实例)
static func load_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("DataBus: 找不到数据文件 " + path)
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

## 攻击属性对防御属性的克制倍率
func multiplier(atk_type: String, def_type: String) -> float:
    return type_chart.multiplier(atk_type, def_type)

## 由种族值字典 + 等级计算实际属性 (实时战斗中即移动/攻防)
func compute_stats(creature_data: Dictionary, level: int) -> Dictionary:
    var b: Dictionary = creature_data["base"]
    var s: Dictionary = {}
    s["max_hp"] = Combat.stat_at_level(int(b["hp"]), level, true)
    for k in ["atk", "def", "spatk", "spdef", "spd"]:
        s[k] = Combat.stat_at_level(int(b[k]), level, false)
    return s
