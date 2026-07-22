class_name Combat
extends RefCounted

## 实时战斗伤害计算 (占位公式, 与 REQUIREMENTS.md §5.3 一致)
## 伤害 = floor( (2*Lv/5 + 2) * Power * Atk/Def / 50 + 2 ) * 克制 * 随机

static func calc_damage(atk: float, def: float, power: float, type_mult: float, level: int, rng: float) -> float:
    var base: float = (2.0 * float(level) / 5.0 + 2.0) * power * (atk / max(def, 1.0)) / 50.0 + 2.0
    return max(1.0, floor(base * type_mult * rng))

## 由种族值 + 等级换算实时属性
static func stat_at_level(base: int, level: int, is_hp: bool) -> int:
    if is_hp:
        return floor(base * 2 * level / 100.0) + level + 10
    return floor(base * 2 * level / 100.0) + 5

## 收服成功率 (占位): 受剩余血量比例、是否异常、球种修正影响
static func capture_chance(current_hp: float, max_hp: float, base_rate: float, ball_mod: float, status_mod: float) -> float:
    var hp_factor: float = 1.0 - (current_hp / max(max_hp, 1.0)) * 0.8  # 血越少越易
    return clamp(base_rate * ball_mod * status_mod * (0.4 + hp_factor), 0.01, 0.99)
