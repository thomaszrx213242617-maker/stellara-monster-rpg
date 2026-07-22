extends Node
class_name EnemyAI

## 敌方灵兽的简单 AI: 靠近玩家, 进入射程后周期性出招 (伤害含属性克制)。
## MVP 用纯 GDScript; 后续可替换为 LimboAI 行为树 (见 REQUIREMENTS.md §5 / T004)。

var player: Node
var enemy: Node
var attack_range: float = 3.0
var attack_interval: float = 1.2

func _physics_process(delta: float) -> void:
    if not player or not enemy:
        return
    if enemy.defeated or player.defeated:
        enemy.move_dir = Vector3.ZERO
        return
    attack_interval = max(0.0, attack_interval - delta)
    var to_player: Vector3 = player.global_position - enemy.global_position
    to_player.y = 0
    var dist: float = to_player.length()
    if dist > attack_range:
        enemy.move_dir = to_player.normalized()
    else:
        enemy.move_dir = Vector3.ZERO
        if attack_interval <= 0.0:
            _enemy_attack()
            attack_interval = 1.2

func _enemy_attack() -> void:
    if enemy.moves.is_empty():
        return
    var mv: Dictionary = DataBus.get_move(enemy.moves[0])
    if mv.is_empty():
        return
    var mult: float = DataBus.multiplier(mv["type"], player.type)
    var dmg: float = Combat.calc_damage(enemy.stats["atk"], player.stats["def"], mv["power"], mult, enemy.level, randf_range(0.85, 1.0))
    if player.invulnerable > 0.0:
        return
    player.take_damage(dmg)
