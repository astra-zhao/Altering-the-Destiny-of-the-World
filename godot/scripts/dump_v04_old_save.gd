extends SceneTree
## 真实走一遍 v0.3.1 的门：reset、固守、结束回合，停在登基夜前。
## godot --headless --path godot -s res://scripts/dump_v04_old_save.gd


func _initialize() -> void:
	var campaign := root.get_node("Campaign")
	for path in ["user://campaign_m2.json", "user://v03_guide.json", "user://audio_prefs.json", "user://advisor_prefs.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	campaign.reset()
	var held: Dictionary = campaign.hold("C1")
	if not bool(held.get("ok", false)):
		push_error("固守失败 %s" % str(held.get("message", "")))
		quit(1)
		return
	var ended: Dictionary = campaign.end_turn()
	if str(ended.get("goto", "")) != "s1" or int(campaign.turn) != 2 or str(campaign.pending_story) != "s1" or campaign.s1_done:
		push_error("没有停在登基夜门前 goto=%s turn=%d pending=%s" % [str(ended.get("goto", "")), int(campaign.turn), str(campaign.pending_story)])
		quit(1)
		return
	var text := JSON.stringify(campaign.snapshot(), "\t")
	var out := FileAccess.open("/opt/cursor/artifacts/v0.4-old-save-s1-pending.json", FileAccess.WRITE)
	if out == null:
		push_error("写不了 artifact")
		quit(1)
		return
	out.store_string(text + "\n")
	var sample := FileAccess.open("res://data/samples/v031_turn2_pending_s1.json", FileAccess.WRITE)
	if sample == null:
		push_error("写不了样本")
		quit(1)
		return
	sample.store_string(text + "\n")
	print("OLD_SAVE_DUMP turn=%d pending=%s s1_done=%s silver=%d grain=%d" % [int(campaign.turn), str(campaign.pending_story), str(campaign.s1_done), int(campaign.silver), int(campaign.grain)])
	print("OLD_SAVE_LOG %s" % str(campaign.log_text))
	quit(0)
