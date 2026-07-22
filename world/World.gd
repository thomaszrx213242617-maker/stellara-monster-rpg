extends Node3D
class_name World

## 探索场景: 代码构建世界(环境/光照/地面/玩家/相机/遭遇区/中心/NPC)。
## 核心循环: 走进草丛 → 随机遭遇野怪 → 实时战斗 → 击败得经验/收服 → 回世界
##          → 宝可梦中心(按 E)治疗并自动存档。夜间按 C 收服被拒(见 REQUIREMENTS §8)。

const PlayerScript := preload("res://world/PlayerController.gd")
const CameraScript := preload("res://world/CameraRig.gd")

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

func _ready() -> void:
	build_world()
	_build_ui()
	DayNight.time_changed.connect(_on_time)
	_on_time(0.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "WASD移动 | 右键转视角 | 空格跳 | 草丛遇野怪 | 中心/道馆按E | B随机遭遇 | 夜晚禁收服"
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

	_dialogue = DialogueBox.new()
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

	for i in range(8):
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2, randf_range(1, 3), 2)
		b.mesh = bm
		b.position = Vector3(randf_range(-25, 25), bm.size.y / 2.0, randf_range(-25, 25))
		add_child(b)

	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 0)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 野怪遭遇区(草丛)
	_add_encounter_zone(Vector3(-14, 0, -8), ["flarefox", "vinelop", "windpip"], 2, 6)
	_add_encounter_zone(Vector3(16, 0, 6), ["aqualeap", "bouldon", "shadepup"], 3, 7)
	_add_encounter_zone(Vector3(-10, 0, 16), ["voltmink", "spiritbud", "lumiadeer"], 3, 8)

	# 宝可梦中心
	var center := CenterZone.new()
	center.position = Vector3(0, 0, -22)
	center.body_entered.connect(_on_center_enter)
	center.body_exited.connect(_on_center_exit)
	add_child(center)

	# 道馆 (按 E 挑战馆主, 胜利获得徽章)
	var gym := GymZone.new()
	gym.position = Vector3(22, 0, -18)
	gym.body_entered.connect(_on_gym_enter)
	gym.body_exited.connect(_on_gym_exit)
	add_child(gym)

	# NPC
	var npc := Npc.new()
	npc.name = "Npc"
	npc.position = Vector3(4, 1, -19)
	npc.player_ref = _player
	npc.lines = [
		"旅行者，欢迎来到星澜地区。",
		"这里的灵兽可在战斗中收服，但切记——夜晚黯潮汹涌，无法收服灵兽。",
		"去草丛走走，会遇到野生的灵兽。祝你好运!"
	]
	_npc = npc
	add_child(npc)

func _add_encounter_zone(pos: Vector3, pool: Array, lmin: int, lmax: int) -> void:
	var z := EncounterZone.new()
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
