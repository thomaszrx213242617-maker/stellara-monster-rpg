extends Node3D
class_name BattleArena

## Z-A 式实时战斗原型:
##  - 玩家操控己方灵兽(来自队伍首位)实时移动 / Shift 闪避 / 空格放招
##  - 敌方灵兽由 EnemyAI 驱动, 靠近并攻击
##  - 伤害含属性克制倍率与随机; 一方 HP 归零判负
##  - 按 C 尝试收服野生灵兽; 夜间被规则拦截 (见 REQUIREMENTS.md §8)

const CombatantScript := preload("res://battle/Combatant.gd")
const EnemyAIScript := preload("res://battle/EnemyAI.gd")

var player_combatant
var enemy_combatant
var enemy_ai
var player_cooldown: float = 0.0
var attack_range: float = 3.0
var battle_over: bool = false
var enemy_is_wild: bool = true

var hud_layer: CanvasLayer
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var info_label: Label
var result_label: Label

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
    var pl := Label.new()
    pl.text = "玩家灵兽"
    pl.position = Vector2(20, 360)
    hud_layer.add_child(pl)
    player_hp_bar = ProgressBar.new()
    player_hp_bar.position = Vector2(20, 380)
    player_hp_bar.size = Vector2(320, 20)
    player_hp_bar.max_value = 1.0
    hud_layer.add_child(player_hp_bar)
    var el := Label.new()
    el.text = "野生灵兽"
    el.position = Vector2(480, 360)
    hud_layer.add_child(el)
    enemy_hp_bar = ProgressBar.new()
    enemy_hp_bar.position = Vector2(480, 380)
    enemy_hp_bar.size = Vector2(320, 20)
    enemy_hp_bar.max_value = 1.0
    hud_layer.add_child(enemy_hp_bar)
    info_label = Label.new()
    info_label.position = Vector2(20, 20)
    info_label.text = "WASD移动 | 空格攻击 | Shift闪避 | C收服(夜晚禁用)"
    hud_layer.add_child(info_label)
    result_label = Label.new()
    result_label.position = Vector2(300, 200)
    result_label.scale = Vector2(2, 2)
    hud_layer.add_child(result_label)

func start_battle() -> void:
    var pdata: Dictionary = GameState.team[0]
    player_combatant = CombatantScript.new()
    player_combatant.position = Vector3(-6, 1, 0)
    player_combatant.setup(pdata["id"], pdata["level"], true)
    add_child(player_combatant)
    player_combatant.hp_changed.connect(_on_hp)
    player_combatant.defeated_signal.connect(_on_player_defeated)

    var enemy_id: String = "aqualeap"
    enemy_combatant = CombatantScript.new()
    enemy_combatant.position = Vector3(6, 1, 0)
    enemy_combatant.setup(enemy_id, 5, false)
    add_child(enemy_combatant)
    enemy_combatant.hp_changed.connect(_on_hp)
    enemy_combatant.defeated_signal.connect(_on_enemy_defeated)

    enemy_ai = EnemyAIScript.new()
    enemy_ai.player = player_combatant
    enemy_ai.enemy = enemy_combatant
    enemy_ai.attack_range = attack_range
    add_child(enemy_ai)
    _update_bars()

func _on_hp(_c: int, _m: int) -> void:
    _update_bars()

func _update_bars() -> void:
    if player_combatant:
        player_hp_bar.value = float(player_combatant.hp) / float(max(player_combatant.max_hp, 1))
    if enemy_combatant:
        enemy_hp_bar.value = float(enemy_combatant.hp) / float(max(enemy_combatant.max_hp, 1))

func _physics_process(delta: float) -> void:
    if battle_over:
        return
    player_cooldown = max(0.0, player_cooldown - delta)

    # 玩家移动 (世界轴, 竞技场内)
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
    player_combatant.move_dir = dir

    if Input.is_action_pressed("attack") and player_cooldown <= 0.0:
        _player_attack()
    if Input.is_action_just_pressed("capture"):
        _try_capture()

func _player_attack() -> void:
    if player_combatant.moves.is_empty():
        return
    var move_id: String = player_combatant.moves[0]
    var mv: Dictionary = DataBus.get_move(move_id)
    if mv.is_empty():
        return
    var dist: float = player_combatant.global_position.distance_to(enemy_combatant.global_position)
    if dist > attack_range + 1.0:
        return
    var mult: float = DataBus.multiplier(mv["type"], enemy_combatant.type)
    var dmg: float = Combat.calc_damage(player_combatant.stats["atk"], enemy_combatant.stats["def"], mv["power"], mult, player_combatant.level, randf_range(0.85, 1.0))
    if enemy_combatant.invulnerable > 0.0:
        _popup("被闪避!")
    else:
        enemy_combatant.take_damage(dmg)
        var name: String = DataBus.get_creature(enemy_combatant.creature_id)["name"]
        _popup(name + " 受 " + str(int(dmg)) + " 伤害 " + DataBus.type_chart.effectiveness_text(mult))
    player_cooldown = float(mv["cooldown"])

func _try_capture() -> void:
    if not enemy_is_wild:
        return
    # 硬性规则: 夜间禁止对战收集点数 / 收服 (REQUIREMENTS §8)
    if DayNight.is_night:
        _popup("夜晚黯潮汹涌，无法收服灵兽!")
        return
    var base: float = DataBus.get_creature(enemy_combatant.creature_id).get("catch_rate", 0.4)
    var chance: float = Combat.capture_chance(enemy_combatant.hp, enemy_combatant.max_hp, base, 1.0, 1.0)
    if randf() < chance:
        _popup("收服成功! " + DataBus.get_creature(enemy_combatant.creature_id)["name"])
        GameState.add_to_team(enemy_combatant.creature_id, enemy_combatant.level)
        _end_battle(true)
    else:
        _popup("收服失败……")

func _popup(text: String) -> void:
    info_label.text = text

func _on_player_defeated() -> void:
    _end_battle(false, "你输了……")

func _on_enemy_defeated() -> void:
    _end_battle(true, "胜利!")

func _end_battle(win: bool, msg: String = "") -> void:
    if battle_over:
        return
    battle_over = true
    result_label.text = msg if msg != "" else ("胜利!" if win else "失败")
    await get_tree().create_timer(1.5).timeout
    get_tree().change_scene_to_file("res://world/World.tscn")
