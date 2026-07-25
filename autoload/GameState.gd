extends Node

## 全局游戏状态 (autoload): 玩家队伍、存储箱、背包、徽章、图鉴进度。
## 队伍每只灵兽为可序列化字典: {id, level, exp, hp, max_hp, status, moves}
## status: null 或 {name:String, turns:int}

signal team_changed
signal inventory_changed
signal leveled_up(creature: Dictionary, new_level: int)
signal evolved(creature: Dictionary, from_name: String, to_name: String)
signal badge_changed

var team: Array = []           # 出战队伍(最多6)
var storage: Array = []        # 存储箱(超出6只)
var inventory: Dictionary = {} # item_id -> count
var badges: Array = []         # 已获得徽章 id
var badges_total: int = 8
var pending_wild: Dictionary = {}  # 待进入的野怪战斗配置 {id, level}; 空则默认
var pending_trainer: Dictionary = {}  # 训练家/道馆战配置 {enemy_id, enemy_level, trainer_name, badge_id}
var caught_count: int = 0      # 图鉴: 收服总数
## 图鉴研究任务(阿尔宙斯式调查): 收服/击败指定属性的灵兽达到数量即完成并发奖
var research: Dictionary = {"type": "金", "need": 3, "progress": 0, "done": false, "reward": "ancient_ball", "reward_n": 1}

func _ready() -> void:
	if team.is_empty():
		add_to_team("flarefox", 5)
	if inventory.is_empty():
		inventory = {"ball": 5, "potion": 3}

## 升到某级所需经验(中速曲线)
func exp_needed(level: int) -> int:
	return level * level

## 击败野生灵兽获得的经验
func wild_exp(level: int) -> int:
	return floor(level * 8) + 8

func max_hp_for(id: String, level: int) -> int:
	var data: Dictionary = DataBus.get_creature(id)
	if data.is_empty():
		return 1
	return DataBus.compute_stats(data, level)["max_hp"]

func add_to_team(id: String, level: int) -> void:
	var data: Dictionary = DataBus.get_creature(id)
	if data.is_empty():
		return
	var mhp: int = max_hp_for(id, level)
	var c := {
		"id": id, "level": level, "exp": 0,
		"hp": mhp, "max_hp": mhp,
		"status": null, "moves": data.get("moves", []).duplicate()
	}
	if team.size() < 6:
		team.append(c)
	else:
		storage.append(c)
	team_changed.emit()

## 给一只队伍灵兽加经验, 处理连续升级与进化。返回事件摘要。
func grant_exp(c: Dictionary, amount: int) -> Dictionary:
	var res := {"levels": 0, "evolved": false, "from": "", "to": ""}
	if c.has("status") and c["status"] != null and c["status"].get("name", "") == "睡眠":
		pass # 睡眠仍可获经验
	c["exp"] = int(c.get("exp", 0)) + amount
	while c["level"] < 100 and int(c["exp"]) >= exp_needed(int(c["level"])):
		c["exp"] = int(c["exp"]) - exp_needed(int(c["level"]))
		c["level"] += 1
		res["levels"] += 1
		_on_level_up(c)
		leveled_up.emit(c, int(c["level"]))
		# 进化
		var data: Dictionary = DataBus.get_creature(c["id"])
		var evo_to: String = data.get("evolve_to", "")
		var evo_lv: int = int(data.get("evolve_level", 999))
		if evo_to != "" and int(c["level"]) >= evo_lv:
			var from_name: String = data["name"]
			var to_data: Dictionary = DataBus.get_creature(evo_to)
			if not to_data.is_empty():
				c["id"] = evo_to
				c["moves"] = to_data.get("moves", []).duplicate()
				var new_max: int = max_hp_for(evo_to, int(c["level"]))
				var ratio: float = float(c["hp"]) / float(max(c["max_hp"], 1))
				c["max_hp"] = new_max
				c["hp"] = int(clamp(ratio * float(new_max), 1, new_max))
				res["evolved"] = true
				res["from"] = from_name
				res["to"] = to_data["name"]
				evolved.emit(c, from_name, to_data["name"])
	return res

func _on_level_up(c: Dictionary) -> void:
	var new_max: int = max_hp_for(c["id"], int(c["level"]))
	var diff: int = new_max - int(c["max_hp"])
	c["max_hp"] = new_max
	c["hp"] = int(min(new_max, int(c["hp"]) + max(diff, 0)))

func heal_team() -> void:
	for c in team:
		c["hp"] = int(c["max_hp"])
		c["status"] = null
	team_changed.emit()

func alive_count() -> int:
	var n := 0
	for c in team:
		if int(c["hp"]) > 0:
			n += 1
	return n

func has_badge(id: String) -> bool:
	return badges.has(id)

func grant_badge(id: String) -> void:
	if not badges.has(id):
		badges.append(id)
		badge_changed.emit()

## 标题画面「开始新游戏」: 清空全部进度并重置为初始状态(同时删除本地存档)。
func reset_new_game() -> void:
	team = []
	storage = []
	inventory = {}
	badges = []
	caught_count = 0
	research = {"type": "金", "need": 3, "progress": 0, "done": false, "reward": "ancient_ball", "reward_n": 1}
	pending_wild = {}
	pending_trainer = {}
	if "time" in DayNight:
		DayNight.time = 0.0
	SaveManager.delete_save()
	add_to_team("flarefox", 5)
	inventory = {"ball": 5, "potion": 3}
	team_changed.emit()
	inventory_changed.emit()
	badge_changed.emit()

## 夜间规则: 不可进行"对战收集点数 / 收服"
func can_collect() -> bool:
	return DayNight.can_battle_collect_points()

## 记录一次「收服/击败」事件, 推进图鉴研究任务; 完成时发放奖励道具。
func note_research(creature_type: String) -> void:
	if research.get("done", false):
		return
	if creature_type != research.get("type", ""):
		return
	research["progress"] = int(research.get("progress", 0)) + 1
	if int(research["progress"]) >= int(research.get("need", 0)):
		research["done"] = true
		add_item(research.get("reward", "ancient_ball"), int(research.get("reward_n", 1)))

func add_item(id: String, n: int) -> void:
	inventory[id] = int(inventory.get(id, 0)) + n
	inventory_changed.emit()

func consume_item(id: String, n: int) -> bool:
	if int(inventory.get(id, 0)) < n:
		return false
	inventory[id] = int(inventory.get(id, 0)) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true

## 取背包中第一个球类道具
func first_ball() -> String:
	for id in inventory.keys():
		var it: Dictionary = DataBus.get_item(id)
		if not it.is_empty() and it.get("type") == "ball":
			return id
	return ""

func ball_mod(id: String) -> float:
	var it: Dictionary = DataBus.get_item(id)
	if it.is_empty():
		return 1.0
	return float(it.get("catch_mod", 1.0))
