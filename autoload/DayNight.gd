extends Node

## 全局昼夜循环 (autoload)。驱动光照变化并在夜晚强制禁用"对战收集点数/收服"。

signal phase_changed(is_night: bool)
signal time_changed(time: float)

var day_length: float = 480.0      # 一天时长(秒), 可配置
var time: float = 60.0             # 当前时间(0..day_length)
var is_night: bool = false

func _process(delta: float) -> void:
	time = fmod(time + delta, day_length)
	var night: bool = time > day_length * 0.75 or time < day_length * 0.05
	if night != is_night:
		is_night = night
		phase_changed.emit(is_night)
	time_changed.emit(time)

## 硬性规则: 夜间不可进行"对战收集点数 / 收服"
func can_battle_collect_points() -> bool:
	return not is_night

func phase_label() -> String:
	return "夜晚" if is_night else "白天"

## 0..1 的昼夜进度, 供 WorldEnvironment 调光照
func day_fraction() -> float:
	return time / day_length
