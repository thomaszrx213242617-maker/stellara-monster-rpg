extends Node3D
class_name World

## 探索场景: 代码构建世界(环境/光照/地面/玩家/相机/各区域/遭遇/中心/NPC/Boss)。
## 分区: 星澜村(新手村, 无草丛无Boss) / 北之路(草丛野怪) / 晨曦镇(道馆+中期小Boss) / 黯潮深渊(终Boss)。
## 核心循环: 踩草丛→随机遭遇→实时战斗→收服/击败→回世界; 中心按E治疗并存档。
## 阿尔宙斯式: 首领灵兽(alpha, 终Boss, 需中期Boss后于黯潮深渊出现); 时空裂隙(北之路周期激活)。

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
var _encounter_cd: float = 0.0
var _in_center: bool = false
var _center_label: Label
var _in_gym: bool = false
var _gym_label: Label
var _in_midboss: bool = false
var _midboss
var _midboss_label: Label
var _alpha_label: Label
var _research_label: Label
var _alpha
var _rift
var _pause_menu

func _ready() -> void:
	build_world()
	_build_ui()
	_setup_pause_menu()
	DayNight.time_changed.connect(_on_time)
	_on_time(0.0)

func _setup_pause_menu() -> void:
	var PauseScript := preload("res://ui/PauseMenu.gd")
	_pause_menu = PauseScript.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.setup(self)
	add_child(_pause_menu)

func open_pause() -> void:
	if _pause_menu == null:
		return
	get_tree().paused = true
	_pause_menu.open()

func resume_from_pause() -> void:
	if _pause_menu == null:
		return
	get_tree().paused = false
	_pause_menu.close()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "WASD移动 | 右键转视角 | 空格跳 | 草丛遇野怪 | 中心/道馆/东镇按E | B随机遭遇 | C收服(夜禁) | 发光首领(黯潮深渊)按E挑战 | 紫裂隙激活靠近触发"
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

	_midboss_label = Label.new()
	_midboss_label.position = Vector2(12, 378)
	_midboss_label.text = ""
	layer.add_child(_midboss_label)

	_research_label = Label.new()
	_research_label.position = Vector2(420, 12)
	layer.add_child(_research_label)

	_alpha_label = Label.new()
	_alpha_label.position = Vector2(260, 280)
	_alpha_label.scale = Vector2(1.4, 1.4)
	_alpha_label.text = ""
	layer.add_child(_alpha_label)

func _on_time(_t: float) -> void:
	if _time_label:
		_time_label.text = "时间: " + DayNight.phase_label() + (" (禁止收服)" if DayNight.is_night else "")

func build_world() -> void:
	# 对话框(CanvasLayer), 供所有 NPC 共用
	var dlayer := CanvasLayer.new()
	add_child(dlayer)
	_dialogue = DialogueScript.new()
	_dialogue.name = "DialogueBox"
	dlayer.add_child(_dialogue)

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

	# 大地(扩张为 240x240, 分区)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	ground.mesh = plane
	ground.rotate_x(deg_to_rad(-90))
	add_child(ground)

	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(240, 0.2, 240)
	col.shape = shape
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

	# ---- 星澜村(新手村): 房子 + 中心 + NPC, 无草丛无Boss ----
	_add_house(Vector3(-14, 0, 8),  Vector3(4, 3, 4), Color(0.85, 0.7, 0.5))
	_add_house(Vector3(14, 0, -8),  Vector3(5, 4, 5), Color(0.7, 0.8, 0.6))
	_add_house(Vector3(-18, 0, -12), Vector3(4, 3, 4), Color(0.8, 0.6, 0.6))
	_add_house(Vector3(18, 0, 14),  Vector3(3, 2.5, 3), Color(0.6, 0.7, 0.85))
	_add_house(Vector3(-8, 0, 18),  Vector3(4, 3.5, 4), Color(0.9, 0.85, 0.6))
	_add_house(Vector3(22, 0, 4),   Vector3(5, 4, 5), Color(0.75, 0.65, 0.8))
	_add_sign("星澜村 · 旅途的起点", Vector3(0, 0, 14))

	var center := CenterScript.new()
	center.position = Vector3(0, 0, -22)
	center.body_entered.connect(_on_center_enter)
	center.body_exited.connect(_on_center_exit)
	add_child(center)

	_player = PlayerScript.new()
	_player.position = Vector3(0, 1, 0)
	add_child(_player)

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 村内 NPC(向导/村民/商店/劲敌)
	_add_npc(Vector3(4, 1, -19), "向导·岚", Color(0.3, 0.7, 0.9), [
		GameState.player_name if GameState.player_name != "" else "旅行者" + "，欢迎来到星澜村。",
		"你自星海降临的事，辉光已告知我。去北之路收服灵兽，壮大你的队伍吧。",
		"宝可梦中心(村中北侧)按 E 可治疗并自动存档；受伤时战斗里也能用伤药。",
		"东边的晨曦镇有道馆与一位强劲的训练家，等你变强再去挑战。",
	], _player)
	_add_npc(Vector3(-6, 1, -16), "村民·禾", Color(0.9, 0.8, 0.3), [
		"最近北之路的草丛里野怪活跃，出门记得带够伤药。",
		"听说黯潮深渊里潜伏着会发光的『首领灵兽』，寻常人可近不得。",
	], _player)
	_add_npc(Vector3(8, 1, -14), "商店·琳", Color(0.8, 0.5, 0.8), [
		"我这儿虽没有店铺，但村里探索常能捡到伤药与灵球，多留意草丛。",
		"战斗里队伍首位没血时，按『道具/伤药』按钮就能治疗，很方便。",
	], _player)
	_add_npc(Vector3(-4, 1, 6), "劲敌·岩", Color(0.9, 0.5, 0.4), [
		"我也想成为点燃星辉的人！不过眼下还得先去北之路练级。",
		"等你在晨曦镇打败那位训练家，黯潮深渊的首领才会出现哦。",
	], _player)

	# ---- 北之路: 草丛野怪 + 裂隙 + 警告NPC ----
	_add_sign("北之路 · 野生灵兽出没", Vector3(0, 0, -40))
	_add_encounter_zone(Vector3(-20, 0, -50), ["flarefox", "vinelop", "windpip"], 2, 6)
	_add_encounter_zone(Vector3(20, 0, -55), ["aqualeap", "bouldon", "shadepup", "ironhide"], 3, 7)
	_add_encounter_zone(Vector3(-5, 0, -78), ["voltmink", "spiritbud", "lumiadeer"], 3, 8)
	# 时空裂隙: 周期激活, 激活时靠近触发稀有金属遭遇
	_rift = RiftScript.new()
	_rift.position = Vector3(10, 0, -68)
	add_child(_rift)
	_add_npc(Vector3(-30, 1, -45), "登山客·石", Color(0.6, 0.6, 0.6), [
		"草丛里每走一步都可能窜出野怪，这可是宝可梦(灵兽)世界的规矩。",
		"紫色的『时空裂隙』会周期性开启，激活时靠近会遇到稀有金属灵兽。",
	], _player)

	# ---- 晨曦镇(东): 道馆 + 中期小Boss ----
	_add_sign("晨曦镇", Vector3(50, 0, 0))
	_add_house(Vector3(55, 0, 8),  Vector3(4, 3, 4), Color(0.7, 0.8, 0.85))
	_add_house(Vector3(82, 0, -6), Vector3(5, 4, 5), Color(0.85, 0.75, 0.6))
	_add_house(Vector3(60, 0, 26), Vector3(4, 3, 4), Color(0.8, 0.6, 0.7))
	var gym := GymScript.new()
	gym.position = Vector3(60, 0, -10)
	gym.body_entered.connect(_on_gym_enter)
	gym.body_exited.connect(_on_gym_exit)
	add_child(gym)
	# 中期小Boss(训练家), 需序章后且已收服≥2种
	var midboss := GymScript.new()
	midboss.position = Vector3(72, 0, 16)
	midboss.body_entered.connect(_on_midboss_enter)
	midboss.body_exited.connect(_on_midboss_exit)
	add_child(midboss)
	_midboss = midboss
	_add_npc(Vector3(54, 1, -2), "镇民·晴", Color(0.5, 0.8, 0.7), [
		"馆主·岩心就在这镇北，想拿徽章得先证明实力。",
		"镇东那位『暗潮使·玄』更不好惹，听说击败他才能唤醒黯潮深渊的首领。",
	], _player)

	# ---- 黯潮深渊(南): 终Boss(alpha), 需中期Boss后 ----
	_add_sign("黯潮深渊 · 首领出没", Vector3(0, 0, 50))
	_alpha = AlphaScript.new()
	_alpha.position = Vector3(0, 0, 72)
	_alpha.visible = GameState.midboss_done
	add_child(_alpha)

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
	# 屋顶(尖顶)
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
	# 门
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.0, 1.8, 0.1)
	door.mesh = dm
	door.position = Vector3(0, 0.9, size.z / 2.0 + 0.05)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.3, 0.2, 0.15)
	door.material_override = dmat
	house.add_child(door)
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

func _add_sign(text: String, pos: Vector3) -> void:
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.1
	pm.bottom_radius = 0.1
	pm.height = 2.0
	post.mesh = pm
	post.position = Vector3(pos.x, 1.0, pos.z)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.5, 0.35, 0.2)
	post.material_override = pmat
	add_child(post)
	var tag := Label3D.new()
	tag.text = text
	tag.position = Vector3(pos.x, 2.4, pos.z)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 28
	add_child(tag)

func _add_npc(pos: Vector3, name: String, color: Color, lines_arr: Array, player) -> void:
	var n := NpcScript.new()
	n.name = name
	n.position = pos
	n.display_name = name
	n.npc_color = color
	n.lines = lines_arr
	n.player_ref = player
	n.dialogue_box = _dialogue
	add_child(n)

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

func _on_midboss_enter(b: Node) -> void:
	if b == _player:
		_in_midboss = true

func _on_midboss_exit(b: Node) -> void:
	if b == _player:
		_in_midboss = false

func _process(delta: float) -> void:
	if _encounter_cd > 0.0:
		_encounter_cd = max(0.0, _encounter_cd - delta)

	if Input.is_action_just_pressed("start_battle"):
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

	# 中期小Boss(暗潮使·玄): 需序章后且已收服≥2种
	if _in_midboss and Input.is_action_just_pressed("interact"):
		var ready: bool = GameState.story_stage >= 1 and GameState.dex_caught_count() >= 2
		if not ready:
			if _dialogue and _dialogue.has_method("start"):
				_dialogue.start(["暗潮使·玄：「你还太稚嫩。先去北之路收服至少两只灵兽，再来寻我。」"])
		else:
			GameState.pending_trainer = {
				"enemy_id": "shadepup",
				"enemy_level": 18,
				"trainer_name": "暗潮使·玄",
				"badge_id": "badge_mid"
			}
			get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _midboss_label:
		if not GameState.midboss_done:
			_midboss_label.text = "暗潮使·玄 (按 E 挑战, 需收服≥2种)" if _in_midboss else ""
		else:
			_midboss_label.text = ""

	# 首领灵兽(alpha, 终Boss): 仅中期Boss后于黯潮深渊出现
	if _alpha and is_instance_valid(_alpha) and _alpha.visible:
		var da: float = _player.global_position.distance_to(_alpha.global_position)
		if da < 6.0 and not _in_center and not _in_gym:
			if _alpha_label:
				_alpha_label.text = "首领灵兽出没! 按 E 挑战 (可收服→结局)"
			if Input.is_action_just_pressed("interact"):
				GameState.pending_wild = {"id": "steeljaw_king", "level": 22, "alpha": true}
				get_tree().change_scene_to_file("res://battle/BattleArena.tscn")
		else:
			if _alpha_label:
				_alpha_label.text = ""
	elif _alpha_label:
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
