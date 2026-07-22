extends Node

## 存档管理 (autoload)。保存到 user://save.json。覆盖队伍/存储/背包/徽章/图鉴/时间。

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	load_game()

func save_game() -> void:
	var data := {
		"team": GameState.team,
		"storage": GameState.storage,
		"inventory": GameState.inventory,
		"badges": GameState.badges,
		"caught_count": GameState.caught_count,
		"time": DayNight.time
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		print("SaveManager: 已保存")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return false
	if data.has("team"):
		GameState.team = data["team"]
	if data.has("storage"):
		GameState.storage = data["storage"]
	if data.has("inventory"):
		GameState.inventory = data["inventory"]
	if data.has("badges"):
		GameState.badges = data["badges"]
	if data.has("caught_count"):
		GameState.caught_count = int(data["caught_count"])
	if data.has("time"):
		DayNight.time = float(data["time"])
	print("SaveManager: 已读取存档")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
