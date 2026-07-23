extends Node3D
class_name World

## 探索场景: 代码构建世界(环境/光照/地面/玩家/相机/遭遇区/中心/NPC)。
## 核心循环: 走进草丛 → 随机遭遇野怪 → 实时战斗 → 击败得经验/收服 → 回世界
##          → 宝可梦中心(按 E)治疗并自动存档。夜间按 C 收服被拒(见 REQUIREMENTS §8)。
## 阿尔宙斯式内容: 首领灵兽(alpha, 游荡发光、靠近按E挑战可收服)、时空裂隙(周期激活触发稀有遭遇)、
##              图鉴研究任务(收服/击败指定属性)。

const PlayerScript := preload("res://world/PlayerController.gd")
const CameraScript := preload("res://world/CameraRig.gd")
const DialogueScript := preload("res://ui/DialogueBox.gd")
const CenterScript := preload("res://world/CenterZone.gd")
const GymScript := preload("res://world/GymZone.gd")
const NpcScript := preload("res://world/Npc.gd")
const EncounterScript := preload("res://world/EncounterZone.gd")
const AlphaScript := preload("res://world/AlphaBeast.gd")
const RiftScript := preload("res://world/RiftZone.gd")

var _player
var _camera
var _env: Environment
var _light: DirectionalLight3D
var _time_label: Label
var _team_label: Label
var _dialogue: Node
var _npc
var _encounter_cd: float = 0.0
var _in_center: bool = false
var _center_label: Label
var _in_gym: bool = false
var _gym_label: Label
var _alpha_label: Label
var _research_label: Label
var _alpha
var _rift

func _ready() -> void:
	build_world()
	_build_ui()
	DayNight.time_changed.connect(_on_time)
	_on_time(0.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "WASD移动 | 右键转视角 | 空格跳 | 草丛遇野怪 | 中心/道馆按E | B随机遭遇 | 夜晚禁收服 | 发光首领按E挑战 | 紫裂隙激活靠近触发"
	hint.position = Vector2(12, 12)
	layer.add_child(hint)
	var t := Label.new()
	t.name = "TimeLabel"
	t.position = Vector2(12, 36)
	layer.add_child(t)
	_time_label = t

	_team_label = Label.new()
	_team_label.position = Vector2(12, 360)
	_team_label.custom_minimum_size = Vector2(320, 160)
	layer.add_child(_team_label)

	_center_label = Label.new()
	_center_label.position = Vector2(12, 330)
	_center_label.text = ""
	layer.add_child(_center_label)

	_gym_label = Label.new()
	_gym_label.position = Vector2(12, 354)
	_gym_label.text = ""
	layer.add_child(_gym_label)

	_research_label = Label.new()
	_research_label.position = Vector2(420, 12)
	layer.add_child(_research_label)

	_alpha_label = Label.new()
	_alpha_label.position = Vector2(260, 280)
	_alpha_label.scale = Vector2(1.4, 1.4)
	_alpha_label.text = ""
	layer.add_child(_alpha_label)

	_dialogue = DialogueScript.new()
	_dialogue.name = "DialogueBox"
	layer.add_child(_dialogue)
	if _npc:
		_npc.dialogue_box = _dialogue

func _on_time(_t: float) -> void:
	if _time_label:
		_time_label.text = "时间: " + DayNight.phase_label() + (" (禁止收服)" if DayNight.is_night else "")

func build_world() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.6, 0.75, 0.95)
	_env.ambient_light_energy = 0.6
	env_node.environment = _env

	_light = DirectionalLight3D.new()
	_light.position = Vector3(10, 25, 10)
	_light.rotation = Vector3(deg_to_rad(-55), 0, 0)
	_light.light_energy = 1.2
	add_child(_light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.rotate_x(deg_to_rad(-90))
	add_child(ground)

	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 0.2, 80)
	col.shape = shape
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

	# 实心房屋(不可穿墙, 像现实里的建筑)——固定位置避免压住出生点/中心/道馆
	_add_house(Vector3(-12, 0, 8),  Vector3(4, 3, 4), Color(0.85, 0.7, 0.5))
	_add_house(Vector3(10, 0, -6),  Vector3(5, 4, 5), Color(0.7, 0.8, 0.6))
	_add_house(Vector3(-18, 0, -10), Vector3(4, 3, 4), Color(0.8, 0.6, 0.6))
	_add_house(Vector3(14, 0, 14),  Vector3(3, 2.5, 3), Color(0.6, 0.7, 0.85))
	_add_house(Vector3(-6, 0, 16),  Vector3(4, 3.5, 4), Color(0.9, 0.85, 0.6))
	_add_house(Vector3(20, 0, 4),   Vector3(5, 4, 5), Color(0.75, 0.65, 0.8))

	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 0)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 野怪遭遇区(草丛)
	_add_encounter_zone(Vector3(-14, 0, -8), ["flarefox", "vinelop", "windpip"], 2, 6)
	_add_encounter_zone(Vector3(16, 0, 6), ["aqualeap", "bouldon", "shadepup", "ironhide"], 3, 7)
	_add_encounter_zone(Vector3(-10, 0, 16), ["voltmink", "spiritbud", "lumiadeer"], 3, 8)

	# 宝可梦中心
	var center := CenterScript.new()
	center.position = Vector3(0, 0, -22)
	center.body_entered.connect(_on_center_enter)
	center.body_exited.connect(_on_center_exit)
	add_child(center)

	# 道馆 (按 E 挑战馆主, 胜利获得徽章)
	var gym := GymScript.new()
	gym.position = Vector3(22, 0, -18)
	gym.body_entered.connect(_on_gym_enter)
	gym.body_exited.connect(_on_gym_exit)
	add_child(gym)

	# 首领灵兽(阿尔宙斯式 alpha): 大体型发光、领地游荡、靠近按E挑战(可收服)
	_alpha = AlphaScript.new()
	_alpha.position = Vector3(-22, 0, 6)
	add_child(_alpha)

	# 时空裂隙: 周期激活, 激活时靠近触发稀有金属遭遇
	_rift = RiftScript.new()
	_rift.position = Vector3(8, 0, -14)
	add_child(_rift)

	# NPC
	var npc := NpcScript.new()
	npc.name = "Npc"
	npc.position = Vector3(4, 1, -19)
	npc.player_ref = _player
	npc.lines = [
		"旅行者，欢迎来到星澜地区。",
		"这里的灵兽可在战斗中收服，但切记——夜晚黯潮汹涌，无法收服灵兽。",
		"近来出现了会发光的「首领灵兽」在旷野游荡，靠近按 E 可挑战(也能收服)。",
		"紫色的「时空裂隙」会周期性开启，激活时靠近会遭遇稀有金属灵兽。",
		"调查任务：去收服或击败 3 只金属性(金)灵兽，完成后领取远古球。"
	]
	_npc = npc
	add_child(npc)

func _add_house(pos: Vector3, size: Vector3, color: Color) -> void:
	var house := Node3D.new()
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = Vector3(0, size.y / 2.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	house.add_child(m)
	# 屋顶
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.1
	rm.bottom_radius = max(size.x, size.z) * 0.75
	rm.height = 1.2
	roof.mesh = rm
	roof.position = Vector3(0, size.y + 0.6, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.4, 0.3, 0.3)
	roof.material_override = rmat
	house.add_child(roof)
	# 实体碰撞: 玩家无法穿过房屋
	var sbh := StaticBody3D.new()
	var scol := CollisionShape3D.new()
	var ssh := BoxShape3D.new()
	ssh.size = size
	scol.shape = ssh
	scol.position = Vector3(0, size.y / 2.0, 0)
	sbh.add_child(scol)
	house.add_child(sbh)
	house.position = pos
	add_child(house)

func _add_encounter_zone(pos: Vector3, pool: Array, lmin: int, lmax: int) -> void:
	var z := EncounterScript.new()
	z.position = pos
	z.pool = pool
	z.lvl_min = lmin
	z.lvl_max = lmax
	z.triggered.connect(_on_encounter)
	add_child(z)

func _on_encounter(creature_id: String, level: int) -> void:
	if _encounter_cd > 0.0:
		return
	_encounter_cd = 2.5
	GameState.pending_wild = {"id": creature_id, "level": level}
	get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

func _on_center_enter(b: Node) -> void:
	if b == _player:
		_in_center = true

func _on_center_exit(b: Node) -> void:
	if b == _player:
		_in_center = false

func _on_gym_enter(b: Node) -> void:
	if b == _player:
		_in_gym = true

func _on_gym_exit(b: Node) -> void:
	if b == _player:
		_in_gym = false

func _process(delta: float) -> void:
	if _encounter_cd > 0.0:
		_encounter_cd = max(0.0, _encounter_cd - delta)

	if Input.is_action_just_pressed("start_battle"):
		# 随机遭遇一只野生灵兽(测试/快速进入战斗)
		var wild_ids := []
		for cid in DataBus.creatures.keys():
			var d: Dictionary = DataBus.get_creature(cid)
			if d.get("wild", false):
				wild_ids.append(cid)
		if wild_ids.is_empty():
			wild_ids = ["aqualeap"]
		var id: String = wild_ids[randi() % wild_ids.size()]
		var d: Dictionary = DataBus.get_creature(id)
		var lv: int = randi_range(int(d.get("min_level", 2)), int(d.get("max_level", 6)))
		GameState.pending_wild = {"id": id, "level": lv}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _in_center and Input.is_action_just_pressed("interact"):
		GameState.heal_team()
		SaveManager.save_game()
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["宝可梦中心：队伍已完全恢复，进度已保存。"])

	if _center_label:
		_center_label.text = "宝可梦中心(按 E 治疗)" if _in_center else ""

	if _in_gym and Input.is_action_just_pressed("interact"):
		GameState.pending_trainer = {
			"enemy_id": "lumiadeer",
			"enemy_level": 12,
			"trainer_name": "馆主·岩心",
			"badge_id": "badge_stone"
		}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _gym_label:
		_gym_label.text = "道馆·岩心 (按 E 挑战)" if _in_gym else ""

	# 首领灵兽(alpha): 靠近按 E 挑战(可收服)
	if _alpha and is_instance_valid(_alpha):
		var da: float = _player.global_position.distance_to(_alpha.global_position)
		if da < 6.0 and not _in_center and not _in_gym:
			if _alpha_label:
				_alpha_label.text = "首领灵兽出没! 按 E 挑战 (可收服)"
			if Input.is_action_just_pressed("interact"):
				GameState.pending_wild = {"id": "steeljaw_king", "level": 18, "alpha": true}
				get_tree().change_scene_to_file("res://battle/BattleArena.tscn")
		else:
			if _alpha_label:
				_alpha_label.text = ""
	else:
		if _alpha_label:
			_alpha_label.text = ""

	# 时空裂隙: 激活时靠近自动触发稀有金属遭遇
	if _rift and is_instance_valid(_rift) and _rift.is_active and _rift.cooldown <= 0.0:
		var dr: float = _player.global_position.distance_to(_rift.global_position)
		if dr < _rift.radius:
			GameState.pending_wild = {"id": "ironhide", "level": 12, "rift": true}
			_rift.consume()
			get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	# 昼夜光照反馈
	if _env:
		if DayNight.is_night:
			_env.background_color = Color(0.05, 0.05, 0.12)
			if _light:
				_light.light_energy = 0.3
		else:
			_env.background_color = Color(0.6, 0.75, 0.95)
			if _light:
				_light.light_energy = 1.2

	_update_team_label()
	_update_research_label()

func _update_team_label() -> void:
	if not _team_label:
		return
	var s := "队伍:\n"
	for c in GameState.team:
		var d: Dictionary = DataBus.get_creature(c["id"])
		var nm: String = d.get("name", c["id"])
		var st: String = (" [" + String(c.get("status", {}).get("name", "")) + "]") if (c.get("status") != null) else ""
		s += "  " + nm + " Lv" + str(c["level"]) + " HP " + str(c["hp"]) + "/" + str(c["max_hp"]) + st + "\n"
	_team_label.text = s

func _update_research_label() -> void:
	if not _research_label:
		return
	var r: Dictionary = GameState.research
	if r.get("done", false):
		_research_label.text = "图鉴研究(金属性): 已完成! 获得远古球"
	else:
		_research_label.text = "图鉴研究(金属性): 收服/击败 " + str(r.get("progress", 0)) + "/" + str(r.get("need", 0))
