extends Node3D
class_name World

## 探索场景: 代码构建世界(环境/光照/地面/玩家/相机/各区域/遭遇/中心/NPC/Boss)。
## 分区: 星澜村(新手村, 无草丛无Boss) / 北之路(草丛野怪) / 晨曦镇(道馆+中期小Boss) / 黯潮深渊(终Boss)。
## 核心循环: 踩草丛→野外突袭(未派出灵兽则玩家掉血)→迎战→收服/击败→回世界; 中心/营地按E治疗并存档。
## 阿尔宙斯式: 首领灵兽(终Boss=黯潮之主·凛)于黯潮深渊出现(需中期Boss后); 时空裂隙(北之路周期激活)。
## 朱紫式: 草丛遇敌为「野外突袭」, 玩家可被直接攻击掉血, 倒下复活到最近存档点。

const PlayerScript := preload("res://world/PlayerController.gd")
const CameraScript := preload("res://world/CameraRig.gd")
const DialogueScript := preload("res://ui/DialogueBox.gd")
const CenterScript := preload("res://world/CenterZone.gd")
const GymScript := preload("res://world/GymZone.gd")
const NpcScript := preload("res://world/Npc.gd")
const EncounterScript := preload("res://world/EncounterZone.gd")
const AlphaScript := preload("res://world/AlphaBeast.gd")
const RiftScript := preload("res://world/RiftZone.gd")
const FieldAmbushScript := preload("res://world/FieldAmbush.gd")
const CampScript := preload("res://world/CampSite.gd")
const ShopScript := preload("res://ui/Shop.gd")
const TeraScript := preload("res://world/TeraPit.gd")

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
var _shop
var _in_shop: bool = false
var _shop_label: Label
var _in_camp: bool = false
var _camp_label: Label
var _in_tera: bool = false
var _tera_label: Label
var _tera_pit

# 野外突袭 / 玩家体力 / 存档点
var _ambush = null
var _last_save_point: Vector3 = Vector3(0, 1, 0)
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _coins_label: Label
var _toast: Label
var _toast_t: float = 0.0

func _ready() -> void:
	build_world()
	_build_ui()
	_setup_pause_menu()
	_setup_shop()
	GameState.current_scene = "res://world/World.tscn"
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
	hint.text = "WASD移动 | 右键转视角 | 空格跳/攻击 | Shift闪避 | E交互/迎战 | B随机遭遇/迎战 | C收服(夜禁) | I/按钮 伤药 | 发光首领(黯潮深渊)按E挑战 | 紫裂隙激活靠近触发 | Esc暂停"
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

	# 玩家体力条(野外被野怪攻击时扣减)
	_player_hp_label = Label.new()
	_player_hp_label.text = "体力"
	_player_hp_label.position = Vector2(12, 70)
	layer.add_child(_player_hp_label)
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.position = Vector2(12, 90)
	_player_hp_bar.size = Vector2(220, 18)
	_player_hp_bar.max_value = float(GameState.player_max_hp)
	layer.add_child(_player_hp_bar)

	_coins_label = Label.new()
	_coins_label.position = Vector2(12, 116)
	_coins_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_coins_label)

	_shop_label = Label.new()
	_shop_label.position = Vector2(12, 332)
	_shop_label.text = ""
	layer.add_child(_shop_label)

	_camp_label = Label.new()
	_camp_label.position = Vector2(12, 356)
	_camp_label.text = ""
	layer.add_child(_camp_label)

	_tera_label = Label.new()
	_tera_label.position = Vector2(12, 404)
	_tera_label.text = ""
	layer.add_child(_tera_label)

	_toast = Label.new()
	_toast.position = Vector2(440, 200)
	_toast.scale = Vector2(1.4, 1.4)
	_toast.modulate = Color(1.0, 0.5, 0.4)
	_toast.text = ""
	layer.add_child(_toast)

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
	_env.ambient_light_energy = 0.75
	_env.ambient_light_color = Color(0.7, 0.8, 0.95)
	_env.fog_enabled = true
	_env.fog_density = 0.012
	_env.fog_color = Color(0.65, 0.78, 0.95)
	env_node.environment = _env

	_light = DirectionalLight3D.new()
	_light.position = Vector3(10, 25, 10)
	_light.rotation = Vector3(deg_to_rad(-55), 0, 0)
	_light.light_energy = 1.3
	_light.light_color = Color(1.0, 0.97, 0.9)
	add_child(_light)

	# 柔和补光(提升立体感与真实度)
	var fill := DirectionalLight3D.new()
	fill.position = Vector3(-12, 18, -8)
	fill.rotation = Vector3(deg_to_rad(40), deg_to_rad(180), 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)

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

	# ---- 植被/树木: 提升 3D 真实度 ----
	_scatter_trees()

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
	_last_save_point = _player.global_position

	_camera = CameraScript.new()
	add_child(_camera)
	_camera.follow_target = _camera.get_path_to(_player)

	# 村内 NPC(向导/村民/劲敌/新伙伴)
	_add_npc(Vector3(4, 1, -19), "向导·岚", Color(0.3, 0.7, 0.9), [
		GameState.player_name if GameState.player_name != "" else "旅行者" + "，欢迎回到星澜村。",
		"你从山洞归来后失了记忆，连伙伴『凛』和那两头金属神兽都下落不明……但辉光说，你仍是星辉冠军。",
		"宝可梦中心(村中北侧)或路旁营地按 E 可治疗并自动存档；受伤时战斗里也能用伤药。",
		"东边的晨曦镇有道馆与一位强劲的训练家，等你变强再去挑战。北之路的草丛里，野怪会直接扑上来——记得带够伤药！",
	], _player)
	_add_npc(Vector3(-6, 1, -16), "村民·禾", Color(0.9, 0.8, 0.3), [
		"最近北之路的草丛里野怪活跃，而且会主动扑人。被咬到可是会掉体力的！",
		"听说黯潮深渊里潜伏着『黯潮之主·凛』——那竟是失踪的伙伴……",
	], _player)
	_add_npc(Vector3(-4, 1, 6), "劲敌·岩", Color(0.9, 0.5, 0.4), [
		"我也想成为点燃星辉的人！不过眼下还得先去北之路练级。",
		"等你在晨曦镇打败那位训练家，黯潮深渊的首领才会出现哦。",
	], _player)
	# 新伙伴: 小岚(同行向导少女)
	_add_npc(Vector3(10, 1, -16), "伙伴·小岚", Color(0.6, 0.9, 0.7), [
		"我叫小岚，是村里的巡林人。你从山洞被救回来那刻，我就守在床边。",
		"以后这一路，我陪你找凛、找那两头金属神兽。放心，伤药我包了。",
		"对了，村口商栈能买到各种灵球，至尊球连神兽都能收服——攒够星辉币就去吧！",
	], _player)
	# 新伙伴: 阿砂(劲敌兼挚友)
	_add_npc(Vector3(-10, 1, -14), "伙伴·阿砂", Color(0.9, 0.6, 0.9), [
		"我是阿砂。虽然咱俩是竞争关系，但找回凛这事上，咱是一条船。",
		"等你击败晨曦镇的暗潮使·玄，黯潮深渊的大门才会开。",
	], _player)

	# ---- 北之路: 草丛野怪 + 裂隙 + 警告NPC + 营地 ----
	_add_sign("北之路 · 野生灵兽出没", Vector3(0, 0, -40))
	_add_encounter_zone(Vector3(-20, 0, -50), ["flarefox", "vinelop", "windpip"], 2, 6)
	_add_encounter_zone(Vector3(20, 0, -55), ["aqualeap", "bouldon", "shadepup", "ironhide"], 3, 7)
	_add_encounter_zone(Vector3(-5, 0, -78), ["voltmink", "spiritbud", "lumiadeer"], 3, 8)
	# 时空裂隙: 周期激活, 激活时靠近触发稀有金属遭遇
	_rift = RiftScript.new()
	_rift.position = Vector3(10, 0, -68)
	add_child(_rift)
	_add_npc(Vector3(-30, 1, -45), "登山客·石", Color(0.6, 0.6, 0.6), [
		"草丛里每走一步都可能窜出野怪，而且它们会直接扑向你——不派出灵兽就会掉体力！",
		"紫色的『时空裂隙』会周期性开启，激活时靠近会遇到稀有金属灵兽。",
		"路旁有帐篷营地，按 E 扎营能回满体力和灵兽，也会成为你倒下后的复活点。",
	], _player)
	# 营地(北之路中途)
	_add_camp(Vector3(-2, 0, -32))

	# ---- 晨曦镇(东): 道馆 + 中期小Boss + 营地 ----
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
	# 营地(镇外)
	_add_camp(Vector3(38, 0, 6))

	# ---- 商栈(可购买灵球/伤药, 至尊球可买) ----
	_add_shop(Vector3(8, 0, -14))

	# ---- 晶变坑(太晶坑原创命名): 三人协力讨伐金属灵兽, 胜利后可收服/放弃 ----
	_add_sign("晶变坑 · 三人协力讨伐", Vector3(-14, 0, -66))
	var pit := TeraScript.new()
	pit.position = Vector3(-14, 0, -72)
	pit.body_entered.connect(_on_tera_enter)
	pit.body_exited.connect(_on_tera_exit)
	add_child(pit)
	_tera_pit = pit

	# ---- 黯潮深渊(南): 终Boss(黯潮之主·凛), 需中期Boss后 ----
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

func _add_camp(pos: Vector3) -> void:
	var c := CampScript.new()
	c.position = pos
	c.body_entered.connect(_on_camp_enter)
	c.body_exited.connect(_on_camp_exit)
	add_child(c)

func _add_shop(pos: Vector3) -> void:
	# 商栈招牌
	_add_sign("星辉商栈 · 按 E 购买", pos + Vector3(0, 0, 2.4))
	var zone := Area3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6, 4, 6)
	col.shape = sh
	col.position = Vector3(0, 2, 0)
	zone.add_child(col)
	zone.body_entered.connect(_on_shop_enter)
	zone.body_exited.connect(_on_shop_exit)
	zone.position = pos
	add_child(zone)

func _on_tera_enter(b: Node) -> void:
	if b == _player:
		_in_tera = true

func _on_tera_exit(b: Node) -> void:
	if b == _player:
		_in_tera = false

func _scatter_trees() -> void:
	var spots := [
		Vector3(-30, 0, 12), Vector3(-26, 0, -4), Vector3(-22, 0, 18),
		Vector3(28, 0, 12), Vector3(34, 0, -10), Vector3(30, 0, 24),
		Vector3(-12, 0, -46), Vector3(14, 0, -50), Vector3(-4, 0, -60),
		Vector3(40, 0, 4), Vector3(-40, 0, -30), Vector3(60, 0, 20)
	]
	for s in spots:
		_add_tree(s)

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
	t.position = pos
	add_child(t)

func _on_encounter(creature_id: String, level: int) -> void:
	# 草丛遇敌改为「野外突袭」: 在大地图生成野怪扑来, 不再直接进战斗
	if _ambush != null or _encounter_cd > 0.0:
		return
	_encounter_cd = 2.5
	_spawn_ambush(creature_id, level)

func _spawn_ambush(creature_id: String, level: int) -> void:
	var a := FieldAmbushScript.new()
	a.creature_id = creature_id
	a.level = level
	a.player = _player
	# 在玩家附近随机方向生成
	var ang: float = randf() * TAU
	var off := Vector3(cos(ang), 0, sin(ang)) * 7.0
	a.position = _player.global_position + off
	a.attack_player.connect(_on_ambush_attack)
	a.fainted.connect(_on_ambush_gone)
	add_child(a)
	_ambush = a
	_show_toast("野生灵兽来袭！按 B/E 迎战，或快跑！")
	# 同时记入图鉴「已见」
	GameState.note_dex_seen(creature_id)

func _on_ambush_attack(dmg: int, is_big: bool) -> void:
	GameState.damage_player(dmg)
	_show_toast(( "大招！" if is_big else "") + "被野生灵兽攻击，体力 -" + str(dmg))
	if GameState.is_player_fainted():
		_on_player_fainted()

func _on_ambush_gone() -> void:
	if _ambush != null and is_instance_valid(_ambush):
		_ambush.queue_free()
	_ambush = null

func _engage_ambush() -> void:
	if _ambush == null:
		return
	var id: String = _ambush.creature_id
	var lv: int = _ambush.level
	_on_ambush_gone()
	GameState.pending_wild = {"id": id, "level": lv}
	get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

func _on_player_fainted() -> void:
	_on_ambush_gone()
	# 复活到最近存档点, 回满体力与队伍
	_player.global_position = _last_save_point
	GameState.heal_player()
	GameState.heal_team()
	SaveManager.save_game()
	_show_toast("你被野生灵兽击倒了……在最近的营地/中心苏醒，体力已恢复。")

func _show_toast(text: String) -> void:
	if _toast:
		_toast.text = text
		_toast_t = 2.2

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

func _on_camp_enter(b: Node) -> void:
	if b == _player:
		_in_camp = true

func _on_camp_exit(b: Node) -> void:
	if b == _player:
		_in_camp = false

func _on_shop_enter(b: Node) -> void:
	if b == _player:
		_in_shop = true

func _on_shop_exit(b: Node) -> void:
	if b == _player:
		_in_shop = false

func _setup_shop() -> void:
	_shop = ShopScript.new()
	_shop.name = "Shop"
	_shop.setup(self)
	add_child(_shop)

func _process(delta: float) -> void:
	if _encounter_cd > 0.0:
		_encounter_cd = max(0.0, _encounter_cd - delta)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.text = ""

	# 野外突袭: 按 B 或 E 迎战(派出灵兽进入战斗)
	if _ambush != null and is_instance_valid(_ambush):
		if Input.is_action_just_pressed("start_battle") or Input.is_action_just_pressed("interact"):
			_engage_ambush()
			return

	if Input.is_action_just_pressed("start_battle") and _ambush == null:
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
		GameState.heal_player()
		_last_save_point = _player.global_position
		SaveManager.save_game()
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["宝可梦中心：队伍与体力已完全恢复，进度已保存。"])

	if _in_camp and Input.is_action_just_pressed("interact"):
		GameState.heal_team()
		GameState.heal_player()
		_last_save_point = _player.global_position
		SaveManager.save_game()
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["你在营地扎营休息，队伍与体力全部恢复，这里已成为新的复活点。"])

	if _in_shop and Input.is_action_just_pressed("interact") and _shop != null and not _shop._open:
		_shop.open_shop()

	# 晶变坑: 三人协力讨伐(胜利后可收服/放弃)
	if _in_tera and Input.is_action_just_pressed("interact"):
		if GameState.pending_raid.is_empty():
			if GameState.story_stage < 1:
				if _dialogue and _dialogue.has_method("start"):
					_dialogue.start(["晶变坑寂静无声……等你真正踏入星澜大地后，守护兽才会苏醒。"])
			elif GameState.team.is_empty():
				_show_toast("你还没有任何灵兽，无法挑战晶变坑。")
			else:
				GameState.pending_raid = {
					"boss_id": "crystal_guardian",
					"boss_level": 28,
					"allies": ["劲敌·岩", "伙伴·小岚", "伙伴·阿砂"]
				}
				get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

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

	# 首领灵兽(终Boss = 黯潮之主·凛): 仅中期Boss后于黯潮深渊出现
	if _alpha and is_instance_valid(_alpha) and _alpha.visible:
		var da: float = _player.global_position.distance_to(_alpha.global_position)
		if da < 6.0 and not _in_center and not _in_gym:
			if _alpha_label:
				_alpha_label.text = "黯潮之主·凛 出没! 按 E 挑战 (可收服→终局)"
			if Input.is_action_just_pressed("interact"):
				GameState.pending_wild = {"id": "steeljaw_king", "level": 22, "alpha": true, "finale": true}
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
	_update_player_hud()

func _update_player_hud() -> void:
	if _player_hp_bar:
		_player_hp_bar.value = float(GameState.player_hp) / float(max(GameState.player_max_hp, 1))
	if _coins_label:
		_coins_label.text = "星辉币: " + str(GameState.coins)
	if _shop_label:
		_shop_label.text = "星辉商栈 (按 E 购买)" if _in_shop else ""
	if _camp_label:
		_camp_label.text = "营地 (按 E 扎营休息)" if _in_camp else ""
	if _tera_label:
		_tera_label.text = "晶变坑 (按 E 三人协力讨伐)" if _in_tera else ""

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
