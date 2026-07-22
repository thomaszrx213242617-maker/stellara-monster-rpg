extends CharacterBody3D
class_name Combatant

## 战斗中的一只灵兽: 承载属性/血量与移动。玩家与敌方共用, 由 is_player 区分。
## 新增: 状态异常、特性、当前技能切换、坚硬保命。

signal hp_changed(current: int, maximum: int)
signal defeated_signal

var creature_id: String = "flarefox"
var level: int = 5
var type: String = "炎"
var max_hp: int = 100
var hp: int = 100
var stats: Dictionary = {}
var moves: Array = []
var is_player: bool = false
var defeated: bool = false

var move_dir: Vector3 = Vector3.ZERO
@export var move_speed: float = 5.0
var base_speed: float = 5.0
var invulnerable: float = 0.0
var gravity: float = 22.0

var status_name: String = ""      # 中毒/灼烧/麻痹/睡眠/冰冻
var status_timer: float = 0.0     # 睡眠/冰冻剩余秒
var status_tick: float = 0.0      # 中毒/灼烧每跳计时
var ability: String = ""
var active_move_index: int = 0
var sturdy_used: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	var m := MeshInstance3D.new()
	m.name = "MeshInstance3D"
	var cap := CapsuleMesh.new()
	cap.radius = 0.6
	cap.height = 1.6
	m.mesh = cap
	m.position = Vector3(0, 0.9, 0)
	add_child(m)
	mesh = m
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius = 0.6
	shp.height = 1.6
	col.shape = shp
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	base_speed = move_speed
	# setup() 在 add_child 之前调用, 彼时 mesh 尚未创建, 故颜色延迟到入树后补应用
	if type != "":
		_apply_color()

func setup(creature_id_: String, level_: int, is_player_: bool, current_hp_: int = -1) -> void:
	creature_id = creature_id_
	level = level_
	is_player = is_player_
	var data: Dictionary = DataBus.get_creature(creature_id)
	if data.is_empty():
		return
	type = data.get("type", "炎")
	ability = data.get("ability", "")
	stats = DataBus.compute_stats(data, level)
	max_hp = stats["max_hp"]
	if current_hp_ >= 0:
		hp = clamp(current_hp_, 0, max_hp)
	else:
		hp = max_hp
	moves = data.get("moves", [])
	active_move_index = 0
	_apply_color()
	hp_changed.emit(hp, max_hp)

func set_move_index(i: int) -> void:
	if moves.is_empty():
		return
	active_move_index = posmod(i, moves.size())

func _apply_color() -> void:
	var colors := {
		"炎": Color(0.9, 0.3, 0.2), "水": Color(0.2, 0.4, 0.9), "木": Color(0.3, 0.7, 0.3),
		"雷": Color(0.9, 0.9, 0.2), "岩": Color(0.6, 0.5, 0.4), "风": Color(0.7, 0.9, 0.8),
		"光": Color(1.0, 0.95, 0.6), "暗": Color(0.3, 0.2, 0.4), "械": Color(0.7, 0.7, 0.75),
		"灵": Color(0.8, 0.6, 0.9)
	}
	var c: Color = colors.get(type, Color(0.8, 0.8, 0.8))
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mesh.material_override = mat

func _physics_process(delta: float) -> void:
	invulnerable = max(0.0, invulnerable - delta)
	_tick_status(delta)
	if defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	var spd: float = base_speed
	if status_name == "麻痹":
		spd *= 0.5
	if status_name == "睡眠" or status_name == "冰冻":
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = move_dir.x * spd
		velocity.z = move_dir.z * spd
		if move_dir.length() > 0.01:
			look_at(global_position + Vector3(move_dir.x, 0, move_dir.z), Vector3.UP)
	move_and_slide()

func _tick_status(delta: float) -> void:
	if status_name == "":
		return
	if status_name == "睡眠" or status_name == "冰冻":
		status_timer -= delta
		if status_timer <= 0.0:
			clear_status()
		return
	if status_name == "中毒" or status_name == "灼烧":
		status_tick -= delta
		if status_tick <= 0.0:
			status_tick = 1.0
			var dmg: int = max(1, int(max_hp / 16.0))
			_dot(dmg)

func _dot(dmg: int) -> void:
	if defeated:
		return
	hp -= dmg
	if hp <= 0:
		hp = 0
		defeated = true
		defeated_signal.emit()
	hp_changed.emit(hp, max_hp)

func apply_status(name: String, turns: float) -> void:
	status_name = name
	if name == "睡眠" or name == "冰冻":
		status_timer = turns
	else:
		status_tick = 0.0

func clear_status() -> void:
	status_name = ""
	status_timer = 0.0
	status_tick = 0.0

## attacker: 施法者节点(用于静电反伤); category: 物理/特殊/变化
func take_damage(amount: float, attacker = null, category: String = "物理") -> void:
	if defeated:
		return
	if ability == "坚硬" and not sturdy_used and (hp - int(amount)) <= 0:
		hp = 1
		sturdy_used = true
		hp_changed.emit(hp, max_hp)
		_pop()
		return
	hp -= int(amount)
	# 静电: 受到物理攻击有概率麻痹对手
	if ability == "静电" and attacker != null and category == "物理" and randf() < 0.3:
		attacker.apply_status("麻痹", 4.0)
	if hp <= 0:
		hp = 0
		defeated = true
		defeated_signal.emit()
	hp_changed.emit(hp, max_hp)
	if mesh:
		var t := create_tween()
		t.tween_property(mesh, "scale", Vector3(1.15, 1.15, 1.15), 0.05)
		t.tween_property(mesh, "scale", Vector3.ONE, 0.1)

func _pop() -> void:
	if mesh:
		var t := create_tween()
		t.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), 0.08)
		t.tween_property(mesh, "scale", Vector3.ONE, 0.12)
