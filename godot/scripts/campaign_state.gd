extends Node
## M1 局面。大纲 §1 的回合、行军/攻城/固守、内政、简战、后金 AI，以及 S1 写回。
## autoload 名：Campaign。切到登基夜场景后数字仍在。

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
var log_text := "第 1 回合。点城，再选主行动。"
var cities: Dictionary = {}


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
	if turn >= Baseline.TURN_LIMIT:
		settled = true
		main_done = false
		civil_done = false
		log_text = "%s 第 %d 回合结束。超时强制结算（残局/史实占位，不粉饰）。" % [ai_line, Baseline.TURN_LIMIT]
		return {"ok": true, "goto": "settle", "message": log_text}
	turn += 1
	main_done = false
	civil_done = false
	log_text = "%s进入第 %d 回合。" % [ai_line, turn]
	if not s1_done and turn <= 3:
		return {"ok": true, "goto": "s1", "message": log_text}
	return {"ok": true, "goto": "map", "message": log_text}


func apply_s1(choice: String) -> Dictionary:
	if s1_done:
		return _fail("登基夜已经写回。")
	match choice:
		"A":
			silver += 5
			worldline += 5
			s1_done = true
			return _ok("登基夜 · 先稳朝堂：银两 +5，世界线 +5。")
		"B":
			liaodong += 8
			silver -= 5
			befriended_yuan = true
			worldline += 10
			s1_done = true
			return _ok("登基夜 · 先重辽东：辽东稳固 +8，银两 -5，结交袁，世界线 +10。")
		"C":
			morale += 10
			grain -= 5
			worldline += 5
			s1_done = true
			return _ok("登基夜 · 先安民：民心 +10，粮草 -5，世界线 +5。")
		_:
			return _fail("没有这个抉择。")


func summary_lines() -> PackedStringArray:
	return PackedStringArray([
		"回合 %d / %d" % [turn, Baseline.TURN_LIMIT],
		"银两 %d　粮草 %d　民心 %d" % [silver, grain, morale],
		"辽东稳固 %d　后金压力 %d　世界线 %d" % [liaodong, pressure, worldline],
		"袁崇焕 %s　结交袁 %s" % [yuan_status, "是" if befriended_yuan else "否"],
	])


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
		return
	if outcome == "lose":
		var loss := maxi(1, sent * 50 / 100)
		src["troops"] = 1 + maxi(0, sent - loss)
		var def_loss := maxi(1, def_troops * 15 / 100)
		dst["troops"] = maxi(1, def_troops - def_loss)
		return
	var atk_loss := maxi(1, sent * 30 / 100)
	src["troops"] = 1 + maxi(0, sent - atk_loss)
	var def_loss := maxi(1, def_troops * 30 / 100)
	dst["troops"] = maxi(1, def_troops - def_loss)


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
