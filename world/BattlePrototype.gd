extends Node3D
class_name BattlePrototype

## Z-A 式(异度神剑式)实时战斗原型 · 垂直切片。
## 复用既有积木: Combatant(setup/take_damage) / core/combat.gd(伤害公式) / EnemyAI(敌方行为) / CameraRig(跟随相机)。
## 本原型专门演示「Z-A 标志三件套」(BattleArena 未覆盖的部分):
##   1) 自动攻击: 进入射程后无需按键、按冷却自动出招(异度神剑的灵魂机制)
##   2) 战技(Art): 空格手动释放, 冷却更长、威力更大
##   3) 位置加成: 绕到敌背后「背击 ×1.5」、侧面「侧击 ×1.25」(Z-A 核心博弈)
## 打开本场景按 F6 即玩: WASD 绕圈走位, 绕到敌人背后触发背击; 空格放战技; Q 切换战技。
## 不切场景、不退出, 仅显示胜负面板, 便于作为战斗地基反复试验。

const CombatantScript := preload("res://battle/Combatant.gd")
const EnemyAIScript := preload("res://battle/EnemyAI.gd")
const CombatScript := preload("res://core/combat.gd")
const CameraScript := preload("res://world/CameraRig.gd")

# ---- 可调参数 ----
const AUTO_INTERVAL: float = 1.1      ## 自动攻击间隔(秒)
const ART_INTERVAL: float = 3.0       ## 战技冷却(秒)
const AUTO_POWER: float = 32.0        ## 自动攻击威力(基础)
const ATTACK_RANGE: float = 3.2       ## 进入此距离才攻击
const BACK_MULT: float = 1.5          ## 背击倍率
const SIDE_MULT: float = 1.25         ## 侧击倍率

var player_combatant: Combatant
var enemy_combatant: Combatant
var enemy_ai: Node
var auto_cd: float = 0.0
var art_cd: float = 0.0
var battle_over: bool = false

# HUD
var hud_layer: CanvasLayer
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var auto_label: Label
var art_label: Label
var popup_label: Label
var result_label: Label
var _popup_t: float = 0.0

func _ready() -> void:
	_build_arena()
	_spawn_combatants()
	_build_hud()
	start_battle()

func _build_arena() -> void:
	var env_node := WorldEnvironment.new()
	add_child(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.20, 0.26)
	env.fog_enabled = true
	env.fog_density = 0.015
	env_node.environment = env

	var light := DirectionalLight3D.new()
	light.position = Vector3(6, 16, 8)
	light.rotation = Vector3(deg_to_rad(-50), 0, 0)
	light.light_energy = 1.3
	add_child(light)

	# 地面(40x40, 带碰撞)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_m.mesh = pm
	floor_m.rotate_x(deg_to_rad(-90))
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.3, 0.34, 0.3)
	fmat.roughness = 1.0
	floor_m.material_override = fmat
	add_child(floor_m)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(40, 0.2, 40)
	col.shape = sh
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	add_child(sb)

	# 跟随相机(复用 CameraRig)
	var cam := CameraScript.new()
	add_child(cam)
	# follow_target 在 _spawn_combatants 之后再绑定

func _spawn_combatants() -> void:
	# 玩家: flarefox(炎), 敌: vinelop(木) → 炎克木 2x, 演示属性克制
	player_combatant = CombatantScript.new()
	player_combatant.position = Vector3(0, 1, 0)
	player_combatant.setup("flarefox", 8, true)
	add_child(player_combatant)

	enemy_combatant = CombatantScript.new()
	enemy_combatant.position = Vector3(0, 1, -3.0)   ## 起点在玩家正前方(-Z), 进射程即开打
	enemy_combatant.setup("vinelop", 6, false)
	add_child(enemy_combatant)

	# 初始互相对视
	player_combatant.look_at(enemy_combatant.global_position)
	enemy_combatant.look_at(player_combatant.global_position)

	# 敌方 AI(复用既有 EnemyAI 驱动靠近+出招)
	enemy_ai = EnemyAIScript.new()
	enemy_ai.player = player_combatant
	enemy_ai.enemy = enemy_combatant
	add_child(enemy_ai)

	# 相机绑定到玩家
	for _c in get_children():
		if _c is CameraRig:
			_c.follow_target = _c.get_path_to(player_combatant)

	# 信号: 血条 + 胜负
	player_combatant.hp_changed.connect(_on_player_hp)
	enemy_combatant.hp_changed.connect(_on_enemy_hp)
	player_combatant.defeated_signal.connect(_on_player_defeated)
	enemy_combatant.defeated_signal.connect(_on_enemy_defeated)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	enemy_hp_bar = _make_bar(Vector2(0.5, 0.04), Vector2(0.5, 0.12), Color(0.9, 0.3, 0.3))
	player_hp_bar = _make_bar(Vector2(0.5, 0.04), Vector2(0.5, 0.9), Color(0.3, 0.8, 0.4))

	auto_label = Label.new()
	auto_label.position = Vector2(20, 70)
	hud_layer.add_child(auto_label)
	art_label = Label.new()
	art_label.position = Vector2(20, 95)
	hud_layer.add_child(art_label)

	popup_label = Label.new()
	popup_label.add_theme_font_size_override("font_size", 28)
	popup_label.position = Vector2(20, 140)
	popup_label.modulate = Color(1, 0.9, 0.3)
	hud_layer.add_child(popup_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.text = ""
	result_label.position = Vector2(360, 240)
	result_label.visible = false
	hud_layer.add_child(result_label)

	var hint := Label.new()
	hint.text = "Z-A 实时战斗原型 · WASD 绕圈走位 | 空格=战技(Art) | Q=切换战技 | 绕到敌人背后触发背击×1.5"
	hint.position = Vector2(20, 12)
	hud_layer.add_child(hint)

	_on_player_hp(player_combatant.hp, player_combatant.max_hp)
	_on_enemy_hp(enemy_combatant.hp, enemy_combatant.max_hp)

func _make_bar(size: Vector2, anchor: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size * Vector2(640, 200)   ## 相对缩放用
	bar.size = Vector2(360, 22)
	bar.position = Vector2(anchor.x * 640 - 180, anchor.y * 400)
	bar.show_percentage = false
	bar.modulate = color
	hud_layer.add_child(bar)
	return bar

func start_battle() -> void:
	_popup("战斗开始! 绕到背后打背击")

func _physics_process(delta: float) -> void:
	if battle_over:
		return
	auto_cd = max(0.0, auto_cd - delta)
	art_cd = max(0.0, art_cd - delta)
	if _popup_t > 0.0:
		_popup_t = max(0.0, _popup_t - delta)
		if _popup_t == 0.0:
			popup_label.text = ""

	# 玩家移动(相机相对, 与 BattleArena 同逻辑)
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_back"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	var dir := Vector3.ZERO
	if input_dir != Vector3.ZERO:
		var cam := get_viewport().get_camera_3d()
		var basis := Basis()
		if cam:
			basis = cam.global_transform.basis
		var fwd := -basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var right := basis.x
		right.y = 0
		right = right.normalized()
		dir = (fwd * -input_dir.z + right * input_dir.x).normalized()
	player_combatant.move_dir = dir

	# 战技(Art): 空格手动释放
	if Input.is_action_just_pressed("attack") and art_cd <= 0.0:
		_do_art()
		art_cd = ART_INTERVAL
	# 切换战技
	if Input.is_action_just_pressed("switch_move"):
		player_combatant.set_move_index(player_combatant.active_move_index + 1)

	# 自动攻击(Z-A 灵魂): 进射程后无需按键定时触发
	if auto_cd <= 0.0 and not enemy_combatant.defeated:
		var dist: float = Vector2(player_combatant.global_position.x, player_combatant.global_position.z).distance_to(
			Vector2(enemy_combatant.global_position.x, enemy_combatant.global_position.z))
		if dist <= ATTACK_RANGE:
			_do_auto_attack()
			auto_cd = AUTO_INTERVAL

	_update_labels()

func _positional(attacker: Node3D, target: Node3D) -> Array:
	## 返回 [倍率, 文案]: 攻击者相对目标的方位(背/侧/正)
	var to_atk := Vector3(attacker.global_position.x - target.global_position.x, 0,
		attacker.global_position.z - target.global_position.z)
	to_atk = to_atk.normalized()
	var fwd := -target.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var d: float = to_atk.dot(fwd)
	if d < -0.5:
		return [BACK_MULT, "背击! ×1.5"]
	if d > 0.5:
		return [1.0, "正面"]
	return [SIDE_MULT, "侧击! ×1.25"]

func _do_auto_attack() -> void:
	if enemy_combatant.defeated:
		return
	# 自动攻击用自身属性做克制判定(炎 vs 木 = 2x)
	var mult: float = Data.multiplier(player_combatant.type, enemy_combatant.type)
	var pos: Array = _positional(player_combatant, enemy_combatant)
	var dmg: float = CombatScript.calc_damage(
		player_combatant.stats["atk"], enemy_combatant.stats["def"], AUTO_POWER, mult,
		player_combatant.level, randf_range(0.85, 1.0)) * pos[0] * player_combatant.dmg_mult
	SFX.play_sfx("attack")
	player_combatant.look_at(enemy_combatant.global_position)
	enemy_combatant.take_damage(dmg, player_combatant, "物理")
	_popup("自动攻击 " + str(int(dmg)) + "  " + pos[1])

func _do_art() -> void:
	if enemy_combatant.defeated or player_combatant.moves.is_empty():
		return
	var move_id: String = player_combatant.moves[player_combatant.active_move_index]
	var mv: Dictionary = Data.get_move(move_id)
	if mv.is_empty():
		return
	var mult: float = Data.multiplier(mv.get("type", "炎"), enemy_combatant.type)
	if mult == 0.0:
		_popup("对 " + enemy_combatant.type + " 无效!")
		return
	var power: float = float(mv.get("power", 60))
	var pos: Array = _positional(player_combatant, enemy_combatant)
	var dmg: float = CombatScript.calc_damage(
		player_combatant.stats["atk"], enemy_combatant.stats["def"], power, mult,
		player_combatant.level, randf_range(0.9, 1.05)) * pos[0] * player_combatant.dmg_mult
	SFX.play_sfx("attack")
	player_combatant.look_at(enemy_combatant.global_position)
	enemy_combatant.take_damage(dmg, player_combatant, mv.get("category", "特殊"))
	_popup("战技 " + mv.get("name", move_id) + " " + str(int(dmg)) + "  " + pos[1])

func _update_labels() -> void:
	auto_label.text = "自动攻击: " + ("就绪" if auto_cd <= 0.0 else "%.1f s" % auto_cd)
	art_label.text = "战技(Space): " + ("就绪" if art_cd <= 0.0 else "%.1f s" % art_cd)

func _on_player_hp(cur: int, maxv: int) -> void:
	if player_hp_bar == null:
		return
	player_hp_bar.max_value = maxv
	player_hp_bar.value = cur

func _on_enemy_hp(cur: int, maxv: int) -> void:
	if enemy_hp_bar == null:
		return
	enemy_hp_bar.max_value = maxv
	enemy_hp_bar.value = cur

func _on_player_defeated() -> void:
	if battle_over:
		return
	battle_over = true
	result_label.text = "战败……"
	result_label.modulate = Color(1, 0.4, 0.4)
	result_label.visible = true

func _on_enemy_defeated() -> void:
	if battle_over:
		return
	battle_over = true
	result_label.text = "胜利!"
	result_label.modulate = Color(0.5, 1.0, 0.6)
	result_label.visible = true

func _popup(text: String) -> void:
	if popup_label == null:
		return
	popup_label.text = text
	_popup_t = 0.9
