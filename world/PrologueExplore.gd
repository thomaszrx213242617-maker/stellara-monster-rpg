extends Node3D

## 原创可探索序章(冠军纪元 · 洞中探险): 真实行走 + 与凛对话 + 洞中野怪真实战斗。
## 衔接: OpeningCutscene(冠军背景) → 本场景(探险/对话/战斗) → OpeningCollapse(神兽苏醒·败北·宝可梦消失) → PrologueCutscene(新伙伴)。

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
var _scout_triggered: bool = false
var _in_depth: bool = false

func _ready() -> void:
	GameState.current_scene = "res://world/PrologueExplore.tscn"
	_build_world()
	_build_ui()
	if GameState.prologue_scout_done:
		_show_toast("侦查战已结束。向洞穴深处前进，按 E 进入。")
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["凛：「就是这里了……前面有股不祥的气息。我们进去吧。」"])
	else:
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["凛：「这洞里似乎有野灵兽游荡，小心些。派你的灵兽迎战！」"])
	MusicBus.play_track("overworld")

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_energy = 0.5
	env_node.environment = env

	var light := DirectionalLight3D.new()
	light.position = Vector3(4, 14, 6)
	light.rotation = Vector3(deg_to_rad(-55), 0, 0)
	light.light_energy = 0.9
	add_child(light)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 80)
	ground.mesh = pm
	ground.rotate_x(deg_to_rad(-90))
	add_child(ground)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(60, 0.2, 80)
	col.shape = sh
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 12)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 洞壁装饰(两侧石壁)
	for x in [-14, 14]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(2, 8, 80)
		wall.mesh = wm
		wall.position = Vector3(x, 4, -10)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.18, 0.18, 0.22)
		wall.material_override = wmat
		add_child(wall)

	# 对话 UI(CanvasLayer) + 凛 NPC(真实对话)
	var dlayer := CanvasLayer.new()
	add_child(dlayer)
	_dialogue = DialogueScript.new()
	_dialogue.name = "DialogueBox"
	dlayer.add_child(_dialogue)
	_rin = NpcScript.new()
	_rin.position = Vector3(3, 1, 8)
	_rin.display_name = "伙伴·凛"
	_rin.npc_color = Color(0.6, 0.8, 1.0)
	_rin.lines = [
		"凛：「你腕上的三枚秘环——巨灵、晶变、超衍，每种一场战斗只能用一次，关键时刻别浪费。」",
		"凛：「前面似乎有野灵兽在游荡。把灵兽派出来迎战，别让它们伤到你。」",
		"凛：「等穿过这片洞厅，深处就是双生神兽的封印了。我总有点不安……」"
	]
	_rin.player_ref = _player
	_rin.dialogue_box = _dialogue
	add_child(_rin)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.text = "WASD移动 | 右键转视角 | 空格跳 | E 与凛对话 / 进入深处 | 走入洞厅触发野怪战斗"
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
		_toast_t = 2.5

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.text = ""
	if _player == null:
		return
	# 洞厅野怪侦查战(未完成时, 走入 z < -2 触发)
	if not GameState.prologue_scout_done and not _scout_triggered:
		if _player.global_position.z < -2.0:
			_scout_triggered = true
			_start_scout_battle()
			return
	# 已完成侦查战: 接近洞穴深处(z < -30) 按 E 进入
	if GameState.prologue_scout_done:
		if _player.global_position.z < -30.0:
			_in_depth = true
			_hint.text = "按 E 进入洞穴深处……"
			if Input.is_action_just_pressed("interact"):
				get_tree().change_scene_to_file("res://ui/OpeningCollapse.tscn")
		else:
			_in_depth = false
			_hint.text = "WASD移动 | 右键转视角 | 空格跳 | E 与凛对话 | 向洞穴深处前进"

func _start_scout_battle() -> void:
	_show_toast("洞中有异动——野灵兽袭来！迎战！")
	GameState.prologue_scout_done = true
	GameState.battle_return_scene = "res://world/PrologueExplore.tscn"
	GameState.pending_wild = {"id": "shadepup", "level": 6}
	get_tree().change_scene_to_file("res://battle/BattleArena.tscn")
