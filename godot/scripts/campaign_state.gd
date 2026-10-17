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
## 终局结算前、最后一次还能改主意时，帮我选认定的最好结局。失败页用这一个字。
var outlook_before_finale := ""
var skip_ending_scene := false
## 0 点城，1 选行动，2 结束回合，3 已完成。跳过或完成后写入引导标记。
var guide_step := 0
var guide_done := false
var log_text := "第 1 回合。先点一座我方的城。"
var cities: Dictionary = {}

const SAVE_PATH := "user://campaign_m2.json"
const GUIDE_PATH := "user://v03_guide.json"
## 上一幕的鼠标或跳过键还按着时，下一幕先吃掉松开。一次按键只过一段。
var _block_mouse := false
var _block_skip_key := false


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
	outlook_before_finale = ""
	skip_ending_scene = false
	log_text = "第 1 回合。先点一座我方的城。"
	guide_step = 0
	guide_done = false
	_block_mouse = false
	_block_skip_key = false
	if guide_disk_dismissed():
		guide_done = true
		guide_step = 3
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
	# 终局前最后一次还能改主意的局面。结算和 AI 还没写进去。
	if s3_done:
		var advisor = load("res://scripts/advisor.gd")
		outlook_before_finale = str(advisor.best_ending(self))
	if not civil_done:
		civil("skip", "")
	var ai_line := _run_ai()
	hold_city = ""
	if s3_done:
		return _begin_settlement("%s第 %d 回合结束，进入结算。" % [ai_line, turn])
	turn += 1
	main_done = false
	civil_done = false
	log_text = "%s进入第 %d 回合。" % [ai_line, turn]
	# 新局在第 1 回合开始前已经写过登基夜。这里只留给还没写回的旧档（例如第 2 回合 pending 仍是 s1）。
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
		"回合 %d / %d" % [turn, Baseline.PLAY_TURNS],
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
		return _fail("存档不完整，已保持当前局面。")
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
		"version": 3,
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
		"outlook_before_finale": outlook_before_finale,
		"log_text": log_text,
		"guide_step": guide_step,
		"guide_done": guide_done,
		"cities": city_rows,
	}


func apply_snapshot(data: Dictionary) -> bool:
	# 先整份检查，再写入。半截档、缺字段、城池行被截断时直接失败，不改当前局面，也不再按缺失键取值（那会 SCRIPT ERROR）。
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var version: Variant = data.get("version", null)
	if not _is_number(version) or (int(version) != 2 and int(version) != 3):
		return false
	var required: PackedStringArray = PackedStringArray([
		"turn", "silver", "grain", "morale", "liaodong", "pressure", "worldline",
		"yuan_status", "befriended_yuan", "yuan_city", "hold_city",
		"main_done", "civil_done", "settled",
		"s1_done", "s2_done", "s3_done",
		"s1_choice", "s2_choice", "s3_choice",
		"held_ningyuan", "loyalist_success", "pending_story", "ending_id", "log_text",
		"cities",
	])
	for key in required:
		if not data.has(key):
			return false
	var numbers: PackedStringArray = PackedStringArray([
		"turn", "silver", "grain", "morale", "liaodong", "pressure", "worldline",
	])
	for key in numbers:
		if not _is_number(data[key]):
			return false
	var flags: PackedStringArray = PackedStringArray([
		"befriended_yuan", "main_done", "civil_done", "settled",
		"s1_done", "s2_done", "s3_done", "held_ningyuan", "loyalist_success",
	])
	for key in flags:
		if typeof(data[key]) != TYPE_BOOL and not _is_number(data[key]):
			return false
	if typeof(data["cities"]) != TYPE_ARRAY:
		return false
	var rows: Array = data["cities"]
	var parsed: Dictionary = {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			return false
		if not row.has("id") or not row.has("faction") or not row.has("troops"):
			return false
		if not _is_number(row["troops"]):
			return false
		var id := str(row["id"])
		if id == "" or not cities.has(id) or parsed.has(id):
			return false
		var faction := str(row["faction"])
		if faction != "明" and faction != "后金":
			return false
		parsed[id] = {"faction": faction, "troops": maxi(0, int(row["troops"]))}
	if parsed.size() != 6:
		return false
	var next_guide_done := guide_done
	var next_guide_step := guide_step
	if data.has("guide_done") and typeof(data["guide_done"]) == TYPE_BOOL:
		next_guide_done = bool(data["guide_done"])
		next_guide_step = 3 if next_guide_done else 0
		if data.has("guide_step") and _is_number(data["guide_step"]):
			next_guide_step = clampi(int(data["guide_step"]), 0, 3)
	elif data.has("guide_step") and _is_number(data["guide_step"]):
		next_guide_step = clampi(int(data["guide_step"]), 0, 3)
		next_guide_done = next_guide_step >= 3
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
	outlook_before_finale = str(data.get("outlook_before_finale", ""))
	guide_done = next_guide_done
	guide_step = next_guide_step
	# 磁盘标记表示已经跳过或走完。中途存档不能把引导再叫出来。坏标记仍当作没跳过。
	if guide_disk_dismissed():
		guide_done = true
		guide_step = 3
	_clamp_stats()
	for id in parsed:
		var info: Dictionary = cities[id]
		info["faction"] = str(parsed[id]["faction"])
		info["troops"] = int(parsed[id]["troops"])
	_clamp_stats()
	return true


func has_campaign_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## 标题「开始游戏」和结局「再来一局」用。局面回到开局，并记一笔「登基夜还没写」。
func prepare_fresh_campaign() -> Dictionary:
	reset()
	pending_story = "s1"
	return save_game()


## 地图上的「新局」用。不覆盖已经在磁盘上的旧档。
func begin_new_game_in_memory() -> void:
	reset()
	pending_story = "s1"


func resume_scene() -> String:
	if pending_story == "s1":
		return "res://scenes/s1_night.tscn"
	if pending_story == "s2":
		return "res://scenes/s2_yuan.tscn"
	if pending_story == "s3":
		return "res://scenes/s3_crisis.tscn"
	if settled and ending_id != "" and not skip_ending_scene:
		return "res://scenes/ending.tscn"
	return "res://scenes/big_map.tscn"


## 只删战役档和引导标记。音量、帮我选偏好不动。
func clear_campaign_files() -> void:
	_remove_user_file(SAVE_PATH)
	_remove_user_file(GUIDE_PATH)
	guide_done = false
	guide_step = 0


## 只删引导标记。战役里的回合和城池不动，引导进度改成未看过，下次进大地图会再出现。
func reset_guide_record() -> void:
	_remove_user_file(GUIDE_PATH)
	guide_done = false
	guide_step = 0
	_patch_save_guide(false, 0)


func arm_skip_guard() -> void:
	_block_mouse = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_block_skip_key = _skip_key_held()


func release_skip_guard_if_idle() -> void:
	if _block_mouse and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_block_mouse = false
	if _block_skip_key and not _skip_key_held():
		_block_skip_key = false


func swallow_skip_guard(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not _block_mouse:
			return false
		if not mouse.pressed:
			_block_mouse = false
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if not _is_skip_key(key.keycode) or not _block_skip_key:
			return false
		if key.echo or key.pressed:
			return true
		_block_skip_key = false
		return true
	return false


func guide_disk_dismissed() -> bool:
	if not FileAccess.file_exists(GUIDE_PATH):
		return false
	var file := FileAccess.open(GUIDE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return false
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if typeof(parsed.get("dismissed", null)) != TYPE_BOOL:
		return false
	return bool(parsed["dismissed"])


func guide_note_city() -> void:
	if guide_done or guide_step != 0:
		return
	guide_step = 1


func guide_note_action() -> void:
	if guide_done:
		return
	# 帮我选直接固守、行军或攻城时，没点过城也算完成选城和选行动。
	if guide_step < 2:
		guide_step = 2


func guide_note_end() -> void:
	if guide_done:
		return
	guide_step = 3
	guide_done = true
	_write_guide_disk()


func guide_skip() -> void:
	guide_step = 3
	guide_done = true
	_write_guide_disk()


func _remove_user_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _patch_save_guide(done: bool, step: int) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	parsed["guide_done"] = done
	parsed["guide_step"] = step
	var out := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(JSON.stringify(parsed))


func _skip_key_held() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) or Input.is_key_pressed(KEY_ESCAPE)


func _is_skip_key(code: Key) -> bool:
	return code == KEY_SPACE or code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_ESCAPE


func _write_guide_disk() -> void:
	var file := FileAccess.open(GUIDE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"dismissed": true}))


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


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
	_clamp_stats()


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
	_clamp_stats()
	_log(message)
	return {"ok": true, "message": message}


func _clamp_stats() -> void:
	silver = maxi(0, silver)
	grain = maxi(0, grain)
	morale = maxi(0, morale)
	liaodong = maxi(0, liaodong)
	pressure = maxi(0, pressure)
	worldline = maxi(0, worldline)


## 黄/红只作提示。开局辽东稳固正好 40，不亮。
func danger_marks() -> Dictionary:
	var marks := {}
	if morale <= 15:
		marks["morale"] = "red"
	elif morale <= 25:
		marks["morale"] = "yellow"
	if silver <= 0:
		marks["silver"] = "red"
	elif silver <= 10:
		marks["silver"] = "yellow"
	if liaodong < 40:
		marks["liaodong"] = "red"
	return marks


func danger_line() -> String:
	var marks: Dictionary = danger_marks()
	if marks.is_empty():
		return ""
	var parts: PackedStringArray = []
	if str(marks.get("morale", "")) == "red":
		parts.append("民心 %d，已到 15" % morale)
	elif str(marks.get("morale", "")) == "yellow":
		parts.append("民心 %d，已到 25，再低到 15 就要小心" % morale)
	if str(marks.get("silver", "")) == "red":
		parts.append("银两 %d，已到 0" % silver)
	elif str(marks.get("silver", "")) == "yellow":
		parts.append("银两 %d，已到 10，用尽就会落到丁" % silver)
	if marks.has("liaodong"):
		parts.append("辽东稳固 %d，不到 40" % liaodong)
	return "小心：" + "；".join(parts)


func finale_hint() -> String:
	if settled:
		return ""
	if s3_done or turn >= Baseline.PLAY_TURNS:
		return "本回合是终局，点下一回合进入结局。"
	if turn >= 6:
		return "下回合是京师危机，再下回合是终局。"
	return ""


func march_options(src_id: String) -> Array[String]:
	var found: Array[String] = []
	if settled or main_done:
		return found
	var src := city(src_id)
	if src.is_empty() or str(src["faction"]) != "明" or int(src["troops"]) < 2:
		return found
	for hop in neighbors_of(src_id):
		var dst_id := str(hop["id"])
		if str(city(dst_id)["faction"]) != "明":
			continue
		var cost := Baseline.MARCH_GRAIN_FAR if bool(hop["far"]) else Baseline.MARCH_GRAIN
		if grain < cost:
			continue
		found.append(dst_id)
	return found


func march_block_reason(src_id: String) -> String:
	if not march_options(src_id).is_empty():
		return ""
	if settled or main_done:
		return "本回合已行动"
	var src := city(src_id)
	if src.is_empty() or str(src["faction"]) != "明":
		return "先点一座我方的城"
	if int(src["troops"]) < 2:
		return "兵力不足，至少留 1 人守城"
	var any_ming := false
	var need := Baseline.MARCH_GRAIN
	for hop in neighbors_of(src_id):
		if str(city(str(hop["id"]))["faction"]) != "明":
			continue
		any_ming = true
		var cost := Baseline.MARCH_GRAIN_FAR if bool(hop["far"]) else Baseline.MARCH_GRAIN
		need = maxi(need, cost)
	if not any_ming:
		return "没有相邻的我方城"
	return "粮草不足（需要 %d）" % need


func attack_options(src_id: String) -> Array[String]:
	var found: Array[String] = []
	if settled or main_done:
		return found
	var src := city(src_id)
	if src.is_empty() or str(src["faction"]) != "明" or int(src["troops"]) < 2:
		return found
	for hop in neighbors_of(src_id):
		var dst_id := str(hop["id"])
		if str(city(dst_id)["faction"]) == "明":
			continue
		var preview := preview_battle(src_id, dst_id)
		if bool(preview.get("ok", false)):
			found.append(dst_id)
	return found


func attack_block_reason(src_id: String) -> String:
	if not attack_options(src_id).is_empty():
		return ""
	if settled or main_done:
		return "本回合已行动"
	var src := city(src_id)
	if src.is_empty() or str(src["faction"]) != "明":
		return "先点一座我方的城"
	if int(src["troops"]) < 2:
		return "兵力不足，出不了兵"
	return "旁边没有可打的城"


func attack_preview_line(src_id: String) -> String:
	var parts: PackedStringArray = []
	for dst_id in attack_options(src_id):
		var preview := preview_battle(src_id, dst_id)
		parts.append("%s攻%s，预计%s" % [city(src_id)["name"], city(dst_id)["name"], str(preview.get("label", ""))])
	return "；".join(parts)


## 预判条只回答「如果现在结算」。照★走到底的最好结局不放在这里。
func forecast_view() -> Dictionary:
	var now := resolve_ending()
	var bits := _avoid_bits(now)
	return {
		"ending": now,
		"plate": _plate_name(now),
		"lead": "照现在这样，预计得",
		"avoid": _bits_plain(bits),
		"bits": bits,
		"danger": now == "丁",
	}


func forecast_text(_best_ending: String = "") -> String:
	var view := forecast_view()
	return "结局预判 %s %s。%s" % [str(view["lead"]), str(view["plate"]), str(view["avoid"])]


func settlement_checks() -> Array:
	var ending := ending_id if ending_id != "" else resolve_ending()
	var rows: Array = []
	var capital := str(city("C1")["faction"]) == "明"
	if ending == "丁":
		if not capital:
			rows.append(_check_row("京师不在明军手里", true, -1, true))
		else:
			rows.append(_check_row("辽东稳固低于 40", liaodong < 40, liaodong, liaodong < 40))
			rows.append(_check_row("并且，下面任意一条", false, -1, false, "note"))
		rows.append(_check_row("民心 ≤ 15", morale <= 15, morale, morale <= 15))
		rows.append(_check_row("银两 ≤ 0", silver <= 0, silver, silver <= 0))
	elif ending == "甲":
		rows.append(_check_row("袁崇焕未死", yuan_status != "已死", -1, false))
		rows.append(_check_row("辽东稳固 ≥ 60", liaodong >= 60, liaodong, false))
		rows.append(_check_row("后金压力 ≤ 40", pressure <= 40, pressure, false))
		rows.append(_check_row("世界线 ≥ 35", worldline >= 35, worldline, false))
	elif ending == "乙":
		rows.append(_check_row("京师在明军手里", capital, -1, false))
		rows.append(_check_row("辽东稳固 ≥ 40", liaodong >= 40, liaodong, false))
		rows.append(_check_row("民心 ≥ 45", morale >= 45, morale, false))
	else:
		rows.append(_check_row("辽东稳固 ≥ 40", liaodong >= 40, liaodong, false))
		rows.append(_check_row("民心 ≥ 45", morale >= 45, morale, false))
		rows.append(_check_row("民心 ≤ 15", morale <= 15, morale, morale <= 15))
		rows.append(_check_row("银两 ≤ 0", silver <= 0, silver, silver <= 0))
	return rows


func stat_hits() -> Dictionary:
	var hits := {}
	var ending := ending_id if ending_id != "" else resolve_ending()
	if ending != "丁":
		return hits
	if morale <= 15:
		hits["morale"] = true
	if silver <= 0:
		hits["silver"] = true
	if liaodong < 40:
		hits["liaodong"] = true
	if str(city("C1")["faction"]) != "明":
		hits["capital"] = true
	return hits


func settlement_basis() -> String:
	var ending := ending_id if ending_id != "" else resolve_ending()
	var head := "第 %d 回合结算，依据：这一局打到第 %d 回合就结算，不是中途被判负。" % [turn, Baseline.PLAY_TURNS]
	var nums := "当时银两 %d，粮草 %d，民心 %d，辽东稳固 %d，后金压力 %d，世界线 %d。袁崇焕 %s。京师 %s。" % [
		silver, grain, morale, liaodong, pressure, worldline, yuan_status,
		"在明军手里" if str(city("C1")["faction"]) == "明" else "已不在明军手里",
	]
	return "%s%s %s" % [head, _rule_sentence(ending), nums]


func _plate_name(ending: String) -> String:
	match ending:
		"甲":
			return "甲·中兴微光"
		"乙":
			return "乙·残局续命"
		"丁":
			return "丁·另途崩解"
		"丙":
			return "丙·史实沉响"
		_:
			return ending


func _avoid_bits(now: String) -> Array:
	if now == "甲":
		return [{"text": "保持现状即可", "color": "FFD978"}]
	if now == "丁":
		var line := "想避开：辽东回到 40 以上，或民心 ≥ 16 且银两 > 0"
		if str(city("C1")["faction"]) != "明":
			line = "想避开：京师不在，民心 ≥ 16 且银两 > 0"
		return [{"text": line, "color": "FFB4A6"}]
	return _gap_bits()


func _gap_bits() -> Array:
	var items: Array = []
	if yuan_status == "已死":
		items.append({"text": "袁已死", "num": false})
	else:
		if str(city("C1")["faction"]) != "明":
			items.append({"text": "京师不在", "num": false})
		if liaodong < 60:
			items.append({"text": "辽东 +%d" % (60 - liaodong), "num": true})
		if pressure > 40:
			items.append({"text": "压力 −%d" % (pressure - 40), "num": true})
		if worldline < 35:
			items.append({"text": "世界线 +%d" % (35 - worldline), "num": true})
	if items.is_empty():
		items.append({"text": "守住现有局面", "num": false})
	var bits := _join_gap(items)
	if _hanzi_count(_bits_plain(bits)) <= 22:
		return bits
	var short_items: Array = []
	for item in items:
		var text := str(item["text"]).replace("世界线", "世").replace("辽东", "辽").replace("压力", "压").replace("京师不在", "京师")
		short_items.append({"text": text, "num": item["num"]})
	bits = _join_gap(short_items)
	while short_items.size() > 1 and _hanzi_count(_bits_plain(bits)) > 22:
		short_items.pop_back()
		bits = _join_gap(short_items)
	return bits


func _join_gap(items: Array) -> Array:
	var bits: Array = [{"text": "想升到甲，还差：", "color": "F6DC92"}]
	var first := true
	for item in items:
		if not first:
			bits.append({"text": "，", "color": "F6DC92"})
		first = false
		var color := "FFD978" if bool(item.get("num", false)) else "F6DC92"
		bits.append({"text": str(item["text"]), "color": color})
	return bits


func _bits_plain(bits: Array) -> String:
	var plain := ""
	for bit in bits:
		plain += str(bit["text"])
	return plain


func _hanzi_count(text: String) -> int:
	var count := 0
	var i := 0
	while i < text.length():
		if text.unicode_at(i) > 0x2E7F:
			count += 1
		i += 1
	return count


func _check_row(text: String, met: bool, value: int, hit: bool, kind: String = "rule") -> Dictionary:
	return {"text": text, "met": met, "value": value, "hit": hit, "kind": kind}


func _ending_name(ending: String) -> String:
	match ending:
		"甲":
			return "甲 · 中兴微光"
		"乙":
			return "乙 · 残局续命"
		"丁":
			return "丁 · 另途崩解"
		"丙":
			return "丙 · 史实沉响"
		_:
			return ending


func upgrade_gaps() -> PackedStringArray:
	var ending := ending_id if ending_id != "" else resolve_ending()
	var lines := PackedStringArray()
	if ending == "甲":
		return lines
	var capital := str(city("C1")["faction"]) == "明"
	if not capital:
		lines.append("差：京师须留在明军手里")
	if yuan_status == "已死":
		lines.append("差：袁崇焕已死，到不了甲")
	else:
		if liaodong < 60:
			lines.append("差 %d：辽东稳固须 ≥60" % (60 - liaodong))
		if pressure > 40:
			lines.append("差 %d：后金压力须 ≤40" % (pressure - 40))
		if worldline < 35:
			lines.append("差 %d：世界线须 ≥35" % (35 - worldline))
	if ending != "乙" and capital and liaodong < 40 and morale < 45:
		lines.append("到乙差 %d：辽东稳固须 ≥40，或差 %d：民心须 ≥45" % [40 - liaodong, 45 - morale])
	return lines


func _better_gaps(now: String) -> String:
	if now == "甲":
		return ""
	var parts: PackedStringArray = []
	if now != "乙":
		if str(city("C1")["faction"]) != "明":
			parts.append("要到乙，京师得留在明军手里")
		else:
			if liaodong < 40 and morale < 45:
				parts.append("要到乙，辽东稳固要到 40，或民心要到 45")
	if yuan_status == "已死":
		parts.append("甲要袁崇焕未死，这一局已经走不到甲")
	else:
		var jia: PackedStringArray = []
		if liaodong < 60:
			jia.append("辽东稳固要到 60")
		if pressure > 40:
			jia.append("后金压力要到 40 或更低")
		if worldline < 35:
			jia.append("世界线要到 35")
		if str(city("C1")["faction"]) != "明":
			jia.append("京师要留在明军手里")
		if not jia.is_empty():
			parts.append("要到甲，还要" + "，".join(jia))
	return "".join(parts) + ("。" if not parts.is_empty() else "")


func _rule_sentence(ending: String) -> String:
	var capital := str(city("C1")["faction"]) == "明"
	if ending == "甲":
		return "走到甲：袁崇焕未死，辽东稳固 %d 已到 60，后金压力 %d 不高于 40，世界线 %d 已到 35，京师在明军手里。" % [liaodong, pressure, worldline]
	if ending == "乙":
		var why := "辽东稳固 %d 已到 40" % liaodong if liaodong >= 40 else "民心 %d 已到 45" % morale
		return "走到乙：京师在明军手里，且%s。甲还没齐。" % why
	if ending == "丁":
		var hits: PackedStringArray = []
		if morale <= 15:
			hits.append("民心 %d，已到 15 或更低" % morale)
		if silver <= 0:
			hits.append("银两 %d，已到 0" % silver)
		var gate := "辽东稳固 %d，不到 40，民心 %d，也不到 45" % [liaodong, morale]
		if not capital:
			gate = "京师已不在明军手里"
		return "走到丁：%s。同时%s。" % [gate, "；".join(hits)]
	var why_not_yi := "辽东稳固 %d 不到 40，民心 %d 也不到 45" % [liaodong, morale]
	if not capital:
		why_not_yi = "京师不在明军手里"
	return "走到丙：%s。民心 %d 高于 15，银两 %d 高于 0，所以不是丁。" % [why_not_yi, morale, silver]


func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "goto": "map"}


func _log(message: String) -> void:
	log_text = message
