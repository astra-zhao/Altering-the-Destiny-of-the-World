extends RefCounted
## v0.2 策略大纲（2026-10-13）。城池、邻接、局面初值，以及 M1 的简单数值。
## 城池 6：C1 京师、C2 保定、C3 大同、C4 宁远、C5 沈阳、C6 锦州。
## 邻接：京师—保定—大同；保定—宁远—锦州—沈阳；大同—宁远为远邻。

const TURN := 1
## 玩家实际能打完的最后一回合。第 7 回合结束进入京师危机，第 8 回合结束结算。
## 旧的「第 10 回合超时」到不了，已去掉，不要再拿它当终局。
const PLAY_TURNS := 8

## 袁崇焕可取：前线可用 / 闲置 / 已死 / 京营。M0 固定显示默认值。
const YUAN_STATUSES: PackedStringArray = ["前线可用", "闲置", "已死", "京营"]
const YUAN_DEFAULT := "前线可用"

const FACTION_LINE := "玩家 · 明　　后金 · AI"

## 局面初值，顺序与大纲 §1.2 一致。value 用字符串，方便和「前线可用」同一套面板。
const STATS: Array[Dictionary] = [
	{"id": "silver", "label": "银两", "value": "40", "hint": "内政/出兵消耗"},
	{"id": "grain", "label": "粮草", "value": "45", "hint": "驻军与行军"},
	{"id": "morale", "label": "民心", "value": "35", "hint": "低则事件惩罚"},
	{"id": "liaodong", "label": "辽东稳固", "value": "40", "hint": "宁远/锦州相关"},
	{"id": "pressure", "label": "后金压力", "value": "50", "hint": "高则敌方更猛"},
	{"id": "worldline", "label": "世界线偏移", "value": "0", "hint": "剧情抉择推高"},
	{"id": "yuan", "label": "袁崇焕", "value": YUAN_DEFAULT, "hint": "前线可用 / 闲置 / 已死 / 京营"},
]

## pos 是地图内的示意坐标（0–1），不是经纬度。西在左，东北在右上。
## troops 为初始兵力。锦州归属显示「争议」，交战时算后金。terrain_pct：100 = 守方 ×1.00。
const CITIES: Array[Dictionary] = [
	{"id": "C1", "name": "京师", "owner": "明", "faction": "明", "troops": 20, "terrain_pct": 110, "note": "首都；失守易崩盘", "pos": Vector2(0.36, 0.52)},
	{"id": "C2", "name": "保定", "owner": "明", "faction": "明", "troops": 14, "terrain_pct": 100, "note": "", "pos": Vector2(0.30, 0.74)},
	{"id": "C3", "name": "大同", "owner": "明", "faction": "明", "troops": 12, "terrain_pct": 115, "note": "边镇", "pos": Vector2(0.15, 0.38)},
	{"id": "C4", "name": "宁远", "owner": "明", "faction": "明", "troops": 18, "terrain_pct": 120, "note": "袁系前线锚点", "pos": Vector2(0.55, 0.36)},
	{"id": "C5", "name": "沈阳", "owner": "后金", "faction": "后金", "troops": 26, "terrain_pct": 110, "note": "敌方核心", "pos": Vector2(0.88, 0.16)},
	{"id": "C6", "name": "锦州", "owner": "争议/后金压境", "faction": "后金", "troops": 10, "terrain_pct": 100, "note": "易触发战事", "pos": Vector2(0.72, 0.26)},
]

const YUAN_CITY := "C4"
const MARCH_GRAIN := 3
const MARCH_GRAIN_FAR := 6
const LEVY_GRAIN := 8
const LEVY_MORALE := 4
const SPEND_SILVER := 6
const SPEND_MORALE := 6
const TRAIN_SILVER := 5
const TRAIN_GRAIN := 4
const TRAIN_TROOPS := 4
const CONSOLIDATE_TROOPS := 4
const HOLD_PCT := 130
const YUAN_ATK_PCT := 125
const WIN_RATIO_PCT := 112
const LOSE_RATIO_PCT := 88

## far=true 表示大纲里的远邻（大同—宁远）。
const ROUTES: Array[Dictionary] = [
	{"a": "C1", "b": "C2", "far": false},
	{"a": "C2", "b": "C3", "far": false},
	{"a": "C2", "b": "C4", "far": false},
	{"a": "C3", "b": "C4", "far": true},
	{"a": "C4", "b": "C6", "far": false},
	{"a": "C6", "b": "C5", "far": false},
]

static func city_by_id(id: String) -> Dictionary:
	for city in CITIES:
		if str(city["id"]) == id:
			return city
	return {}
