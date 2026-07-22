extends GdUnitTest

## 数据层单元测试 (需启用 GDUnit4 插件后, 在编辑器 GDUnit4 面板运行)。
## 验证属性克制倍率与伤害公式。

func test_fire_super_effective_vs_grass():
    var tc := TypeChart.new()
    assert_float(tc.multiplier("炎", "木")).is_equal_approx(2.0)

func test_water_resisted_by_grass():
    var tc := TypeChart.new()
    assert_float(tc.multiplier("水", "木")).is_equal_approx(0.5)

func test_neutral_is_one():
    var tc := TypeChart.new()
    assert_float(tc.multiplier("光", "水")).is_equal_approx(1.0)

func test_damage_scales_with_level_and_type():
    var dmg_low := Combat.calc_damage(50, 50, 50, 2.0, 5, 1.0)
    var dmg_high := Combat.calc_damage(50, 50, 50, 2.0, 50, 1.0)
    assert_bool(dmg_high > dmg_low).is_true()
