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
var _in_gym2: bool = false
var _gym2_label: Label
var _in_gym3: bool = false
var _gym3_label: Label
var _in_gym4: bool = false
var _gym4_label: Label
var _in_wish: bool = false
var _wish
var _wish_label: Label
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
var _bag_layer: CanvasLayer = null
var _bag_open: bool = false
const _bag_script := preload("res://ui/PartyBag.gd")
var _in_camp: bool = false
var _camp_label: Label
var _in_tera: bool = false
var _tera_label: Label
var _tera_pit

# 可探索点: 辉光晶簇(一次性奖励) / 古老封印(小谜题, 需收服≥3种)
var _in_crystal: bool = false
var _crystal
var _crystal_label: Label
var _in_seal: bool = false
var _seal
var _seal_label: Label

# 野外突袭 / 玩家体力 / 存档点
var _ambush = null
var _last_save_point: Vector3 = Vector3(0, 1, 0)
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _coins_label: Label
var _toast: Label
var _toast_t: float = 0.0

# 常驻 HUD: 当前目标 / 首发灵兽 / 存档点
var _objective: Label
var _objective_bg: ColorRect
var _lead_label: Label
var _lead_hp_bar: ProgressBar
var _savepoint_label: Label
var _last_save_name: String = "星澜村·宝可梦中心"

func _ready() -> void:
	build_world()
	_build_ui()
	_setup_pause_menu()
	_setup_shop()
	Game.current_scene = "res://world/World.tscn"
	# 目标罗盘 HUD: 清除序章遗留的手动目标, 改由 current_objective_target() 驱动
	Game.objective_target = Vector3.ZERO
	var CompassScript := preload("res://ui/ObjectiveCompass.gd")
	var compass = CompassScript.new()
	add_child(compass)
	Clock.time_changed.connect(_on_time)
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

## 野外按 I 直接打开背包/队伍面板(覆盖层; 不暂停, 冻结世界处理直到关闭)
func _open_bag() -> void:
	if _bag_open or _pause_menu == null or get_tree().paused:
		return
	_bag_open = true
	_bag_layer = CanvasLayer.new()
	_bag_layer.name = "BagLayer"
	_bag_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bag_layer)
	var party = _bag_script.new()
	party.name = "PartyBag"
	_bag_layer.add_child(party)
	party.closed.connect(_close_bag)
	SFX.play_sfx("select")

func _close_bag() -> void:
	if _bag_layer != null:
		_bag_layer.queue_free()
		_bag_layer = null
	_bag_open = false

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "WASD移动 | 右键转视角 | 空格跳/攻击 | Shift闪避 | E交互/迎战 | B随机遭遇/迎战 | C收服(夜禁) | I背包 | 发光首领(黯潮深渊)按E挑战 | 紫裂隙激活靠近触发 | Esc暂停"
	hint.position = Vector2(360, 1012)
	hint.size = Vector2(1200, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(0.85, 0.9, 0.95)
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

	_gym2_label = Label.new()
	_gym2_label.position = Vector2(12, 476)
	_gym2_label.text = ""
	layer.add_child(_gym2_label)

	_gym3_label = Label.new()
	_gym3_label.position = Vector2(12, 500)
	_gym3_label.text = ""
	layer.add_child(_gym3_label)

	_gym4_label = Label.new()
	_gym4_label.position = Vector2(12, 524)
	_gym4_label.text = ""
	layer.add_child(_gym4_label)

	_wish_label = Label.new()
	_wish_label.position = Vector2(12, 548)
	_wish_label.text = ""
	layer.add_child(_wish_label)

	_midboss_label = Label.new()
	_midboss_label.position = Vector2(12, 378)
	_midboss_label.text = ""
	layer.add_child(_midboss_label)

	_research_label = Label.new()
	_research_label.position = Vector2(1480, 14)
	_research_label.add_theme_font_size_override("font_size", 18)
	_research_label.modulate = Color(0.8, 0.95, 1.0)
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
	_player_hp_bar.max_value = float(Game.player_max_hp)
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

	_crystal_label = Label.new()
	_crystal_label.position = Vector2(12, 428)
	_crystal_label.text = ""
	layer.add_child(_crystal_label)

	_seal_label = Label.new()
	_seal_label.position = Vector2(12, 452)
	_seal_label.text = ""
	layer.add_child(_seal_label)

	# ---- 当前目标(主线指引, 常驻顶部居中) ----
	_objective_bg = ColorRect.new()
	_objective_bg.color = Color(0.05, 0.07, 0.12, 0.65)
	_objective_bg.position = Vector2(560, 10)
	_objective_bg.size = Vector2(800, 46)
	layer.add_child(_objective_bg)
	_objective = Label.new()
	_objective.name = "ObjectiveHUD"
	_objective.position = Vector2(560, 16)
	_objective.size = Vector2(800, 36)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective.add_theme_font_size_override("font_size", 22)
	_objective.modulate = Color(0.85, 1.0, 0.8)
	layer.add_child(_objective)

	# ---- 首发灵兽面板(队伍首位, 右上) ----
	var lead_box := ColorRect.new()
	lead_box.color = Color(0.05, 0.07, 0.12, 0.6)
	lead_box.position = Vector2(1500, 56)
	lead_box.size = Vector2(400, 120)
	layer.add_child(lead_box)
	var lead_title := Label.new()
	lead_title.text = "首发灵兽"
	lead_title.position = Vector2(1512, 62)
	lead_title.add_theme_font_size_override("font_size", 16)
	lead_title.modulate = Color(0.9, 0.95, 1.0)
	layer.add_child(lead_title)
	_lead_label = Label.new()
	_lead_label.position = Vector2(1512, 88)
	_lead_label.size = Vector2(376, 28)
	_lead_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_lead_label)
	_lead_hp_bar = ProgressBar.new()
	_lead_hp_bar.position = Vector2(1512, 122)
	_lead_hp_bar.size = Vector2(376, 16)
	_lead_hp_bar.max_value = 1.0
	layer.add_child(_lead_hp_bar)

	# ---- 存档点提示(右下) ----
	_savepoint_label = Label.new()
	_savepoint_label.position = Vector2(1500, 980)
	_savepoint_label.size = Vector2(400, 60)
	_savepoint_label.add_theme_font_size_override("font_size", 16)
	_savepoint_label.modulate = Color(0.8, 0.95, 1.0)
	layer.add_child(_savepoint_label)

	_toast = Label.new()
	_toast.position = Vector2(440, 200)
	_toast.scale = Vector2(1.4, 1.4)
	_toast.modulate = Color(1.0, 0.5, 0.4)
	_toast.text = ""
	layer.add_child(_toast)

func _on_time(_t: float) -> void:
	if _time_label:
		_time_label.text = "时间: " + Clock.phase_label() + " " + Clock.clock_string() + (" (禁止收服)" if Clock.is_night else "")

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
	_add_sign("方向牌：北之路↑(野怪)  晨曦镇→(道馆)  黯潮深渊↓(首领)", Vector3(0, 0, -10))

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
		Game.player_name if Game.player_name != "" else "旅行者" + "，欢迎回到星澜村。",
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
	# 说书人·墨: 世界观与支线线索
	_add_npc(Vector3(16, 1, -16), "说书人·墨", Color(0.8, 0.7, 0.9), [
		"星澜大陆的传说里，曾有双生金属神兽守护这片土地——直到黯潮降临。",
		"听说北之路藏着会发光的『辉光晶簇』，靠近按 E 就能采得；还有一道『古老封印』，需集齐三种灵兽方能唤醒。",
		"夜幕降临后，黯潮翻涌，那时是收服不了的——记得白天再出手。",
	], _player)

	# ---- 北之路: 草丛野怪 + 裂隙 + 警告NPC + 营地 ----
	_add_sign("北之路 · 野生灵兽出没", Vector3(0, 0, -40))
	_add_encounter_zone(Vector3(-20, 0, -50), ["windpip", "voltmink", "lumiadeer"], 2, 6)
	_add_encounter_zone(Vector3(20, 0, -55), ["tidecup", "bouldon", "shadepup", "ironhide"], 3, 7)
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
	# 守林人·霜: 支线提示 + 草丛生存建议
	_add_npc(Vector3(-26, 1, -52), "守林人·霜", Color(0.6, 0.8, 0.7), [
		"这片林子我守了二十年。野怪虽凶，却也藏着稀有的金属灵兽——收服它们能推进图鉴研究。",
		"若你见到发着蓝光的『辉光晶簇』，别错过，那是天地灵气凝结的宝物。",
		"受伤别硬撑，回村中心或扎营都能回满，还能自动存档。",
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
	# 第二座道馆: 清风道馆(星澜村西), 馆主·清, 清风徽章
	var gym2 := GymScript.new()
	gym2.position = Vector3(-30, 0, 0)
	gym2.body_entered.connect(_on_gym2_enter)
	gym2.body_exited.connect(_on_gym2_exit)
	add_child(gym2)
	_add_sign("清风道馆 · 馆主·清", Vector3(-30, 0, 8))
	# 第三座道馆: 烈焰道馆(熔岩谷), 馆主·炎心, 烈焰徽章
	var gym3 := GymScript.new()
	gym3.position = Vector3(100, 0, 55)
	gym3.roof_color = Color(0.9, 0.3, 0.2)
	gym3.body_entered.connect(_on_gym3_enter)
	gym3.body_exited.connect(_on_gym3_exit)
	add_child(gym3)
	_add_sign("熔岩谷 · 馆主·炎心", Vector3(100, 0, 63))
	# 第四座道馆: 寒冰道馆(霜原), 馆主·霜音, 寒冰徽章
	var gym4 := GymScript.new()
	gym4.position = Vector3(-100, 0, 55)
	gym4.roof_color = Color(0.6, 0.85, 0.95)
	gym4.body_entered.connect(_on_gym4_enter)
	gym4.body_exited.connect(_on_gym4_exit)
	add_child(gym4)
	_add_sign("霜原 · 馆主·霜音", Vector3(-100, 0, 63))
	# 主题区: 熔岩谷(烈焰道馆氛围) —— 发光熔岩晶簇 + 野怪表
	_add_glow_cluster(Vector3(100, 0, 46), Color(1.0, 0.45, 0.2), Color(1.0, 0.5, 0.2))
	_add_encounter_zone(Vector3(100, 0, 38), ["emberat", "ashfang", "ironhide"], 4, 9)
	# 主题区: 霜原(寒冰道馆氛围) —— 发光冰晶簇 + 野怪表
	_add_glow_cluster(Vector3(-100, 0, 46), Color(0.6, 0.85, 1.0), Color(0.7, 0.9, 1.0))
	_add_encounter_zone(Vector3(-100, 0, 38), ["snowkit", "snowmane", "windpip"], 4, 9)
	# 连接两主题区的守界人(剧情线索)
	_add_npc(Vector3(0, 1, 50), "守界人·烬", Color(0.9, 0.7, 0.4), [
		"熔岩谷的炎心、霜原的霜音，是新近崛起的两位馆主。",
		"他们的徽章，是开启黯潮深渊封印的关键。",
		"（主线：集齐岩石·清风·烈焰·寒冰四徽章，再去找暗潮使·玄。）"
	], _player)

	# 支线任务: 祈愿石碑(集齐≥2枚徽章可领取一次补给)
	var wish := Area3D.new()
	var wcol := CollisionShape3D.new()
	var wsh := SphereShape3D.new()
	wsh.radius = 2.6
	wcol.shape = wsh
	wish.add_child(wcol)
	wish.body_entered.connect(_on_wish_enter)
	wish.body_exited.connect(_on_wish_exit)
	wish.position = Vector3(0, 0, 70)
	add_child(wish)
	_wish = wish
	_add_sign("祈愿石碑", Vector3(0, 0, 73))

	# 支线NPC: 老探险家(线索)——提示烈焰/寒冰道馆与暗潮使·玄的要求
	_add_npc(Vector3(8, 1, 64), "老探险家·岩叔", Color(0.7, 0.6, 0.4), [
		"听说熔岩谷的炎心、霜原的霜音，都收着崭新的徽章。",
		"想去会暗潮使·玄？得把岩石、清风、烈焰、寒冰四枚徽章全凑齐才行。",
		"（支线：集齐四枚徽章后，去镇东找玄，他会指点你封印双神兽的路。）"
	], _player)

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

	# 可探索点: 辉光晶簇(北之路西北角) + 古老封印(时空裂隙旁)
	_add_crystal(Vector3(-24, 0, -64))
	_add_seal(Vector3(18, 0, -72))

	# ---- 黯潮深渊(南): 终Boss(黯潮之主·凛), 需中期Boss后 ----
	_add_sign("黯潮深渊 · 首领出没", Vector3(0, 0, 50))
	_alpha = AlphaScript.new()
	_alpha.position = Vector3(0, 0, 72)
	_alpha.visible = Game.midboss_done
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

## 可探索点: 辉光晶簇(发光, 首次交互赠 远古球 ×1)
func _add_crystal(pos: Vector3) -> void:
	var c := Area3D.new()
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 2.4
	col.shape = sh
	c.add_child(col)
	c.body_entered.connect(_on_crystal_enter)
	c.body_exited.connect(_on_crystal_exit)
	c.position = pos
	add_child(c)
	_crystal = c
	var shard := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.0
	sm.bottom_radius = 0.5
	sm.height = 1.8
	shard.mesh = sm
	shard.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.9, 1.0)
	mat.emission = Color(0.3, 0.8, 1.0)
	mat.emission_energy = 1.8
	mat.roughness = 0.25
	shard.material_override = mat
	c.add_child(shard)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.2, 0)
	glow.light_color = Color(0.4, 0.9, 1.0)
	glow.light_energy = 2.2
	glow.omni_range = 7.0
	c.add_child(glow)
	var tag := Label3D.new()
	tag.text = "辉光晶簇"
	tag.position = Vector3(0, 2.3, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 26
	c.add_child(tag)

## 主题区发光晶簇(纯装饰): 在 pos 处生成若干发光晶体 + 一盏点光, 烘托熔岩谷/霜原氛围
func _add_glow_cluster(pos: Vector3, base: Color, glow: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var offsets := [Vector3(0, 0, 0), Vector3(1.6, 0, 0.8), Vector3(-1.4, 0, -0.6)]
	var heights := [2.2, 1.6, 1.9]
	for i in offsets.size():
		var shard := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.45
		sm.height = heights[i]
		shard.mesh = sm
		shard.position = offsets[i] + Vector3(0, heights[i] / 2.0, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base
		mat.emission = glow
		mat.emission_energy = 2.0
		mat.roughness = 0.25
		shard.material_override = mat
		root.add_child(shard)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.0, 0)
	light.light_color = glow
	light.light_energy = 3.0
	light.omni_range = 10.0
	root.add_child(light)

## 小谜题: 古老封印(需收服≥3种灵兽方可唤醒, 赠 好伤药 ×2 + 线索)
func _add_seal(pos: Vector3) -> void:
	var s := Area3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4, 4, 4)
	col.shape = sh
	col.position = Vector3(0, 2, 0)
	s.add_child(col)
	s.body_entered.connect(_on_seal_enter)
	s.body_exited.connect(_on_seal_exit)
	s.position = pos
	add_child(s)
	_seal = s
	var stone := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 3.0, 0.5)
	stone.mesh = bm
	stone.position = Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.5)
	mat.roughness = 0.8
	stone.material_override = mat
	s.add_child(stone)
	var tag := Label3D.new()
	tag.text = "古老封印"
	tag.position = Vector3(0, 3.4, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 30
	s.add_child(tag)

func _on_crystal_enter(b: Node) -> void:
	if b == _player:
		_in_crystal = true

func _on_crystal_exit(b: Node) -> void:
	if b == _player:
		_in_crystal = false

func _on_seal_enter(b: Node) -> void:
	if b == _player:
		_in_seal = true

func _on_seal_exit(b: Node) -> void:
	if b == _player:
		_in_seal = false

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
	Game.note_dex_seen(creature_id)

func _on_ambush_attack(dmg: int, is_big: bool) -> void:
	Game.damage_player(dmg)
	_show_toast(( "大招！" if is_big else "") + "被野生灵兽攻击，体力 -" + str(dmg))
	if Game.is_player_fainted():
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
	var pw: Dictionary = {"id": id, "level": lv}
	# 夜间黯潮: 野生灵兽按概率狂暴化(攻防/血提升且不可收服)
	if Clock.is_night:
		pw["berserk"] = Clock.should_berserk()
	Game.pending_wild = pw
	get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

func _on_player_fainted() -> void:
	_on_ambush_gone()
	# 复活到最近存档点, 回满体力与队伍
	_player.global_position = _last_save_point
	Game.heal_player()
	Game.heal_team()
	Save.save_game()
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

func _on_gym2_enter(b: Node) -> void:
	if b == _player:
		_in_gym2 = true

func _on_gym2_exit(b: Node) -> void:
	if b == _player:
		_in_gym2 = false

func _on_gym3_enter(b: Node) -> void:
	if b == _player:
		_in_gym3 = true

func _on_gym3_exit(b: Node) -> void:
	if b == _player:
		_in_gym3 = false

func _on_gym4_enter(b: Node) -> void:
	if b == _player:
		_in_gym4 = true

func _on_gym4_exit(b: Node) -> void:
	if b == _player:
		_in_gym4 = false

func _on_wish_enter(b: Node) -> void:
	if b == _player:
		_in_wish = true

func _on_wish_exit(b: Node) -> void:
	if b == _player:
		_in_wish = false

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
	# 每帧同步玩家世界坐标给目标罗盘
	if _player != null:
		Game.player_position = _player.position
	# 背包打开时: Esc 关闭, 其余世界处理冻结
	if _bag_open:
		if Input.is_action_just_pressed("ui_cancel"):
			_close_bag()
		return
	if Input.is_action_just_pressed("open_bag") and not get_tree().paused:
		_open_bag()
		return
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
		for cid in Data.creatures.keys():
			var d: Dictionary = Data.get_creature(cid)
			if d.get("wild", false):
				wild_ids.append(cid)
		if wild_ids.is_empty():
			wild_ids = ["windpip"]
		var id: String = wild_ids[randi() % wild_ids.size()]
		var d: Dictionary = Data.get_creature(id)
		var lv: int = randi_range(int(d.get("min_level", 2)), int(d.get("max_level", 6)))
		Game.pending_wild = {"id": id, "level": lv}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _in_center and Input.is_action_just_pressed("interact"):
		Game.heal_team()
		Game.heal_player()
		_last_save_point = _player.global_position
		_last_save_name = "星澜村·宝可梦中心"
		Save.save_game()
		SFX.play_sfx("heal")
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["宝可梦中心：队伍与体力已完全恢复，进度已保存。"])

	if _in_camp and Input.is_action_just_pressed("interact"):
		Game.heal_team()
		Game.heal_player()
		_last_save_point = _player.global_position
		_last_save_name = "路旁营地（休整点）"
		Save.save_game()
		SFX.play_sfx("heal")
		if _dialogue and _dialogue.has_method("start"):
			_dialogue.start(["你在营地扎营休息，队伍与体力全部恢复，这里已成为新的复活点。"])

	if _in_shop and Input.is_action_just_pressed("interact") and _shop != null and not _shop._open:
		_shop.open_shop()

	# 晶变坑: 三人协力讨伐(胜利后可收服/放弃)
	if _in_tera and Input.is_action_just_pressed("interact"):
		if Game.pending_raid.is_empty():
			if Game.story_stage < 1:
				if _dialogue and _dialogue.has_method("start"):
					_dialogue.start(["晶变坑寂静无声……等你真正踏入星澜大地后，守护兽才会苏醒。"])
			elif Game.team.is_empty():
				_show_toast("你还没有任何灵兽，无法挑战晶变坑。")
			else:
				Game.pending_raid = {
					"boss_id": "crystal_guardian",
					"boss_level": 28,
					"allies": ["劲敌·岩", "伙伴·小岚", "伙伴·阿砂"]
				}
				get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	# 可探索点: 辉光晶簇(一次性奖励)
	if _in_crystal and Input.is_action_just_pressed("interact"):
		if not Game.flags.get("crystal_north", false):
			Game.flags["crystal_north"] = true
			Game.add_item("ancient_ball", 1)
			SFX.play_sfx("capture_success")
			Save.save_game()
			_show_toast("你采得一枚辉光晶簇，获赠 远古球 ×1！")
		else:
			_show_toast("这枚辉光晶簇已被你采走了。")

	# 小谜题: 古老封印(需收服≥3种灵兽方能唤醒)
	if _in_seal and Input.is_action_just_pressed("interact"):
		if not Game.flags.get("seal_opened", false):
			if Game.dex_caught_count() >= 3:
				Game.flags["seal_opened"] = true
				Game.add_item("super_potion", 2)
				SFX.play_sfx("levelup")
				Save.save_game()
				if _dialogue and _dialogue.has_method("start"):
					_dialogue.start(["封印低语：『当三相之灵归于你手，深渊之门将为你而开。』",
						"你领悟了封印之力，获得 好伤药 ×2！"])
			else:
				if _dialogue and _dialogue.has_method("start"):
					_dialogue.start(["封印纹丝不动……似乎需要收服至少 3 种灵兽，才能唤醒其中的力量。"])
		else:
			_show_toast("封印已被你唤醒过了。")

	if _center_label:
		_center_label.text = "宝可梦中心(按 E 治疗)" if _in_center else ""

	if _in_gym and Input.is_action_just_pressed("interact"):
		Game.pending_trainer = {
			"enemy_id": "lumiadeer",
			"enemy_level": 12,
			"trainer_name": "馆主·岩心",
			"badge_id": "badge_stone"
		}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _gym_label:
		_gym_label.text = "道馆·岩心 (按 E 挑战)" if _in_gym else ""

	if _in_gym2 and Input.is_action_just_pressed("interact"):
		Game.pending_trainer = {
			"enemy_id": "windpip",
			"enemy_level": 10,
			"trainer_name": "馆主·清",
			"badge_id": "badge_wave"
		}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _gym2_label:
		_gym2_label.text = "清风道馆·清 (按 E 挑战)" if _in_gym2 else ""

	if _in_gym3 and Input.is_action_just_pressed("interact"):
		Game.pending_trainer = {
			"enemy_id": "magmaw",
			"enemy_level": 15,
			"trainer_name": "馆主·炎心",
			"badge_id": "badge_flame"
		}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _gym3_label:
		_gym3_label.text = "烈焰道馆·炎心 (按 E 挑战)" if _in_gym3 else ""

	if _in_gym4 and Input.is_action_just_pressed("interact"):
		Game.pending_trainer = {
			"enemy_id": "frostpard",
			"enemy_level": 15,
			"trainer_name": "馆主·霜音",
			"badge_id": "badge_frost"
		}
		get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _gym4_label:
		_gym4_label.text = "寒冰道馆·霜音 (按 E 挑战)" if _in_gym4 else ""

	# 中期小Boss(暗潮使·玄): 需集齐四枚徽章; 战后可再次对话获取剧情指引
	if _in_midboss and Input.is_action_just_pressed("interact"):
		if Game.midboss_done:
			if _dialogue and _dialogue.has_method("start"):
				_dialogue.start([
					"暗潮使·玄：「四徽章已齐，封印之钥已在你手。」",
					"「前往北境的黯潮深渊——黯潮之主·凛正守着双生神兽的裂隙。」",
					"「救回你的伙伴凛，让星澜大陆重归平衡。去吧。」"
				])
		else:
			var ready: bool = Game.story_stage >= 1 and Game.has_badge("badge_stone") and Game.has_badge("badge_wave") and Game.has_badge("badge_flame") and Game.has_badge("badge_frost")
			if not ready:
				if _dialogue and _dialogue.has_method("start"):
					_dialogue.start(["暗潮使·玄：「集齐四枚道馆徽章，再来寻我。岩石、清风、烈焰、寒冰，皆需你亲手赢下。」"])
			else:
				Game.pending_trainer = {
					"enemy_id": "shadepup",
					"enemy_level": 18,
					"trainer_name": "暗潮使·玄",
					"badge_id": "badge_mid"
				}
				get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	if _midboss_label:
		if not Game.midboss_done:
			_midboss_label.text = "暗潮使·玄 (按 E 挑战, 需四枚徽章)" if _in_midboss else ""
		else:
			_midboss_label.text = ""

	# 首领灵兽(终Boss = 黯潮之主·凛): 仅中期Boss后于黯潮深渊出现
	if _alpha and is_instance_valid(_alpha) and _alpha.visible:
		var da: float = _player.global_position.distance_to(_alpha.global_position)
		if da < 6.0 and not _in_center and not _in_gym:
			if _alpha_label:
				_alpha_label.text = "黯潮之主·凛 出没! 按 E 挑战 (可收服→终局)"
			if Input.is_action_just_pressed("interact"):
				Game.pending_wild = {"id": "steeljaw_king", "level": 22, "alpha": true, "finale": true}
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
			Game.pending_wild = {"id": "ironhide", "level": 12, "rift": true}
			_rift.consume()
			get_tree().change_scene_to_file("res://battle/BattleArena.tscn")

	# 昼夜光照反馈(平滑插值, 由 Clock.lighting() 驱动)
	if _env:
		var lit: Dictionary = Clock.lighting()
		_env.background_color = lit["sky"]
		_env.fog_light_color = lit["fog"]
		_env.fog_density = float(lit["fog_density"])
		if _light:
			_light.light_energy = float(lit["light"])

	_update_team_label()
	_update_research_label()
	_update_player_hud()
	_update_objective()
	_update_lead_panel()
	_update_savepoint()

func _update_player_hud() -> void:
	if _player_hp_bar:
		_player_hp_bar.value = float(Game.player_hp) / float(max(Game.player_max_hp, 1))
	if _coins_label:
		_coins_label.text = "星辉币: " + str(Game.coins)
	if _shop_label:
		_shop_label.text = "星辉商栈 (按 E 购买)" if _in_shop else ""
	if _camp_label:
		_camp_label.text = "营地 (按 E 扎营休息)" if _in_camp else ""
	if _tera_label:
		_tera_label.text = "晶变坑 (按 E 三人协力讨伐)" if _in_tera else ""
	if _crystal_label:
		_crystal_label.text = "辉光晶簇 (按 E 采集)" if _in_crystal else ""
	if _seal_label:
		_seal_label.text = "古老封印 (按 E 探查)" if _in_seal else ""

func _update_team_label() -> void:
	if not _team_label:
		return
	var s := "队伍:\n"
	for c in Game.team:
		var d: Dictionary = Data.get_creature(c["id"])
		var nm: String = d.get("name", c["id"])
		var st: String = (" [" + String(c.get("status", {}).get("name", "")) + "]") if (c.get("status") != null) else ""
		s += "  " + nm + " Lv" + str(c["level"]) + " HP " + str(c["hp"]) + "/" + str(c["max_hp"]) + st + "\n"
	_team_label.text = s

func _update_research_label() -> void:
	if not _research_label:
		return
	var r: Dictionary = Game.research
	if r.get("done", false):
		_research_label.text = "图鉴研究(金属性): 已完成! 获得远古球"
	else:
		_research_label.text = "图鉴研究(金属性): 收服/击败 " + str(r.get("progress", 0)) + "/" + str(r.get("need", 0))

## 常驻 HUD: 当前目标(主线指引)
func _update_objective() -> void:
	if not _objective:
		return
	_objective.text = "▶ 当前目标：" + Game.current_objective()

## 常驻 HUD: 首发灵兽(队伍首位) 名称/等级/状态/HP
func _update_lead_panel() -> void:
	if not _lead_label or not _lead_hp_bar:
		return
	if Game.team.is_empty():
		_lead_label.text = "（暂无灵兽）"
		_lead_hp_bar.value = 0.0
		return
	var c: Dictionary = Game.team[0]
	var d: Dictionary = Data.get_creature(c["id"])
	var nm: String = d.get("name", c["id"])
	var st: String = ("  [" + str(c.get("status", {}).get("name", "")) + "]") if (c.get("status") != null) else ""
	_lead_label.text = nm + "  Lv" + str(c["level"]) + st
	var ratio: float = float(c["hp"]) / float(max(int(c["max_hp"]), 1))
	_lead_hp_bar.value = ratio
	_lead_hp_bar.modulate = Color(0.4, 1.0, 0.5) if ratio > 0.5 else (Color(1.0, 0.85, 0.3) if ratio > 0.2 else Color(1.0, 0.4, 0.4))

## 常驻 HUD: 存档点 / 复活点提示
func _update_savepoint() -> void:
	if not _savepoint_label:
		return
	var in_zone: bool = _in_center or _in_camp
	var z: String = "⛺ 当前为存档点 · 按 E 休整并自动存档" if in_zone else ""
	_savepoint_label.text = "复活点：" + _last_save_name + ("\n" + z if z != "" else "")
