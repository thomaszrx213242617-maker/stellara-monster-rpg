extends Control

## 原创序章·崩塌: 双生神兽苏醒 → 并肩迎战 → 败北、山洞崩塌 → 灵兽全数消失 → 在家苏醒。
## 由 PrologueExplore(洞中探险) 衔接进入; 播完衔接 PrologueCutscene(新序章/新伙伴)。
## 旁白改用 NarrationBox(淡入背景 + 漂浮微光 + 脉动光球 + 打字机文字)。

const NarrationScript := preload("res://ui/NarrationBox.gd")

func _ready() -> void:
	var n := NarrationScript.new()
	add_child(n)
	var nm: String = GameState.player_name if GameState.player_name != "" else "旅人"
	n.present([
		"凛（望向洞窟深处）：「是辉金龙……还有黯钢兽。两头金属神兽，同时苏醒了。」",
		"凛：「不好，它们被黯潮污染了！」",
		"（你与最强的伙伴并肩迎战，灵球破空而出——）",
		"（双生神兽齐声咆哮，金属风暴撕裂了岩壁。这一击，远超你们能承受的范围。）",
		"凛：「（被暗光卷走）……」",
		"（再睁眼时，你躺在自家床上。窗外，是星澜村熟悉的晨光。）",
		"（可你怀中空空——被神兽打败后，灵兽全数消失了。）",
		"（你握紧拳。）这一回，要从零开始，找回凛，也救下那两头被污染的金属神兽。",
		"（新的旅程，从这里开始。）"
	], "序章 · 双生神兽的怒吼")
	n.finished.connect(_finish)

func _finish() -> void:
	GameState.prologue_scout_done = false  # 新周目重置探险标记
	SaveManager.save_game()
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://ui/PrologueCutscene.tscn")
