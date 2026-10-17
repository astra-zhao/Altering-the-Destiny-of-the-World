extends SceneTree
## v0.4 开局流程。无头可跑。
## godot --headless --path godot -s res://scripts/v04_boot_check.gd

const SAMPLE := "res://data/samples/v031_turn2_pending_s1.json"

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var campaign := root.get_node_or_null("Campaign")
	if campaign == null:
		_fail("没有 Campaign")
		_finish()
		return
	_clear_user_files()
	_check_skip_guard(campaign)
	_check_old_gate(campaign)
	_check_file_rules(campaign)
	await _check_fresh_flow(campaign)
	await _check_old_save(campaign)
	_finish()


func _check_skip_guard(campaign: Node) -> void:
	campaign.reset()
	campaign.arm_skip_guard()
	if campaign.get("_block_mouse") or campaign.get("_block_skip_key"):
		_fail("没按着键时不该挡住下一段")
	campaign.set("_block_skip_key", true)
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	press.echo = false
	if not campaign.swallow_skip_guard(press) or not campaign.get("_block_skip_key"):
		_fail("按住的空格应被吃掉，而且要等松开")
	var echo := press.duplicate() as InputEventKey
	echo.echo = true
	if not campaign.swallow_skip_guard(echo):
		_fail("连发的空格也应被吃掉")
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	release.physical_keycode = KEY_SPACE
	release.pressed = false
	if not campaign.swallow_skip_guard(release) or campaign.get("_block_skip_key"):
		_fail("松开空格后应放开下一段")
	var again := press.duplicate() as InputEventKey
	again.echo = false
	if campaign.swallow_skip_guard(again):
		_fail("松开之后的新按键不该再被吃掉")
	campaign.set("_block_mouse", true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	if not campaign.swallow_skip_guard(click):
		_fail("按住的左键应被吃掉")
	if campaign.swallow_skip_guard(again):
		_fail("挡住鼠标时不该连空格一起挡")
	click.pressed = false
	campaign.swallow_skip_guard(click)
	print("V04_SKIP_GUARD_OK")


func _check_old_gate(campaign: Node) -> void:
	campaign.reset()
	var held: Dictionary = campaign.hold("C1")
	if not bool(held.get("ok", false)):
		_fail("固守失败 %s" % str(held.get("message", "")))
		return
	var ended: Dictionary = campaign.end_turn()
	if str(ended.get("goto", "")) != "s1" or str(campaign.pending_story) != "s1" or int(campaign.turn) != 2:
		_fail("旧路径第 1 回合结束仍应进登基夜，现在 %s turn=%d pending=%s" % [str(ended.get("goto", "")), int(campaign.turn), str(campaign.pending_story)])
		return
	print("V04_OLD_GATE_OK")


func _check_file_rules(campaign: Node) -> void:
	_write_text("user://campaign_m2.json", "{\"version\":3,\"turn\":4,\"guide_done\":true,\"guide_step\":3}")
	_write_text("user://v03_guide.json", "{\"dismissed\":true}")
	_write_text("user://audio_prefs.json", "{\"linear\":0.4,\"muted\":false}")
	_write_text("user://advisor_prefs.json", "{\"self_pick\":true}")
	var audio_before := FileAccess.get_file_as_string("user://audio_prefs.json")
	var advisor_before := FileAccess.get_file_as_string("user://advisor_prefs.json")
	campaign.reset_guide_record()
	if FileAccess.file_exists("user://v03_guide.json"):
		_fail("重置引导后标记还在")
	if not FileAccess.file_exists("user://campaign_m2.json"):
		_fail("重置引导不该删战役档")
	var patched: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://campaign_m2.json"))
	if typeof(patched) != TYPE_DICTIONARY or int(patched.get("turn", -1)) != 4 or bool(patched.get("guide_done", true)):
		_fail("重置引导应只把引导进度清掉，回合还在：%s" % str(patched))
	if FileAccess.get_file_as_string("user://audio_prefs.json") != audio_before:
		_fail("重置引导改了音量")
	if FileAccess.get_file_as_string("user://advisor_prefs.json") != advisor_before:
		_fail("重置引导改了帮我选偏好")
	campaign.clear_campaign_files()
	if FileAccess.file_exists("user://campaign_m2.json") or FileAccess.file_exists("user://v03_guide.json"):
		_fail("清空后战役或引导还在")
	if FileAccess.get_file_as_string("user://audio_prefs.json") != audio_before:
		_fail("清空存档改了音量")
	if FileAccess.get_file_as_string("user://advisor_prefs.json") != advisor_before:
		_fail("清空存档改了帮我选偏好")
	print("V04_FILES_OK")


func _check_fresh_flow(campaign: Node) -> void:
	_clear_user_files()
	_write_text("user://audio_prefs.json", "{\"linear\":0.4,\"muted\":false}")
	change_scene_to_file("res://scenes/title_screen.tscn")
	var title := await _wait_scene("TitleScreen")
	if title == null:
		return
	var cont := title.find_child("ContinueButton", true, false) as Button
	if cont == null or not cont.disabled:
		_fail("没有存档时继续应是灰的")
		return
	title._on_start()
	var prologue := await _wait_scene("Prologue")
	if prologue == null:
		return
	if prologue.card_index() != 0 or prologue.card_text() != "天启七年，熹宗驾崩。十七岁的信王朱由检，在一夜之间成了大明天子。":
		_fail("序章第一张不对：%s" % prologue.card_text())
		return
	if str(campaign.pending_story) != "s1" or int(campaign.turn) != 1 or campaign.s1_done:
		_fail("新局进序章前应记着登基夜，回合仍是 1")
		return
	prologue.advance_for_test()
	if prologue.card_index() != 1:
		_fail("一键应只进一张，现在 %d" % prologue.card_index())
		return
	prologue.advance_for_test()
	if prologue.card_index() != 2:
		_fail("第三张没有出现")
		return
	if str(prologue.card_text()) != "史书里，这个王朝只剩十七年。这一次，由你来选。":
		_fail("第三张文案不对")
		return
	prologue.advance_for_test()
	var s1 := await _wait_scene("S1Night")
	if s1 == null:
		return
	if int(campaign.turn) != 1 or campaign.s1_done or str(campaign.pending_story) != "s1":
		_fail("登基夜应在第 1 回合之前，现在 turn=%d done=%s pending=%s" % [int(campaign.turn), str(campaign.s1_done), str(campaign.pending_story)])
		return
	await process_frame
	await process_frame
	await process_frame
	if bool(s1.get("_skipping")) or bool(s1.get("_skip_queued")):
		_fail("序章最后一键把推镜也跳了")
		return
	s1._choose("B")
	var map := await _wait_scene("BigMap")
	if map == null:
		return
	if not campaign.s1_done or str(campaign.pending_story) != "" or int(campaign.turn) != 1:
		_fail("选完应回到第 1 回合，登基夜已写回")
		return
	if int(campaign.silver) != 35 or int(campaign.liaodong) != 48 or int(campaign.worldline) != 10 or not campaign.befriended_yuan:
		_fail("先重辽东的数值不对 silver=%d liao=%d world=%d" % [int(campaign.silver), int(campaign.liaodong), int(campaign.worldline)])
		return
	var guide: CanvasItem = map.get("_guide")
	if guide == null or not guide.visible or campaign.guide_done:
		_fail("登基夜之后大地图应出现新手引导")
		return
	var held: Dictionary = campaign.hold("C1")
	if not bool(held.get("ok", false)):
		_fail("第 1 回合固守失败 %s" % str(held.get("message", "")))
		return
	var ended: Dictionary = campaign.end_turn()
	if str(ended.get("goto", "")) == "s1" or str(campaign.pending_story) == "s1" or int(campaign.turn) != 2:
		_fail("写回之后结束回合不该再进登基夜 goto=%s pending=%s turn=%d" % [str(ended.get("goto", "")), str(campaign.pending_story), int(campaign.turn)])
		return
	var again: Dictionary = campaign.apply_s1("B")
	if bool(again.get("ok", false)):
		_fail("登基夜被写了两次")
		return
	print("V04_FRESH_OK")


func _check_old_save(campaign: Node) -> void:
	_clear_user_files()
	_write_text("user://campaign_m2.json", FileAccess.get_file_as_string(SAMPLE))
	_write_text("user://v03_guide.json", "{\"dismissed\":true}")
	_write_text("user://audio_prefs.json", "{\"linear\":0.55,\"muted\":true}")
	_write_text("user://advisor_prefs.json", "{\"kept\":1}")
	var audio_before := FileAccess.get_file_as_string("user://audio_prefs.json")
	var advisor_before := FileAccess.get_file_as_string("user://advisor_prefs.json")
	change_scene_to_file("res://scenes/title_screen.tscn")
	var title := await _wait_scene("TitleScreen")
	if title == null:
		return
	var cont := title.find_child("ContinueButton", true, false) as Button
	if cont == null or cont.disabled:
		_fail("旧档在时继续不该是灰的")
		return
	title._on_continue()
	var s1 := await _wait_scene("S1Night")
	if s1 == null:
		return
	if current_scene.name == "Prologue":
		_fail("继续旧档不该播序章")
		return
	if int(campaign.turn) != 2 or str(campaign.pending_story) != "s1" or campaign.s1_done:
		_fail("旧档应停在第 2 回合的登基夜 turn=%d pending=%s done=%s" % [int(campaign.turn), str(campaign.pending_story), str(campaign.s1_done)])
		return
	await process_frame
	await process_frame
	await process_frame
	if bool(s1.get("_skipping")) or bool(s1.get("_skip_queued")) or bool(s1.get("_push_done")):
		_fail("继续不该跳过或直接揭开登基夜")
		return
	s1._choose("A")
	var map := await _wait_scene("BigMap")
	if map == null:
		return
	if str(campaign.s1_choice) != "A" or not campaign.s1_done or str(campaign.pending_story) != "" or int(campaign.turn) != 2:
		_fail("旧档选完应留在第 2 回合")
		return
	if int(campaign.silver) != 45 or int(campaign.worldline) != 5:
		_fail("旧档先稳朝堂数值 silver=%d world=%d" % [int(campaign.silver), int(campaign.worldline)])
		return
	if bool(campaign.apply_s1("A").get("ok", false)):
		_fail("旧档登基夜被写了两次")
		return
	if str(campaign.resume_scene()) != "res://scenes/big_map.tscn":
		_fail("写回之后继续不该再进登基夜")
		return
	if FileAccess.get_file_as_string("user://audio_prefs.json") != audio_before:
		_fail("读旧档改了音量")
	if FileAccess.get_file_as_string("user://advisor_prefs.json") != advisor_before:
		_fail("读旧档改了帮我选偏好")
	print("V04_OLD_SAVE_OK")


func _wait_scene(node_name: String) -> Node:
	for _i in 180:
		await process_frame
		var scene := current_scene
		if scene != null and scene.name == node_name:
			return scene
	_fail("没有进入 %s，现在是 %s" % [node_name, str(current_scene)])
	return null


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("写不了 %s" % path)
		return
	file.store_string(text)


func _clear_user_files() -> void:
	for path in ["user://campaign_m2.json", "user://v03_guide.json", "user://audio_prefs.json", "user://advisor_prefs.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	_clear_user_files()
	if _failures.is_empty():
		print("V04_BOOT_OK")
		quit(0)
		return
	for message in _failures:
		print("V04_BOOT_FAIL %s" % message)
	quit(1)
