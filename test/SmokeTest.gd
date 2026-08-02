extends Node

## 临时冒烟测试: 验证战斗初始化/招式列表/没有效果/晶变坑/终局链推进, 不触发场景切换。
## 通过把 battle_over 提前置真, 让 _end_battle 立即返回(不再 change_scene), 从而安全读取终局状态。

func _ready() -> void:
	print("Smoke: Data=", Data != null, " Game=", Game != null, " Clock=", Clock != null)
	# ---- 单元测试: 没有效果不扣血 + 四档分类 ----
	_check(Combat.calc_damage(50.0, 50.0, 50.0, 0.0, 5, 1.0) == 0.0, "calc_damage(type_mult=0) == 0")
	_check(Data.type_chart.tier_label(0.0) == "没有效果", "tier 0 -> 没有效果")
	_check(Data.type_chart.tier_label(2.0) == "效果绝佳", "tier 2 -> 效果绝佳")
	_check(Data.type_chart.tier_label(1.0) == "有效果", "tier 1 -> 有效果")
	_check(Data.type_chart.tier_label(0.5) == "效果一般", "tier 0.5 -> 效果一般")
	_check(abs(Data.multiplier("炎", "木") - 2.0) < 0.001, "炎->木 = 2x")
	_check(Data.multiplier("水", "炎") == 2.0, "水->炎 = 2x")
	_check(Data.multiplier("炎", "炎") == 1.0, "炎->炎 = 1x")
	_check(Data.multiplier("水", "金") == 0.5, "水->金 = 0.5x")

	# ---- 音效系统(SFX): 13 个音效全覆盖(程序化合成 + 真实 wav 兜底) ----
	_check(SFX != null, "SFX 自动加载存在")
	var _all := SFX._sounds.keys()
	_check(_all.size() == 13, "SFX: 音效总数=13 (实际 %d)" % _all.size())
	for _s in _all:
		var _wav := SFX._get_wav(_s)
		_check(_wav != null, "SFX: [%s] _get_wav 返回非空音频流" % _s)
		SFX.play_sfx(_s)
	SFX.set_sfx_enabled(false)
	SFX.play_sfx("select")   # 关闭后不应发声但也不报错
	SFX.set_sfx_enabled(true)
	_check(SFX.sfx_names().size() == 13, "SFX: sfx_names() 返回 13 个名称")

	# ---- 存储箱(盒子): 存取逻辑 ----
	Game.team = []
	Game.storage = []
	Game.add_to_team("flarefox", 5)
	Game.add_to_team("vinelop", 5)
	Game.add_to_team("aqualeap", 7)
	_check(Game.deposit_to_storage(0), "存储箱: 存入成功")
	_check(Game.team.size() == 2 and Game.storage.size() == 1, "存储箱: 存入后 队伍2/存储1")
	_check(Game.withdraw_from_storage(0), "存储箱: 取出成功")
	_check(Game.team.size() == 3 and Game.storage.size() == 0, "存储箱: 取出后 队伍3/存储0")
	Game.team = [Game.team[0]]
	_check(not Game.deposit_to_storage(0), "存储箱: 队伍仅1只禁止存入")
	Game.team = []
	for _i in range(6):
		Game.add_to_team("flarefox", 5)
	Game.storage = [Game.team[0].duplicate()]
	_check(not Game.withdraw_from_storage(0), "存储箱: 队伍满6禁止取出")
	Game.reset_new_game()

	# ---- 伤药数值(数据驱动, 与 items.json 一致) ----
	_check(int(Data.get_item("potion").get("power", 0)) == 30, "伤药 power=30")
	_check(int(Data.get_item("super_potion").get("power", 0)) == 60, "好伤药 power=60")

	# ---- 升级习得招式(LEVEL_MOVES) ----
	Game.reset_new_game()
	var tc := Data.get_creature("tidecup")
	var mon2 := {"id": "tidecup", "level": 5, "exp": 0, "moves": tc.get("moves", []).duplicate(), "max_hp": 10, "hp": 10}
	var r2 := Game.grant_exp(mon2, 5000)
	_check("beam" in mon2["moves"], "升级学招: tidecup 习得 beam")
	_check(r2.has("learned") and "beam" in r2["learned"], "升级学招: res.learned 含 beam")
	var lc := Data.get_creature("lumiadeer")
	var mon3 := {"id": "lumiadeer", "level": 5, "exp": 0, "moves": lc.get("moves", []).duplicate(), "max_hp": 10, "hp": 10}
	var r3 := Game.grant_exp(mon3, 5000)
	_check("hypno" in mon3["moves"], "升级学招: lumiadeer 习得 hypno")

	# ---- 御三家进化 + 专属招式(进化时必定习得招牌技) ----
	Game.reset_new_game()
	for _mid in ["flarehowl", "tidalcrash", "vinegrip"]:
		_check(not Data.get_move(_mid).is_empty(), "专属招式存在: " + _mid)
	var ff := Data.get_creature("flarefox")
	var mon4 := {"id": "flarefox", "level": 15, "exp": 0, "moves": ff.get("moves", []).duplicate(), "max_hp": 10, "hp": 10}
	var r4 := Game.grant_exp(mon4, Game.exp_needed(15))
	_check(r4["evolved"] and mon4["id"] == "flarewolf", "进化: 焰狐15→16 进化为炎狼")
	_check("flarehowl" in mon4["moves"], "进化: 炎狼习得专属招式 炎狼啸")
	_check(r4.has("learned") and "flarehowl" in r4["learned"], "进化: res.learned 含 炎狼啸")

	# ---- 目标方向罗盘: 方位角计算 ----
	Game.player_position = Vector3(0, 0, 0)
	Game.objective_target = Vector3(0, 0, -100)   # 正北
	var cmp: Object = load("res://ui/ObjectiveCompass.gd").new()
	_check(abs(cmp.get_bearing_deg() - 0.0) < 0.001, "罗盘: 正北方位角=0")
	Game.objective_target = Vector3(100, 0, 0)     # 正东
	_check(abs(cmp.get_bearing_deg() - 90.0) < 0.001, "罗盘: 正东方位角=90")
	Game.objective_target = Vector3.ZERO           # 复位(避免影响后续)

	# ---- UI 场景 _ready 实例化(捕捉运行时错误) ----
	# 纯代码构建的场景(无 .tscn): 用 .gd + new()
	for _sc in ["res://ui/PartyBag.gd", "res://ui/SettingsMenu.gd", "res://ui/EndingCutscene.gd", "res://ui/Pokedex.gd", "res://ui/NarrationBox.gd", "res://ui/OpeningCollapse.gd", "res://ui/StarterSelect.gd", "res://ui/EvolutionSequence.gd", "res://ui/ObjectiveCompass.gd"]:
		var _inst = load(_sc).new()
		add_child(_inst)
		_check(_inst != null, "UI 实例化无崩溃: " + _sc.get_file())
		_inst.queue_free()
	# 真实开局链路场景(有 .tscn): 用 .tscn + instantiate() 捕捉 _ready 运行时错误
	for _sc in ["res://ui/IntroCinematic.tscn", "res://ui/OpeningCutscene.tscn", "res://ui/PrologueCutscene.tscn", "res://world/PrologueExplore.tscn"]:
		var _inst = load(_sc).instantiate()
		add_child(_inst)
		_check(_inst != null, "UI 实例化无崩溃: " + _sc.get_file())
		_inst.queue_free()

	# ---- 普通战斗: 初始化 + 招式列表构建 ----
	Game.reset_new_game()
	Game.pending_wild = {}
	var b := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(b)
	await get_tree().create_timer(0.5).timeout
	b.battle_over = true
	_check(b.enemy_combatant != null, "普通战斗: 敌方存在")
	var _ml := _collect_label_texts(b._move_box)
	_check(_ml.length() > 0, "普通战斗: 招式列表非空")
	print("  招式列表 => ", _ml)
	_defeat(b)
	await get_tree().create_timer(0.05).timeout
	b.queue_free()

	# ---- 晶变坑(太晶坑)讨伐 ----
	Game.reset_new_game()
	Game.pending_raid = {"boss_id": "crystal_guardian", "boss_level": 28, "allies": ["劲敌·岩", "伙伴·小岚", "伙伴·阿砂"]}
	var r := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(r)
	await get_tree().create_timer(0.5).timeout
	r.battle_over = true
	_check(r.enemy_combatant != null, "晶变坑: Boss 存在")
	_check(r._raid_mode == true, "晶变坑: 进入讨伐模式")
	_defeat(r)
	await get_tree().create_timer(0.05).timeout
	_check(r._raid_pending == true, "晶变坑: 击败后进入收服/放弃选择")
	r.queue_free()

	# ---- 道馆战(馆主·清, badge_wave): 训练家模式 + 徽章发放 ----
	Game.reset_new_game()
	Game.pending_trainer = {"enemy_id": "windpip", "enemy_level": 10, "trainer_name": "馆主·清", "badge_id": "badge_wave"}
	var g := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(g)
	await get_tree().create_timer(0.4).timeout
	g.battle_over = true
	_defeat(g)
	_check(Game.has_badge("badge_wave"), "道馆战: 击败馆主·清后获得 badge_wave")
	g.queue_free()

	# ---- 终局链: stage0 凛 -> stage1 辉金龙 ----
	Game.reset_new_game()
	Game.finale_stage = 0
	Game.pending_wild = {"id": "steeljaw_king", "level": 22, "alpha": true, "finale": true}
	var f0 := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(f0)
	await get_tree().create_timer(0.4).timeout
	f0.battle_over = true
	_defeat(f0)
	_check(Game.finale_stage == 1, "终局: 击败凛后 stage=1 (实际 " + str(Game.finale_stage) + ")")
	_check(Game.pending_wild.get("id", "") == "hui_jin_long", "终局: 下一战应为辉金龙 (实际 " + str(Game.pending_wild.get("id", "")) + ")")
	f0.queue_free()

	# ---- 终局链: stage1 辉金龙 -> stage2 黯钢兽 ----
	Game.finale_stage = 1
	Game.pending_wild = {"id": "hui_jin_long", "level": 32, "alpha": true, "finale": true}
	var f1 := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(f1)
	await get_tree().create_timer(0.4).timeout
	f1.battle_over = true
	_defeat(f1)
	_check(Game.finale_stage == 2, "终局: 击败辉金龙后 stage=2 (实际 " + str(Game.finale_stage) + ")")
	_check(Game.pending_wild.get("id", "") == "an_gang_shou", "终局: 下一战应为黯钢兽 (实际 " + str(Game.pending_wild.get("id", "")) + ")")
	f1.queue_free()

	# ---- 终局链: stage2 黯钢兽 -> 结局(收服双神兽) ----
	Game.finale_stage = 2
	Game.pending_wild = {"id": "an_gang_shou", "level": 34, "alpha": true, "finale": true}
	var f2 := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(f2)
	await get_tree().create_timer(0.4).timeout
	f2.battle_over = true
	_defeat(f2)
	_check(Game.ending_done == true, "终局: 击败黯钢兽后结局触发")
	_check(Game.dex_caught.has("hui_jin_long") and Game.dex_caught.has("an_gang_shou"), "终局: 双神兽已收服入图鉴")
	f2.queue_free()

	# ---- 序章·双生神兽战: 真实对战(盟友协同) + 战败转旁白分支 ----
	Game.reset_new_game()
	Game.add_to_team("flarefox", 5)
	Game.prologue_beast_mode = true
	Game.pending_raid = {"boss_id": "hui_jin_long", "boss_level": 42, "allies": ["伙伴·凛", "伙伴·小岚", "伙伴·阿砂"]}
	var pb := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(pb)
	await get_tree().create_timer(0.5).timeout
	pb.battle_over = true   # 阻止真实切场景, 仅校验逻辑
	_check(pb._raid_mode == true, "序章神兽战: 进入讨伐(盟友协同)模式")
	_check(pb.enemy_combatant != null, "序章神兽战: 辉金龙 Boss 存在")
	_check(pb._raid_allies.size() == 3, "序章神兽战: 三名伙伴协同(凛/小岚/阿砂)")
	# 模拟「被击败 → 转旁白」分支(清空队伍/复位标记, 不真正切场景)
	pb._on_player_defeated()
	_check(Game.team == [], "序章神兽战: 战败后队伍清空(灵兽全失)")
	_check(Game.pending_raid == {}, "序章神兽战: 战败后 pending_raid 清理")
	_check(Game.prologue_beast_mode == false, "序章神兽战: 战败后标记复位")
	pb.queue_free()

	# ---- 目标罗盘坐标映射(current_objective_target) ----
	Game.reset_new_game()
	var t0: Vector3 = Game.current_objective_target()
	_check(t0 == Vector3(4, 0, -19), "罗盘目标: 新手教程指向向导·岚 (实际 %s)" % str(t0))
	Game.story_stage = 1
	_check(Game.current_objective_target() == Vector3(60, 0, -10), "罗盘目标: 无徽章→岩石道馆(岩心)")
	Game.grant_badge("badge_stone")
	_check(Game.current_objective_target() == Vector3(-30, 0, 0), "罗盘目标: 已得岩石→清风道馆(清)")
	Game.grant_badge("badge_wave")
	Game.grant_badge("badge_flame")
	Game.grant_badge("badge_frost")
	Game.note_dex_caught("flarefox")
	Game.note_dex_caught("aqualeap")
	_check(Game.current_objective_target() == Vector3(72, 0, 16), "罗盘目标: 四徽章+图鉴≥2→暗潮使·玄")
	Game.midboss_done = true
	_check(Game.current_objective_target() == Vector3(0, 0, 60), "罗盘目标: 玄已败→黯潮深渊(凛)")
	Game.ending_done = true
	_check(Game.current_objective_target() == Vector3.ZERO, "罗盘目标: 主线完结→隐藏(零向量)")

	# ---- 进化形态视觉区分(Combatant 读取 visual 字段) ----
	var evo: Combatant = load("res://battle/Combatant.gd").new()
	evo.setup("flarewolf", 20, true)
	_check(abs(evo.scale.x - 1.18) < 0.01, "进化视觉: 炎狼体型放大(scale=%s)" % str(evo.scale.x))
	_check(evo._evolved == true, "进化视觉: 炎狼标记为进化形态(用强调色+辉光)")
	_check(evo._accent != Color(0, 0, 0), "进化视觉: 炎狼强调色已设置")
	var base: Combatant = load("res://battle/Combatant.gd").new()
	base.setup("flarefox", 5, true)
	_check(base.scale == Vector3.ONE, "进化视觉: 焰狐(初始)体型不变")
	_check(base._evolved == false, "进化视觉: 焰狐非进化形态")
	evo.queue_free()
	base.queue_free()

	# ---- 玩家朝向: 眼睛建在 -Z(Godot 前进方向), 走路真正面朝前方 ----
	var pc: PlayerController = load("res://world/PlayerController.gd").new()
	add_child(pc)
	await get_tree().process_frame
	var eye_forward := false
	for _c in pc.get_children():
		if _c is MeshInstance3D and (_c as MeshInstance3D).position.z < -0.1:
			eye_forward = true
			break
	_check(eye_forward, "玩家朝向: 眼睛位于 -Z(面朝前进方向, 非倒走)")
	pc.queue_free()

	# ---- 世界场景运行(捕捉大地图运行时崩溃) ----
	Game.reset_new_game()
	var world := load("res://world/World.tscn").instantiate() as World
	add_child(world)
	await get_tree().create_timer(1.2).timeout
	_check(world != null, "世界场景: 加载并运行 1.2s 无崩溃")
	var tree_col := _count_tree_colliders(world)
	_check(tree_col >= 11, "世界: 树木带碰撞体(不可穿过) count=%d" % tree_col)
	world.queue_free()
	await get_tree().process_frame

	print("Smoke: 全部检查完成")
	get_tree().quit()

func _count_tree_colliders(node) -> int:
	var n := 0
	for c in node.get_children():
		if c is StaticBody3D:
			for sc in c.get_children():
				if sc is CollisionShape3D and sc.shape is CylinderShape3D:
					var r := (sc.shape as CylinderShape3D).radius
					if abs(r - 0.45) < 0.05:
						n += 1
		n += _count_tree_colliders(c)
	return n

func _defeat(battle) -> void:
	var guard: int = 0
	while battle.enemy_combatant != null and not battle.enemy_combatant.defeated and guard < 20:
		battle.enemy_combatant.take_damage(99999, null, "特殊")
		guard += 1

func _collect_label_texts(node) -> String:
	var s := ""
	if node is Label:
		s += node.text + " | "
	for _ch in node.get_children():
		s += _collect_label_texts(_ch)
	return s

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   ", msg)
	else:
		printerr("  [FAIL] ", msg)
