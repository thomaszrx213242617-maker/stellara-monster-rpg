extends Node3D
class_name BattleArena

## Z-A 式实时战斗:
##  - 玩家操控己方灵兽(队伍首位)实时移动 / Shift 闪避 / 空格放招 / Q 切技能
##  - 敌方由 EnemyAI 驱动; 伤害含属性克制、特性增伤
##  - 击败野生灵兽获得经验(可升级/进化); 按 C 用灵球收服(夜间禁用, 消耗背包球)
##  - 状态异常(中毒/灼烧/麻痹/睡眠)实时生效

const CombatantScript := preload("res://battle/Combatant.gd")
const EnemyAIScript := preload("res://battle/EnemyAI.gd")

var player_combatant
var enemy_combatant
var enemy_ai
var player_cooldown: float = 0.0
var attack_range: float = 3.2
var battle_over: bool = false
var enemy_is_wild: bool = true
var _trainer_name: String = ""
var _badge_id: String = ""

var hud_layer: CanvasLayer
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var hint_label: Label
var move_label: Label
var popup_label: Label
var result_label: Label
var popup_timer: Timer

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
	cam.look_at(Vector3.ZERO, Vector3.UP)
	add_child(cam)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hint_label = Label.new()
	hint_label.text = "WASD移动 | 空格攻击 | Shift闪避 | Q切技能 | C收服(夜晚禁用)"
	hint_label.position = Vector2(20, 12)
	hud_layer.add_child(hint_label)

	move_label = Label.new()
	move_label.position = Vector2(20, 36)
	hud_layer.add_child(move_label)

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

func start_battle() -> void:
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
		GameState.pending_wild = {}

	enemy_combatant = CombatantScript.new()
	enemy_combatant.position = Vector3(6, 1, 0)
	enemy_combatant.setup(enemy_id, enemy_level, false)
	add_child(enemy_combatant)
	enemy_combatant.hp_changed.connect(_on_hp)
	enemy_combatant.defeated_signal.connect(_on_enemy_defeated)

	enemy_ai = EnemyAIScript.new()
	enemy_ai.player = player_combatant
	enemy_ai.enemy = enemy_combatant
	enemy_ai.attack_range = attack_range
	add_child(enemy_ai)
	_refresh_move_label()
	_update_bars()

func _on_hp(_c: int, _m: int) -> void:
	_update_bars()

func _update_bars() -> void:
	if player_combatant:
		player_hp_bar.value = float(player_combatant.hp) / float(max(player_combatant.max_hp, 1))
	if enemy_combatant:
		enemy_hp_bar.value = float(enemy_combatant.hp) / float(max(enemy_combatant.max_hp, 1))
	_refresh_move_label()

func _refresh_move_label() -> void:
	if not player_combatant or not move_label:
		return
	var move_id: String = ""
	if not player_combatant.moves.is_empty():
		move_id = player_combatant.moves[player_combatant.active_move_index]
	var mv: Dictionary = DataBus.get_move(move_id)
	var mtxt: String = "技能: " + (mv.get("name", "无") if not mv.is_empty() else "无")
	var est: String = DataBus.get_creature(player_combatant.creature_id).get("name", "")
	var pst: String = (" [我方:" + player_combatant.status_name + "]") if player_combatant.status_name != "" else ""
	var est2: String = ""
	var estat: String = ""
	if enemy_combatant:
		est2 = DataBus.get_creature(enemy_combatant.creature_id).get("name", "")
		if enemy_combatant.status_name != "":
			estat = " [敌方:" + enemy_combatant.status_name + "]"
	move_label.text = est + " Lv" + str(player_combatant.level) + pst + "  |  " + mtxt + "\n" + est2 + estat

func _physics_process(delta: float) -> void:
	if battle_over:
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
		var dash := dir if dir != Vector3.ZERO else -player_combatant.global_transform.basis.z
		player_combatant.velocity += dash * 9.0
	if Input.is_action_just_pressed("switch_move"):
		player_combatant.set_move_index(player_combatant.active_move_index + 1)
		_refresh_move_label()
	player_combatant.move_dir = dir

	if Input.is_action_pressed("attack") and player_cooldown <= 0.0:
		_player_attack()
	if Input.is_action_just_pressed("capture"):
		_try_capture()

func _player_attack() -> void:
	if player_combatant.moves.is_empty():
		return
	var move_id: String = player_combatant.moves[player_combatant.active_move_index]
	var mv: Dictionary = DataBus.get_move(move_id)
	if mv.is_empty():
		return
	var dist: float = player_combatant.global_position.distance_to(enemy_combatant.global_position)
	if dist > attack_range + 1.0:
		return
	var mult: float = DataBus.multiplier(mv["type"], enemy_combatant.type)
	# 特性: 猛火/蓄水 低血量增伤
	if (player_combatant.ability == "猛火" and mv["type"] == "炎") or (player_combatant.ability == "蓄水" and mv["type"] == "水"):
		if player_combatant.hp < player_combatant.max_hp / 3.0:
			mult *= 1.5
	var power: float = float(mv.get("power", 0))
	if power <= 0.0:
		# 纯状态招式
		if enemy_combatant.invulnerable <= 0.0 and mv.has("status"):
			enemy_combatant.apply_status(mv["status"], 4.0)
			_pop(DataBus.get_creature(enemy_combatant.creature_id)["name"] + " 陷入" + mv["status"])
		player_cooldown = float(mv["cooldown"])
		return
	if enemy_combatant.invulnerable > 0.0:
		_pop("被闪避!")
	else:
		var dmg: float = Combat.calc_damage(player_combatant.stats["atk"], enemy_combatant.stats["def"], power, mult, player_combatant.level, randf_range(0.85, 1.0))
		var cat: String = mv.get("category", "物理")
		enemy_combatant.take_damage(dmg, player_combatant, cat)
		var ename: String = DataBus.get_creature(enemy_combatant.creature_id)["name"]
		var eff: String = DataBus.type_chart.effectiveness_text(mult)
		_pop(ename + " 受 " + str(int(dmg)) + " 伤害 " + eff)
		if mv.has("status") and randf() < float(mv.get("status_chance", 0.0)):
			enemy_combatant.apply_status(mv["status"], 4.0)
			_pop(ename + " 陷入" + mv["status"])
	player_cooldown = float(mv["cooldown"])

func _try_capture() -> void:
	if not enemy_is_wild:
		_pop("无法收服" + _trainer_name + "的灵兽!")
		return
	if not GameState.can_collect():
		_pop("夜晚黯潮汹涌，无法收服灵兽!")
		return
	var ball: String = GameState.first_ball()
	if ball == "":
		_pop("没有灵球了!")
		return
	GameState.consume_item(ball, 1)
	var base: float = DataBus.get_creature(enemy_combatant.creature_id).get("catch_rate", 0.4)
	var chance: float = Combat.capture_chance(enemy_combatant.hp, enemy_combatant.max_hp, base, GameState.ball_mod(ball), 1.0)
	if randf() < chance:
		var ename: String = DataBus.get_creature(enemy_combatant.creature_id)["name"]
		GameState.add_to_team(enemy_combatant.creature_id, enemy_combatant.level)
		GameState.caught_count += 1
		_pop("收服成功! " + ename)
		_end_battle(true)
	else:
		_pop("收服失败……")

func _popup(text: String) -> void:
	if popup_label:
		popup_label.text = text
		popup_timer.start()

func _on_player_defeated() -> void:
	_end_battle(false, "你输了……")

func _on_enemy_defeated() -> void:
	# 给队伍首位加经验
	var pdata: Dictionary = GameState.team[0]
	var exp: int = GameState.wild_exp(enemy_combatant.level)
	var res: Dictionary = GameState.grant_exp(pdata, exp)
	var msg: String = "胜利! 获得 " + str(exp) + " 经验"
	if not enemy_is_wild and _badge_id != "":
		GameState.grant_badge(_badge_id)
		msg += "\n获得徽章: " + _badge_id
	if res["levels"] > 0:
		msg += "\n升级! Lv" + str(pdata["level"])
	if res["evolved"]:
		msg += "\n进化: " + res["from"] + " → " + res["to"] + "!"
	_pop(msg)
	_end_battle(true, "胜利!")

func _end_battle(win: bool, msg: String = "") -> void:
	if battle_over:
		return
	battle_over = true
	# 回写玩家灵兽血量并持久化
	if player_combatant and not GameState.team.is_empty():
		GameState.team[0]["hp"] = int(clamp(player_combatant.hp, 0, player_combatant.max_hp))
	SaveManager.save_game()
	result_label.text = msg if msg != "" else ("胜利!" if win else "失败")
	await get_tree().create_timer(1.8).timeout
	get_tree().change_scene_to_file("res://world/World.tscn")
