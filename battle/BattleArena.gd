extends Node3D
class_name BattleArena

## Z-A 式实时战斗:
##  - 玩家操控己方灵兽(队伍首位)实时移动 / Shift 闪避 / 空格放招 / Q 切技能
##  - 敌方由 EnemyAI 驱动; 伤害含属性克制、特性增伤
##  - 击败野生灵兽获得经验(可升级/进化); 按 C 用灵球收服(夜间禁用, 消耗背包球)
##  - 状态异常(中毒/灼烧/麻痹/睡眠)实时生效

const CombatantScript := preload("res://battle/Combatant.gd")
const EnemyAIScript := preload("res://battle/EnemyAI.gd")
const CombatScript := preload("res://core/combat.gd")

var player_combatant
var enemy_combatant
var enemy_ai
var player_cooldown: float = 0.0
var attack_range: float = 3.2
var battle_over: bool = false
var enemy_is_wild: bool = true
var _trainer_name: String = ""
var _badge_id: String = ""
var _enemy_is_alpha: bool = false
var _enemy_is_finale: bool = false

var hud_layer: CanvasLayer
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var hint_label: Label
var _move_box: VBoxContainer
var popup_label: Label
var result_label: Label
var popup_timer: Timer
var item_btn: Button
var ball_btn: Button
var _giant_btn: Button
var _crystal_btn: Button
var _hyper_btn: Button
var coin_label: Label

## 晶变坑(太晶坑原创命名)讨伐: 三名训练家协助, 胜利后可选收服/放弃
var _raid_mode: bool = false
var _raid_pending: bool = false
var _raid_allies: Array = []
var _ally_t: float = 0.0
var _raid_panel: Panel

## 三秘环: 每场战斗各可用一次(巨灵环/晶变环/超衍环)
var _bands_used: Dictionary = {"giant": false, "crystal": false, "hyper": false}

func _ready() -> void:
	build_arena()
	_build_hud()
	start_battle()

func build_arena() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.22, 0.28)
	env_node.environment = env

	var light := DirectionalLight3D.new()
	light.position = Vector3(5, 15, 5)
	light.rotation = Vector3(deg_to_rad(-50), 0, 0)
	add_child(light)

	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_m.mesh = pm
	floor_m.rotate_x(deg_to_rad(-90))
	add_child(floor_m)

	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(40, 0.2, 40)
	col.shape = sh
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 13, 17)
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hint_label = Label.new()
	hint_label.text = "WASD移动 | 空格攻击 | Shift闪避 | Q切技能 | C收服(夜晚禁用) | I/按钮 伤药 | 巨灵/晶变/超衍环 各一场一次"
	hint_label.position = Vector2(20, 12)
	hud_layer.add_child(hint_label)

	# 招式列表(放大 + 按克制效果四档着色)。背景面板提升可读性
	var move_bg := Panel.new()
	move_bg.position = Vector2(10, 30)
	move_bg.size = Vector2(400, 168)
	var move_bg_style := StyleBoxFlat.new()
	move_bg_style.bg_color = Color(0.05, 0.07, 0.12, 0.55)
	move_bg_style.corner_radius_top_left = 8
	move_bg_style.corner_radius_top_right = 8
	move_bg_style.corner_radius_bottom_left = 8
	move_bg_style.corner_radius_bottom_right = 8
	move_bg.add_theme_stylebox_override("panel", move_bg_style)
	hud_layer.add_child(move_bg)

	_move_box = VBoxContainer.new()
	_move_box.position = Vector2(20, 40)
	_move_box.size = Vector2(380, 150)
	_move_box.add_theme_constant_override("separation", 3)
	hud_layer.add_child(_move_box)

	var pl := Label.new()
	pl.text = "我方"
	pl.position = Vector2(20, 360)
	hud_layer.add_child(pl)
	player_hp_bar = ProgressBar.new()
	player_hp_bar.position = Vector2(20, 380)
	player_hp_bar.size = Vector2(320, 20)
	player_hp_bar.max_value = 1.0
	hud_layer.add_child(player_hp_bar)

	var el := Label.new()
	el.text = "敌方"
	el.position = Vector2(480, 360)
	hud_layer.add_child(el)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(480, 380)
	enemy_hp_bar.size = Vector2(320, 20)
	enemy_hp_bar.max_value = 1.0
	hud_layer.add_child(enemy_hp_bar)

	popup_label = Label.new()
	popup_label.position = Vector2(180, 300)
	popup_label.scale = Vector2(1.4, 1.4)
	hud_layer.add_child(popup_label)
	popup_timer = Timer.new()
	popup_timer.wait_time = 1.6
	popup_timer.one_shot = true
	popup_timer.timeout.connect(func(): if popup_label: popup_label.text = "")
	hud_layer.add_child(popup_timer)

	result_label = Label.new()
	result_label.position = Vector2(300, 200)
	result_label.scale = Vector2(2, 2)
	hud_layer.add_child(result_label)

	# 道具/伤药按钮(队伍首位HP未满且有伤药时可用)
	item_btn = Button.new()
	item_btn.text = "道具 / 伤药"
	item_btn.position = Vector2(20, 412)
	item_btn.custom_minimum_size = Vector2(150, 38)
	item_btn.pressed.connect(_on_use_potion)
	hud_layer.add_child(item_btn)

	# 切换球按钮(朱紫式: 战斗中可切换使用的灵球)
	ball_btn = Button.new()
	ball_btn.position = Vector2(185, 412)
	ball_btn.custom_minimum_size = Vector2(170, 38)
	ball_btn.pressed.connect(_on_cycle_ball)
	hud_layer.add_child(ball_btn)
	_refresh_ball_btn()

	coin_label = Label.new()
	coin_label.position = Vector2(480, 412)
	coin_label.add_theme_font_size_override("font_size", 16)
	hud_layer.add_child(coin_label)

	# 三秘环按钮(每场战斗各可用一次)——原创命名, 对应极巨/太晶/超演之力
	_giant_btn = Button.new()
	_giant_btn.text = "巨灵环"
	_giant_btn.position = Vector2(20, 456)
	_giant_btn.custom_minimum_size = Vector2(130, 34)
	_giant_btn.pressed.connect(_on_use_band.bind("giant"))
	hud_layer.add_child(_giant_btn)
	_crystal_btn = Button.new()
	_crystal_btn.text = "晶变环"
	_crystal_btn.position = Vector2(155, 456)
	_crystal_btn.custom_minimum_size = Vector2(130, 34)
	_crystal_btn.pressed.connect(_on_use_band.bind("crystal"))
	hud_layer.add_child(_crystal_btn)
	_hyper_btn = Button.new()
	_hyper_btn.text = "超衍环"
	_hyper_btn.position = Vector2(290, 456)
	_hyper_btn.custom_minimum_size = Vector2(130, 34)
	_hyper_btn.pressed.connect(_on_use_band.bind("hyper"))
	hud_layer.add_child(_hyper_btn)
	_refresh_band_btns()

	# 晶变坑讨伐结果: 收服 / 放弃
	_raid_panel = Panel.new()
	_raid_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_raid_panel.custom_minimum_size = Vector2(440, 200)
	_raid_panel.visible = false
	hud_layer.add_child(_raid_panel)
	var rl := Label.new()
	rl.text = "讨伐成功！是否收服这只灵兽？"
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.add_theme_font_size_override("font_size", 20)
	rl.position = Vector2(20, 22)
	rl.size = Vector2(400, 40)
	_raid_panel.add_child(rl)
	var cap_btn := Button.new()
	cap_btn.text = "收服"
	cap_btn.custom_minimum_size = Vector2(160, 50)
	cap_btn.position = Vector2(50, 100)
	cap_btn.pressed.connect(func(): _raid_finish(true))
	_raid_panel.add_child(cap_btn)
	var dec_btn := Button.new()
	dec_btn.text = "放弃收服"
	dec_btn.custom_minimum_size = Vector2(160, 50)
	dec_btn.position = Vector2(230, 100)
	dec_btn.pressed.connect(func(): _raid_finish(false))
	_raid_panel.add_child(dec_btn)

func start_battle() -> void:
	# 记录当前场景, 退出重进时自动回到此处(续玩)
	if GameState.battle_return_scene != "":
		GameState.current_scene = GameState.battle_return_scene
	else:
		GameState.current_scene = "res://world/World.tscn"
	if GameState.team.is_empty():
		GameState.add_to_team("flarefox", 5)
	var pdata: Dictionary = GameState.team[0]
	player_combatant = CombatantScript.new()
	player_combatant.position = Vector3(-6, 1, 0)
	player_combatant.setup(pdata["id"], int(pdata["level"]), true, int(pdata.get("hp", -1)))
	add_child(player_combatant)
	player_combatant.hp_changed.connect(_on_hp)
	player_combatant.defeated_signal.connect(_on_player_defeated)

	var enemy_id: String = "aqualeap"
	var enemy_level: int = 5
	enemy_is_wild = true
	if not GameState.pending_trainer.is_empty():
		enemy_id = GameState.pending_trainer.get("enemy_id", "aqualeap")
		enemy_level = int(GameState.pending_trainer.get("enemy_level", 5))
		enemy_is_wild = false
		_trainer_name = GameState.pending_trainer.get("trainer_name", "训练家")
		_badge_id = GameState.pending_trainer.get("badge_id", "")
		GameState.pending_trainer = {}
	elif not GameState.pending_wild.is_empty():
		enemy_id = GameState.pending_wild.get("id", "aqualeap")
		enemy_level = int(GameState.pending_wild.get("level", 5))
		_enemy_is_alpha = GameState.pending_wild.get("alpha", false)
		_enemy_is_finale = GameState.pending_wild.get("finale", false)
		GameState.pending_wild = {}

	# ---- 晶变坑讨伐(三人协力): 独立分支, 覆盖默认敌人 ----
	if not GameState.pending_raid.is_empty():
		_enter_raid_mode()
		return

	enemy_combatant = CombatantScript.new()
	enemy_combatant.position = Vector3(6, 1, 0)
	enemy_combatant.setup(enemy_id, enemy_level, false)
	if _enemy_is_alpha:
		enemy_combatant.scale = Vector3(1.7, 1.7, 1.7)
		if GameState.pending_wild.get("finale", false):
			_pop("黯潮之主·凛 现身! 曾经的伙伴，如今被黯潮吞没……")
		else:
			_pop("首领灵兽 " + DataBus.get_creature(enemy_id).get("name", "") + " 出现!")
	add_child(enemy_combatant)
	enemy_combatant.hp_changed.connect(_on_hp)
	enemy_combatant.defeated_signal.connect(_on_enemy_defeated)
	# 图鉴: 遭遇即记为「已见」
	GameState.note_dex_seen(enemy_combatant.creature_id)
	if coin_label:
		coin_label.text = "星辉币: " + str(GameState.coins)

	enemy_ai = EnemyAIScript.new()
	enemy_ai.player = player_combatant
	enemy_ai.enemy = enemy_combatant
	enemy_ai.attack_range = attack_range
	add_child(enemy_ai)
	# 秘环每场重置(各可用一次)
	_bands_used = {"giant": false, "crystal": false, "hyper": false}
	_refresh_band_btns()
	_refresh_move_label()
	_update_bars()

func _on_hp(_c: int, _m: int) -> void:
	_update_bars()

func _update_bars() -> void:
	if player_combatant and player_hp_bar:
		player_hp_bar.value = float(player_combatant.hp) / float(max(player_combatant.max_hp, 1))
	if enemy_combatant and enemy_hp_bar:
		enemy_hp_bar.value = float(enemy_combatant.hp) / float(max(enemy_combatant.max_hp, 1))
	_refresh_move_label()

func _refresh_move_label() -> void:
	if not player_combatant or not _move_box:
		return
	for c in _move_box.get_children():
		c.queue_free()
	var pc_name: String = DataBus.get_creature(player_combatant.creature_id).get("name", "我方")
	var pst: String = ("  [我方:" + player_combatant.status_name + "]") if player_combatant.status_name != "" else ""
	var enemy_type: String = ""
	var enemy_name: String = ""
	var estat: String = ""
	if enemy_combatant and not enemy_combatant.defeated:
		enemy_type = enemy_combatant.type
		enemy_name = DataBus.get_creature(enemy_combatant.creature_id).get("name", "敌方")
		if enemy_combatant.status_name != "":
			estat = " [敌方:" + enemy_combatant.status_name + "]"

	var header := Label.new()
	header.text = pc_name + " Lv" + str(player_combatant.level) + pst + ("  |  敌:" + enemy_name + " [" + enemy_type + "]" + estat if enemy_name != "" else "")
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1, 1, 1))
	_move_box.add_child(header)

	if player_combatant.moves.is_empty():
		var none := Label.new()
		none.text = "(无招式)"
		none.add_theme_font_size_override("font_size", 16)
		none.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_move_box.add_child(none)
		return

	for i in range(player_combatant.moves.size()):
		var mv: Dictionary = DataBus.get_move(player_combatant.moves[i])
		if mv.is_empty():
			continue
		var mv_name: String = mv.get("name", "???")
		var mv_type: String = mv.get("type", "?")
		var mult: float = 1.0
		if enemy_type != "":
			mult = DataBus.multiplier(mv_type, enemy_type)
		var tier: String = DataBus.type_chart.tier_label(mult)
		var col: Color = DataBus.type_chart.tier_color_value(mult)
		var mark: String = "▶ " if i == player_combatant.active_move_index else "   "
		var mult_txt: String = (" ×" + ("%.1f" % mult)) if enemy_type != "" else ""
		var row := Label.new()
		row.text = mark + mv_name + " [" + mv_type + "]" + mult_txt + "  " + tier
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override("font_color", col)
		_move_box.add_child(row)

func _physics_process(delta: float) -> void:
	if battle_over or _raid_pending:
		return
	player_cooldown = max(0.0, player_cooldown - delta)

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_back"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	var dir := Vector3.ZERO
	if input_dir != Vector3.ZERO:
		dir = Vector3(input_dir.x, 0, input_dir.z).normalized()
	if Input.is_action_just_pressed("dodge"):
		player_combatant.invulnerable = 0.4
		var dash: Vector3 = dir if dir != Vector3.ZERO else -player_combatant.global_transform.basis.z
		player_combatant.velocity += dash * 9.0
	if Input.is_action_just_pressed("switch_move"):
		player_combatant.set_move_index(player_combatant.active_move_index + 1)
		_refresh_move_label()
	player_combatant.move_dir = dir

	if Input.is_action_pressed("attack") and player_cooldown <= 0.0:
		_player_attack()
	# 协助训练家自动攻击(晶变坑三人协力)
	if _raid_mode and enemy_combatant and not enemy_combatant.defeated:
		_ally_t += delta
		if _ally_t >= 1.6:
			_ally_t = 0.0
			var dmg: float = 8.0 + float(player_combatant.level) * 1.5
			for _a in _raid_allies:
				enemy_combatant.take_damage(dmg, null, "特殊")
			_pop("三名训练家协力攻击！总计 -" + str(int(dmg * _raid_allies.size())))
	if Input.is_action_just_pressed("capture"):
		_try_capture()

func _player_attack() -> void:
	if player_combatant == null or player_combatant.moves.is_empty():
		return
	if enemy_combatant == null or enemy_combatant.defeated:
		return
	var move_id: String = player_combatant.moves[player_combatant.active_move_index]
	var mv: Dictionary = DataBus.get_move(move_id)
	if mv.is_empty():
		return
	var dist: float = player_combatant.global_position.distance_to(enemy_combatant.global_position)
	if dist > attack_range + 1.0:
		return
	var mult: float = DataBus.multiplier(mv.get("type", "炎"), enemy_combatant.type)
	# 特性: 猛火/蓄水 低血量增伤
	if (player_combatant.ability == "猛火" and mv.get("type", "") == "炎") or (player_combatant.ability == "蓄水" and mv.get("type", "") == "水"):
		if player_combatant.hp < player_combatant.max_hp / 3.0:
			mult *= 1.5
	var ename: String = DataBus.get_creature(enemy_combatant.creature_id).get("name", "敌方")
	# 没有效果: 完全不扣血、不施加状态(用户明确要求)
	if mult == 0.0:
		player_cooldown = float(mv.get("cooldown", 1.0))
		_pop(ename + " 对 " + enemy_combatant.type + " 属性没有效果，不造成伤害！")
		return
	var power: float = float(mv.get("power", 0))
	if power <= 0.0:
		# 纯状态招式
		if enemy_combatant.invulnerable <= 0.0 and mv.has("status"):
			enemy_combatant.apply_status(mv["status"], 4.0)
			_pop(ename + " 陷入" + str(mv["status"]))
		player_cooldown = float(mv.get("cooldown", 1.0))
		return
	if enemy_combatant.invulnerable > 0.0:
		_pop("被闪避!")
	else:
		var dmg: float = CombatScript.calc_damage(player_combatant.stats["atk"], enemy_combatant.stats["def"], power, mult, player_combatant.level, randf_range(0.85, 1.0)) * player_combatant.dmg_mult
		var cat: String = mv.get("category", "物理")
		enemy_combatant.take_damage(dmg, player_combatant, cat)
		var eff: String = DataBus.type_chart.effectiveness_text(mult)
		_pop(ename + " 受 " + str(int(dmg)) + " 伤害 " + eff)
		if mv.has("status") and randf() < float(mv.get("status_chance", 0.0)):
			enemy_combatant.apply_status(mv["status"], 4.0)
			_pop(ename + " 陷入" + str(mv["status"]))
	player_cooldown = float(mv.get("cooldown", 1.0))

func _try_capture() -> void:
	if _raid_mode:
		_pop("晶变坑讨伐中无法收服，胜利后再决定。")
		return
	if not enemy_is_wild:
		_pop("无法收服" + _trainer_name + "的灵兽!")
		return
	if not GameState.can_collect():
		_pop("夜晚黯潮汹涌，无法收服灵兽!")
		return
	var ball: String = GameState.selected_ball
	if ball == "" or GameState.inventory.get(ball, 0) <= 0:
		ball = GameState.first_ball()
	if ball == "":
		_pop("没有灵球了!")
		return
	GameState.consume_item(ball, 1)
	_refresh_ball_btn()
	var ename: String = DataBus.get_creature(enemy_combatant.creature_id).get("name", "敌方")
	var base: float = DataBus.get_creature(enemy_combatant.creature_id).get("catch_rate", 0.4)
	var chance: float = CombatScript.capture_chance(enemy_combatant.hp, enemy_combatant.max_hp, base, GameState.ball_mod(ball), 1.0)
	if randf() < chance:
		GameState.add_to_team(enemy_combatant.creature_id, enemy_combatant.level)
		GameState.caught_count += 1
		GameState.note_dex_caught(enemy_combatant.creature_id)
		GameState.note_research(DataBus.get_creature(enemy_combatant.creature_id).get("type", ""))
		_pop("用" + DataBus.get_item(ball).get("name", "灵球") + "收服成功! " + ename)
		_end_battle(true)
	else:
		_pop("收服失败……")

## 战斗中切换使用的灵球(朱紫式)
func _on_cycle_ball() -> void:
	var b: String = GameState.cycle_ball()
	_refresh_ball_btn()

func _refresh_ball_btn() -> void:
	if not ball_btn:
		return
	var b: String = GameState.selected_ball
	if b == "" or GameState.inventory.get(b, 0) <= 0:
		b = GameState.first_ball()
	if b == "":
		ball_btn.text = "灵球: 无"
		return
	var it: Dictionary = DataBus.get_item(b)
	ball_btn.text = "灵球: " + it.get("name", b) + " ×" + str(GameState.inventory.get(b, 0))

## ---- 三秘环: 每场战斗各可用一次 ----
func _on_use_band(kind: String) -> void:
	if battle_over or not player_combatant or not GameState.transformation_bands:
		return
	if _bands_used.get(kind, false):
		_pop("该秘环本场已经用过了")
		return
	_apply_band(kind)
	_bands_used[kind] = true
	_refresh_band_btns()

func _apply_band(kind: String) -> void:
	var p: Combatant = player_combatant
	var nm: String = DataBus.get_creature(p.creature_id).get("name", "")
	match kind:
		"giant":
			p.stats["atk"] = int(float(p.stats["atk"]) * 1.5)
			p.max_hp = int(float(p.max_hp) * 1.5)
			p.hp = p.max_hp
			p.scale = Vector3(1.8, 1.8, 1.8)
			_pop("巨灵环！" + nm + " 巨大化, 攻击与体力大涨!")
		"crystal":
			p.dmg_mult *= 1.5
			if p.mesh:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.7, 0.85, 1.0)
				p.mesh.material_override = mat
			_pop("晶变环！" + nm + " 招式伤害提升, 泛起金属光泽!")
		"hyper":
			p.stats["atk"] = int(float(p.stats["atk"]) * 1.6)
			p.base_speed *= 1.4
			p.max_hp = int(float(p.max_hp) * 1.3)
			p.hp = p.max_hp
			_pop("超衍环！" + nm + " 速度与攻击飙升!")
	_refresh_move_label()
	_update_bars()

func _refresh_band_btns() -> void:
	if not _giant_btn:
		return
	var owned: bool = GameState.transformation_bands
	_giant_btn.visible = owned
	_crystal_btn.visible = owned
	_hyper_btn.visible = owned
	if not owned:
		return
	_giant_btn.text = "巨灵环" + (" ✓" if _bands_used.get("giant", false) else "")
	_giant_btn.disabled = _bands_used.get("giant", false)
	_crystal_btn.text = "晶变环" + (" ✓" if _bands_used.get("crystal", false) else "")
	_crystal_btn.disabled = _bands_used.get("crystal", false)
	_hyper_btn.text = "超衍环" + (" ✓" if _bands_used.get("hyper", false) else "")
	_hyper_btn.disabled = _bands_used.get("hyper", false)

## 胜利奖励星辉币
func _award_coins() -> void:
	var reward: int = 20 + enemy_combatant.level * 4
	GameState.coins += reward
	if coin_label:
		coin_label.text = "星辉币: " + str(GameState.coins) + " (+" + str(reward) + ")"

func _pop(text: String) -> void:
	if popup_label:
		popup_label.text = text
		popup_timer.start()

## 战斗中给队伍首位使用伤药(原创: 普通伤药+20 / 超级伤药+50)
func _on_use_potion() -> void:
	if battle_over or not player_combatant:
		return
	if int(player_combatant.hp) >= int(player_combatant.max_hp):
		_pop("HP 已满，无需伤药")
		return
	var has_super: bool = int(GameState.inventory.get("super_potion", 0)) > 0
	var has_pot: bool = int(GameState.inventory.get("potion", 0)) > 0
	if not has_super and not has_pot:
		_pop("没有伤药了!")
		return
	var use_super: bool = has_super
	var heal: int = 50 if use_super else 20
	var item_id: String = "super_potion" if use_super else "potion"
	GameState.consume_item(item_id, 1)
	var before: int = int(player_combatant.hp)
	player_combatant.hp = mini(player_combatant.max_hp, before + heal)
	if not GameState.team.is_empty():
		GameState.team[0]["hp"] = int(player_combatant.hp)
	GameState.team_changed.emit()
	var label: String = "超级伤药" if use_super else "伤药"
	_pop("使用" + label + "！HP +" + str(int(player_combatant.hp) - before))
	_update_bars()

func _on_player_defeated() -> void:
	_end_battle(false, "你输了……")

func _on_enemy_defeated() -> void:
	# 晶变坑讨伐: 击败后让玩家选择收服或放弃
	if _raid_mode and not _raid_pending:
		_raid_pending = true
		_award_coins()
		_show_raid_result()
		return
	# 给队伍首位加经验
	if GameState.team.is_empty():
		_award_coins()
		_end_battle(true, "胜利!")
		return
	var pdata: Dictionary = GameState.team[0]
	var exp: int = GameState.wild_exp(enemy_combatant.level)
	if _enemy_is_alpha:
		exp = int(exp * 1.5)
	var res: Dictionary = GameState.grant_exp(pdata, exp)
	var msg: String = "胜利! 获得 " + str(exp) + " 经验"
	if enemy_is_wild:
		GameState.note_research(enemy_combatant.type)
	if not enemy_is_wild and _badge_id != "":
		GameState.grant_badge(_badge_id)
		if _badge_id == "badge_mid":
			GameState.midboss_done = true
		msg += "\n获得徽章: " + _badge_id
	if res["levels"] > 0:
		msg += "\n升级! Lv" + str(pdata["level"])
	if res["evolved"]:
		msg += "\n进化: " + res["from"] + " → " + res["to"] + "!"
	_pop(msg)
	_award_coins()

	# ---- 终局链: 凛(stage0) → 辉金龙(stage1) → 黯钢兽(stage2) → 结局 ----
	# 注意: 三场都是 finale+alpha, 必须用 finale_stage 区分, 否则会卡在辉金龙无限循环
	if _enemy_is_finale and _enemy_is_alpha:
		if GameState.finale_stage == 0:
			# 第一阶段: 击败黯潮之主·凛
			GameState.finale_stage = 1
			GameState.pending_wild = {"id": "hui_jin_long", "level": 32, "alpha": true, "finale": true}
			_end_battle(true, "凛倒下了！但辉金龙自黯潮中崛起——迎战！", "res://battle/BattleArena.tscn")
			return
		elif GameState.finale_stage == 1:
			# 第二阶段: 击败辉金龙
			GameState.finale_stage = 2
			GameState.pending_wild = {"id": "an_gang_shou", "level": 34, "alpha": true, "finale": true}
			_end_battle(true, "辉金龙归服！黯钢兽咆哮着现身！", "res://battle/BattleArena.tscn")
			return
		elif GameState.finale_stage == 2:
			# 第三阶段: 击败黯钢兽 → 收服双神兽, 进入结局
			GameState.obtain_legendary("hui_jin_long")
			GameState.obtain_legendary("an_gang_shou")
			GameState.ending_done = true
			GameState.story_stage = 3
			_end_battle(true, "双神兽归你所有！星澜大陆重归平衡。", "res://ui/EndingCutscene.tscn")
			return
	# 首领灵兽(终Boss, 非终局旗标)被击败 → 进入结局(兜底)
	if _enemy_is_alpha:
		GameState.ending_done = true
		GameState.story_stage = 3
		_end_battle(true, "首领灵兽倒下……星辉重燃！", "res://ui/EndingCutscene.tscn")
		return
	_end_battle(true, "胜利!")

## ---- 晶变坑讨伐(太晶坑原创) ----
func _enter_raid_mode() -> void:
	_raid_mode = true
	var cfg: Dictionary = GameState.pending_raid
	var boss_id: String = cfg.get("boss_id", "crystal_guardian")
	var boss_level: int = int(cfg.get("boss_level", 28))
	var allies: Array = cfg.get("allies", [])
	enemy_is_wild = true
	enemy_combatant = CombatantScript.new()
	enemy_combatant.position = Vector3(9, 1, 0)
	enemy_combatant.setup(boss_id, boss_level, false)
	enemy_combatant.scale = Vector3(1.5, 1.5, 1.5)
	add_child(enemy_combatant)
	enemy_combatant.hp_changed.connect(_on_hp)
	enemy_combatant.defeated_signal.connect(_on_enemy_defeated)
	GameState.note_dex_seen(enemy_combatant.creature_id)
	_pop("晶变坑讨伐！" + DataBus.get_creature(boss_id).get("name", "") + " 现身！三名训练家前来协助！")
	# 协助训练家(视觉 + 自动攻击)
	_raid_allies = []
	var slots := [Vector3(-9, 1, 4), Vector3(-9, 1, 0), Vector3(-9, 1, -4)]
	for i in range(min(allies.size(), 3)):
		_raid_allies.append(_make_ally(allies[i], slots[i]))
	enemy_ai = EnemyAIScript.new()
	enemy_ai.player = player_combatant
	enemy_ai.enemy = enemy_combatant
	enemy_ai.attack_range = attack_range
	add_child(enemy_ai)
	_bands_used = {"giant": false, "crystal": false, "hyper": false}
	_refresh_band_btns()
	_refresh_move_label()
	_update_bars()

func _make_ally(name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.5
	bm.height = 1.4
	body.mesh = bm
	body.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 0.5)
	mat.roughness = 0.55
	body.material_override = mat
	n.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.36
	hm.height = 0.72
	head.mesh = hm
	head.position = Vector3(0, 1.85, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.95, 0.85, 0.7)
	hmat.roughness = 0.55
	head.material_override = hmat
	n.add_child(head)
	var label := Label3D.new()
	label.text = name
	label.position = Vector3(0, 2.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26
	label.modulate = Color(1, 1, 1)
	n.add_child(label)
	add_child(n)
	return n

func _show_raid_result() -> void:
	if _raid_panel:
		_raid_panel.visible = true

func _raid_finish(capture: bool) -> void:
	if _raid_panel:
		_raid_panel.visible = false
	if capture and enemy_combatant:
		var id: String = enemy_combatant.creature_id
		GameState.add_to_team(id, enemy_combatant.level)
		GameState.note_dex_caught(id)
		GameState.note_research(enemy_combatant.type)
		_pop("收服了 " + DataBus.get_creature(id).get("name", "") + "！")
	else:
		_pop("你放弃了收服。")
	GameState.pending_raid = {}
	_end_battle(true, "晶变坑讨伐完成！", "res://world/World.tscn")

func _end_battle(win: bool, msg: String = "", next_scene: String = "res://world/World.tscn") -> void:
	if battle_over:
		return
	battle_over = true
	# 回写玩家灵兽血量并持久化
	if player_combatant and not GameState.team.is_empty():
		GameState.team[0]["hp"] = int(clamp(player_combatant.hp, 0, player_combatant.max_hp))
	SaveManager.save_game()
	result_label.text = msg if msg != "" else ("胜利!" if win else "失败")
	# 序章探险等场景可指定战斗结束后的返回点
	var target: String = next_scene
	if GameState.battle_return_scene != "":
		target = GameState.battle_return_scene
		GameState.battle_return_scene = ""
	await get_tree().create_timer(1.8).timeout
	get_tree().change_scene_to_file(target)
