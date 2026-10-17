extends Node
## M2 局面。M1 的回合与简战仍在；这里加上 S2/S3 写回、结局优先级、存读档。
## autoload 名：Campaign。切场景后数字仍在。

const Baseline := preload("res://data/campaign_baseline.gd")

var turn := 1
var silver := 40
var grain := 45
var morale := 35
var liaodong := 40
var pressure := 50
var worldline := 0
var yuan_status := "前线可用"
var befriended_yuan := false
var yuan_city := ""
var hold_city := ""
var main_done := false
var civil_done := false
var settled := false
var s1_done := false
var s2_done := false
var s3_done := false
var s1_choice := ""
var s2_choice := ""
var s3_choice := ""
var held_ningyuan := false
var loyalist_success := false
var pending_story := ""
var ending_id := ""
var skip_ending_scene := false
var log_text := "第 1 回合。点城，再选主行动。"
var cities: Dictionary = {}

const SAVE_PATH := "user://campaign_m2.json"


func _ready() -> void:
	reset()


func reset() -> void:
	turn = Baseline.TURN
	silver = 40
	grain = 45
	morale = 35
	liaodong = 40
	pressure = 50
	worldline = 0
	yuan_status = Baseline.YUAN_DEFAULT
	befriended_yuan = false
	yuan_city = Baseline.YUAN_CITY
	hold_city = ""
	main_done = false
	civil_done = false
	settled = false
	s1_done = false
	s2_done = false
	s3_done = false
	s1_choice = ""
	s2_choice = ""
	s3_choice = ""
	held_ningyuan = false
	loyalist_success = false
	pending_story = ""
	ending_id = ""
	skip_ending_scene = false
	log_text = "第 1 回合。点城，再选主行动。"
	cities.clear()
	for src in Baseline.CITIES:
		cities[str(src["id"])] = {
			"id": str(src["id"]),
			"name": str(src["name"]),
			"note": str(src["note"]),
			"faction": str(src["faction"]),
			"troops": int(src["troops"]),
			"terrain_pct": int(src["terrain_pct"]),
		}
	if str(city("C4")["faction"]) == "明":
		held_ningyuan = true


func city(id: String) -> Dictionary:
	return cities.get(id, {})


func display_owner(id: String) -> String:
	var info := city(id)
	if info.is_empty():
		return ""
	if str(info["faction"]) == "明":
		return "明"
	if id == "C6":
		return "争议"
	return "后金"


func neighbors_of(id: String) -> Array:
	var found: Array = []
	for route in Baseline.ROUTES:
		var other := ""
		if str(route["a"]) == id:
			other = str(route["b"])
		elif str(route["b"]) == id:
			other = str(route["a"])
		else:
			continue
		found.append({"id": other, "far": bool(route["far"])})
	return found


func route_far(a: String, b: String) -> bool:
	for hop in neighbors_of(a):
		if str(hop["id"]) == b:
			return bool(hop["far"])
	return false


func is_adjacent(a: String, b: String) -> bool:
	for hop in neighbors_of(a):
		if str(hop["id"]) == b:
			return true
	return false


func march(src_id: String, dst_id: String) -> Dictionary:
	if settled or main_done:
		return _fail("本回合的主行动已经用过。")
	var src := city(src_id)
	var dst := city(dst_id)
	if src.is_empty() or dst.is_empty():
		return _fail("城池不存在。")
	if str(src["faction"]) != "明" or str(dst["faction"]) != "明":
		return _fail("行军只能在相邻的明军城之间。")
	if not is_adjacent(src_id, dst_id):
		return _fail("两城不相邻。")
	if int(src["troops"]) < 2:
		return _fail("%s 至少要留下 1 兵力，无法出兵。" % src["name"])
	var far := route_far(src_id, dst_id)
	var cost := Baseline.MARCH_GRAIN_FAR if far else Baseline.MARCH_GRAIN
	if grain < cost:
		return _fail("粮草不足（需要 %d）。" % cost)
	var moved := int(src["troops"]) - 1
	grain -= cost
	src["troops"] = 1
	dst["troops"] = int(dst["troops"]) + moved
	if yuan_city == src_id:
		yuan_city = dst_id
	main_done = true
	var far_note := "，远邻" if far else ""
	return _ok("行军 %s → %s，移兵 %d，耗粮 %d%s。" % [src["name"], dst["name"], moved, cost, far_note])


func hold(city_id: String) -> Dictionary:
	if settled or main_done:
		return _fail("本回合的主行动已经用过。")
	var info := city(city_id)
	if info.is_empty() or str(info["faction"]) != "明":
		return _fail("固守要选一座明军城。")
	hold_city = city_id
	main_done = true
	return _ok("固守 %s。本回合该城防御 ×1.3。" % info["name"])


func preview_battle(src_id: String, dst_id: String) -> Dictionary:
	return _resolve(src_id, dst_id, false, true)


func commit_player_battle(src_id: String, dst_id: String) -> Dictionary:
	if settled or main_done:
		return _fail("本回合的主行动已经用过。")
	var result := _resolve(src_id, dst_id, true, true)
	if bool(result["ok"]):
		main_done = true
	return result


func civil(kind: String, city_id: String) -> Dictionary:
	if settled or civil_done:
		return _fail("本回合的内政已经用过。")
	match kind:
		"levy":
			grain += Baseline.LEVY_GRAIN
			morale = maxi(0, morale - Baseline.LEVY_MORALE)
			civil_done = true
			return _ok("征粮：粮草 %+d，民心 %+d。" % [Baseline.LEVY_GRAIN, -Baseline.LEVY_MORALE])
		"spend":
			if silver < Baseline.SPEND_SILVER:
				return _fail("银两不足（需要 %d）。" % Baseline.SPEND_SILVER)
			silver -= Baseline.SPEND_SILVER
			morale = mini(100, morale + Baseline.SPEND_MORALE)
			civil_done = true
			return _ok("发帑：银两 %+d，民心 %+d。" % [-Baseline.SPEND_SILVER, Baseline.SPEND_MORALE])
		"train":
			var info := city(city_id)
			if info.is_empty() or str(info["faction"]) != "明":
				return _fail("练兵要先点一座明军城。")
			if silver < Baseline.TRAIN_SILVER or grain < Baseline.TRAIN_GRAIN:
				return _fail("练兵需要银 %d、粮 %d。" % [Baseline.TRAIN_SILVER, Baseline.TRAIN_GRAIN])
			silver -= Baseline.TRAIN_SILVER
			grain -= Baseline.TRAIN_GRAIN
			info["troops"] = int(info["troops"]) + Baseline.TRAIN_TROOPS
			civil_done = true
			return _ok("练兵 %s：兵力 %+d，银 %+d，粮 %+d。" % [info["name"], Baseline.TRAIN_TROOPS, -Baseline.TRAIN_SILVER, -Baseline.TRAIN_GRAIN])
		"skip":
			civil_done = true
			return _ok("内政跳过。")
		_:
			return _fail("没有这项内政。")


func end_turn() -> Dictionary:
	if settled:
		return {"ok": false, "goto": "settle", "message": log_text}
	if not main_done:
		return _fail("先完成主行动（行军、攻城或固守），再结束回合。")
	if not civil_done:
		civil("skip", "")
	var ai_line := _run_ai()
	hold_city = ""
	if s3_done:
		return _begin_settlement("%s终局前夜之后进入结算。" % ai_line)
	if turn >= Baseline.TURN_LIMIT:
		return _begin_settlement("%s第 %d 回合结束。超时，按当前局面结算，不粉饰。" % [ai_line, Baseline.TURN_LIMIT])
	turn += 1
	main_done = false
	civil_done = false
	log_text = "%s进入第 %d 回合。" % [ai_line, turn]
	if not s1_done and turn <= 3:
		pending_story = "s1"
		return {"ok": true, "goto": "s1", "message": log_text}
	var s2_why := _s2_reason()
	if s2_why != "":
		pending_story = "s2"
		log_text += s2_why + "。"
		return {"ok": true, "goto": "s2", "message": log_text}
	if _s3_ready():
		pending_story = "s3"
		log_text += "京师危机。"
		return {"ok": true, "goto": "s3", "message": log_text}
	return {"ok": true, "goto": "map", "message": log_text}


func apply_s1(choice: String) -> Dictionary:
	if s1_done:
		return _fail("登基夜已经写回。")
	match choice:
		"A":
			silver += 5
			worldline += 5
			s1_choice = "A"
			s1_done = true
			pending_story = ""
			return _ok("登基夜 · 先稳朝堂：银两 +5，世界线 +5。")
		"B":
			liaodong += 8
			silver -= 5
			befriended_yuan = true
			worldline += 10
			s1_choice = "B"
			s1_done = true
			pending_story = ""
			return _ok("登基夜 · 先重辽东：辽东稳固 +8，银两 -5，结交袁，世界线 +10。")
		"C":
			morale += 10
			grain -= 5
			worldline += 5
			s1_choice = "C"
			s1_done = true
			pending_story = ""
			return _ok("登基夜 · 先安民：民心 +10，粮草 -5，世界线 +5。")
		_:
			return _fail("没有这个抉择。")


func summary_lines() -> PackedStringArray:
	return PackedStringArray([
		"回合 %d / %d" % [turn, Baseline.TURN_LIMIT],
		"银两 %d　粮草 %d　民心 %d" % [silver, grain, morale],
		"辽东稳固 %d　后金压力 %d　世界线 %d" % [liaodong, pressure, worldline],
		"袁崇焕 %s　结交袁 %s　勤王 %s" % [yuan_status, "是" if befriended_yuan else "否", "成功" if loyalist_success else "否"],
		"结局 %s" % (ending_title() if ending_id != "" else "未定"),
	])


func apply_s2(choice: String) -> Dictionary:
	if s2_done:
		return _fail("袁崇焕生死已经写回。")
	match choice:
		"A":
			yuan_status = "已死"
			yuan_city = ""
			liaodong -= 20
			pressure += 15
			worldline += 5
			s2_choice = "A"
		"B":
			yuan_status = "闲置"
			yuan_city = ""
			liaodong -= 8
			worldline += 15
			s2_choice = "B"
		"C":
			yuan_status = "前线可用"
			_station_yuan_front()
			liaodong += 12
			silver -= 10
			morale -= 5
			worldline += 30
			s2_choice = "C"
		"D":
			if not befriended_yuan:
				return _fail("尚未结交袁，不能调京营。")
			yuan_status = "京营"
			yuan_city = "C1" if str(city("C1")["faction"]) == "明" else ""
			liaodong += 4
			worldline += 20
			s2_choice = "D"
		_:
			return _fail("没有这个抉择。")
	s2_done = true
	pending_story = ""
	var line := "袁崇焕生死 · %s：袁=%s，辽东 %d，压力 %d，世界线 %d。" % [s2_choice, yuan_status, liaodong, pressure, worldline]
	return _ok(line)


func apply_s3(choice: String) -> Dictionary:
	if s3_done:
		return _fail("京师危机已经写回。")
	match choice:
		"A":
			s3_choice = "A"
			if liaodong >= 55 and pressure <= 45:
				loyalist_success = true
				pressure = maxi(0, pressure - 8)
				worldline += 5
			else:
				loyalist_success = false
				worldline += 2
				morale -= 3
		"B":
			s3_choice = "B"
			morale += 6
			liaodong += 3
			worldline += 4
		"C":
			s3_choice = "C"
			silver += 20
			morale -= 8
			worldline += 10
		_:
			return _fail("没有这个抉择。")
	s3_done = true
	pending_story = ""
	return _ok(_s3_line())


func resolve_ending() -> String:
	var capital_ming := str(city("C1")["faction"]) == "明"
	if yuan_status != "已死" and liaodong >= 60 and pressure <= 40 and worldline >= 35 and capital_ming:
		return "甲"
	if capital_ming and (liaodong >= 40 or morale >= 45):
		return "乙"
	if morale <= 15 or silver <= 0:
		return "丁"
	return "丙"


func ending_title() -> String:
	match ending_id:
		"甲":
			return "甲 · 中兴微光"
		"乙":
			return "乙 · 残局续命"
		"丁":
			return "丁 · 另途崩解"
		"丙":
			return "丙 · 史实沉响"
		_:
			return "未定"


func rewrite_lines() -> PackedStringArray:
	var first := "登基夜没有写回。"
	match s1_choice:
		"A":
			first = "登基夜先稳了朝堂。"
		"B":
			first = "登基夜点名袁崇焕，结交袁。"
		"C":
			first = "登基夜先安了民。"
	var second := "袁崇焕生死未决。"
	match s2_choice:
		"A":
			second = "袁崇焕被处死，辽东震动。"
		"B":
			second = "袁崇焕下狱，闲置不用。"
		"C":
			second = "袁崇焕复任辽东。"
		"D":
			second = "袁崇焕调入京营。"
	var third := "终局前夜没有到来，按当前局面收束。"
	if s3_choice == "A" and loyalist_success:
		third = "终局前夜倾国勤王，勤王成功。"
	elif s3_choice == "A":
		third = "终局前夜号召勤王，未能成功。"
	elif s3_choice == "B":
		third = "终局前夜选择固守拖延。"
	elif s3_choice == "C":
		third = "终局前夜开海税补饷。"
	return PackedStringArray([first, second, third])


func capital_threatened() -> bool:
	if str(city("C1")["faction"]) != "明":
		return true
	for hop in neighbors_of("C1"):
		if str(city(str(hop["id"]))["faction"]) == "后金":
			return true
	return false


func save_game() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return _fail("存档写不进去。")
	file.store_string(JSON.stringify(snapshot()))
	return _ok("已存档。")


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _fail("没有存档。")
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _fail("存档读不出来。")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("存档损坏。")
	if not apply_snapshot(parsed):
		return _fail("存档缺字段。")
	skip_ending_scene = false
	return _ok("已读档。第 %d 回合。" % turn)


func snapshot() -> Dictionary:
	var city_rows: Array = []
	for id in ["C1", "C2", "C3", "C4", "C5", "C6"]:
		var info := city(id)
		city_rows.append({
			"id": id,
			"faction": str(info["faction"]),
			"troops": int(info["troops"]),
		})
	return {
		"version": 2,
		"turn": turn,
		"silver": silver,
		"grain": grain,
		"morale": morale,
		"liaodong": liaodong,
		"pressure": pressure,
		"worldline": worldline,
		"yuan_status": yuan_status,
		"befriended_yuan": befriended_yuan,
		"yuan_city": yuan_city,
		"hold_city": hold_city,
		"main_done": main_done,
		"civil_done": civil_done,
		"settled": settled,
		"s1_done": s1_done,
		"s2_done": s2_done,
		"s3_done": s3_done,
		"s1_choice": s1_choice,
		"s2_choice": s2_choice,
		"s3_choice": s3_choice,
		"held_ningyuan": held_ningyuan,
		"loyalist_success": loyalist_success,
		"pending_story": pending_story,
		"ending_id": ending_id,
		"log_text": log_text,
		"cities": city_rows,
	}


func apply_snapshot(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 2 or not data.has("cities"):
		return false
	turn = int(data["turn"])
	silver = int(data["silver"])
	grain = int(data["grain"])
	morale = int(data["morale"])
	liaodong = int(data["liaodong"])
	pressure = int(data["pressure"])
	worldline = int(data["worldline"])
	yuan_status = str(data["yuan_status"])
	befriended_yuan = bool(data["befriended_yuan"])
	yuan_city = str(data["yuan_city"])
	hold_city = str(data["hold_city"])
	main_done = bool(data["main_done"])
	civil_done = bool(data["civil_done"])
	settled = bool(data["settled"])
	s1_done = bool(data["s1_done"])
	s2_done = bool(data["s2_done"])
	s3_done = bool(data["s3_done"])
	s1_choice = str(data["s1_choice"])
	s2_choice = str(data["s2_choice"])
	s3_choice = str(data["s3_choice"])
	held_ningyuan = bool(data["held_ningyuan"])
	loyalist_success = bool(data["loyalist_success"])
	pending_story = str(data["pending_story"])
	ending_id = str(data["ending_id"])
	log_text = str(data["log_text"])
	for row in data["cities"]:
		var info := city(str(row["id"]))
		if info.is_empty():
			return false
		info["faction"] = str(row["faction"])
		info["troops"] = int(row["troops"])
	return true


func _begin_settlement(prefix: String) -> Dictionary:
	settled = true
	main_done = true
	civil_done = true
	pending_story = ""
	ending_id = resolve_ending()
	log_text = "%s%s" % [prefix, ending_title()]
	return {"ok": true, "goto": "ending", "message": log_text}


func _s2_reason() -> String:
	if s2_done or turn < 4 or turn > 6:
		return ""
	if held_ningyuan:
		return "曾控制宁远"
	if liaodong <= 35:
		return "辽东告急"
	if turn == 6:
		return "边报"
	return ""


func _s3_ready() -> bool:
	if s3_done or not s1_done:
		return false
	if not s2_done and turn <= 6:
		return false
	return turn >= 8 or capital_threatened()


func _station_yuan_front() -> void:
	for id in ["C4", "C6", "C2", "C3", "C1"]:
		if str(city(id)["faction"]) == "明":
			yuan_city = id
			return
	yuan_city = ""


func _s3_line() -> String:
	if s3_choice == "A" and loyalist_success:
		return "京师危机 · 倾国勤王成功：后金压力 -8，世界线 +5。"
	if s3_choice == "A":
		return "京师危机 · 勤王未成：世界线 +2，民心 -3。"
	if s3_choice == "B":
		return "京师危机 · 固守以拖待变：民心 +6，辽东 +3，世界线 +4。"
	return "京师危机 · 开海税：银两 +20，民心 -8，世界线 +10。"


func _run_ai() -> String:
	if pressure >= 60:
		var push := _try_push()
		if push != "":
			return push
		return _consolidate("后金无处再推进，改为巩固。")
	# 压力未到 60：回合+压力为偶数则巩固，否则按兵。长期约一半回合会动。
	if (turn + pressure) % 2 == 0:
		return _consolidate("")
	return "后金按兵不动。"


func _try_push() -> String:
	var targets: Array[String] = []
	if str(city("C6")["faction"]) != "后金":
		targets.append("C6")
	if str(city("C4")["faction"]) != "后金":
		targets.append("C4")
	for target_id in targets:
		var best := ""
		var best_troops := 1
		for hop in neighbors_of(target_id):
			var src_id := str(hop["id"])
			var src := city(src_id)
			if str(src["faction"]) != "后金":
				continue
			if int(src["troops"]) <= best_troops:
				continue
			best = src_id
			best_troops = int(src["troops"])
		if best == "":
			continue
		var result := _resolve(best, target_id, true, false)
		if bool(result["ok"]):
			return "后金推进：%s" % result["message"]
	return ""


func _consolidate(prefix: String) -> String:
	var host := "C5"
	if str(city(host)["faction"]) != "后金":
		host = ""
		var most := -1
		for id in cities:
			var info: Dictionary = cities[id]
			if str(info["faction"]) != "后金":
				continue
			if int(info["troops"]) > most:
				most = int(info["troops"])
				host = str(id)
	if host == "":
		return "%s后金没有城可增援。" % prefix
	var info := city(host)
	info["troops"] = int(info["troops"]) + Baseline.CONSOLIDATE_TROOPS
	return "%s后金巩固%s，兵力 +%d。" % [prefix, info["name"], Baseline.CONSOLIDATE_TROOPS]


func _resolve(src_id: String, dst_id: String, commit: bool, player_side: bool) -> Dictionary:
	var src := city(src_id)
	var dst := city(dst_id)
	if src.is_empty() or dst.is_empty():
		return _fail("城池不存在。")
	if player_side and str(src["faction"]) != "明":
		return _fail("攻城要从明军城出发。")
	if str(src["faction"]) == str(dst["faction"]):
		return _fail("不能攻打己方城。")
	if not is_adjacent(src_id, dst_id):
		return _fail("只能攻打相邻的城。")
	if int(src["troops"]) < 2:
		return _fail("%s 兵力不足。" % src["name"])
	var sent := int(src["troops"]) - 1
	var defender_before := int(dst["troops"])
	var yuan_bonus := yuan_status == "前线可用" and yuan_city == src_id and str(src["faction"]) == "明"
	var atk_x100 := sent * (Baseline.YUAN_ATK_PCT if yuan_bonus else 100)
	var def_x100 := int(dst["troops"]) * int(dst["terrain_pct"])
	var held := hold_city == dst_id and str(dst["faction"]) == "明"
	if held:
		def_x100 = def_x100 * Baseline.HOLD_PCT / 100
	var outcome := "draw"
	if atk_x100 * 100 >= def_x100 * Baseline.WIN_RATIO_PCT:
		outcome = "win"
	elif atk_x100 * 100 <= def_x100 * Baseline.LOSE_RATIO_PCT:
		outcome = "lose"
	var label := "平两损"
	if outcome == "win":
		label = "胜占城"
	elif outcome == "lose":
		label = "负退回"
	var message := "%s 攻 %s：%s（出兵 %d，守军 %d）。" % [src["name"], dst["name"], label, sent, defender_before]
	if yuan_bonus:
		message += "袁部 ×1.25。"
	if held:
		message += "固守加成。"
	if commit:
		_apply_outcome(src, dst, src_id, dst_id, sent, outcome)
		_log(message)
	return {
		"ok": true,
		"message": message,
		"outcome": outcome,
		"label": label,
		"sent": sent,
		"defender": defender_before,
		"atk_x100": atk_x100,
		"def_x100": def_x100,
		"yuan_bonus": yuan_bonus,
		"held": held,
		"terrain_pct": int(dst["terrain_pct"]),
		"src_name": str(src["name"]),
		"dst_name": str(dst["name"]),
	}


func _apply_outcome(src: Dictionary, dst: Dictionary, src_id: String, dst_id: String, sent: int, outcome: String) -> void:
	var def_troops := int(dst["troops"])
	var src_faction := str(src["faction"])
	var dst_faction := str(dst["faction"])
	if outcome == "win":
		var loss := maxi(1, sent * 25 / 100)
		var remain := maxi(1, sent - loss)
		src["troops"] = 1
		dst["faction"] = str(src["faction"])
		dst["troops"] = remain
		if str(src["faction"]) == "明" and yuan_city == src_id:
			yuan_city = dst_id
		elif str(src["faction"]) == "后金" and yuan_city == dst_id:
			_displace_yuan(dst_id)
		_shift_front(src_faction, dst_faction, dst_id, outcome)
		return
	if outcome == "lose":
		var loss := maxi(1, sent * 50 / 100)
		src["troops"] = 1 + maxi(0, sent - loss)
		var def_loss := maxi(1, def_troops * 15 / 100)
		dst["troops"] = maxi(1, def_troops - def_loss)
		_shift_front(src_faction, dst_faction, dst_id, outcome)
		return
	var atk_loss := maxi(1, sent * 30 / 100)
	src["troops"] = 1 + maxi(0, sent - atk_loss)
	var def_loss := maxi(1, def_troops * 30 / 100)
	dst["troops"] = maxi(1, def_troops - def_loss)
	_shift_front(src_faction, dst_faction, dst_id, outcome)


func _shift_front(src_faction: String, dst_faction: String, dst_id: String, outcome: String) -> void:
	if str(city("C4")["faction"]) == "明":
		held_ningyuan = true
	if src_faction == "明" and dst_faction == "后金":
		if outcome == "win":
			pressure = maxi(0, pressure - 8)
			if dst_id == "C4" or dst_id == "C6":
				liaodong += 4
		elif outcome == "lose":
			pressure += 6
			liaodong -= 3
		else:
			pressure += 2
	elif src_faction == "后金" and dst_faction == "明" and outcome == "win":
		pressure += 8
		if dst_id == "C4" or dst_id == "C6":
			liaodong -= 6


func _displace_yuan(from_id: String) -> void:
	if yuan_city != from_id:
		return
	for id in ["C1", "C2", "C3", "C4", "C6", "C5"]:
		if id == from_id:
			continue
		if str(city(id)["faction"]) == "明":
			yuan_city = id
			return
	yuan_city = ""


func _ok(message: String) -> Dictionary:
	_log(message)
	return {"ok": true, "message": message}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "goto": "map"}


func _log(message: String) -> void:
	log_text = message
