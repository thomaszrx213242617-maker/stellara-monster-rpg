extends Node
class_name GameState

## 全局游戏状态 (autoload): 玩家队伍、进度、图鉴等。MVP 先实现队伍与徽章。

signal team_changed

var team: Array = []          # 每只: {id, level, hp, max_hp}
var badges: Array = []        # 已获得徽章 id
var badges_total: int = 8

func _ready() -> void:
    # MVP 起始队伍: 一只焰狐 Lv5
    add_to_team("flarefox", 5)

func add_to_team(creature_id: String, level: int) -> void:
    if team.size() >= 6:
        return
    var data: Dictionary = DataBus.get_creature(creature_id)
    if data.is_empty():
        return
    var stats: Dictionary = DataBus.compute_stats(data, level)
    team.append({
        "id": creature_id,
        "level": level,
        "hp": stats["max_hp"],
        "max_hp": stats["max_hp"]
    })
    team_changed.emit()

func has_badge(id: String) -> bool:
    return badges.has(id)

func grant_badge(id: String) -> void:
    if not badges.has(id):
        badges.append(id)
