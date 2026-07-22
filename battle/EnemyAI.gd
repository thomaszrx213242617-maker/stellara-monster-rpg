extends Node
class_name EnemyAI

const CombatScript := preload("res://core/combat.gd")

## 敌方灵兽的简单 AI: 靠近玩家, 进入射程后周期性出招 (伤害含属性克制与特性)。
## 出招随机从技能池选取, 命中可施加状态异常。

var player: Node
var enemy: Node
var attack_range: float = 3.0
var attack_interval: float = 1.4

func _physics_process(delta: float) -> void:
	if not player or not enemy:
		return
	if enemy.defeated or player.defeated:
		enemy.move_dir = Vector3.ZERO
		return
	attack_interval = max(0.0, attack_interval - delta)
	var to_player: Vector3 = player.global_position - enemy.global_position
	to_player.y = 0
	var dist: float = to_player.length()
	if dist > attack_range:
		enemy.move_dir = to_player.normalized()
	else:
		enemy.move_dir = Vector3.ZERO
		if attack_interval <= 0.0:
			_enemy_attack()
			attack_interval = randf_range(1.2, 1.8)

func _enemy_attack() -> void:
	if enemy.moves.is_empty():
		return
	var move_id: String = enemy.moves[randi() % enemy.moves.size()]
	var mv: Dictionary = DataBus.get_move(move_id)
	if mv.is_empty():
		return
	var mult: float = DataBus.multiplier(mv["type"], player.type)
	# 特性: 猛火/蓄水 低血量增伤
	if (enemy.ability == "猛火" and mv["type"] == "炎") or (enemy.ability == "蓄水" and mv["type"] == "水"):
		if enemy.hp < enemy.max_hp / 3.0:
			mult *= 1.5
	var power: float = float(mv.get("power", 0))
	if power <= 0.0:
		# 纯状态招式
		if player.invulnerable <= 0.0 and mv.has("status"):
			player.apply_status(mv["status"], 4.0)
		return
	var dmg: float = CombatScript.calc_damage(enemy.stats["atk"], player.stats["def"], power, mult, enemy.level, randf_range(0.85, 1.0))
	if player.invulnerable > 0.0:
		return
	var cat: String = mv.get("category", "物理")
	player.take_damage(dmg, enemy, cat)
	if mv.has("status") and randf() < float(mv.get("status_chance", 0.0)):
		player.apply_status(mv["status"], 4.0)
