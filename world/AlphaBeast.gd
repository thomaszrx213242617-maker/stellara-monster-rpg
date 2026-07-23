extends Node3D
class_name AlphaBeast

## 阿尔宙斯式「首领灵兽」: 大体型、发光、在领地内游荡的强力野怪。
## 玩家靠近后(由 World 监听)按 E 触发一场高难度实时战斗, 击败或收服后回到世界即视为刷新。

var creature_id: String = "steeljaw_king"
var level: int = 18
var roam_center: Vector3 = Vector3.ZERO
var roam_radius: float = 9.0
var _target: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D
var _t: float = 0.0

func _ready() -> void:
	roam_center = global_position
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3, 3, 3)
	_mesh.mesh = bm
	_mesh.position = Vector3(0, 1.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.75, 0.82)
	mat.emission = Color(0.5, 0.6, 0.8)
	mat.emission_energy = 0.8
	_mesh.material_override = mat
	add_child(_mesh)
	# 光环标识(区分普通野怪)
	var halo := MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 2.4
	hm.outer_radius = 2.9
	halo.mesh = hm
	halo.rotation.x = deg_to_rad(90)
	halo.position = Vector3(0, 0.3, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.4, 0.6, 1.0)
	hmat.emission = Color(0.4, 0.6, 1.0)
	hmat.emission_energy = 1.2
	halo.material_override = hmat
	add_child(halo)
	_pick_target()

func _pick_target() -> void:
	var ang := randf() * TAU
	var r := randf() * roam_radius
	_target = roam_center + Vector3(cos(ang) * r, 0, sin(ang) * r)

func _process(delta: float) -> void:
	_t += delta
	if _mesh:
		(_mesh.material_override as StandardMaterial3D).emission_energy = 0.6 + 0.4 * sin(_t * 3.0)
	var to: Vector3 = _target - global_position
	to.y = 0
	if to.length() < 0.5:
		_pick_target()
	else:
		global_position += to.normalized() * 2.0 * delta
		look_at(_target, Vector3.UP)
