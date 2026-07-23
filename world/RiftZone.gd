extends Node3D
class_name RiftZone

## 阿尔宙斯式「时空裂隙」: 周期性激活, 激活时靠近会触发稀有金属遭遇。
## World 读取 is_active / radius, 在冷却结束后触发一场特殊战斗(见 World._process)。

var is_active: bool = false
var radius: float = 4.5
var cooldown: float = 0.0
var _t: float = 0.0
var _phase: float = 0.0        # 周期计时(未激活累计)
var _active_left: float = 0.0  # 剩余激活时间
var _ring: MeshInstance3D
var _beam: MeshInstance3D

func _ready() -> void:
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.0
	tm.outer_radius = 2.6
	_ring.mesh = tm
	_ring.rotation.x = deg_to_rad(90)
	_ring.position = Vector3(0, 0.3, 0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.6, 0.3, 0.9)
	cmat.emission = Color(0.6, 0.3, 0.9)
	cmat.emission_energy = 0.3
	_ring.material_override = cmat
	add_child(_ring)

	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5
	cm.bottom_radius = 1.5
	cm.height = 8.0
	_beam.mesh = cm
	_beam.position = Vector3(0, 4.0, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.7, 0.4, 1.0, 0.35)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.emission = Color(0.7, 0.4, 1.0)
	bmat.emission_energy = 0.5
	_beam.material_override = bmat
	_beam.visible = false
	add_child(_beam)

func _process(delta: float) -> void:
	_t += delta
	if cooldown > 0.0:
		cooldown = max(0.0, cooldown - delta)
	_phase += delta
	if is_active:
		_active_left -= delta
		if _active_left <= 0.0:
			is_active = false
			_phase = 0.0
	else:
		if _phase >= 25.0:
			is_active = true
			_active_left = 12.0
	if _ring:
		_ring.rotation.z += delta * 1.5
		(_ring.material_override as StandardMaterial3D).emission_energy = 1.6 if is_active else 0.3
	if _beam:
		_beam.visible = is_active

## 触发一次遭遇后调用, 防止短时间内重复触发
func consume() -> void:
	cooldown = 8.0
	is_active = false
	_phase = 0.0
