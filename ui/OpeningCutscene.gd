extends Node3D

## 原创开场(借鉴《王国之泪》"在神秘之地苏醒→伙伴在场开口引导→探索环境→向前进入"的进入方式, 文案全原创, 与任天堂无关)。
## 玩法: 玩家直接在 3D 洞厅中醒来并可操控; 伙伴·凛开口交代背景(无旁白); 可走近碑文按 E 查看线索;
##       向前(走入洞口)即进入 PrologueExplore(洞中探险/对话/战斗)。
## 由 TitleScreen「开始新游戏」后进入; 走完衔接 PrologueExplore → OpeningCollapse → PrologueCutscene → World。

const PlayerScript := preload("res://world/PlayerController.gd")
const CameraScript := preload("res://world/CameraRig.gd")
const DialogueScript := preload("res://ui/DialogueBox.gd")
const NpcScript := preload("res://world/Npc.gd")

var _player
var _camera
var _dialogue: Node
var _rin: Node
var _hint: Label
var _toast: Label
var _toast_t: float = 0.0
var _inscription: Node3D
var _near_inscription: bool = false
var _inscription_done: bool = false
var _exiting: bool = false

func _ready() -> void:
	GameState.current_scene = "res://ui/OpeningCutscene.tscn"
	_build_world()
	_build_ui()
	# 苏醒即由伙伴·凛开口交代背景(代替旁白)
	if _dialogue and _dialogue.has_method("start"):
		_dialogue.start(_rin.lines)
	MusicBus.play_track("overworld")

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.09)
	env.ambient_light_energy = 0.55
	env.ambient_light_color = Color(0.5, 0.6, 0.9)
	env_node.environment = env

	# 冷色「星光」自上方洒下
	var moon := DirectionalLight3D.new()
	moon.position = Vector3(3, 16, 4)
	moon.rotation = Vector3(deg_to_rad(-60), 0, 0)
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = 0.9
	add_child(moon)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 7, 0)
	glow.light_color = Color(0.6, 0.8, 1.0)
	glow.light_energy = 1.2
	glow.omni_range = 22.0
	add_child(glow)

	# 地面
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 50)
	ground.mesh = pm
	ground.rotate_x(deg_to_rad(-90))
	add_child(ground)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(40, 0.2, 50)
	col.shape = sh
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

	# 三面石壁(后方 + 两侧), 前方留作洞口; 缝隙透冷光, 与「深处」风格一致
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.16, 0.17, 0.22)
	wmat.roughness = 0.9
	wmat.emission_enabled = true
	wmat.emission = Color(0.2, 0.5, 0.8)
	wmat.emission_energy_multiplier = 0.3
	for spec in [Vector3(0, 4, 16), Vector3(-9, 4, 0), Vector3(9, 4, 0)]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		if spec.z == 0:
			wm.size = Vector3(2, 8, 54)
		else:
			wm.size = Vector3(40, 8, 2)
		wall.mesh = wm
		wall.position = spec
		wall.material_override = wmat
		add_child(wall)

	# 入口处的发光晶簇(深处质感)
	for cx in [-6, 6]:
		var cp := MeshInstance3D.new()
		var cpm := CylinderMesh.new()
		cpm.top_radius = 0.4
		cpm.bottom_radius = 0.4
		cpm.height = 3.2
		cp.mesh = cpm
		cp.position = Vector3(cx, 1.6, 4)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.2, 0.4, 0.5)
		cmat.metallic = 0.3
		cmat.emission_enabled = true
		cmat.emission = Color(0.4, 0.85, 1.0)
		cmat.emission_energy_multiplier = 0.9
		cp.material_override = cmat
		add_child(cp)

	# 洞口(前方)的微光, 提示前进方向
	var exit_glow := OmniLight3D.new()
	exit_glow.position = Vector3(0, 2, -8)
	exit_glow.light_color = Color(0.9, 0.85, 0.6)
	exit_glow.light_energy = 1.4
	exit_glow.omni_range = 10.0
	add_child(exit_glow)

	# 碑文(可探索线索)
	_inscription = Node3D.new()
	_inscription.position = Vector3(-4, 0, 0)
	var stele := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.8, 2.2, 0.4)
	stele.mesh = sm
	stele.position = Vector3(0, 1.1, 0)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.35, 0.5)
	smat.emission_enabled = true
	smat.emission = Color(0.2, 0.7, 1.0)
	smat.emission_energy_multiplier = 0.8
	stele.material_override = smat
	_inscription.add_child(stele)
	var slab_light := OmniLight3D.new()
	slab_light.position = Vector3(0, 1.6, 0)
	slab_light.light_color = Color(0.4, 0.9, 1.0)
	slab_light.light_energy = 1.6
	slab_light.omni_range = 6.0
	_inscription.add_child(slab_light)
	var tag := Label3D.new()
	tag.text = "碑文"
	tag.position = Vector3(0, 2.6, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 28
	_inscription.add_child(tag)
	add_child(_inscription)

	# 玩家
	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 8)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 对话 UI + 伙伴·凛(开口引导, 代替旁白)
	var dlayer := CanvasLayer.new()
	add_child(dlayer)
	_dialogue = DialogueScript.new()
	_dialogue.name = "DialogueBox"
	dlayer.add_child(_dialogue)
	_rin = NpcScript.new()
	_rin.position = Vector3(3, 1, 2)
	_rin.display_name = "伙伴·凛"
	_rin.npc_color = Color(0.6, 0.8, 1.0)
	_rin.lines = [
		"凛：「你醒了？我们就在这『沉眠之洞』的入口。昨夜你一直念着那两头金属神兽的名字。」",
		"凛：「你腕上这三枚秘环——巨灵、晶变、超衍，每种力量在一场战斗里只能用一次，关键时刻别浪费。」",
		"凛：「洞厅里有野灵兽游荡，派灵兽迎战，别让它们伤着你。」",
		"凛：「小岚和阿砂已经先去洞里探路了。等咱们汇合，四个一起闯封印之地。」",
		"凛：(伸手拉你起来) 「别怕。不管是野灵兽还是那两头神兽，我都陪着你。」"
	]
	_rin.player_ref = _player
	_rin.dialogue_box = _dialogue
	_rin.follow_target = _player
	add_child(_rin)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.text = "WASD移动 | 右键转视角 | 空格跳 | E 与凛对话 / 查看碑文 | 向前(洞口微光处)走入沉眠之洞"
	_hint.position = Vector2(12, 12)
	layer.add_child(_hint)
	_toast = Label.new()
	_toast.position = Vector2(360, 200)
	_toast.scale = Vector2(1.3, 1.3)
	_toast.modulate = Color(1.0, 0.7, 0.4)
	_toast.text = ""
	layer.add_child(_toast)

func _show_toast(text: String) -> void:
	if _toast:
		_toast.text = text
		_toast_t = 3.0

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.text = ""
	if _player == null or _exiting:
		return
	# 碑文: 靠近按 E 查看线索(凛口述, 无旁白)
	var d: float = _inscription.global_position.distance_to(_player.global_position)
	_near_inscription = d < 3.2
	if _near_inscription:
		_hint.text = "按 E 查看碑文"
		if not _inscription_done and Input.is_action_just_pressed("interact") and (_dialogue == null or not _dialogue.active):
			_inscription_done = true
			if _dialogue and _dialogue.has_method("start"):
				_dialogue.start([
					"凛（望着碑文）：「一龙，一兽，都泛着金属的光泽……传说，这就是双生神兽的封印。」",
					"凛：「可你看——石缝里正渗出暗紫色的雾气。黯潮，已经渗进来了。」"
				])
	else:
		_hint.text = "WASD移动 | 右键转视角 | 空格跳 | E 与凛对话 / 查看碑文 | 向前(洞口微光处)走入沉眠之洞"
	# 向前走入洞口 → 进入洞中探险(加长入口, 走得更远才到洞口)
	if _player.global_position.z < -8.0:
		_exiting = true
		_show_toast("你步入沉眠之洞……")
		GameState.opening_done = true
		SaveManager.save_game()
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file("res://world/PrologueExplore.tscn")
