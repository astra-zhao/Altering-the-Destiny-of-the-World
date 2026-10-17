extends RefCounted
## v0.2 策略大纲（2026-10-13）的 M0 设计基线。只读初值，不做回合模拟。
## 城池 6：C1 京师、C2 保定、C3 大同、C4 宁远、C5 沈阳、C6 锦州。
## 邻接：京师—保定—大同；保定—宁远—锦州—沈阳；大同—宁远为远邻。

const TURN := 1
const TURN_LIMIT := 10

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
const CITIES: Array[Dictionary] = [
	{"id": "C1", "name": "京师", "owner": "明", "note": "首都；失守易崩盘", "pos": Vector2(0.36, 0.52)},
	{"id": "C2", "name": "保定", "owner": "明", "note": "", "pos": Vector2(0.30, 0.74)},
	{"id": "C3", "name": "大同", "owner": "明", "note": "边镇", "pos": Vector2(0.15, 0.38)},
	{"id": "C4", "name": "宁远", "owner": "明", "note": "袁系前线锚点", "pos": Vector2(0.55, 0.36)},
	{"id": "C5", "name": "沈阳", "owner": "后金", "note": "敌方核心", "pos": Vector2(0.88, 0.16)},
	{"id": "C6", "name": "锦州", "owner": "争议/后金压境", "note": "易触发战事", "pos": Vector2(0.72, 0.26)},
]

## far=true 表示大纲里的远邻（大同—宁远）。
const ROUTES: Array[Dictionary] = [
	{"a": "C1", "b": "C2", "far": false},
	{"a": "C2", "b": "C3", "far": false},
	{"a": "C2", "b": "C4", "far": false},
	{"a": "C3", "b": "C4", "far": true},
	{"a": "C4", "b": "C6", "far": false},
	{"a": "C6", "b": "C5", "far": false},
]

const STORY_IDLE := "M1 将在此接入：切换场景 → 抉择 → 写回。按下只说明流程，不改局面。"
const STORY_PRESSED := "已点占位：切换场景 → 抉择 → 写回策略变量 → 返回大地图。\nS1 登基夜、S2 袁崇焕生死、S3 京师危机尚未接入。\n银两、粮草、民心、辽东稳固、后金压力、世界线偏移、袁崇焕仍为初值。"


static func city_by_id(id: String) -> Dictionary:
	for city in CITIES:
		if str(city["id"]) == id:
			return city
	return {}
