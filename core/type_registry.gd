class_name TypeRegistry
extends RefCounted

## 属性注册表(数据驱动): 从 data/types.json 加载 12 属性的颜色与描述。
## 作为「属性/数值」数据层的单一来源, 取代 DataBus.type_color 与 Combatant._apply_color 中各自的硬编码副本。

var _order: Array = []
var _data: Dictionary = {}

func _init() -> void:
	var text := FileAccess.get_file_as_string("res://data/types.json")
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	var d: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_order = d.get("order", [])
	_data = d.get("data", {})

## 全部属性(按展示顺序)
func all_types() -> Array:
	return _order.duplicate()

func count() -> int:
	return _order.size()

func exists(type: String) -> bool:
	return _data.has(type)

## 属性主题色(与既有视觉一致); 未知属性返回中性灰
func color(type: String) -> Color:
	var entry: Dictionary = _data.get(type, {})
	var c: Array = entry.get("color", [0.8, 0.8, 0.8])
	return Color(float(c[0]), float(c[1]), float(c[2]))

## 属性说明文字(图鉴/教学用)
func description(type: String) -> String:
	var entry: Dictionary = _data.get(type, {})
	return entry.get("desc", "")
