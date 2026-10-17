extends RefCounted
## 局势推荐。只从行军、攻城、固守、征粮、发帑、练兵里挑，外加「行动点用完时的下一回合」。
## 同一局面同一输出。粮草不够不推荐出兵；打不赢不推荐攻城。
## S1/S2/S3 的选项不在这里定，execute 也不会写回剧情。

const Baseline := preload("res://data/campaign_baseline.gd")
const PREF_PATH := "user://advisor_prefs.json"

## 低于这个粮草就不出兵（行军、攻城都不推荐）。行军近邻正好要 3。
const GRAIN_SORTIE := 3


static func recommend(campaign: Node) -> Array[Dictionary]:
	return _mark_best(campaign, _recommend_raw(campaign))


static func _recommend_raw(campaign: Node) -> Array[Dictionary]:
	if bool(campaign.settled):
		return [_item("settled", "settled", "这一局已经结束", "可以读档，或开一局新的。", false)]
	var pending := str(campaign.pending_story)
	if pending == "s1" or pending == "s2" or pending == "s3":
		return [_story_wait(pending)]
	if bool(campaign.main_done):
		return [_end_turn_item(campaign)]
	var grain_low := int(campaign.grain) < GRAIN_SORTIE
	var ming := _ming_ids(campaign)
	var attacks: Array[Dictionary] = []
	var marches: Array[Dictionary] = []
	if not grain_low and ming.size() >= 2:
		attacks = _attacks(campaign)
		marches = _marches(campaign)
	elif not grain_low and ming.size() == 1:
		# 只剩一座城：不推荐行军，也不把人派去送。守和内政就够。
		attacks = []
		marches = []
	var holds := _holds(campaign)
	var civils := _civils(campaign, grain_low)
	var picked: Array[Dictionary] = []
	if grain_low:
		_take(picked, civils, 2)
		_take(picked, holds, 1)
	elif ming.size() <= 1:
		_take(picked, holds, 1)
		_take(picked, civils, 2)
	elif not attacks.is_empty():
		_take(picked, attacks, 1)
		_take(picked, civils, 1)
		_take(picked, holds, 1)
	else:
		_take(picked, holds, 1)
		_take(picked, civils, 1)
		_take(picked, marches, 1)
	if picked.is_empty():
		picked.append(_item("none", "none", "没有可做的行动", "现在没有我方城，不能行军、攻城或固守。", false))
	if picked.size() > 3:
		var trimmed: Array[Dictionary] = []
		for i in 3:
			trimmed.append(picked[i])
		return trimmed
	return picked


static func execute(campaign: Node, action: Dictionary) -> Dictionary:
	if not bool(action.get("executable", true)):
		return {"ok": false, "message": str(action.get("reason", "这一步不能代做。")), "goto": "map"}
	var pending := str(campaign.pending_story)
	if pending == "s1" or pending == "s2" or pending == "s3":
		return {"ok": false, "message": "剧情选项要你自己点，帮我选不能替你定。", "goto": "map"}
	match str(action.get("kind", "")):
		"march":
			return campaign.march(str(action.get("src", "")), str(action.get("dst", "")))
		"attack":
			return campaign.commit_player_battle(str(action.get("src", "")), str(action.get("dst", "")))
		"hold":
			return campaign.hold(str(action.get("city", "")))
		"levy":
			return campaign.civil("levy", "")
		"spend":
			return campaign.civil("spend", "")
		"train":
			return campaign.civil("train", str(action.get("city", "")))
		"end_turn":
			return campaign.end_turn()
		_:
			return {"ok": false, "message": "没有这项行动。", "goto": "map"}


static func _story_wait(which: String) -> Dictionary:
	var name := "这场剧情"
	if which == "s1":
		name = "登基夜"
	elif which == "s2":
		name = "袁崇焕生死"
	elif which == "s3":
		name = "京师危机"
	return _item(
		"story:%s" % which,
		"story_wait",
		"请你自己选",
		"%s要你自己点。帮我选不能替你定结局。" % name,
		false
	)


static func _end_turn_item(campaign: Node) -> Dictionary:
	var nxt := _after_end(campaign)
	var reason := "这个回合能做的已经做完了。点下一回合，时间才会往前走。"
	if nxt == "ending":
		reason = "再点一次就进入结局。"
	elif nxt != "":
		var name := "剧情"
		if nxt == "s1":
			name = "登基夜"
		elif nxt == "s2":
			name = "袁崇焕生死"
		elif nxt == "s3":
			name = "京师危机"
		reason = "点下去会进入%s。里面的选项要你自己选，不能代点。" % name
	return _item("end_turn", "end_turn", "下一回合", reason, true)


static func _after_end(campaign: Node) -> String:
	if bool(campaign.s3_done):
		return "ending"
	var next := int(campaign.turn) + 1
	if not bool(campaign.s1_done) and next <= 3:
		return "s1"
	if not bool(campaign.s2_done) and next >= 4 and next <= 6:
		if bool(campaign.held_ningyuan) or int(campaign.liaodong) <= 35 or next == 6:
			return "s2"
	if bool(campaign.s3_done) or not bool(campaign.s1_done):
		return ""
	if not bool(campaign.s2_done) and next <= 6:
		return ""
	if next >= 8 or bool(campaign.capital_threatened()):
		return "s3"
	return ""


static func _attacks(campaign: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for src_id in _ming_ids(campaign):
		var src: Dictionary = campaign.city(src_id)
		if int(src["troops"]) < 2:
			continue
		for hop in campaign.neighbors_of(src_id):
			var dst_id := str(hop["id"])
			var dst: Dictionary = campaign.city(dst_id)
			if str(dst["faction"]) == "明":
				continue
			var preview: Dictionary = campaign.preview_battle(src_id, dst_id)
			if not bool(preview.get("ok", false)):
				continue
			if str(preview.get("outcome", "")) != "win":
				continue
			var atk := int(preview["atk_x100"])
			var defense := maxi(1, int(preview["def_x100"]))
			var ratio := float(atk) / float(defense)
			var yuan := 1 if bool(preview.get("yuan_bonus", false)) else 0
			var jinzhou := 1 if dst_id == "C6" else 0
			var item := _item(
				"attack:%s:%s" % [src_id, dst_id],
				"attack",
				"攻城 %s→%s" % [src["name"], dst["name"]],
				"出兵 %d，守军 %d。战力 %d 对 %d，你这边更强，能占下这座城。" % [int(preview["sent"]), int(preview["defender"]), atk, defense],
				true
			)
			item["src"] = src_id
			item["dst"] = dst_id
			item["sort"] = [ratio, yuan, jinzhou, -_ord(src_id), -_ord(dst_id)]
			found.append(item)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_desc(a["sort"], b["sort"])
	)
	return found


static func _marches(campaign: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for src_id in _ming_ids(campaign):
		var src: Dictionary = campaign.city(src_id)
		if int(src["troops"]) < 2:
			continue
		for hop in campaign.neighbors_of(src_id):
			var dst_id := str(hop["id"])
			var dst: Dictionary = campaign.city(dst_id)
			if str(dst["faction"]) != "明":
				continue
			var far := bool(hop["far"])
			var cost := Baseline.MARCH_GRAIN_FAR if far else Baseline.MARCH_GRAIN
			if int(campaign.grain) < cost:
				continue
			if int(dst["troops"]) >= int(src["troops"]):
				continue
			var item := _item(
				"march:%s:%s" % [src_id, dst_id],
				"march",
				"行军 %s→%s" % [src["name"], dst["name"]],
				"把兵调到%s，留 1 人守%s。耗粮 %d。" % [dst["name"], src["name"], cost],
				true
			)
			item["src"] = src_id
			item["dst"] = dst_id
			item["sort"] = [int(src["troops"]) - int(dst["troops"]), 0 if far else 1, -_ord(src_id), -_ord(dst_id)]
			found.append(item)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_desc(a["sort"], b["sort"])
	)
	return found


static func _holds(campaign: Node) -> Array[Dictionary]:
	var best := ""
	var best_troops := -1
	for id in _ming_ids(campaign):
		var troops := int(campaign.city(id)["troops"])
		if troops > best_troops or (troops == best_troops and (best == "" or id < best)):
			best = id
			best_troops = troops
	if best == "":
		return []
	var info: Dictionary = campaign.city(best)
	var item := _item(
		"hold:%s" % best,
		"hold",
		"固守 %s" % info["name"],
		"这个回合%s更难被打下，人不挪窝，也不耗粮。" % info["name"],
		true
	)
	item["city"] = best
	return [item]


static func _civils(campaign: Node, grain_low: bool) -> Array[Dictionary]:
	if bool(campaign.civil_done):
		return []
	# 民心到黄线或红线就不再推荐征粮，改推发帑或其他不伤民心的内政。银两到黄线也不再推荐花钱。
	var morale_low := int(campaign.morale) <= 25
	var silver_tight := int(campaign.silver) <= 10
	var found: Array[Dictionary] = []
	if not morale_low:
		var levy_reason := "粮草 %+d，民心 %+d。" % [Baseline.LEVY_GRAIN, -Baseline.LEVY_MORALE]
		if grain_low:
			levy_reason = "粮草不够出兵（行军至少要 %d）。先征粮：粮草 %+d，民心 %+d。" % [GRAIN_SORTIE, Baseline.LEVY_GRAIN, -Baseline.LEVY_MORALE]
		found.append(_item("levy", "levy", "征粮", levy_reason, true))
	var train := _train_item(campaign)
	var spend: Dictionary = {}
	if not silver_tight and int(campaign.silver) >= Baseline.SPEND_SILVER:
		spend = _item(
			"spend",
			"spend",
			"发帑",
			"银两 -%d，民心 %+d。" % [Baseline.SPEND_SILVER, Baseline.SPEND_MORALE],
			true
		)
	if morale_low:
		if not spend.is_empty():
			spend["reason"] = "民心告急，先安民。银两 -%d，民心 %+d。" % [Baseline.SPEND_SILVER, Baseline.SPEND_MORALE]
			found.append(spend)
		if not silver_tight and not train.is_empty():
			found.append(train)
		return found
	if not silver_tight and not train.is_empty():
		found.append(train)
	if not spend.is_empty():
		found.append(spend)
	return found


static func _train_item(campaign: Node) -> Dictionary:
	var host := ""
	var host_troops := -1
	for id in _ming_ids(campaign):
		var troops := int(campaign.city(id)["troops"])
		if troops > host_troops or (troops == host_troops and (host == "" or id < host)):
			host = id
			host_troops = troops
	if host == "" or int(campaign.silver) < Baseline.TRAIN_SILVER or int(campaign.grain) < Baseline.TRAIN_GRAIN:
		return {}
	var info: Dictionary = campaign.city(host)
	var train := _item(
		"train:%s" % host,
		"train",
		"练兵 %s" % info["name"],
		"%s兵力 %+d。耗银 %d、粮 %d。" % [info["name"], Baseline.TRAIN_TROOPS, Baseline.TRAIN_SILVER, Baseline.TRAIN_GRAIN],
		true
	)
	train["city"] = host
	return train


static func _ming_ids(campaign: Node) -> Array[String]:
	var ids: Array[String] = []
	for city in Baseline.CITIES:
		var id := str(city["id"])
		if str(campaign.city(id)["faction"]) == "明":
			ids.append(id)
	return ids


static func _take(into: Array[Dictionary], src: Array[Dictionary], count: int) -> void:
	var added := 0
	for item in src:
		if added >= count:
			return
		var seen := false
		for have in into:
			if str(have["id"]) == str(item["id"]):
				seen = true
				break
		if seen:
			continue
		into.append(item)
		added += 1


static func _item(id: String, kind: String, title: String, reason: String, executable: bool) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"title": title,
		"reason": reason,
		"executable": executable,
	}


static func _ord(id: String) -> int:
	match id:
		"C1":
			return 1
		"C2":
			return 2
		"C3":
			return 3
		"C4":
			return 4
		"C5":
			return 5
		"C6":
			return 6
		_:
			return 9


static func _sort_desc(a: Array, b: Array) -> bool:
	var n := mini(a.size(), b.size())
	for i in n:
		if float(a[i]) == float(b[i]):
			continue
		return float(a[i]) > float(b[i])
	return false


static func self_pick() -> bool:
	if not FileAccess.file_exists(PREF_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREF_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return bool(parsed.get("self_pick", false))


static func set_self_pick(on: bool) -> void:
	var file := FileAccess.open(PREF_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"self_pick": on}))


static func head_line(campaign: Node) -> String:
	var aim := best_ending(campaign)
	if aim == "甲":
		return "照★走，最好可得：甲"
	return "当前最好结局：%s" % _name(aim)


static func best_ending(campaign: Node) -> String:
	if _jia_open(campaign):
		return "甲"
	if _yi_open(campaign):
		return "乙"
	if _ding_likely(campaign) and not _can_leave_ding(campaign):
		return "丁"
	return "丙"


static func story_star(campaign: Node, which: String) -> Dictionary:
	var aim := best_ending(campaign)
	match which:
		"s1":
			if aim == "甲":
				return _star("B", "先重辽东", "先重辽东并结交袁。辽东与世界线才够得到甲。", aim)
			if int(campaign.liaodong) < 40 and int(campaign.morale) >= 35:
				return _star("B", "先重辽东", "当前最好结局：%s。先把辽东稳固补上去。" % _name(aim), aim)
			return _star("C", "先安民", "当前最好结局：%s。先安民，民心 +10，更容易续命。" % _name(aim), aim)
		"s2":
			if aim == "甲":
				return _star("C", "复辽职", "复辽职。辽东 +12，世界线 +30，袁留在前线。处死或下狱都走不到甲。", aim)
			return _star("C", "复辽职", "当前最好结局：%s。不要处死袁。复辽职能把辽东稳固拉回来。" % _name(aim), aim)
		"s3":
			if aim == "甲" and int(campaign.liaodong) >= 55 and int(campaign.pressure) <= 45:
				return _star("A", "倾国勤王", "倾国勤王。辽东与压力都够，勤王成功就能把压力压到甲的线内。", aim)
			if int(campaign.liaodong) < 40 or int(campaign.morale) < 45:
				return _star("B", "固守以拖待变", "当前最好结局：%s。固守以拖待变，民心与辽东都会升一点。" % _name(aim), aim)
			return _star("B", "固守以拖待变", "当前最好结局：%s。这一步把局面留在续命上。" % _name(aim), aim)
		_:
			return _star("", "", "没有这场剧情。", aim)


static func present_story_star(which: String, campaign: Node, banner: Label, buttons: Array) -> void:
	var star := story_star(campaign, which)
	if banner != null:
		banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner.text = "★推荐 %s %s。%s" % [str(star.get("choice", "")), str(star.get("title", "")), str(star.get("reason", ""))]
	var choice := str(star.get("choice", ""))
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		var id := str(button.get_meta("choice_id", ""))
		var base := str(button.get_meta("base_text", ""))
		if base == "":
			base = button.text.trim_prefix("★ ")
			button.set_meta("base_text", base)
		if id == choice:
			button.text = "★ " + base
		else:
			button.text = base


static func _star(choice: String, title: String, reason: String, aim: String) -> Dictionary:
	return {"choice": choice, "title": title, "reason": reason, "aim": aim}


static func _name(ending: String) -> String:
	match ending:
		"甲":
			return "甲"
		"乙":
			return "乙"
		"丁":
			return "丁"
		_:
			return "丙"


static func _mark_best(campaign: Node, recs: Array[Dictionary]) -> Array[Dictionary]:
	var aim := best_ending(campaign)
	var pool: Array[Dictionary] = []
	for item in recs:
		if bool(item.get("executable", false)):
			pool.append(item)
	var extra := _recovery_action(campaign, aim)
	if not extra.is_empty() and aim != "甲":
		var seen := false
		for item in pool:
			if str(item.get("id", "")) == str(extra.get("id", "")):
				seen = true
				break
		if not seen and not pool.is_empty() and str(pool[0].get("kind", "")) != "end_turn":
			if recs.size() >= 3:
				recs[recs.size() - 1] = extra
			else:
				recs.append(extra)
	pool.clear()
	for item in recs:
		if bool(item.get("executable", false)):
			pool.append(item)
	var best_id := ""
	var best_score := -1.0e18
	for item in pool:
		var score := _value_of(campaign, item, aim)
		if score > best_score:
			best_score = score
			best_id = str(item.get("id", ""))
	for item in recs:
		var chosen := best_id != "" and str(item.get("id", "")) == best_id
		item["best"] = chosen
		item["aim"] = aim
		if chosen:
			item["outlook"] = _outlook(campaign, item, aim)
	return recs


static func _recovery_action(campaign: Node, aim: String) -> Dictionary:
	if aim == "甲" or bool(campaign.main_done) or bool(campaign.civil_done) or bool(campaign.settled):
		return {}
	if str(campaign.pending_story) != "":
		return {}
	if aim == "乙" and int(campaign.morale) < 45 and int(campaign.liaodong) < 40 and int(campaign.silver) > 10 and int(campaign.silver) >= Baseline.SPEND_SILVER:
		return _item("spend", "spend", "发帑", "银两 -%d，民心 %+d。这样才续得上命。" % [Baseline.SPEND_SILVER, Baseline.SPEND_MORALE], true)
	return {}


static func _value_of(campaign: Node, action: Dictionary, aim: String) -> float:
	var ghost := _clone(campaign)
	if ghost == null:
		return -1.0e18
	var result: Dictionary = execute(ghost, action)
	var score := -1.0e18
	if bool(result.get("ok", false)):
		score = _state_value(ghost, aim)
	ghost.free()
	return score


static func _outlook(campaign: Node, action: Dictionary, aim: String) -> String:
	var ghost := _clone(campaign)
	if ghost == null:
		return ""
	var result: Dictionary = execute(ghost, action)
	var text := str(result.get("message", ""))
	if bool(result.get("ok", false)):
		var lead := "这一步之后：银两 %d，粮草 %d，民心 %d，辽东稳固 %d，后金压力 %d，世界线 %d。" % [int(ghost.silver), int(ghost.grain), int(ghost.morale), int(ghost.liaodong), int(ghost.pressure), int(ghost.worldline)]
		if str(ghost.pending_story) != "":
			lead += "接着要你自己选剧情，画面上有 ★推荐。"
		if aim == "甲":
			text = "朝甲走。" + lead
		else:
			text = "当前最好结局：%s。甲已经走不到。%s" % [_name(aim), lead]
	ghost.free()
	return text


static func _state_value(campaign: Node, aim: String) -> float:
	var now := str(campaign.resolve_ending())
	var rank := 0.0
	match now:
		"甲":
			rank = 5000.0
		"乙":
			rank = 3000.0
		"丙":
			rank = 800.0
		_:
			rank = 0.0
	var prog := minf(float(campaign.liaodong), 90.0) * 4.0
	prog += maxf(0.0, 70.0 - float(campaign.pressure)) * 5.0
	prog += minf(float(campaign.worldline), 60.0) * 3.0
	prog += minf(float(campaign.morale), 80.0)
	prog += minf(float(campaign.silver), 50.0) * 0.3
	if str(campaign.city("C6")["faction"]) == "明":
		prog += 180.0
	if str(campaign.city("C4")["faction"]) == "明":
		prog += 40.0
	if str(campaign.yuan_status) == "已死":
		prog -= 500.0
	elif str(campaign.yuan_status) == "前线可用":
		prog += 30.0
	if aim == "甲" and now != "甲":
		prog += 20.0
	return rank + prog


static func _clone(campaign: Node) -> Node:
	var ghost: Node = load("res://scripts/campaign_state.gd").new()
	ghost.reset()
	if not ghost.apply_snapshot(campaign.snapshot()):
		ghost.free()
		return null
	return ghost


static func _jia_open(campaign: Node) -> bool:
	if str(campaign.city("C1")["faction"]) != "明":
		return false
	if str(campaign.yuan_status) == "已死":
		return false
	if bool(campaign.s2_done) and str(campaign.s2_choice) == "A":
		return false
	var world := int(campaign.worldline)
	if not bool(campaign.s1_done):
		world += 10
	if not bool(campaign.s2_done):
		world += 30
	if not bool(campaign.s3_done):
		world += 10
	if world < 35:
		return false
	var liao := int(campaign.liaodong)
	if not bool(campaign.s1_done):
		liao += 8
	if not bool(campaign.s2_done):
		liao += 12
	if _front_win(campaign):
		liao += 4
	if liao < 60:
		return false
	var pressure := int(campaign.pressure)
	var drop := 0
	var win_now := _any_win(campaign)
	var during_s3 := str(campaign.pending_story) == "s3"
	if win_now and not during_s3:
		drop += 8
	var liao_now := liao
	if not bool(campaign.s3_done) and not during_s3 and liao_now >= 55 and pressure - drop <= 45:
		drop += 8
	elif during_s3 and int(campaign.liaodong) >= 55 and int(campaign.pressure) <= 45:
		drop += 8
	if win_now and during_s3:
		drop += 8
	if pressure - drop > 40:
		return false
	return true


static func _yi_open(campaign: Node) -> bool:
	if str(campaign.city("C1")["faction"]) != "明":
		return false
	if int(campaign.liaodong) >= 40 or int(campaign.morale) >= 45:
		return true
	var liao := int(campaign.liaodong)
	if not bool(campaign.s2_done):
		liao += 12
	if not bool(campaign.s1_done):
		liao += 8
	if liao >= 40:
		return true
	var morale := int(campaign.morale)
	if not bool(campaign.s1_done):
		morale += 10
	if not bool(campaign.s3_done):
		morale += 6
	var turns_left := maxi(0, Baseline.PLAY_TURNS - int(campaign.turn))
	if int(campaign.silver) >= Baseline.SPEND_SILVER:
		morale += mini(turns_left, int(campaign.silver) / Baseline.SPEND_SILVER) * Baseline.SPEND_MORALE
	return morale >= 45


static func _ding_likely(campaign: Node) -> bool:
	return int(campaign.morale) <= 15 or int(campaign.silver) <= 0


static func _can_leave_ding(campaign: Node) -> bool:
	if str(campaign.city("C1")["faction"]) == "明" and (int(campaign.liaodong) >= 40 or int(campaign.morale) >= 45):
		return true
	return _yi_open(campaign)


static func _any_win(campaign: Node) -> bool:
	if bool(campaign.main_done):
		return false
	for src_id in _ming_ids(campaign):
		if int(campaign.city(src_id)["troops"]) < 2:
			continue
		for hop in campaign.neighbors_of(src_id):
			var dst_id := str(hop["id"])
			if str(campaign.city(dst_id)["faction"]) == "明":
				continue
			var preview: Dictionary = campaign.preview_battle(src_id, dst_id)
			if bool(preview.get("ok", false)) and str(preview.get("outcome", "")) == "win":
				return true
	return false


static func _front_win(campaign: Node) -> bool:
	if bool(campaign.main_done):
		return false
	for src_id in _ming_ids(campaign):
		if int(campaign.city(src_id)["troops"]) < 2:
			continue
		for hop in campaign.neighbors_of(src_id):
			var dst_id := str(hop["id"])
			if dst_id != "C4" and dst_id != "C6":
				continue
			if str(campaign.city(dst_id)["faction"]) == "明":
				continue
			var preview: Dictionary = campaign.preview_battle(src_id, dst_id)
			if bool(preview.get("ok", false)) and str(preview.get("outcome", "")) == "win":
				return true
	return false
