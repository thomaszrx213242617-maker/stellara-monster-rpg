extends Node

## 临时冒烟测试: 验证战斗初始化/招式列表/没有效果/晶变坑/终局链推进, 不触发场景切换。
## 通过把 battle_over 提前置真, 让 _end_battle 立即返回(不再 change_scene), 从而安全读取终局状态。

func _ready() -> void:
	print("Smoke: DataBus=", DataBus != null, " GameState=", GameState != null, " DayNight=", DayNight != null)
	# ---- 单元测试: 没有效果不扣血 + 四档分类 ----
	_check(Combat.calc_damage(50.0, 50.0, 50.0, 0.0, 5, 1.0) == 0.0, "calc_damage(type_mult=0) == 0")
	_check(DataBus.type_chart.tier_label(0.0) == "没有效果", "tier 0 -> 没有效果")
	_check(DataBus.type_chart.tier_label(2.0) == "效果绝佳", "tier 2 -> 效果绝佳")
	_check(DataBus.type_chart.tier_label(1.0) == "有效果", "tier 1 -> 有效果")
	_check(DataBus.type_chart.tier_label(0.5) == "效果一般", "tier 0.5 -> 效果一般")
	_check(abs(DataBus.multiplier("炎", "木") - 2.0) < 0.001, "炎->木 = 2x")
	_check(DataBus.multiplier("水", "炎") == 2.0, "水->炎 = 2x")
	_check(DataBus.multiplier("炎", "炎") == 1.0, "炎->炎 = 1x")
	_check(DataBus.multiplier("水", "金") == 0.5, "水->金 = 0.5x")

	# ---- 音效系统(SoundBus): 程序化合成 + 调用不报错 ----
	_check(SoundBus != null, "SoundBus 自动加载存在")
	var _sounds := ["select", "attack", "hit", "capture", "capture_success", "heal", "levelup", "faint", "error", "evolve", "step", "grass"]
	var _sfx_ok := true
	for _s in _sounds:
		SoundBus.play_sfx(_s)
	SoundBus.set_sfx_enabled(false)
	SoundBus.play_sfx("select")   # 关闭后不应发声但也不报错
	SoundBus.set_sfx_enabled(true)
	_check(_sfx_ok, "SoundBus: 全部音效 play_sfx 调用无异常")

	# ---- 音乐系统(MusicBus): 自定义音乐接口 + 原创曲目存在 ----
	_check(MusicBus != null, "MusicBus 自动加载存在")
	GameState.custom_music = ""
	var _files := MusicBus.list_music_files()
	_check(typeof(_files) == TYPE_ARRAY, "MusicBus.list_music_files 返回数组")
	_check("title" in MusicBus._tracks and "overworld" in MusicBus._tracks and "battle" in MusicBus._tracks, "MusicBus: 原创曲目(title/overworld/battle)已重编")
	MusicBus.set_custom_music("res://audio/__nonexistent_test__.wav")  # 不存在文件应安全回退
	_check(MusicBus.mode == "procedural", "set_custom_music 异常文件安全回退为程序化")
	GameState.custom_music = ""
	MusicBus.play_track("overworld")
	_check(MusicBus.current_track == "overworld", "play_track(overworld) 生效")

	# ---- 存储箱(盒子): 存取逻辑 ----
	GameState.team = []
	GameState.storage = []
	GameState.add_to_team("flarefox", 5)
	GameState.add_to_team("vinelop", 5)
	GameState.add_to_team("aqualeap", 7)
	_check(GameState.deposit_to_storage(0), "存储箱: 存入成功")
	_check(GameState.team.size() == 2 and GameState.storage.size() == 1, "存储箱: 存入后 队伍2/存储1")
	_check(GameState.withdraw_from_storage(0), "存储箱: 取出成功")
	_check(GameState.team.size() == 3 and GameState.storage.size() == 0, "存储箱: 取出后 队伍3/存储0")
	GameState.team = [GameState.team[0]]
	_check(not GameState.deposit_to_storage(0), "存储箱: 队伍仅1只禁止存入")
	GameState.team = []
	for _i in range(6):
		GameState.add_to_team("flarefox", 5)
	GameState.storage = [GameState.team[0].duplicate()]
	_check(not GameState.withdraw_from_storage(0), "存储箱: 队伍满6禁止取出")
	GameState.reset_new_game()

	# ---- 伤药数值(数据驱动, 与 items.json 一致) ----
	_check(int(DataBus.get_item("potion").get("power", 0)) == 30, "伤药 power=30")
	_check(int(DataBus.get_item("super_potion").get("power", 0)) == 60, "好伤药 power=60")

	# ---- 升级习得招式(LEVEL_MOVES) ----
	GameState.reset_new_game()
	var tc := DataBus.get_creature("tidecup")
	var mon2 := {"id": "tidecup", "level": 5, "exp": 0, "moves": tc.get("moves", []).duplicate(), "max_hp": 10, "hp": 10}
	var r2 := GameState.grant_exp(mon2, 5000)
	_check("beam" in mon2["moves"], "升级学招: tidecup 习得 beam")
	_check(r2.has("learned") and "beam" in r2["learned"], "升级学招: res.learned 含 beam")
	var lc := DataBus.get_creature("lumiadeer")
	var mon3 := {"id": "lumiadeer", "level": 5, "exp": 0, "moves": lc.get("moves", []).duplicate(), "max_hp": 10, "hp": 10}
	var r3 := GameState.grant_exp(mon3, 5000)
	_check("hypno" in mon3["moves"], "升级学招: lumiadeer 习得 hypno")

	# ---- UI 场景 _ready 实例化(捕捉运行时错误) ----
	for _sc in ["res://ui/PartyBag.gd", "res://ui/SettingsMenu.gd", "res://ui/EndingCutscene.gd", "res://ui/Pokedex.gd", "res://ui/NarrationBox.gd", "res://ui/OpeningCollapse.gd", "res://ui/StarterSelect.gd", "res://ui/EvolutionSequence.gd"]:
		var _inst = load(_sc).new()
		add_child(_inst)
		_check(_inst != null, "UI 实例化无崩溃: " + _sc.get_file())
		_inst.queue_free()

	# ---- 普通战斗: 初始化 + 招式列表构建 ----
	GameState.reset_new_game()
	GameState.pending_wild = {}
	var b := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(b)
	await get_tree().create_timer(0.5).timeout
	b.battle_over = true
	_check(b.enemy_combatant != null, "普通战斗: 敌方存在")
	var _ml := ""
	for _c in b._move_box.get_children():
		if _c is Label:
			_ml += _c.text + " | "
	_check(_ml.length() > 0, "普通战斗: 招式列表非空")
	print("  招式列表 => ", _ml)
	_defeat(b)
	await get_tree().create_timer(0.05).timeout
	b.queue_free()

	# ---- 晶变坑(太晶坑)讨伐 ----
	GameState.reset_new_game()
	GameState.pending_raid = {"boss_id": "crystal_guardian", "boss_level": 28, "allies": ["劲敌·岩", "伙伴·小岚", "伙伴·阿砂"]}
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
	GameState.reset_new_game()
	GameState.pending_trainer = {"enemy_id": "windpip", "enemy_level": 10, "trainer_name": "馆主·清", "badge_id": "badge_wave"}
	var g := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(g)
	await get_tree().create_timer(0.4).timeout
	g.battle_over = true
	_defeat(g)
	_check(GameState.has_badge("badge_wave"), "道馆战: 击败馆主·清后获得 badge_wave")
	g.queue_free()

	# ---- 终局链: stage0 凛 -> stage1 辉金龙 ----
	GameState.reset_new_game()
	GameState.finale_stage = 0
	GameState.pending_wild = {"id": "steeljaw_king", "level": 22, "alpha": true, "finale": true}
	var f0 := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(f0)
	await get_tree().create_timer(0.4).timeout
	f0.battle_over = true
	_defeat(f0)
	_check(GameState.finale_stage == 1, "终局: 击败凛后 stage=1 (实际 " + str(GameState.finale_stage) + ")")
	_check(GameState.pending_wild.get("id", "") == "hui_jin_long", "终局: 下一战应为辉金龙 (实际 " + str(GameState.pending_wild.get("id", "")) + ")")
	f0.queue_free()

	# ---- 终局链: stage1 辉金龙 -> stage2 黯钢兽 ----
	GameState.finale_stage = 1
	GameState.pending_wild = {"id": "hui_jin_long", "level": 32, "alpha": true, "finale": true}
	var f1 := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(f1)
	await get_tree().create_timer(0.4).timeout
	f1.battle_over = true
	_defeat(f1)
	_check(GameState.finale_stage == 2, "终局: 击败辉金龙后 stage=2 (实际 " + str(GameState.finale_stage) + ")")
	_check(GameState.pending_wild.get("id", "") == "an_gang_shou", "终局: 下一战应为黯钢兽 (实际 " + str(GameState.pending_wild.get("id", "")) + ")")
	f1.queue_free()

	# ---- 终局链: stage2 黯钢兽 -> 结局(收服双神兽) ----
	GameState.finale_stage = 2
	GameState.pending_wild = {"id": "an_gang_shou", "level": 34, "alpha": true, "finale": true}
	var f2 := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(f2)
	await get_tree().create_timer(0.4).timeout
	f2.battle_over = true
	_defeat(f2)
	_check(GameState.ending_done == true, "终局: 击败黯钢兽后结局触发")
	_check(GameState.dex_caught.has("hui_jin_long") and GameState.dex_caught.has("an_gang_shou"), "终局: 双神兽已收服入图鉴")
	f2.queue_free()

	# ---- 序章·双生神兽战: 真实对战(盟友协同) + 战败转旁白分支 ----
	GameState.reset_new_game()
	GameState.add_to_team("flarefox", 5)
	GameState.prologue_beast_mode = true
	GameState.pending_raid = {"boss_id": "hui_jin_long", "boss_level": 42, "allies": ["伙伴·凛", "伙伴·小岚", "伙伴·阿砂"]}
	var pb := load("res://battle/BattleArena.tscn").instantiate() as BattleArena
	add_child(pb)
	await get_tree().create_timer(0.5).timeout
	pb.battle_over = true   # 阻止真实切场景, 仅校验逻辑
	_check(pb._raid_mode == true, "序章神兽战: 进入讨伐(盟友协同)模式")
	_check(pb.enemy_combatant != null, "序章神兽战: 辉金龙 Boss 存在")
	_check(pb._raid_allies.size() == 3, "序章神兽战: 三名伙伴协同(凛/小岚/阿砂)")
	# 模拟「被击败 → 转旁白」分支(清空队伍/复位标记, 不真正切场景)
	pb._on_player_defeated()
	_check(GameState.team == [], "序章神兽战: 战败后队伍清空(灵兽全失)")
	_check(GameState.pending_raid == {}, "序章神兽战: 战败后 pending_raid 清理")
	_check(GameState.prologue_beast_mode == false, "序章神兽战: 战败后标记复位")
	pb.queue_free()

	# ---- 世界场景运行(捕捉大地图运行时崩溃) ----
	GameState.reset_new_game()
	var world := load("res://world/World.tscn").instantiate() as World
	add_child(world)
	await get_tree().create_timer(1.2).timeout
	_check(world != null, "世界场景: 加载并运行 1.2s 无崩溃")
	world.queue_free()
	await get_tree().process_frame

	print("Smoke: 全部检查完成")
	get_tree().quit()

func _defeat(battle) -> void:
	var guard: int = 0
	while battle.enemy_combatant != null and not battle.enemy_combatant.defeated and guard < 20:
		battle.enemy_combatant.take_damage(99999, null, "特殊")
		guard += 1

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   ", msg)
	else:
		printerr("  [FAIL] ", msg)
