extends Node3D
class_name MvpExplore

## MVP 垂直切片: 3D 探索(移动) + 第三人称相机。
## 纯代码拼装(与 world/World.tscn 同约定: Node3D + 脚本, 子节点在 _ready 生成),
## 复用既有 PlayerController / CameraRig, 不引入任何剧情/战斗/背包/UI 系统。
##
## 用法: 在编辑器打开 world/MvpExplore.tscn 按 F6(运行当前场景) 即可直接体验:
##   WASD 相机相对移动 · 右键拖动旋转视角(yaw/pitch) · 空格跳跃 · 角色自动面朝移动方向。
## 用途: 验证「WASD 移动 + 朝向 + 第三人称跟随相机」这一最小可玩闭环, 作为后续内容扩建的地基。

const PlayerScript := preload("res://world/PlayerController.gd")
const CameraScript := preload("res://world/CameraRig.gd")

var _player: Node3D
var _camera: Node3D

func _ready() -> void:
	_build_environment()
	_build_ground()
	_spawn_landmarks()
	_spawn_player_and_camera()
	_add_hint()

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.75, 0.95)
	env.ambient_light_energy = 0.8
	env.ambient_light_color = Color(0.7, 0.8, 0.95)
	env.fog_enabled = true
	env.fog_density = 0.01
	env_node.environment = env

	# 主光(太阳)
	var sun := DirectionalLight3D.new()
	sun.position = Vector3(10, 25, 10)
	sun.rotation = Vector3(deg_to_rad(-55), 0, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.97, 0.9)
	add_child(sun)

	# 柔和补光(提升立体感)
	var fill := DirectionalLight3D.new()
	fill.position = Vector3(-12, 18, -8)
	fill.rotation = Vector3(deg_to_rad(40), deg_to_rad(180), 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	ground.mesh = plane
	ground.rotate_x(deg_to_rad(-90))
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.45, 0.62, 0.35)
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	# 地面碰撞(不可穿地)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 0.2, 160)
	col.shape = shape
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

func _spawn_landmarks() -> void:
	# 树木 + 中央石柱, 提供空间参照与碰撞遮挡(真实探索感)
	var spots := [
		Vector3(-8, 0, -6), Vector3(10, 0, 4), Vector3(-14, 0, 10),
		Vector3(16, 0, -12), Vector3(0, 0, -18), Vector3(-20, 0, -4),
		Vector3(22, 0, 14), Vector3(-6, 0, 16)
	]
	for s in spots:
		_add_tree(s)
	_add_pillar(Vector3(0, 0, 0))

func _add_tree(pos: Vector3) -> void:
	var t := Node3D.new()
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.25
	tm.bottom_radius = 0.35
	tm.height = 2.0
	trunk.mesh = tm
	trunk.position = Vector3(0, 1.0, 0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.45, 0.3, 0.18)
	tmat.roughness = 0.9
	trunk.material_override = tmat
	t.add_child(trunk)
	var foliage := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 1.3
	fm.height = 3.0
	foliage.mesh = fm
	foliage.position = Vector3(0, 3.2, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.2, 0.5, 0.25)
	fmat.roughness = 0.8
	foliage.material_override = fmat
	t.add_child(foliage)
	# 碰撞: 树干实体, 玩家(CharacterBody3D)不可穿过
	var tsb := StaticBody3D.new()
	var tcol := CollisionShape3D.new()
	var tsh := CylinderShape3D.new()
	tsh.radius = 0.45
	tsh.height = 2.4
	tcol.shape = tsh
	tcol.position = Vector3(0, 1.2, 0)
	tsb.add_child(tcol)
	t.add_child(tsb)
	t.position = pos
	add_child(t)

func _add_pillar(pos: Vector3) -> void:
	var p := Node3D.new()
	var m := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.8
	pm.bottom_radius = 1.0
	pm.height = 3.0
	m.mesh = pm
	m.position = Vector3(0, 1.5, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.8, 0.82, 0.88)
	pmat.roughness = 0.4
	pmat.metallic = 0.1
	m.material_override = pmat
	p.add_child(m)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.0
	sh.height = 3.0
	col.shape = sh
	col.position = Vector3(0, 1.5, 0)
	sb.add_child(col)
	p.add_child(sb)
	p.position = pos
	add_child(p)

func _spawn_player_and_camera() -> void:
	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 0)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	# 关键绑定: 相机跟随玩家(与 World.gd 同写法)
	_camera.follow_target = _camera.get_path_to(_player)

func _add_hint() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "MVP 探索 · WASD 移动 | 右键拖动转视角 | 空格跳跃"
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.position = Vector2(16, 16)
	layer.add_child(label)
	add_child(layer)
