extends Node3D

## 原创可探索序章(冠军纪元 · 洞中探险): 真实行走 + 与凛对话 + 洞中野怪真实战斗。
## 场景风格借鉴《王国之泪》"地下遗迹/深渊"的发光质感(自创: 发光晶壁、光苔、晶柱、漂浮光点, 不抄任何素材)。
## 衔接: OpeningCutscene(苏醒·洞入口) → 本场景(长走廊探险/对话/战斗) → 真实双生神兽战(盟友协同) →
##       战败 → OpeningCollapse(旁白) → PrologueCutscene(新伙伴·在家苏醒) → World。

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
var _motes: Array = []
var _pickups: Array = []
var _page_flags: Array = ["page_1", "page_2", "page_3"]
var _t: float = 0.0

func _ready() -> void:
	Game.current_scene = "res://world/PrologueExplore.tscn"
	Game.set_objective_target(Vector3(0, 0, -150))   # 序章目标: 洞穴深处封印之地
	_build_world()
	_build_ui()
	if Game.prologue_scout_done:
		_show_toast("侦查战已结束。沿着发光晶壁，向洞穴深处前进。")
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["凛：「就是这里了……前面有股不祥的气息。我们进去吧。」"])
	else:
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["凛：「这洞里似乎有野灵兽游荡，小心些。派你的灵兽迎战！」"])

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)   # 深渊般的暗蓝
	env.ambient_light_energy = 0.32
	env.ambient_light_color = Color(0.35, 0.5, 0.7)
	env_node.environment = env

	# 高处一束冷色"天光"洒入裂隙(地下遗迹常见的微光)
	var moon := DirectionalLight3D.new()
	moon.position = Vector3(6, 20, 4)
	moon.rotation = Vector3(deg_to_rad(-62), 0, 0)
	moon.light_color = Color(0.6, 0.75, 1.0)
	moon.light_energy = 0.55
	add_child(moon)

	# 地面(长走廊): 60 x 320, 覆盖从洞口到封印之地
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 320)
	ground.mesh = pm
	ground.rotate_x(deg_to_rad(-90))
	ground.position = Vector3(0, 0, -40)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.06, 0.08, 0.12)
	gmat.roughness = 0.85
	gmat.metallic = 0.1
	ground.material_override = gmat
	add_child(ground)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(60, 0.2, 320)
	col.shape = sh
	col.position = Vector3(0, -0.1, -40)
	sb.add_child(col)
	add_child(sb)

	# 两侧晶壁(发光岩壁, 借鉴"地下遗迹"质感, 自创配色)
	for x in [-14, 14]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(2, 9, 320)
		wall.mesh = wm
		wall.position = Vector3(x, 4.5, -40)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.10, 0.13, 0.20)
		wmat.roughness = 0.7
		wmat.metallic = 0.2
		# 岩壁缝隙透出冷光(自发光), 营造"深处发光"观感
		wmat.emission_enabled = true
		wmat.emission = Color(0.15, 0.45, 0.7)
		wmat.emission_energy_multiplier = 0.35
		wall.material_override = wmat
		add_child(wall)

	# 沿路发光晶柱(两侧交错) + 部分带点光源
	var pillar_z := [-12, -36, -60, -84, -108, -132, -156]
	var lit_idx := [1, 3, 5, 6]   # 这几根晶柱带真实点光, 其余仅靠自发光
	for i in range(pillar_z.size()):
		for x in [-10, 10]:
			_add_crystal_pillar(Vector3(x, 0, pillar_z[i]), (i % 2 == 0))
			if i in lit_idx:
				var gl := OmniLight3D.new()
				gl.position = Vector3(x * 0.7, 2.4, pillar_z[i])
				gl.light_color = Color(0.4, 0.85, 1.0) if (i % 2 == 0) else Color(0.75, 0.5, 1.0)
				gl.light_energy = 1.3
				gl.omni_range = 12.0
				add_child(gl)

	# 漂浮光点(深渊萤火)
	for k in range(10):
		var z := -10.0 - float(k) * 15.0
		var x := (0.5 if k % 2 == 0 else -0.5) * (6.0 + float(k % 3) * 2.0)
		_add_mote(Vector3(x, 1.4 + float(k % 4) * 0.5, z))

	# 中途路牌: 提示更深处方向
	_add_signpost(Vector3(0, 0, -70), "更深处 · 双生神兽封印  →")
	# 发光桥地标(暖色, 作为行进中的落脚记忆点)
	var bridge := MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(8, 10)
	bridge.mesh = bm
	bridge.rotate_x(deg_to_rad(-90))
	bridge.position = Vector3(0, 0.05, -110)
	var brmat := StandardMaterial3D.new()
	brmat.albedo_color = Color(0.3, 0.4, 0.55)
	brmat.emission_enabled = true
	brmat.emission = Color(0.6, 0.8, 1.0)
	brmat.emission_energy_multiplier = 0.7
	bridge.material_override = brmat
	add_child(bridge)
	var bl := OmniLight3D.new()
	bl.position = Vector3(0, 2.2, -110)
	bl.light_color = Color(0.7, 0.85, 1.0)
	bl.light_energy = 1.6
	bl.omni_range = 14.0
	add_child(bl)

	# 封印之地(深处): 强紫光拱门, 提示神兽所在
	_add_seal_arch(Vector3(0, 0, -156))

	# 可探索拾取: 辉光结晶(补给) + 封印残页(小谜题)
	_add_crystal_pickup(Vector3(-9, 0, -28), "crystal_1", "potion", 1, "伤药")
	_add_crystal_pickup(Vector3(9, 0, -78), "crystal_2", "super_potion", 1, "好伤药")
	_add_crystal_pickup(Vector3(-9, 0, -128), "crystal_3", "ancient_ball", 1, "远古球")
	_add_page(Vector3(8, 0, -45), "page_1")
	_add_page(Vector3(-8, 0, -95), "page_2")
	_add_page(Vector3(8, 0, -135), "page_3")

	# 玩家
	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 18)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 对话 UI(CanvasLayer) + 三名伙伴(均跟随玩家, 与神兽战盟友一致)
	var dlayer := CanvasLayer.new()
	add_child(dlayer)
	_dialogue = DialogueScript.new()
	_dialogue.name = "DialogueBox"
	dlayer.add_child(_dialogue)
	_add_companion("伙伴·凛", Color(0.6, 0.8, 1.0), Vector3(3, 1, 14), [
		"凛：「你腕上的三枚秘环——巨灵、晶变、超衍，每种一场战斗只能用一次，关键时刻别浪费。」",
		"凛：「前面似乎有野灵兽在游荡。把灵兽派出来迎战，别让它们伤着你。」",
		"凛：「越往里走，岩壁里的光越亮……传说，这里是双生神兽的封印之地。」",
		"凛：「放心，小岚和阿砂都在后面跟着呢。咱们四个，一起闯过去。」",
		"凛：(压低声音) 「其实我也有点怕……但只要你在我身边，就没什么好怕的。」"
	])
	_add_companion("伙伴·小岚", Color(0.7, 0.9, 0.6), Vector3(-3, 1, 16), [
		"小岚：「我是巡林人，最熟悉这些洞窟。踩稳脚下的晶石，别滑倒。」",
		"小岚：「野灵兽怕光。要是它们围上来，你就往发光晶柱旁边靠。」",
		"小岚：「别看阿砂老是跟你较劲，真到危险时，他比谁都靠得住。」"
	])
	_add_companion("伙伴·阿砂", Color(0.95, 0.6, 0.5), Vector3(0, 1, 18), [
		"阿砂：「哼，这次就当陪你练练手。等收拾了那两头神兽，咱俩再好好比一场。」",
		"阿砂：「这封印之地的气息不对劲……黯潮，比传说里更浓。」",
		"阿砂：「走前面点！要挡刀也是我先上。」"
	])

func _add_crystal_pillar(pos: Vector3, cyan: bool) -> void:
	var p := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 4.5
	p.mesh = cm
	p.position = Vector3(pos.x, 2.25, pos.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.5) if cyan else Color(0.4, 0.3, 0.55)
	mat.roughness = 0.3
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 1.0) if cyan else Color(0.7, 0.4, 1.0)
	mat.emission_energy_multiplier = 0.9
	p.material_override = mat
	add_child(p)

func _add_mote(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	m.mesh = sm
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.4
	m.material_override = mat
	add_child(m)
	_motes.append({"node": m, "base": pos.y, "phase": randf() * TAU})

func _add_signpost(pos: Vector3, text: String) -> void:
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.3, 2.4, 0.3)
	post.mesh = pm
	post.position = Vector3(pos.x, 1.2, pos.z + 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.18)
	post.material_override = mat
	add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, 1.0, 0.2)
	board.mesh = bm
	board.position = Vector3(pos.x, 2.2, pos.z + 1.2)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.5, 0.4, 0.3)
	bmat.emission_enabled = true
	bmat.emission = Color(0.4, 0.6, 0.5)
	bmat.emission_energy_multiplier = 0.4
	board.material_override = bmat
	add_child(board)
	var tag := Label3D.new()
	tag.text = text
	tag.position = Vector3(pos.x, 2.2, pos.z + 1.32)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 32
	tag.modulate = Color(1, 1, 1)
	add_child(tag)

func _add_seal_arch(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.4, 1.0)
	mat.emission_energy_multiplier = 1.1
	for x in [-3, 3]:
		var p := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.8, 7, 0.8)
		p.mesh = pm
		p.position = Vector3(pos.x + x, 3.5, pos.z)
		p.material_override = mat
		add_child(p)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(7.5, 0.8, 0.8)
	top.mesh = tm
	top.position = Vector3(pos.x, 7, pos.z)
	top.material_override = mat
	add_child(top)
	var gl := OmniLight3D.new()
	gl.position = Vector3(pos.x, 3, pos.z)
	gl.light_color = Color(0.8, 0.5, 1.0)
	gl.light_energy = 2.4
	gl.omni_range = 18.0
	add_child(gl)

## 创建一名跟随伙伴(玩家走动时自动尾随, 靠近按 E 对话)
func _add_companion(name: String, color: Color, pos: Vector3, lines: Array) -> void:
	var n := NpcScript.new()
	n.position = pos
	n.display_name = name
	n.npc_color = color
	n.lines = lines
	n.player_ref = _player
	n.dialogue_box = _dialogue
	n.follow_target = _player
	add_child(n)

## 辉光结晶拾取(一次性, flags 记录): 走近按 E 获得补给
func _add_crystal_pickup(pos: Vector3, flag: String, item: String, qty: int, hint: String) -> void:
	var n := Node3D.new()
	n.position = pos
	var cm := MeshInstance3D.new()
	var cym := CylinderMesh.new()
	cym.top_radius = 0.35
	cym.bottom_radius = 0.35
	cym.height = 1.6
	cm.mesh = cym
	cm.position = Vector3(0, 0.8, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 0.9)
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.2
	cm.material_override = mat
	n.add_child(cm)
	var gl := OmniLight3D.new()
	gl.position = Vector3(0, 1.2, 0)
	gl.light_color = Color(0.4, 0.9, 1.0)
	gl.light_energy = 1.6
	gl.omni_range = 7.0
	n.add_child(gl)
	var tag := Label3D.new()
	tag.text = "辉光结晶"
	tag.position = Vector3(0, 2.0, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 28
	n.add_child(tag)
	add_child(n)
	_pickups.append({"node": n, "flag": flag, "item": item, "qty": qty, "hint": hint, "kind": "crystal"})

## 封印残页(小谜题: 集齐 2/3 解锁线索 + 奖励)
func _add_page(pos: Vector3, flag: String) -> void:
	var n := Node3D.new()
	n.position = pos
	var pm := MeshInstance3D.new()
	var pbm := BoxMesh.new()
	pbm.size = Vector3(0.5, 0.7, 0.05)
	pm.mesh = pbm
	pm.position = Vector3(0, 1.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.5)
	mat.emission_energy_multiplier = 0.8
	pm.material_override = mat
	n.add_child(pm)
	var gl := OmniLight3D.new()
	gl.position = Vector3(0, 1.2, 0)
	gl.light_color = Color(1.0, 0.85, 0.5)
	gl.light_energy = 1.2
	gl.omni_range = 5.0
	n.add_child(gl)
	var tag := Label3D.new()
	tag.text = "封印残页"
	tag.position = Vector3(0, 1.7, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 26
	n.add_child(tag)
	add_child(n)
	_pickups.append({"node": n, "flag": flag, "item": "", "qty": 0, "hint": "封印残页", "kind": "page"})

func _collect_pickup(pk: Dictionary) -> void:
	if pk["node"] != null:
		pk["node"].visible = false
	Game.flags[pk["flag"]] = true
	if pk["kind"] == "crystal":
		Game.add_item(pk["item"], pk["qty"])
		_show_toast("获得 " + pk["hint"] + " ×" + str(pk["qty"]))
	else:
		_show_toast("拾得 " + pk["hint"])
	SFX.play_sfx("levelup")
	if pk["kind"] == "page":
		_check_page_puzzle()

## 封印残页小谜题: 集齐 2/3 → 凛解读线索 + 好伤药 ×2
func _check_page_puzzle() -> void:
	var got: int = 0
	for f in _page_flags:
		if Game.flags.get(f, false):
			got += 1
	if got >= 2 and not Game.flags.get("page_reward", false):
		Game.flags["page_reward"] = true
		Game.add_item("super_potion", 2)
		_show_toast("集齐封印残页！凛解读线索，获好伤药 ×2")
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start([
				"凛：「残页上写着：『双生神兽，一金一暗。金者镇于东岭，暗者沉于深渊。』」",
				"凛：「原来它们的封印是分开的……封印之地只是入口，真正的深处还在下面。」"
			])

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
	# 目标方向罗盘(指向洞穴深处封印之地)
	var compass = load("res://ui/ObjectiveCompass.gd").new()
	add_child(compass)

func _show_toast(text: String) -> void:
	if _toast:
		_toast.text = text
		_toast_t = 2.5

func _process(delta: float) -> void:
	_t += delta
	# 光点轻微浮动
	for m in _motes:
		if m["node"]:
			m["node"].position.y = m["base"] + sin(_t * 1.5 + m["phase"]) * 0.3
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.text = ""
	if _player == null:
		return
	Game.player_position = _player.global_position
	# 拾取物: 晶簇 / 封印残页(靠近按 E)
	for pk in _pickups:
		if pk["node"] == null or not pk["node"].visible:
			continue
		if pk["node"].global_position.distance_to(_player.global_position) < 2.6:
			_hint.text = "按 E 拾取：" + pk["hint"]
			if Input.is_action_just_pressed("interact"):
				_collect_pickup(pk)
			return
	# 洞厅野怪侦查战(走入 z < -15 触发, 给一点热身距离)
	if not Game.prologue_scout_done and not _scout_triggered:
		if _player.global_position.z < -15.0:
			_scout_triggered = true
			_start_scout_battle()
			return
	# 已完成侦查战: 接近封印之地(z < -150) 按 E 进入神兽战
	if Game.prologue_scout_done:
		if _player.global_position.z < -150.0:
			_in_depth = true
			_hint.text = "按 E 进入双生神兽的封印之地……"
			if Input.is_action_just_pressed("interact"):
				_enter_depth()
		else:
			_in_depth = false
			_hint.text = "WASD移动 | 右键转视角 | 空格跳 | E 与凛对话 | 沿发光晶壁向洞穴深处前进"

func _start_scout_battle() -> void:
	_show_toast("洞中有异动——野灵兽袭来！迎战！")
	# 确保首发灵兽以满血迎战(避免上一场残留低血)
	if not Game.team.is_empty() and Game.team[0].has("max_hp"):
		Game.team[0]["hp"] = int(Game.team[0]["max_hp"])
	Game.prologue_scout_done = true
	Game.battle_return_scene = "res://world/PrologueExplore.tscn"
	Game.pending_wild = {"id": "shadepup", "level": 6}
	get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

## 双生神兽战: 真实对战(凛/小岚/阿砂 协同), 战败后才播旁白。
func _enter_depth() -> void:
	_show_toast("封印之地的气流将你掀翻——双生神兽，就在眼前！")
	Game.prologue_beast_mode = true
	Game.pending_raid = {
		"boss_id": "hui_jin_long",
		"boss_level": 42,
		"allies": ["伙伴·凛", "伙伴·小岚", "伙伴·阿砂"]
	}
	# 不设置 battle_return_scene: 战败由 BattleArena 直接转入 OpeningCollapse 旁白
	get_tree().change_scene_to_file("res://battle/BattleArena.tscn")
