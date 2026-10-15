extends SceneTree
## 无头冒烟：每回合只执行推荐的第一条，直到结局。
## 剧情选项不走推荐引擎。这里按冲甲的玩家手点：登基夜 B、袁崇焕 C、京师危机 A。
## godot --headless --path godot -s res://scripts/advisor_smoke.gd

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
	var guard := 0
	while not bool(campaign.settled) and guard < 40:
		guard += 1
		var pending := str(campaign.pending_story)
		if pending != "":
			var picked := _player_story(campaign, pending)
			if not bool(picked.get("ok", false)):
				_fail("玩家剧情点选失败 %s %s" % [pending, str(picked.get("message", ""))])
				break
			if str(campaign.pending_story) != "":
				_fail("剧情点选后 pending 还在")
				break
			continue
		var recs: Array = AdvisorScript.recommend(campaign)
		if recs.is_empty():
			_fail("第 %d 步没有推荐" % guard)
			break
		var first: Dictionary = recs[0]
		if not bool(first.get("executable", true)):
			_fail("第 %d 步第一条不能执行：%s" % [guard, str(first.get("reason", ""))])
			break
		var result: Dictionary = AdvisorScript.execute(campaign, first)
		if not bool(result.get("ok", false)):
			_fail("第 %d 步执行失败 %s：%s" % [guard, str(first.get("id", "")), str(result.get("message", ""))])
			break
		print("ADVISOR_SMOKE step=%d id=%s turn=%d" % [guard, str(first.get("id", "")), int(campaign.turn)])
	if not bool(campaign.settled):
		_fail("40 步内没有进入结局")
	elif str(campaign.ending_id) != "甲":
		_fail("结局是 %s，冲甲路径应是甲" % str(campaign.ending_id))
	else:
		print("ADVISOR_SMOKE ending=%s steps=%d" % [str(campaign.ending_id), guard])
	_finish()


func _player_story(campaign: Node, pending: String) -> Dictionary:
	# 这是烟雾脚本代替玩家点下去，不是推荐引擎写回。
	print("ADVISOR_SMOKE player_choice pending=%s" % pending)
	if pending == "s1":
		return campaign.apply_s1("B")
	if pending == "s2":
		return campaign.apply_s2("C")
	if pending == "s3":
		return campaign.apply_s3("A")
	return {"ok": false, "message": "未知剧情"}


func _clear_user_files() -> void:
	for path in ["user://campaign_m2.json", "user://v03_guide.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ADVISOR_SMOKE_OK")
		quit(0)
		return
	for message in _failures:
		print("ADVISOR_SMOKE_FAIL %s" % message)
	quit(1)
