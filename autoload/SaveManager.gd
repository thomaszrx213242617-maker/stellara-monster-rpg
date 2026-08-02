extends Node
class_name SaveManager

## 存档管理 (autoload)。保存到 user://save.json。覆盖队伍/存储/背包/徽章/图鉴/时间。

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	load_game()

func save_game() -> void:
	var data := {
		"team": Game.team,
		"storage": Game.storage,
		"inventory": Game.inventory,
		"badges": Game.badges,
		"caught_count": Game.caught_count,
		"dex_seen": Game.dex_seen,
		"dex_caught": Game.dex_caught,
		"research": Game.research,
		"time": Clock.time,
		"player_name": Game.player_name,
		"player_gender": Game.player_gender,
		"story_stage": Game.story_stage,
		"opening_done": Game.opening_done,
		"prologue_done": Game.prologue_done,
		"midboss_done": Game.midboss_done,
		"ending_done": Game.ending_done,
		"coins": Game.coins,
		"player_hp": Game.player_hp,
		"finale_stage": Game.finale_stage,
		"current_scene": Game.current_scene,
		"sfx_on": Game.sfx_on,
		"sfx_volume": Game.sfx_volume,
		"text_speed": Game.text_speed,
		"story_log": Game.story_log,
		"flags": Game.flags
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		print("Save: 已保存")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return false
	if data.has("team"):
		Game.team = data["team"]
	if data.has("storage"):
		Game.storage = data["storage"]
	if data.has("inventory"):
		Game.inventory = data["inventory"]
	if data.has("badges"):
		Game.badges = data["badges"]
	if data.has("caught_count"):
		Game.caught_count = int(data["caught_count"])
	if data.has("dex_seen"):
		Game.dex_seen = data["dex_seen"]
	if data.has("dex_caught"):
		Game.dex_caught = data["dex_caught"]
	if data.has("time"):
		Clock.time = float(data["time"])
	if data.has("research"):
		Game.research = data["research"]
	if data.has("player_name"):
		Game.player_name = str(data["player_name"])
	if data.has("player_gender"):
		Game.player_gender = str(data["player_gender"])
	if data.has("story_stage"):
		Game.story_stage = int(data["story_stage"])
	if data.has("opening_done"):
		Game.opening_done = bool(data["opening_done"])
	if data.has("midboss_done"):
		Game.midboss_done = bool(data["midboss_done"])
	if data.has("ending_done"):
		Game.ending_done = bool(data["ending_done"])
	if data.has("prologue_done"):
		Game.prologue_done = bool(data["prologue_done"])
	if data.has("coins"):
		Game.coins = int(data["coins"])
	if data.has("player_hp"):
		Game.player_hp = int(data["player_hp"])
	if data.has("finale_stage"):
		Game.finale_stage = int(data["finale_stage"])
	if data.has("current_scene"):
		Game.current_scene = str(data["current_scene"])
	if data.has("sfx_on"):
		Game.sfx_on = bool(data["sfx_on"])
	if data.has("sfx_volume"):
		Game.sfx_volume = float(data["sfx_volume"])
	if data.has("text_speed"):
		Game.text_speed = int(data["text_speed"])
	if data.has("story_log"):
		Game.story_log = data["story_log"]
	if data.has("flags"):
		Game.flags = data["flags"]
	print("Save: 已读取存档")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 删除本地存档(用于「开始新游戏」覆盖)。
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d := DirAccess.open("user://")
		if d != null:
			d.remove("save.json")
		print("Save: 已删除存档")
