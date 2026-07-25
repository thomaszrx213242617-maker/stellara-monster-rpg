extends Area3D
class_name EncounterZone

const PlayerScript := preload("res://world/PlayerController.gd")

## 草丛遭遇区(宝可梦式): 玩家在草丛内逐步随机遇敌(非一进就触发), 草丛有摆动动画。
## pool 为可遭遇灵兽 id 列表; lvl_min/lvl_max 为等级区间。

signal triggered(creature_id: String, level: int)

var pool: Array = ["flarefox"]
var lvl_min: int = 2
var lvl_max: int = 6
var _inside: bool = false
var _cd: float = 0.0
var _grace: float = 0.0
var _tufts: Array = []
var _t: float = 0.0

func _ready() -> void:
	_build_grass()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(10, 2.0, 10)
	col.shape = sh
	col.position = Vector3(0, 1.0, 0)
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _build_grass() -> void:
	# 地面草色底盘
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(10, 0.2, 10)
	base.mesh = bm
	base.position = Vector3(0, 0.1, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.22, 0.5, 0.2)
	base.material_override = bmat
	add_child(base)
	# 一丛丛高草(细高草叶)
	for i in range(70):
		var tuft := MeshInstance3D.new()
		var tm := BoxMesh.new()
		var w: float = randf_range(0.18, 0.32)
		tm.size = Vector3(w, randf_range(0.9, 1.5), w)
		tuft.mesh = tm
		var x: float = randf_range(-4.6, 4.6)
		var z: float = randf_range(-4.6, 4.6)
		tuft.position = Vector3(x, 0.1 + tm.size.y / 2.0, z)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25 + randf() * 0.15, 0.55 + randf() * 0.2, 0.2 + randf() * 0.1)
		tuft.material_override = mat
		add_child(tuft)
		_tufts.append(tuft)

func _on_body_entered(b: Node) -> void:
	if b is PlayerScript:
		_inside = true
		# 进入草丛不立即遇敌: 给予一段缓冲时间
		_grace = 2.2

func _on_body_exited(b: Node) -> void:
	if b is PlayerScript:
		_inside = false

func _physics_process(delta: float) -> void:
	_t += delta
	if _cd > 0.0:
		_cd = max(0.0, _cd - delta)
	if _grace > 0.0:
		_grace = max(0.0, _grace - delta)
	# 草摆动
	var sway: float = sin(_t * 3.0) * 0.06
	for t in _tufts:
		t.rotation.z = sway
	# 在草丛内逐步随机遇敌(宝可梦式 ~12%/秒 触发概率)
	if _inside and _cd <= 0.0 and _grace <= 0.0:
		if randf() < 0.12:
			_cd = 1.6
			# 保留 30% 不刷出(虚假响动): 草丛晃动但不出现野怪
			if randf() >= 0.30:
				var id: String = pool[randi() % pool.size()]
				var lv: int = randi_range(lvl_min, lvl_max)
				triggered.emit(id, lv)
