extends Node3D
class_name FieldAmbush

## 野外突袭(朱紫式): 草丛遇敌不在战斗界面立即开始, 而是在大地图生成一只野生灵兽
## 朝玩家扑来。玩家若不派出灵兽(按 B/E 迎战), 它会直接攻击玩家使其掉血;
## 多次攻击或偶尔的「大招」可将玩家打晕, 触发复活到最近存档点。
## World 负责生成本节点、监听 attack_player / engage 信号。

signal attack_player(damage: int, is_big: bool)
signal fainted

const PlayerScript := preload("res://world/PlayerController.gd")

var creature_id: String = "flarefox"
var level: int = 5
var player = null
var _atk_cd: float = 0.0
var _life: float = 26.0          # 一段时间未迎战则野怪退去
var _speed: float = 5.5
var _big_chance: float = 0.22

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var data: Dictionary = Data.get_creature(creature_id)
	var tc: String = data.get("type", "无")
	var col := Color(0.7, 0.7, 0.7)
	var TYPE_COLORS := {
		"炎": Color(0.9, 0.4, 0.25), "水": Color(0.3, 0.5, 0.9), "木": Color(0.4, 0.7, 0.35),
		"雷": Color(0.95, 0.85, 0.3), "岩": Color(0.6, 0.5, 0.4), "风": Color(0.7, 0.9, 0.8),
		"光": Color(1.0, 0.95, 0.6), "暗": Color(0.35, 0.3, 0.5), "械": Color(0.6, 0.65, 0.7),
		"灵": Color(0.7, 0.6, 0.9), "金": Color(0.75, 0.78, 0.82)
	}
	if TYPE_COLORS.has(tc):
		col = TYPE_COLORS[tc]
	# 身体
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.4
	bm.height = 0.8
	body.mesh = bm
	body.position = Vector3(0, 0.7, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	body.material_override = mat
	add_child(body)
	# 头(发光眼)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.38
	hm.height = 0.5
	head.mesh = hm
	head.position = Vector3(0, 1.25, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = col.lightened(0.25)
	head.material_override = hmat
	add_child(head)
	# 红色怒意光环
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.5
	rm.outer_radius = 0.7
	rm.height = 0.12
	ring.mesh = rm
	ring.position = Vector3(0, 0.2, 0)
	ring.rotation.x = deg_to_rad(90)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.2, 0.2)
	ring.material_override = rmat
	add_child(ring)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_life -= delta
	if _life <= 0.0:
		# 野怪自行退去(玩家成功逃离)
		fainted.emit()
		queue_free()
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0
	var dist: float = to.length()
	if dist > 0.1:
		global_position += to.normalized() * _speed * delta
		look_at(player.global_position, Vector3.UP)
	if _atk_cd > 0.0:
		_atk_cd -= delta
	# 接触攻击
	if dist < 2.2 and _atk_cd <= 0.0:
		_atk_cd = 1.3
		var is_big: bool = randf() < _big_chance
		var dmg: int = 35 if is_big else 12
		attack_player.emit(dmg, is_big)
