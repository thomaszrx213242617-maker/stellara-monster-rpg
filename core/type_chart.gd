class_name TypeChart
extends RefCounted

## 属性克制表封装。从 data/type_chart.json 加载。
## 原创 10 属性: 炎/水/木/雷/岩/风/光/暗/械/灵

var _types: Array = []
var _chart: Dictionary = {}

func _init() -> void:
	var text := FileAccess.get_file_as_string("res://data/type_chart.json")
	var data: Dictionary = JSON.parse_string(text) if text != "" else {}
	if data:
		_types = data.get("types", [])
		_chart = data.get("chart", {})

## 攻击属性 atk_type 对 防御属性 def_type 的倍率 (默认 1.0)
func multiplier(atk_type: String, def_type: String) -> float:
	if _chart.has(atk_type) and _chart[atk_type].has(def_type):
		return float(_chart[atk_type][def_type])
	return 1.0

## 给 UI 使用的文字提示
func effectiveness_text(mult: float) -> String:
	if mult >= 2.0:
		return "效果拔群!"
	if mult <= 0.5:
		return "效果不太理想..."
	return ""
