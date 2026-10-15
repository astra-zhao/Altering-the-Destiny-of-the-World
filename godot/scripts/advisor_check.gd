extends SceneTree
## 推荐引擎与半截存档的无头检查。不碰画面。
## godot --headless --path godot -s res://scripts/advisor_check.gd

const AdvisorScript := preload("res://scripts/advisor.gd")

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
	campaign.reset()
	_test_b1(campaign)
	_test_b2(campaign)
	_test_b3(campaign)
	_test_b4(campaign)
	_test_b5(campaign)
	_test_b6(campaign)
	_test_b7(campaign)
	_test_b8(campaign)
	_test_b10(campaign)
	_test_b11(campaign)
	_test_b12(campaign)
	_test_snapshot(campaign)
	_test_guide(campaign)
	_finish()


func _test_b1(campaign: Node) -> void:
	campaign.reset()
	var recs := _recs(campaign)
	if not _has_kind(recs, "attack") and not _has_kind(recs, "march"):
		_fail("B1 开局没有出兵")
	if not (_has_kind(recs, "levy") or _has_kind(recs, "spend") or _has_kind(recs, "train")):
		_fail("B1 开局没有内政")
	if recs.size() < 2 or recs.size() > 3:
		_fail("B1 条数是 %d" % recs.size())


func _test_b2(campaign: Node) -> void:
	campaign.reset()
	campaign.grain = 2
	var recs := _recs(campaign)
	if recs.is_empty() or str(recs[0]["kind"]) != "levy":
		_fail("B2 第一条不是征粮")
	elif not str(recs[0]["reason"]).contains("粮草"):
		_fail("B2 理由没提粮草")
	if _has_kind(recs, "attack") or _has_kind(recs, "march"):
		_fail("B2 粮草不足仍推荐出兵")


func _test_b3(campaign: Node) -> void:
	campaign.reset()
	for id in ["C1", "C2", "C3", "C4", "C6"]:
		campaign.city(id)["troops"] = 1
	var recs := _recs(campaign)
	if _has_kind(recs, "attack"):
		_fail("B3 兵力不足仍推荐攻城")
	if not (_has_kind(recs, "train") or _has_kind(recs, "levy") or _has_kind(recs, "hold")):
		_fail("B3 没有守势或内政")


func _test_b4(campaign: Node) -> void:
	campaign.reset()
	var recs := _recs(campaign)
	var attack: Dictionary = {}
	for item in recs:
		if str(item["kind"]) == "attack":
			attack = item
			break
	if attack.is_empty():
		_fail("B4 没有攻城")
		return
	if str(attack.get("dst", "")) != "C6" or str(attack.get("src", "")) != "C4":
		_fail("B4 没有推荐宁远打锦州，而是 %s" % str(attack.get("id", "")))
	var reason := str(attack["reason"])
	if not reason.contains("17") or not reason.contains("10"):
		_fail("B4 没有出兵/守军对比：%s" % reason)
	for item in recs:
		if str(item.get("dst", "")) == "C5":
			_fail("B4 推荐了打沈阳")


func _test_b5(campaign: Node) -> void:
	campaign.reset()
	campaign.main_done = true
	var recs := _recs(campaign)
	if recs.size() != 1 or str(recs[0]["kind"]) != "end_turn":
		_fail("B5 行动点用尽时不是只推荐下一回合")


func _test_b6(campaign: Node) -> void:
	campaign.reset()
	campaign.turn = 3
	campaign.s1_done = true
	campaign.s1_choice = "B"
	campaign.main_done = true
	campaign.held_ningyuan = true
	var choice_before := str(campaign.s2_choice)
	var recs := _recs(campaign)
	if recs.size() != 1 or str(recs[0]["kind"]) != "end_turn":
		_fail("B6 没有推荐进入下一回合/剧情")
	elif not str(recs[0]["reason"]).contains("剧情") and not str(recs[0]["reason"]).contains("袁"):
		_fail("B6 理由没说会进剧情：%s" % str(recs[0]["reason"]))
	var result: Dictionary = AdvisorScript.execute(campaign, recs[0])
	if not bool(result.get("ok", false)):
		_fail("B6 下一回合失败")
	if str(campaign.pending_story) != "s2":
		_fail("B6 没有进入 S2，pending=%s" % str(campaign.pending_story))
	if str(campaign.s2_choice) != choice_before or bool(campaign.s2_done):
		_fail("B6 推荐替玩家定了 S2")


func _test_b7(campaign: Node) -> void:
	for which in ["s2", "s3"]:
		campaign.reset()
		campaign.pending_story = which
		var recs := _recs(campaign)
		if recs.is_empty() or bool(recs[0].get("executable", true)):
			_fail("B7 %s 推荐可被直接执行" % which)
			continue
		var result: Dictionary = AdvisorScript.execute(campaign, recs[0])
		if bool(result.get("ok", false)):
			_fail("B7 %s 执行成功了" % which)
		var forged := {"kind": "attack", "src": "C4", "dst": "C6", "executable": true, "id": "forged"}
		AdvisorScript.execute(campaign, forged)
		if str(campaign.s2_choice) != "" or str(campaign.s3_choice) != "" or str(campaign.ending_id) != "":
			_fail("B7 %s 写回了结局或选项" % which)
		if bool(campaign.s2_done) or bool(campaign.s3_done):
			_fail("B7 %s 把剧情标记写上了" % which)


func _test_b8(campaign: Node) -> void:
	campaign.reset()
	for id in ["C2", "C3", "C4", "C5", "C6"]:
		campaign.city(id)["faction"] = "后金"
	var recs := _recs(campaign)
	if _has_kind(recs, "march"):
		_fail("B8 只剩一座城仍推荐行军")
	if _has_kind(recs, "attack"):
		_fail("B8 只剩一座城仍推荐出兵")
	if not (_has_kind(recs, "hold") or _has_kind(recs, "levy")):
		_fail("B8 没有守势或内政")


func _test_b10(campaign: Node) -> void:
	campaign.reset()
	var before := int(campaign.grain)
	for _i in 20:
		AdvisorScript.recommend(campaign)
	if int(campaign.grain) != before or bool(campaign.main_done) or bool(campaign.civil_done):
		_fail("B10 连点推荐 20 次改了局面")
	var recs := _recs(campaign)
	var levy := {}
	for item in recs:
		if str(item["kind"]) == "levy":
			levy = item
	if levy.is_empty():
		_fail("B10 没有征粮可测")
		return
	var once: Dictionary = AdvisorScript.execute(campaign, levy)
	if not bool(once.get("ok", false)):
		_fail("B10 第一次征粮失败")
		return
	var after := int(campaign.grain)
	for _j in 20:
		AdvisorScript.execute(campaign, levy)
		AdvisorScript.recommend(campaign)
	if int(campaign.grain) != after:
		_fail("B10 重复执行又扣/加了粮")


func _test_b11(campaign: Node) -> void:
	campaign.reset()
	var recs := _recs(campaign)
	var attack := {}
	for item in recs:
		if str(item["kind"]) == "attack":
			attack = item
	if attack.is_empty():
		_fail("B11 没有攻城")
		return
	var result: Dictionary = AdvisorScript.execute(campaign, attack)
	if not bool(result.get("ok", false)):
		_fail("B11 攻城失败")
		return
	var saved_state: Dictionary = campaign.snapshot()
	saved_state.erase("log_text")
	var saved := JSON.stringify(saved_state)
	var again := JSON.stringify(_public_recs(campaign))
	var write: Dictionary = campaign.save_game()
	if not bool(write.get("ok", false)):
		_fail("B11 存档失败")
		return
	campaign.silver = 1
	campaign.grain = 1
	campaign.city("C6")["faction"] = "后金"
	var loaded: Dictionary = campaign.load_game()
	if not bool(loaded.get("ok", false)):
		_fail("B11 读档失败 %s" % str(loaded.get("message", "")))
		return
	var loaded_state: Dictionary = campaign.snapshot()
	loaded_state.erase("log_text")
	if JSON.stringify(loaded_state) != saved:
		_fail("B11 读档后局面不一致")
	if JSON.stringify(_public_recs(campaign)) != again:
		_fail("B11 读档后推荐不一致")


func _test_b12(campaign: Node) -> void:
	campaign.reset()
	campaign.grain = 12
	campaign.morale = 28
	var a := JSON.stringify(_public_recs(campaign))
	var b := JSON.stringify(_public_recs(campaign))
	if a != b:
		_fail("B12 同一局面两次推荐不同")
	if a == "[]":
		_fail("B12 推荐是空的")


func _test_snapshot(campaign: Node) -> void:
	campaign.reset()
	campaign.silver = 17
	var before := JSON.stringify(campaign.snapshot())
	var cases: Array = [
		{"version": 2},
		{"version": 2, "cities": []},
		{"version": 2, "turn": 3, "cities": [{"id": "C1", "faction": "明"}]},
		{"version": 2, "cities": "半截"},
	]
	for data in cases:
		var full: Dictionary = campaign.snapshot()
		for key in data:
			full[key] = data[key]
		if key_missing_case(data):
			full = data
		if campaign.apply_snapshot(full):
			_fail("半截存档不该读入 %s" % JSON.stringify(data))
		if JSON.stringify(campaign.snapshot()) != before:
			_fail("半截存档改动了局面")
			campaign.reset()
			campaign.silver = 17
			before = JSON.stringify(campaign.snapshot())
	# 城池数组缺一行
	var partial: Dictionary = campaign.snapshot()
	partial["cities"] = [{"id": "C1", "faction": "明", "troops": 3}]
	if campaign.apply_snapshot(partial):
		_fail("缺城的存档不该读入")
	if int(campaign.silver) != 17:
		_fail("失败的读档把银两改了")


func key_missing_case(data: Dictionary) -> bool:
	return not data.has("turn") or not data.has("log_text")


func _test_guide(campaign: Node) -> void:
	_clear_user_files()
	campaign.reset()
	if bool(campaign.guide_done) or int(campaign.guide_step) != 0:
		_fail("新局应出现引导")
	campaign.guide_note_city()
	campaign.guide_note_city()
	if int(campaign.guide_step) != 1:
		_fail("连点城推进了多次，step=%d" % int(campaign.guide_step))
	var saved: Dictionary = campaign.save_game()
	if not bool(saved.get("ok", false)):
		_fail("引导中存档失败")
		return
	campaign.guide_step = 0
	campaign.guide_done = false
	var loaded: Dictionary = campaign.load_game()
	if not bool(loaded.get("ok", false)):
		_fail("引导读档失败")
		return
	if int(campaign.guide_step) != 1 or bool(campaign.guide_done):
		_fail("教程中途的存档应回到选城之后")
	campaign.guide_skip()
	if not bool(campaign.guide_done):
		_fail("跳过没有关掉引导")
	loaded = campaign.load_game()
	if not bool(loaded.get("ok", false)):
		_fail("跳过后读档失败")
		return
	if not bool(campaign.guide_done) or int(campaign.guide_step) < 3:
		_fail("跳过引导后读档，引导不应再出现")
	campaign.reset()
	if not bool(campaign.guide_done):
		_fail("跳过后再开局仍弹引导")
	var file := FileAccess.open("user://v03_guide.json", FileAccess.WRITE)
	file.store_string("{这不是json")
	campaign.reset()
	if bool(campaign.guide_done):
		_fail("引导标记损坏时没有回到首次引导")


func _recs(campaign: Node) -> Array[Dictionary]:
	return AdvisorScript.recommend(campaign)


func _public_recs(campaign: Node) -> Array:
	var clean: Array = []
	for item in _recs(campaign):
		clean.append({
			"id": str(item["id"]),
			"kind": str(item["kind"]),
			"title": str(item["title"]),
			"reason": str(item["reason"]),
			"executable": bool(item["executable"]),
		})
	return clean


func _has_kind(recs: Array[Dictionary], kind: String) -> bool:
	for item in recs:
		if str(item["kind"]) == kind:
			return true
	return false


func _clear_user_files() -> void:
	for path in ["user://campaign_m2.json", "user://v03_guide.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ADVISOR_CHECK_OK")
		quit(0)
		return
	for message in _failures:
		print("ADVISOR_CHECK_FAIL %s" % message)
	quit(1)
