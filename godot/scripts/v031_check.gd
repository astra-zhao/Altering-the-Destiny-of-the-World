extends SceneTree
## v0.3.1 无头检查：回合、预警、钳制、预判、★、悬停、规则边界。
## godot --headless --path godot -s res://scripts/glyph_subset_check.gd 不扫本文件。
## godot --headless --path godot -s res://scripts/v031_check.gd

const AdvisorScript := preload("res://scripts/advisor.gd")
const Baseline := preload("res://data/campaign_baseline.gd")

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
	_out_marks(campaign)
	_out_clamp(campaign)
	_out_old_save(campaign)
	_out_turns(campaign)
	_out_gaps(campaign)
	_out_ending_grid(campaign)
	_pre_forecast(campaign)
	_adv_avoid_levy(campaign)
	_adv_loss_outlook(campaign)
	_adv_preview_grid(campaign)
	_adv_stories(campaign)
	await _hv_layout()
	_reg_source()
	_finish()


func _out_marks(campaign: Node) -> void:
	campaign.reset()
	if not campaign.danger_marks().is_empty():
		_fail("OUT 开局不该有预警 %s" % str(campaign.danger_marks()))
	var cases := [
		["morale", 26, ""],
		["morale", 25, "yellow"],
		["morale", 16, "yellow"],
		["morale", 15, "red"],
		["silver", 11, ""],
		["silver", 10, "yellow"],
		["silver", 1, "yellow"],
		["silver", 0, "red"],
		["liaodong", 41, ""],
		["liaodong", 40, ""],
		["liaodong", 39, "red"],
	]
	for row in cases:
		campaign.reset()
		campaign.set(str(row[0]), int(row[1]))
		var got := str(campaign.danger_marks().get(str(row[0]), ""))
		if got != str(row[2]):
			_fail("OUT-14 %s=%s 期望 %s 得到 %s" % [row[0], row[1], row[2], got])
	campaign.reset()
	campaign.morale = 25
	var line := str(campaign.danger_line())
	if not line.contains("民心 25") or not line.contains("15"):
		_fail("OUT-05 民心黄文案 %s" % line)
	campaign.morale = 35
	campaign.silver = 10
	line = str(campaign.danger_line())
	if not line.contains("银两 10") or not line.contains("丁"):
		_fail("OUT-05 银两黄文案 %s" % line)
	campaign.silver = 40
	campaign.liaodong = 39
	line = str(campaign.danger_line())
	if not line.contains("辽东稳固 39"):
		_fail("OUT-05 辽东红文案 %s" % line)
	if line.contains("✗"):
		_fail("预警文案里不该有叉号")
	print("OUT_MARKS_OK")


func _out_clamp(campaign: Node) -> void:
	campaign.reset()
	campaign.silver = 3
	campaign.morale = 2
	var s1: Dictionary = campaign.apply_s1("B")
	if not bool(s1.get("ok", false)) or int(campaign.silver) != 0:
		_fail("OUT-09 S1 银两应钳到 0，现在 %d" % int(campaign.silver))
	campaign.silver = 3
	campaign.morale = 2
	var s2: Dictionary = campaign.apply_s2("C")
	if not bool(s2.get("ok", false)):
		_fail("OUT-09 S2 写回失败")
	if int(campaign.silver) < 0 or int(campaign.morale) < 0:
		_fail("OUT-09 S2 仍为负 银 %d 民 %d" % [int(campaign.silver), int(campaign.morale)])
	campaign.liaodong = 5
	campaign.pressure = 0
	var kill: Dictionary = campaign.apply_s2("A")
	if bool(kill.get("ok", false)):
		_fail("OUT S2 不能写第二次")
	campaign.reset()
	campaign.liaodong = 5
	var killed: Dictionary = campaign.apply_s2("A")
	if not bool(killed.get("ok", false)) or int(campaign.liaodong) != 0:
		_fail("OUT-18 辽东应钳到 0，现在 %d" % int(campaign.liaodong))
	if int(campaign.pressure) < 0:
		_fail("压力为负")
	print("OUT_CLAMP_OK silver=%d morale=%d liaodong=%d" % [int(campaign.silver), int(campaign.morale), int(campaign.liaodong)])


func _out_old_save(campaign: Node) -> void:
	campaign.reset()
	var data: Dictionary = campaign.snapshot()
	data["silver"] = -7
	data["morale"] = -3
	data["liaodong"] = -5
	data["pressure"] = -3
	data["grain"] = -1
	data["worldline"] = -2
	if not campaign.apply_snapshot(data):
		_fail("OUT-17 旧负数档被拒")
		return
	if int(campaign.silver) != 0 or int(campaign.morale) != 0 or int(campaign.liaodong) != 0 or int(campaign.pressure) != 0:
		_fail("OUT-17 读入未钳 0：%d %d %d %d" % [int(campaign.silver), int(campaign.morale), int(campaign.liaodong), int(campaign.pressure)])
	if int(campaign.grain) != 0 or int(campaign.worldline) != 0:
		_fail("OUT-17 粮草或世界线未钳 0")
	var again: Dictionary = campaign.snapshot()
	for key in ["silver", "morale", "liaodong", "pressure", "grain", "worldline"]:
		if int(again[key]) < 0:
			_fail("OUT-17 再存档仍为负 %s" % key)
	if str(campaign.resolve_ending()) != "丁":
		_fail("OUT-17 钳到 0 后应是丁，现在 %s" % str(campaign.resolve_ending()))
	print("OUT_OLD_SAVE_OK ending=%s" % str(campaign.resolve_ending()))


func _out_turns(campaign: Node) -> void:
	if Baseline.PLAY_TURNS != 8:
		_fail("PLAY_TURNS=%d" % Baseline.PLAY_TURNS)
	var baseline_text := FileAccess.get_file_as_string("res://data/campaign_baseline.gd")
	if baseline_text.contains("TURN_LIMIT"):
		_fail("OUT-13 TURN_LIMIT 还在")
	var state_text := FileAccess.get_file_as_string("res://scripts/campaign_state.gd")
	if state_text.contains("超时"):
		_fail("OUT-13 还有超时文案")
	campaign.reset()
	if str(campaign.finale_hint()) != "":
		_fail("第 1 回合不该有终局横幅")
	campaign.turn = 5
	if str(campaign.finale_hint()) != "":
		_fail("第 5 回合不该有终局横幅")
	campaign.turn = 6
	if str(campaign.finale_hint()) != "下回合是京师危机，再下回合是终局。":
		_fail("第 6 回合横幅 %s" % str(campaign.finale_hint()))
	campaign.turn = 7
	if str(campaign.finale_hint()) != "下回合是京师危机，再下回合是终局。":
		_fail("第 7 回合横幅 %s" % str(campaign.finale_hint()))
	campaign.turn = 8
	if str(campaign.finale_hint()) != "本回合是终局，点下一回合进入结局。":
		_fail("第 8 回合横幅 %s" % str(campaign.finale_hint()))
	var summary := "\n".join(campaign.summary_lines())
	if summary.contains("/ 10") or summary.contains("/10"):
		_fail("摘要仍有 /10")
	if not summary.contains("/ 8"):
		_fail("摘要没有 / 8：%s" % summary)
	print("OUT_TURNS_OK")


func _out_gaps(campaign: Node) -> void:
	campaign.reset()
	campaign.s1_done = true
	campaign.s2_done = true
	campaign.s3_done = true
	campaign.yuan_status = "前线可用"
	campaign.liaodong = 60
	campaign.pressure = 41
	campaign.worldline = 35
	campaign.morale = 35
	campaign.silver = 20
	if str(campaign.resolve_ending()) != "乙":
		_fail("压力 41 应是乙，现在 %s" % str(campaign.resolve_ending()))
	var joined := " ".join(campaign.upgrade_gaps())
	if not joined.contains("差 1：后金压力须 ≤40"):
		_fail("OUT-08 差 1 文案：%s" % joined)
	campaign.liaodong = 36
	campaign.pressure = 50
	campaign.worldline = 20
	campaign.morale = 30
	if str(campaign.resolve_ending()) != "丙":
		_fail("丙样本现在是 %s" % str(campaign.resolve_ending()))
	var view: Dictionary = campaign.forecast_view()
	var avoid := str(view.get("avoid", ""))
	if not avoid.contains("辽东 +24"):
		_fail("丙的辽东差应按 60 现算，文案 %s" % avoid)
	if avoid.contains("+17"):
		_fail("预判不该照抄示意 +17：%s" % avoid)
	print("OUT_GAPS_OK %s" % joined)


func _out_ending_grid(campaign: Node) -> void:
	var mismatch := 0
	var points := 0
	var liaos: Array[int] = [0, 39, 40, 59, 60, 80]
	for n in 81:
		liaos.append(n)
	var morales: Array[int] = [0, 14, 15, 16, 44, 45]
	var m := 0
	while m <= 60:
		morales.append(m)
		m += 2
	var silvers: Array[int] = [0, 1, 5, 10, 20]
	var pressures: Array[int] = [30, 40, 41, 70]
	var worlds: Array[int] = [0, 34, 35, 60]
	campaign.reset()
	for liao in liaos:
		for morale in morales:
			for silver in silvers:
				for capital in [true, false]:
					for dead in [true, false]:
						for pressure in pressures:
							for world in worlds:
								points += 1
								campaign.liaodong = liao
								campaign.morale = morale
								campaign.silver = silver
								campaign.pressure = pressure
								campaign.worldline = world
								campaign.yuan_status = "已死" if dead else "前线可用"
								campaign.city("C1")["faction"] = "明" if capital else "后金"
								var got := str(campaign.resolve_ending())
								var want := _formula(capital, dead, liao, pressure, world, morale, silver)
								if got != want:
									mismatch += 1
									if mismatch < 6:
										_fail("OUT-16 %s!=%s 辽%d 民%d 银%d 压%d 世%d 京%s 袁%s" % [got, want, liao, morale, silver, pressure, world, capital, dead])
	var spot := [
		[39, 44, 0, "丁"],
		[39, 44, 5, "丙"],
		[40, 10, 0, "乙"],
		[0, 45, 0, "乙"],
		[60, 10, 10, "甲"],
	]
	for row in spot:
		campaign.liaodong = int(row[0])
		campaign.morale = int(row[1])
		campaign.silver = int(row[2])
		campaign.pressure = 40
		campaign.worldline = 35
		campaign.yuan_status = "前线可用"
		campaign.city("C1")["faction"] = "明"
		if str(campaign.resolve_ending()) != str(row[3]):
			_fail("边界 %s 得到 %s" % [row, campaign.resolve_ending()])
	if mismatch != 0:
		_fail("OUT-16 不一致 %d / %d" % [mismatch, points])
	print("OUT_ENDING_GRID points=%d mismatch=%d" % [points, mismatch])


func _formula(capital: bool, dead: bool, liao: int, pressure: int, world: int, morale: int, silver: int) -> String:
	if not dead and liao >= 60 and pressure <= 40 and world >= 35 and capital:
		return "甲"
	if capital and (liao >= 40 or morale >= 45):
		return "乙"
	if morale <= 15 or silver <= 0:
		return "丁"
	return "丙"


func _pre_forecast(campaign: Node) -> void:
	campaign.reset()
	var before := JSON.stringify(campaign.snapshot())
	for _i in 100:
		campaign.forecast_view()
	if JSON.stringify(campaign.snapshot()) != before:
		_fail("PRE-06 预判改了局面")
	var longest := ""
	var samples := 0
	for liao in [0, 19, 36, 39, 40, 56, 60, 80]:
		for pressure in [0, 40, 41, 48, 70]:
			for world in [0, 20, 34, 35, 60]:
				for dead in [false, true]:
					for capital in [true, false]:
						campaign.liaodong = liao
						campaign.pressure = pressure
						campaign.worldline = world
						campaign.yuan_status = "已死" if dead else "前线可用"
						campaign.city("C1")["faction"] = "明" if capital else "后金"
						campaign.morale = 30
						campaign.silver = 20
						var view: Dictionary = campaign.forecast_view()
						samples += 1
						if str(view.get("ending", "")) != str(campaign.resolve_ending()):
							_fail("PRE 预判结局 != 现在结算")
						var avoid := str(view.get("avoid", ""))
						if avoid.length() > longest.length():
							longest = avoid
						if avoid.contains("如"):
							_fail("预判含「如」：%s" % avoid)
						var bits: Array = view.get("bits", [])
						var now := str(view.get("ending", ""))
						if now == "甲":
							if avoid != "保持现状即可":
								_fail("甲预判 %s" % avoid)
							if str(bits[0].get("color", "")) != "FFD978":
								_fail("甲字色")
						elif now == "丁":
							if not avoid.begins_with("想避开："):
								_fail("丁预判 %s" % avoid)
							if str(bits[0].get("color", "")) != "FFB4A6":
								_fail("丁字色")
						else:
							if not avoid.begins_with("想升到甲，还差："):
								_fail("乙丙预判 %s" % avoid)
							if str(bits[0].get("color", "")) != "F6DC92":
								_fail("乙丙前缀色")
						if str(view.get("lead", "")) != "照现在这样，预计得":
							_fail("预判前缀 %s" % str(view.get("lead", "")))
	campaign.liaodong = 39
	campaign.pressure = 40
	campaign.worldline = 35
	campaign.yuan_status = "前线可用"
	campaign.city("C1")["faction"] = "明"
	var low: Dictionary = campaign.forecast_view()
	if not str(low.get("avoid", "")).contains("辽东 +21"):
		_fail("辽东 39 升甲至少差 21：%s" % str(low.get("avoid", "")))
	print("PRE_FORECAST_OK samples=%d" % samples)
	print("PRE_LONGEST %s" % longest)


func _adv_avoid_levy(campaign: Node) -> void:
	campaign.reset()
	campaign.morale = 25
	for item in AdvisorScript.recommend(campaign):
		if str(item.get("kind", "")) == "levy":
			_fail("ADV-13 民心 25 仍推荐征粮")
	var saw_spend := false
	for item in AdvisorScript.recommend(campaign):
		if str(item.get("kind", "")) == "spend":
			saw_spend = true
			if not str(item.get("reason", "")).contains("民心告急"):
				_fail("发帑理由 %s" % str(item.get("reason", "")))
	if not saw_spend:
		_fail("民心 25、银两够时应收发帑")
	campaign.silver = 10
	for item in AdvisorScript.recommend(campaign):
		var kind := str(item.get("kind", ""))
		if kind == "spend" or kind == "train" or kind == "levy":
			_fail("银两 10 仍推荐 %s" % kind)
	print("ADV_CIVIL_OK")


func _adv_loss_outlook(campaign: Node) -> void:
	campaign.reset()
	var first: Dictionary = campaign.commit_player_battle("C4", "C6")
	if str(first.get("outcome", "")) != "win":
		_fail("开局宁远攻锦州应胜：%s" % str(first.get("message", "")))
	campaign.civil("skip", "")
	campaign.end_turn()
	if str(campaign.pending_story) != "s1":
		_fail("第 2 回合应进登基夜，现在 %s" % str(campaign.pending_story))
	campaign.apply_s1("B")
	var second: Dictionary = campaign.commit_player_battle("C6", "C5")
	if str(second.get("outcome", "")) != "lose":
		_fail("锦州攻沈阳应负：%s" % str(second.get("message", "")))
	var line := AdvisorScript.head_line(campaign)
	if line != "当前最好结局：乙":
		_fail("打输后标题 %s" % line)
	if str(campaign.forecast_view().get("ending", "")) == "甲":
		_fail("打输后若现在结算不该是甲")
	if str(campaign.forecast_view().get("avoid", "")).contains("照★走"):
		_fail("预判条不该写照★走")
	print("ADV_LOSS_OK head=%s forecast=%s pressure=%d" % [line, campaign.forecast_view().get("ending", ""), int(campaign.pressure)])


func _adv_preview_grid(campaign: Node) -> void:
	campaign.reset()
	var open_preview: Dictionary = campaign.preview_battle("C4", "C6")
	if int(open_preview.get("atk_x100", 0)) != 2125 or int(open_preview.get("def_x100", 0)) != 1000 or str(open_preview.get("outcome", "")) != "win":
		_fail("开局战力 %s" % str(open_preview))
	var bad := 0
	var points := 0
	var terrains: Array[int] = [100, 110, 115, 120]
	for troops in range(3, 42):
		for defend in range(1, 41):
			for terrain in terrains:
				for yuan in [false, true]:
					points += 1
					campaign.city("C4")["troops"] = troops
					campaign.city("C6")["troops"] = defend
					campaign.city("C6")["faction"] = "后金"
					campaign.city("C6")["terrain_pct"] = terrain
					campaign.yuan_status = "前线可用" if yuan else "闲置"
					campaign.yuan_city = "C4"
					campaign.hold_city = ""
					var preview: Dictionary = campaign.preview_battle("C4", "C6")
					var sent := troops - 1
					var atk := sent * (125 if yuan else 100)
					var defense := defend * terrain
					var want := "draw"
					if atk * 100 >= defense * Baseline.WIN_RATIO_PCT:
						want = "win"
					elif atk * 100 <= defense * Baseline.LOSE_RATIO_PCT:
						want = "lose"
					if str(preview.get("outcome", "")) != want or int(preview.get("atk_x100", -1)) != atk:
						bad += 1
	var frozen := JSON.stringify(campaign.snapshot())
	for _i in 20:
		campaign.preview_battle("C4", "C6")
	if JSON.stringify(campaign.snapshot()) != frozen:
		_fail("ADV-11 预览改了局面")
	var edges := [[28, "win"], [27, "draw"], [22, "lose"], [23, "draw"]]
	for edge in edges:
		campaign.city("C4")["troops"] = int(edge[0]) + 1
		campaign.city("C6")["troops"] = 25
		campaign.city("C6")["terrain_pct"] = 100
		campaign.yuan_status = "闲置"
		var preview: Dictionary = campaign.preview_battle("C4", "C6")
		if str(preview.get("outcome", "")) != str(edge[1]):
			_fail("边界出兵 %s 得到 %s" % [edge, preview.get("outcome", "")])
	if bad != 0:
		_fail("ADV-11 不一致 %d / %d" % [bad, points])
	print("ADV_PREVIEW_OK points=%d mismatch=%d" % [points, bad])


func _adv_stories(campaign: Node) -> void:
	var jia := PackedStringArray()
	var bad_turn := 0
	var negative := 0
	for s1 in ["A", "B", "C"]:
		for s2 in ["A", "B", "C", "D"]:
			for s3 in ["A", "B", "C"]:
				campaign.reset()
				var result := _play(campaign, s1, s2, s3, false)
				print("ADV36 %s%s%s %s" % [s1, s2, s3, result])
				if result.begins_with("甲@"):
					jia.append("%s%s%s" % [s1, s2, s3])
				if result.contains("@") and not result.ends_with("@8"):
					bad_turn += 1
				if int(campaign.silver) < 0 or int(campaign.morale) < 0 or int(campaign.liaodong) < 0 or int(campaign.pressure) < 0:
					negative += 1
	campaign.reset()
	var starred := _play(campaign, "", "", "", true)
	print("ADV_STAR %s" % starred)
	if starred != "甲@8":
		_fail("照★走应是甲@8，现在 %s" % starred)
	if not jia.has("BCA"):
		_fail("36 组里 BCA 没有得到甲，得到甲的是 %s" % " ".join(jia))
	if bad_turn != 0 or negative != 0:
		_fail("36 组回合或负数 bad_turn=%d negative=%d" % [bad_turn, negative])
	var attacks := 0
	campaign.reset()
	for _i in 8:
		if bool(campaign.settled) or str(campaign.pending_story) != "":
			break
		for item in AdvisorScript.recommend(campaign):
			if str(item.get("kind", "")) != "attack":
				continue
			attacks += 1
			var preview: Dictionary = campaign.preview_battle(str(item.get("src", "")), str(item.get("dst", "")))
			if str(preview.get("outcome", "")) != "win":
				_fail("ADV-10 推荐了非胜攻城 %s" % str(item.get("id", "")))
		break
	print("ADV_STORIES_OK jia=%s attack_recs=%d" % [" ".join(jia), attacks])


func _play(campaign: Node, s1: String, s2: String, s3: String, star_story: bool) -> String:
	var guard := 0
	while not bool(campaign.settled) and guard < 48:
		guard += 1
		var pending := str(campaign.pending_story)
		if pending != "":
			var choice := s1 if pending == "s1" else (s2 if pending == "s2" else s3)
			if star_story:
				choice = str(AdvisorScript.story_star(campaign, pending).get("choice", ""))
			if pending == "s2" and choice == "D" and not bool(campaign.befriended_yuan):
				return "locked-D"
			var written: Dictionary = campaign.apply_s1(choice) if pending == "s1" else (campaign.apply_s2(choice) if pending == "s2" else campaign.apply_s3(choice))
			if not bool(written.get("ok", false)):
				return "story-fail %s" % str(written.get("message", ""))
			continue
		if not bool(campaign.main_done):
			var picked: Dictionary = {}
			for item in AdvisorScript.recommend(campaign):
				var kind := str(item.get("kind", ""))
				if not bool(item.get("executable", false)):
					continue
				if kind != "attack" and kind != "march" and kind != "hold":
					continue
				if bool(item.get("best", false)) or picked.is_empty():
					picked = item
					if bool(item.get("best", false)):
						break
			if picked.is_empty():
				var held: Dictionary = campaign.hold("C1")
				if not bool(held.get("ok", false)):
					return "hold-fail"
			else:
				var done: Dictionary = AdvisorScript.execute(campaign, picked)
				if not bool(done.get("ok", false)):
					return "act-fail %s" % str(picked.get("id", ""))
			continue
		if not bool(campaign.civil_done):
			campaign.civil("skip", "")
			continue
		var ended: Dictionary = campaign.end_turn()
		if not bool(ended.get("ok", false)) and not bool(campaign.settled):
			return "end-fail %s" % str(ended.get("message", ""))
	if not bool(campaign.settled):
		return "unsettled"
	return "%s@%d" % [str(campaign.ending_id), int(campaign.turn)]


func _hv_layout() -> void:
	var campaign := root.get_node("Campaign")
	campaign.reset()
	campaign.guide_done = true
	campaign.guide_step = 3
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/big_map.tscn") as PackedScene
	var map := packed.instantiate()
	root.add_child(map)
	for _i in 8:
		await process_frame
	map.size = Vector2(1280, 720)
	if map.has_method("_layout_chrome"):
		map._layout_chrome()
	var cities := ["C2", "C1", "C3", "C4"]
	for city_id in cities:
		map._on_city_pressed(city_id)
		await process_frame
		var spots: Array[Vector2] = []
		for _n in 6:
			map._layout_actions()
			spots.append(map._actions.position)
		var unique := 1
		for spot in spots:
			if spot.distance_to(spots[0]) > 0.5:
				unique += 1
		var calls_before := int(map.layout_calls)
		map._on_seal_hover("btn_action_march", true)
		map._on_seal_hover("btn_action_march", false)
		map._on_seal_hover("btn_action_siege", true)
		map._on_seal_hover("btn_action_siege", false)
		map._on_seal_hover("btn_action_hold", true)
		map._on_seal_hover("btn_action_hold", false)
		if int(map.layout_calls) != calls_before:
			_fail("HV 悬停触发了重排 %s" % city_id)
		if unique != 1:
			_fail("HV %s 位置不幂等 unique=%d pos=%s" % [city_id, unique, spots])
	var bar: Control = map._forecast_bar
	print("VIS_FORECAST rect=%s size=%s" % [bar.get_global_rect(), bar.size])
	var bits: Control = map._forecast_bits
	print("VIS_AVOID rect=%s text=%s" % [bits.get_global_rect(), _label_text(bits)])
	if bar.position.distance_to(Vector2(12, 58)) > 4.0:
		_fail("VIS 预判条位置 %s" % bar.position)
	if absf(bar.size.x - 970.0) > 4.0 or absf(bar.size.y - 44.0) > 4.0:
		_fail("VIS 预判条尺寸 %s" % bar.size)
	var banner: Control = map._turn_banner
	if absf(banner.position.x + banner.size.x * 0.5 - 640.0) > 4.0:
		_fail("VIS 横幅中心 %s" % banner.position)
	map.queue_free()
	print("HV_VIS_OK")


func _label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text
	for child in node.get_children():
		text += _label_text(child)
	return text


func _reg_source() -> void:
	var advisor := FileAccess.get_file_as_string("res://scripts/advisor.gd")
	if advisor.contains("self_pick") and FileAccess.get_file_as_string("res://scripts/campaign_state.gd").contains("\"self_pick\""):
		_fail("REG 自己选写进了局面快照")
	print("REG_SOURCE_OK")


func _clear_user_files() -> void:
	for path in ["user://campaign_m2.json", "user://v03_guide.json", "user://advisor_prefs.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("V031_CHECK_OK")
		quit(0)
		return
	for message in _failures:
		print("V031_CHECK_FAIL %s" % message)
	print("V031_CHECK_FAIL count=%d" % _failures.size())
	quit(1)
