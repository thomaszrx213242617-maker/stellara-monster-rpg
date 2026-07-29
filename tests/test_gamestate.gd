extends GdUnitTest

const CombatScript := preload("res://core/combat.gd")

## 游戏状态 / 养成 / 收服 单元测试 (启用 GDUnit4 后在编辑器运行)。

func _make(creature_id: String, level: int) -> Dictionary:
	var mhp: int = Game.max_hp_for(creature_id, level)
	return {"id": creature_id, "level": level, "exp": 0, "hp": mhp, "max_hp": mhp, "status": null, "moves": []}

func test_level_up_increases_level():
	var c := _make("flarefox", 5)
	var res: Dictionary = Game.grant_exp(c, 1000)
	assert_bool(int(c["level"]) > 5).is_true()
	assert_bool(res["levels"] > 0).is_true()

func test_evolution_at_threshold():
	var c := _make("flarefox", 15)
	var res: Dictionary = Game.grant_exp(c, 10000)
	assert_str(c["id"]).is_equal("flarewolf")
	assert_bool(res["evolved"]).is_true()

func test_capture_chance_hp_monotonic():
	var full: float = CombatScript.capture_chance(100, 100, 0.5, 1.0, 1.0)
	var weak: float = CombatScript.capture_chance(5, 100, 0.5, 1.0, 1.0)
	assert_bool(weak > full).is_true()

func test_ball_modifier_boosts_capture():
	var normal: float = CombatScript.capture_chance(50, 100, 0.4, 1.0, 1.0)
	var great: float = CombatScript.capture_chance(50, 100, 0.4, 1.5, 1.0)
	assert_bool(great > normal).is_true()

func test_items_loaded_from_data():
	assert_bool(not Data.get_item("ball").is_empty()).is_true()
	assert_str(Data.get_item("ball")["type"]).is_equal("ball")

func test_inventory_consume_and_add():
	Game.inventory = {"ball": 2}
	assert_bool(Game.consume_item("ball", 1)).is_true()
	assert_int(Game.inventory.get("ball", 0)).is_equal(1)
	Game.add_item("potion", 3)
	assert_int(Game.inventory.get("potion", 0)).is_equal(3)
