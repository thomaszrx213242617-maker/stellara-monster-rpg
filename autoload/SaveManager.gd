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
		"dex_seen": GameState.dex_seen,
		"dex_caught": GameState.dex_caught,
		"research": GameState.research,
		"time": DayNight.time,
		"player_name": GameState.player_name,
		"player_gender": GameState.player_gender,
		"story_stage": GameState.story_stage,
		"opening_done": GameState.opening_done,
		"prologue_done": GameState.prologue_done,
		"midboss_done": GameState.midboss_done,
		"ending_done": GameState.ending_done,
		"coins": GameState.coins,
		"player_hp": GameState.player_hp,
		"finale_stage": GameState.finale_stage,
		"current_scene": GameState.current_scene,
		"music_on": GameState.music_on,
		"music_volume": GameState.music_volume,
		"sfx_on": GameState.sfx_on,
		"sfx_volume": GameState.sfx_volume,
		"text_speed": GameState.text_speed,
		"story_log": GameState.story_log,
		"custom_music": GameState.custom_music
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
	if data.has("dex_seen"):
		GameState.dex_seen = data["dex_seen"]
	if data.has("dex_caught"):
		GameState.dex_caught = data["dex_caught"]
	if data.has("time"):
		DayNight.time = float(data["time"])
	if data.has("research"):
		GameState.research = data["research"]
	if data.has("player_name"):
		GameState.player_name = str(data["player_name"])
	if data.has("player_gender"):
		GameState.player_gender = str(data["player_gender"])
	if data.has("story_stage"):
		GameState.story_stage = int(data["story_stage"])
	if data.has("opening_done"):
		GameState.opening_done = bool(data["opening_done"])
	if data.has("midboss_done"):
		GameState.midboss_done = bool(data["midboss_done"])
	if data.has("ending_done"):
		GameState.ending_done = bool(data["ending_done"])
	if data.has("prologue_done"):
		GameState.prologue_done = bool(data["prologue_done"])
	if data.has("coins"):
		GameState.coins = int(data["coins"])
	if data.has("player_hp"):
		GameState.player_hp = int(data["player_hp"])
	if data.has("finale_stage"):
		GameState.finale_stage = int(data["finale_stage"])
	if data.has("current_scene"):
		GameState.current_scene = str(data["current_scene"])
	if data.has("music_on"):
		GameState.music_on = bool(data["music_on"])
	if data.has("music_volume"):
		GameState.music_volume = float(data["music_volume"])
	if data.has("sfx_on"):
		GameState.sfx_on = bool(data["sfx_on"])
	if data.has("sfx_volume"):
		GameState.sfx_volume = float(data["sfx_volume"])
	if data.has("text_speed"):
		GameState.text_speed = int(data["text_speed"])
	if data.has("story_log"):
		GameState.story_log = data["story_log"]
	if data.has("custom_music"):
		GameState.custom_music = str(data["custom_music"])
	print("SaveManager: 已读取存档")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 删除本地存档(用于「开始新游戏」覆盖)。
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d := DirAccess.open("user://")
		if d != null:
			d.remove("save.json")
		print("SaveManager: 已删除存档")
