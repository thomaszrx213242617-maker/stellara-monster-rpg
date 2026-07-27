extends Node3D

## 原创开场动画: 从「家」出发, 沿发光小径走向「沉眠之洞」入口。
## 借鉴《王国之泪》"启程旅行"的镜头语言(自创, 不抄任何素材); 玩家与伙伴·凛同行。
## 可跳过: 按 E / 空格 / Esc 直接结束 → 进入 OpeningCutscene(洞中苏醒)。
## 不依赖旁白: 仅用环境与镜头叙事。

const OPENING_SCENE := "res://ui/OpeningCutscene.tscn"

var _camera: Camera3D
var _player: Node3D
var _rin: Node3D
var _t: float = 0.0
var _duration: float = 17.0
var _transitioning: bool = false
var _fade: ColorRect
var _hint: Label

func _ready() -> void:
	_build_world()
	_build_ui()
	MusicBus.play_track("title")
	_camera.make_current()

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.12)
	env.ambient_light_energy = 0.5
	env.ambient_light_color = Color(0.6, 0.7, 1.0)
	env_node.environment = env

	# 夕照般的暖光(启程)
	var sun := DirectionalLight3D.new()
	sun.position = Vector3(10, 18, 8)
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(20), 0)
	sun.light_color = Color(1.0, 0.85, 0.6)
	sun.light_energy = 1.1
	add_child(sun)

	# 地面小径(家 z=+12 → 洞口 z=-115)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24, 150)
	ground.mesh = pm
	ground.rotate_x(deg_to_rad(-90))
	ground.position = Vector3(0, 0, -50)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.18, 0.16, 0.14)
	gmat.roughness = 0.95
	ground.material_override = gmat
	add_child(ground)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(24, 0.2, 150)
	col.shape = sh
	col.position = Vector3(0, -0.1, -50)
	sb.add_child(col)
	add_child(sb)

	# 家(盒身 + 盒顶 + 门), 位于小径起点
	var home := Node3D.new()
	home.position = Vector3(0, 0, 12)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 5, 6)
	body.mesh = bm
	body.position = Vector3(0, 2.5, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.7, 0.6, 0.45)
	hmat.roughness = 0.9
	body.material_override = hmat
	home.add_child(body)
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(7, 1.4, 7)
	roof.mesh = rm
	roof.position = Vector3(0, 5.7, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.5, 0.3, 0.25)
	roof.material_override = rmat
	home.add_child(roof)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.6, 3, 0.3)
	door.mesh = dm
	door.position = Vector3(0, 1.5, 3.05)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.2, 0.12, 0.08)
	door.material_override = dmat
	home.add_child(door)
	add_child(home)

	# 沿路发光晶簇(深处质感提前铺垫)
	for k in range(8):
		var z := 4.0 - float(k) * 14.0
		var x := (4.0 if k % 2 == 0 else -4.0)
		var cp := MeshInstance3D.new()
		var cpm := CylinderMesh.new()
		cpm.top_radius = 0.35
		cpm.bottom_radius = 0.35
		cpm.height = 2.4
		cp.mesh = cpm
		cp.position = Vector3(x, 1.2, z)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.2, 0.4, 0.5)
		cmat.metallic = 0.3
		cmat.emission_enabled = true
		cmat.emission = Color(0.4, 0.85, 1.0)
		cmat.emission_energy_multiplier = 0.9
		cp.material_override = cmat
		add_child(cp)
		var gl := OmniLight3D.new()
		gl.position = Vector3(x, 2.0, z)
		gl.light_color = Color(0.4, 0.85, 1.0)
		gl.light_energy = 1.0
		gl.omni_range = 8.0
		add_child(gl)

	# 洞口拱门(小径尽头, 紫光), 提示"沉眠之洞"
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.3, 0.2, 0.45)
	arch_mat.emission_enabled = true
	arch_mat.emission = Color(0.7, 0.4, 1.0)
	arch_mat.emission_energy_multiplier = 1.1
	for ax in [-3, 3]:
		var p := MeshInstance3D.new()
		var pm2 := BoxMesh.new()
		pm2.size = Vector3(0.8, 7, 0.8)
		p.mesh = pm2
		p.position = Vector3(ax, 3.5, -115)
		p.material_override = arch_mat
		add_child(p)
	var atop := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(7.5, 0.8, 0.8)
	atop.mesh = tm
	atop.position = Vector3(0, 7, -115)
	atop.material_override = arch_mat
	add_child(atop)
	var agl := OmniLight3D.new()
	agl.position = Vector3(0, 3, -112)
	agl.light_color = Color(0.8, 0.5, 1.0)
	agl.light_energy = 2.2
	agl.omni_range = 16.0
	add_child(agl)

	# 玩家(简版胶囊)与伙伴·凛(同行)
	_player = _make_walker(Color(0.25, 0.55, 1.0), Vector3(0, 1, 10))
	add_child(_player)
	_rin = _make_walker(Color(0.6, 0.8, 1.0), Vector3(2.2, 1, 13))
	add_child(_rin)

	# 摄像机(本场景由脚本直接控制)
	_camera = Camera3D.new()
	_camera.position = Vector3(7, 7, 26)
	add_child(_camera)

func _make_walker(color: Color, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.32
	bm.height = 0.7
	body.mesh = bm
	body.position = Vector3(0, 0.55, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = color
	body.material_override = bmat
	n.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.42
	hm.height = 0.6
	head.mesh = hm
	head.position = Vector3(0, 1.15, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.98, 0.85, 0.72)
	head.material_override = hmat
	n.add_child(head)
	return n

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.text = "（开场动画 · 按 E / 空格 / Esc 跳过）"
	_hint.position = Vector2(12, 12)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.modulate = Color(0.9, 0.9, 1.0)
	layer.add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate = Color(0, 0, 0, 0)
	layer.add_child(_fade)

func _process(delta: float) -> void:
	if _transitioning:
		# 黑场淡入中
		_fade.modulate.a = min(1.0, _fade.modulate.a + delta * 2.2)
		return
	# 跳过
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_cancel"):
		_skip()
		return
	_t += delta
	var p: float = clamp(_t / _duration, 0.0, 1.0)
	# 玩家与凛沿小径前行(家→洞口)
	_player.position.z = lerp(10.0, -110.0, p)
	_rin.position.z = _player.position.z + 3.0
	_rin.position.x = lerp(2.2, 0.6, p)
	# 镜头: 从家的远景建立镜头, 渐变为跟随
	var cam_start := Vector3(7, 7, 26)
	var cam_end := Vector3(0, 4.5, _player.position.z + 12)
	_camera.global_position = lerp(cam_start, cam_end, p)
	_camera.look_at(Vector3(_player.position.x, 2.0, _player.position.z - 4.0))
	# 自动结束
	if p >= 1.0:
		_skip()

func _skip() -> void:
	if _transitioning:
		return
	_transitioning = true
	_hint.text = ""
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file(OPENING_SCENE)
