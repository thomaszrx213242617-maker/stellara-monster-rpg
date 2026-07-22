extends Node
class_name SaveManager

## 存档管理 (autoload, MVP 占位)。保存到 user://save.json。

const SAVE_PATH := "user://save.json"

func save_game() -> void:
    var data := {
        "team": GameState.team,
        "badges": GameState.badges,
        "time": DayNight.time
    }
    var text := JSON.stringify(data)
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(text)
        f.close()
        print("SaveManager: 已保存")

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var text := FileAccess.get_file_as_string(SAVE_PATH)
    var data: Variant = JSON.parse_string(text)
    if data == null:
        return false
    GameState.team = data.get("team", [])
    GameState.badges = data.get("badges", [])
    DayNight.time = float(data.get("time", 0.0))
    print("SaveManager: 已读取存档")
    return true
