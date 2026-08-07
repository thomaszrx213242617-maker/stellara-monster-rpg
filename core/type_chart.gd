class_name TypeChart
extends RefCounted

## 属性克制表封装。从 data/type_chart.json 加载。
## 原创 12 属性: 炎/水/木/雷/岩/风/光/暗/械/灵/金/冰

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

## 战斗 HUD 招式列表用的「四档」分类。实测倍率仅 0 / 0.5 / 1 / 2 四档,
## 分别与用户要求的四档一一对应(从高到低):
##   效果绝佳 (>=2x) > 有效果 (==1x, 正常生效) > 效果一般 (0<x<1, 被抵抗) > 没有效果 (==0x)
func tier_label(mult: float) -> String:
	if mult >= 2.0:
		return "效果绝佳"
	if mult > 1.0:   # 兼容未来可能出现的 1.5 倍
		return "效果绝佳"
	if mult == 1.0:
		return "有效果"
	if mult > 0.0:
		return "效果一般"
	return "没有效果"

## 四档对应的文字颜色(浅色背景下可读)
func tier_color(mult: float) -> String:
	if mult >= 2.0:
		return "#0a8a1a"   # 鲜绿: 效果绝佳
	if mult > 1.0:
		return "#0a8a1a"
	if mult == 1.0:
		return "#1b1b1b"   # 近黑: 正常生效
	if mult > 0.0:
		return "#b06a00"   # 琥珀: 被抵抗
	return "#8a8a8a"       # 灰: 没有效果

## 四档颜色(Color 对象, 便于直接赋给 Label 的 font_color)
func tier_color_value(mult: float) -> Color:
	return Color(tier_color(mult))
