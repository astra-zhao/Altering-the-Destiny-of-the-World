extends RefCounted
## 局势推荐。只从行军、攻城、固守、征粮、发帑、练兵里挑，外加「行动点用完时的下一回合」。
## 同一局面同一输出。粮草不够不推荐出兵；打不赢不推荐攻城。
## S1/S2/S3 的选项不在这里定，execute 也不会写回剧情。

const Baseline := preload("res://data/campaign_baseline.gd")

## 低于这个粮草就不出兵（行军、攻城都不推荐）。行军近邻正好要 3。
const GRAIN_SORTIE := 3


static func recommend(campaign: Node) -> Array[Dictionary]:
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
	if bool(campaign.s3_done) or int(campaign.turn) >= Baseline.TURN_LIMIT:
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
	var levy_reason := "粮草 %+d，民心 %+d。" % [Baseline.LEVY_GRAIN, -Baseline.LEVY_MORALE]
	if grain_low:
		levy_reason = "粮草不够出兵（行军至少要 %d）。先征粮：粮草 %+d，民心 %+d。" % [GRAIN_SORTIE, Baseline.LEVY_GRAIN, -Baseline.LEVY_MORALE]
	var levy := _item("levy", "levy", "征粮", levy_reason, true)
	var found: Array[Dictionary] = [levy]
	var host := ""
	var host_troops := -1
	for id in _ming_ids(campaign):
		var troops := int(campaign.city(id)["troops"])
		if troops > host_troops or (troops == host_troops and (host == "" or id < host)):
			host = id
			host_troops = troops
	if host != "" and int(campaign.silver) >= Baseline.TRAIN_SILVER and int(campaign.grain) >= Baseline.TRAIN_GRAIN:
		var info: Dictionary = campaign.city(host)
		var train := _item(
			"train:%s" % host,
			"train",
			"练兵 %s" % info["name"],
			"%s兵力 %+d。耗银 %d、粮 %d。" % [info["name"], Baseline.TRAIN_TROOPS, Baseline.TRAIN_SILVER, Baseline.TRAIN_GRAIN],
			true
		)
		train["city"] = host
		found.append(train)
	if int(campaign.silver) >= Baseline.SPEND_SILVER:
		found.append(_item(
			"spend",
			"spend",
			"发帑",
			"银两 -%d，民心 %+d。" % [Baseline.SPEND_SILVER, Baseline.SPEND_MORALE],
			true
		))
	if grain_low:
		return found
	# 粮够时，内政仍保留征粮，但练兵放在发帑前面与否不影响「至少一条内政」。顺序固定：征粮、练兵、发帑。
	return found


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
