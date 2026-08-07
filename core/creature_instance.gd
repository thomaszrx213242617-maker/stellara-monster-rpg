class_name CreatureInstance
extends RefCounted

## 收服养成数据层: 一只被收服灵兽的「个体」模型。
## 承载: 物种/等级/累计经验/当前与最大血量/招式/状态/特性, 并提供养成操作
## (加经验 → 连续升级 → 进化 → 学招) 与存档序列化(to_dict/from_dict)。
## 升级/进化/学招规则复用 GameState 中的权威表(LEVEL_MOVES / SIGNATURE_MOVES), 不重复定义。

signal leveled_up(new_level: int)
signal evolved(from_name: String, to_name: String, learned: Array)
signal learned_move(move_id: String)

var species_id: String = "flarefox"
var nickname: String = ""
var level: int = 5
var exp: int = 0                 # 累计经验(见 Growth)
var current_hp: int = 1
var max_hp: int = 1
var stats: Dictionary = {}       # 派生属性(由种族值+等级)
var moves: Array = []            # 招式 id 列表(最多4)
var status_name: String = ""     # 异常状态
var ability: String = ""

## 创建一只指定物种、等级的个体(满血)
static func create(species_id_: String, level_: int, nickname_: String = "") -> CreatureInstance:
	var ci: CreatureInstance = CreatureInstance.new()
	ci.species_id = species_id_
	ci.nickname = nickname_
	ci.level = max(1, level_)
	ci.exp = Growth.cumulative(ci.level)
	var data: Dictionary = Data.get_creature(ci.species_id)
	if not data.is_empty():
		ci.ability = data.get("ability", "")
		ci.stats = Data.compute_stats(data, ci.level)
		ci.max_hp = int(ci.stats.get("max_hp", 1))
		ci.moves = data.get("moves", []).duplicate()
	ci.current_hp = ci.max_hp
	return ci

## 由存档字典重建(见 to_dict)
static func from_dict(d: Dictionary) -> CreatureInstance:
	var ci: CreatureInstance = CreatureInstance.new()
	ci.species_id = str(d.get("id", "flarefox"))
	ci.nickname = str(d.get("nickname", ""))
	ci.level = int(d.get("level", 1))
	ci.exp = int(d.get("exp", 0))
	ci.current_hp = int(d.get("hp", 1))
	ci.max_hp = int(d.get("max_hp", 1))
	ci.status_name = str(d.get("status", ""))
	ci.moves = d.get("moves", []).duplicate()
	var data: Dictionary = Data.get_creature(ci.species_id)
	ci.ability = data.get("ability", "") if not data.is_empty() else ""
	ci.stats = Data.compute_stats(data, ci.level) if not data.is_empty() else {}
	return ci

## 序列化为可存档字典(与 GameState 队伍字典结构兼容)
func to_dict() -> Dictionary:
	return {
		"id": species_id,
		"nickname": nickname,
		"level": level,
		"exp": exp,
		"hp": current_hp,
		"max_hp": max_hp,
		"status": status_name,
		"moves": moves.duplicate()
	}

## 重新派生属性(进化/升级后调用)
func derive_stats() -> void:
	var data: Dictionary = Data.get_creature(species_id)
	if data.is_empty():
		return
	ability = data.get("ability", "")
	stats = Data.compute_stats(data, level)
	max_hp = int(stats.get("max_hp", max_hp))

## 距离下一级还差多少经验
func exp_to_next() -> int:
	return Growth.exp_to_next(level, exp)

## 当前等级(由累计经验校正, 防御性)
func sync_level() -> void:
	level = Growth.level_from_exp(exp)
	derive_stats()

## 加经验: 处理连续升级与进化。返回事件摘要字典。
## exp 为「累计经验」(绝对总量), 升级时只比较阈值、不扣减; 距下一级用 exp_to_next 计算。
func gain_exp(amount: int) -> Dictionary:
	var res := {"levels": 0, "evolved": false, "from": "", "to": "", "learned": []}
	exp += max(0, amount)
	while level < Growth.level_cap() and exp >= Growth.cumulative(level + 1):
		level += 1
		res["levels"] += 1
		_on_level_up()
		leveled_up.emit(level)
		# 升级学招(每跨越阈值学一次, 满4招或已学会则跳过)
		var table: Array = Game.LEVEL_MOVES.get(species_id, [])
		for entry in table:
			if int(entry[0]) <= level and not (entry[1] in moves) and moves.size() < 4:
				moves.append(entry[1])
				res["learned"].append(entry[1])
				learned_move.emit(entry[1])
		# 进化判定
		var data: Dictionary = Data.get_creature(species_id)
		var evo_to: String = data.get("evolve_to", "")
		var evo_lv: int = int(data.get("evolve_level", 999))
		if evo_to != "" and level >= evo_lv:
			_evolve(evo_to, res)
	return res

func _on_level_up() -> void:
	var ratio: float = float(current_hp) / float(max(max_hp, 1))
	derive_stats()
	current_hp = int(clamp(ratio * float(max_hp), 1, max_hp))

func _evolve(to_id: String, res: Dictionary) -> void:
	var from_data: Dictionary = Data.get_creature(species_id)
	var from_name: String = species_id
	if not from_data.is_empty():
		from_name = str(from_data.get("name", species_id))
	var to_data: Dictionary = Data.get_creature(to_id)
	if to_data.is_empty():
		return
	var to_name: String = str(to_data.get("name", to_id))
	species_id = to_id
	moves = to_data.get("moves", []).duplicate()
	# 进化专属招式(招牌技): 必定习得, 已满则替换最后一招
	var sig: String = Game.SIGNATURE_MOVES.get(to_id, "")
	if sig != "":
		if not (sig in moves):
			if moves.size() < 4:
				moves.append(sig)
			else:
				moves[moves.size() - 1] = sig
		if not (sig in res["learned"]):
			res["learned"].append(sig)
			learned_move.emit(sig)
	# 重新派生属性, 保持血量比例
	var ratio: float = float(current_hp) / float(max(max_hp, 1))
	derive_stats()
	current_hp = int(clamp(ratio * float(max_hp), 1, max_hp))
	res["evolved"] = true
	res["from"] = from_name
	res["to"] = to_name
	evolved.emit(from_name, to_name, res["learned"])

## 治疗(回满 + 清状态)
func heal() -> void:
	current_hp = max_hp
	status_name = ""

func is_fainted() -> bool:
	return current_hp <= 0

## 显示名(有昵称用昵称, 否则用物种名)
func display_name() -> String:
	if nickname != "":
		return nickname
	var data: Dictionary = Data.get_creature(species_id)
	return str(data.get("name", species_id))
