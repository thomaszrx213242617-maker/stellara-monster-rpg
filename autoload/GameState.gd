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
var coins: int = 300           # 货币(原创: 星辉币)
var player_hp: int = 100       # 野外玩家血量(被野生灵兽袭击时扣减)
var player_max_hp: int = 100
var finale_stage: int = 0      # 终局链: 0 未开始 / 1 已击败凛 / 2 已击败辉金龙
var selected_ball: String = "ball"  # 战斗中使用的球(可在战斗内切换)
var pending_wild: Dictionary = {}  # 待进入的野怪战斗配置 {id, level}; 空则默认
var pending_trainer: Dictionary = {}  # 训练家/道馆战配置 {enemy_id, enemy_level, trainer_name, badge_id}
var caught_count: int = 0      # 图鉴: 收服总数
## 图鉴: 按物种记录「已见 / 已捕」
var dex_seen: Dictionary = {}   # id -> true  (遭遇/见过)
var dex_caught: Dictionary = {} # id -> true  (成功收服过)
## 图鉴研究任务(阿尔宙斯式调查): 收服/击败指定属性的灵兽达到数量即完成并发奖
var research: Dictionary = {"type": "金", "need": 3, "progress": 0, "done": false, "reward": "ancient_ball", "reward_n": 1}

## 玩家身份与剧情进度(原创IP)
var player_name: String = ""
var player_gender: String = "少年"   # 少年 / 少女
var story_stage: int = 0             # 0 序章前 / 1 落地星澜 / 2 中期Boss后 / 3 结局后
var opening_done: bool = false
var midboss_done: bool = false
var ending_done: bool = false
var prologue_done: bool = false
## 剧情大事记(已完成里程碑, 供「剧情」面板展示): [{text, done}]
var story_log: Array = []

## 三枚秘环(原创机制, 对应极巨/太晶/超演之力, 规避版权): 开局即拥有, 每场战斗各可用一次
## giant=巨灵环(巨大化) / crystal=晶变环(晶化增伤) / hyper=超衍环(超演增益)
var transformation_bands: bool = true

## 战斗结束后返回的自定义场景(序章探险用; 空则回 World)
var battle_return_scene: String = ""
## 序章探险: 洞中野怪侦查战是否已完成(用于场景重建后跳过)
var prologue_scout_done: bool = false
## 序章·双生神兽战: 是否处于「真实神兽战」模式(战败才播旁白, 非普通胜负)
var prologue_beast_mode: bool = false
## 退出游戏前所在的场景路径; 重进时若有存档则自动回到此处(续玩)
var current_scene: String = ""
## 晶变坑(太晶坑原创命名)讨伐配置: {boss_id, boss_level, allies:[训练家名]}
var pending_raid: Dictionary = {}
## 玩家当前身处草丛区的数量(引用计数): 进入 +1、离开 -1；>0 表示在草丛中(脚步声换草丛版)
var grass_zones: int = 0

## 一次性探索事件标记(辉光晶簇 / 古老封印等), 由 World 读写, 随存档持久化
var flags: Dictionary = {}

## 音频设置(背景音乐/音效 开关与音量; 全局偏好, 不随「新游戏」重置)
var music_on: bool = true
var music_volume: float = 0.6
var sfx_on: bool = true
var sfx_volume: float = 0.7

## 文字速度(对话打字机): 0=慢 1=中 2=快(快=瞬间显示); 全局偏好
var text_speed: int = 1

## 自定义背景音乐文件路径(res://audio/...); 空字符串=使用内置原创合成。
## 在「设置→背景音乐」里切换并持久化; 属全局偏好, 不随「新游戏」重置。
var custom_music: String = ""

## 设置玩家名字与性别(名字空则回退为"旅人")
func set_player_identity(name: String, gender: String) -> void:
	player_name = name.strip_edges()
	if player_name == "":
		player_name = "旅人"
	player_gender = gender

## 图鉴: 标记一只灵兽为「已见」(野生/训练家遭遇、alpha、裂隙均算)
func note_dex_seen(id: String) -> void:
	if id != "":
		dex_seen[id] = true

## 图鉴: 标记一只灵兽为「已捕」(同时记入已见)
func note_dex_caught(id: String) -> void:
	if id != "":
		dex_caught[id] = true
		dex_seen[id] = true

func dex_total() -> int:
	return DataBus.creatures.size()

func dex_seen_count() -> int:
	return dex_seen.size()

func dex_caught_count() -> int:
	return dex_caught.size()

func _ready() -> void:
	if team.is_empty():
		add_to_team("flarefox", 5)
	if inventory.is_empty():
		inventory = {"ball": 5, "potion": 3}
	coins = 300
	player_hp = player_max_hp
	selected_ball = "ball"

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

## 把队伍第 i 只存入存储箱(队伍仅剩 1 只时禁止, 避免无灵兽可用)
func deposit_to_storage(i: int) -> bool:
	if i < 0 or i >= team.size():
		return false
	if team.size() <= 1:
		return false
	var c: Dictionary = team[i]
	team.remove_at(i)
	storage.append(c)
	team_changed.emit()
	return true

## 把存储箱第 i 只取出放入队伍(队伍满 6 只时禁止)
func withdraw_from_storage(i: int) -> bool:
	if i < 0 or i >= storage.size():
		return false
	if team.size() >= 6:
		return false
	var c: Dictionary = storage[i]
	storage.remove_at(i)
	team.append(c)
	team_changed.emit()
	return true

## 给一只队伍灵兽加经验, 处理连续升级与进化。返回事件摘要。
## 升级习得招式表: 灵兽id -> [[等级, 招式id], ...] (仅当未满4招且未学过才学)
const LEVEL_MOVES := {
	"snowmane": [[18, "blizzard"], [22, "frost"]],
	"ashfang": [[18, "inferno"], [24, "blaze"]],
	"tidecup": [[6, "torrent"], [11, "aqua"], [15, "beam"]],
	"breezewing": [[6, "gust"], [12, "hurricane"]],
	"lumiadeer": [[10, "beam"], [15, "shadow"], [18, "hypno"]],
	"windpip": [[8, "gust"], [13, "hurricane"]],
	"vinelop": [[9, "leaf"], [14, "vine"]],
	"voltmink": [[9, "spark"], [14, "thunderwave"]],
	"shadepup": [[9, "shadowclaw"], [14, "darkpulse"]]
}

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
		# 升级习得新招式(每跨越一个阈值学一次, 满4招或已学会则跳过)
		for entry in LEVEL_MOVES.get(c["id"], []):
			if int(entry[0]) <= int(c["level"]) and not (entry[1] in c["moves"]) and c["moves"].size() < 4:
				c["moves"].append(entry[1])
				if not res.has("learned"):
					res["learned"] = []
				res["learned"].append(entry[1])
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
	dex_seen = {}
	dex_caught = {}
	research = {"type": "金", "need": 3, "progress": 0, "done": false, "reward": "ancient_ball", "reward_n": 1}
	pending_wild = {}
	pending_trainer = {}
	opening_done = false
	midboss_done = false
	ending_done = false
	prologue_done = false
	story_log = []
	transformation_bands = true
	story_stage = 0
	player_name = ""
	battle_return_scene = ""
	prologue_scout_done = false
	prologue_beast_mode = false
	current_scene = ""
	pending_raid = {}
	grass_zones = 0
	flags = {}
	player_gender = "少年"
	finale_stage = 0
	coins = 300
	player_hp = player_max_hp
	selected_ball = "ball"
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

## ---- 剧情大事记 / 当前目标(原创IP) ----
func complete_milestone(text: String) -> void:
	for e in story_log:
		if e["text"] == text:
			e["done"] = true
			return
	story_log.append({"text": text, "done": true})

## 根据当前进度推导「当前目标」(供剧情面板/常驻HUD展示): 集齐两枚道馆徽章 → 挑战暗潮使·玄 → 冠军之路
func current_objective() -> String:
	if ending_done:
		return "主线已完结：自由探索星澜大陆，收集图鉴、挑战晶变坑、培养灵兽"
	if finale_stage >= 1:
		return "终局：收服双生金属神兽「辉金龙」与「黯钢兽」，救回凛"
	if midboss_done:
		return "前往黯潮深渊，击败黯潮之主·凛（靠近后按 E 挑战）"
	if story_stage < 1:
		return "跟随向导·岚，熟悉星澜村与基本操作"
	if not has_badge("badge_stone"):
		return "前往晨曦镇，挑战馆主·岩心，赢取岩石徽章"
	if not has_badge("badge_wave"):
		return "前往星澜村西，挑战馆主·清，赢取清风徽章"
	if not has_badge("badge_flame"):
		return "前往熔岩谷，挑战馆主·炎心，赢取烈焰徽章"
	if not has_badge("badge_frost"):
		return "前往霜原，挑战馆主·霜音，赢取寒冰徽章"
	if dex_caught_count() < 2:
		return "前往北之路，收服至少 2 只灵兽（野怪会主动扑来，按 B/E 迎战）"
	return "前往晨曦镇，挑战暗潮使·玄（需集齐四枚徽章）"

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

## ---- 货币 / 商店 ----
func price_of(id: String) -> int:
	var it: Dictionary = DataBus.get_item(id)
	if it.is_empty():
		return 0
	return int(it.get("price", 0))

func can_buy(id: String) -> bool:
	var it: Dictionary = DataBus.get_item(id)
	if it.is_empty():
		return false
	return bool(it.get("buyable", false))

## 在商店购买 n 个道具; 钱不够或不可购买返回 false
func buy_item(id: String, n: int = 1) -> bool:
	if not can_buy(id):
		return false
	var cost: int = price_of(id) * n
	if coins < cost:
		return false
	coins -= cost
	add_item(id, n)
	return true

## 可购买的道具列表(球类在前)
func shop_items() -> Array:
	var out := []
	for iid in DataBus.items.keys():
		if can_buy(iid):
			out.append(iid)
	return out

## 玩家野外血量
func heal_player() -> void:
	player_hp = player_max_hp

func damage_player(amount: int) -> void:
	player_hp = max(0, player_hp - amount)

func is_player_fainted() -> bool:
	return player_hp <= 0

## ---- 战斗用球选择(朱紫式可切换球) ----
func owned_balls() -> Array:
	var out := []
	for id in inventory.keys():
		var it: Dictionary = DataBus.get_item(id)
		if not it.is_empty() and it.get("type") == "ball":
			out.append(id)
	return out

## 在已拥有的球之间循环选择
func cycle_ball() -> String:
	var owned := owned_balls()
	if owned.is_empty():
		selected_ball = ""
		return ""
	if selected_ball == "" or not selected_ball in owned:
		selected_ball = owned[0]
	else:
		var i: int = owned.find(selected_ball)
		selected_ball = owned[(i + 1) % owned.size()]
	return selected_ball

## 收服成功后把神兽收入队伍/存储(终局奖励)
func obtain_legendary(id: String) -> void:
	add_to_team(id, 30)
	note_dex_seen(id)
	note_dex_caught(id)
