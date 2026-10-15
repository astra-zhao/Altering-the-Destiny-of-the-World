extends SceneTree
## 扫描玩家能看见的源码字符串，确认每个字符都在三份 Noto 子集里。
## godot --headless --path godot -s res://scripts/glyph_subset_check.gd

const FONTS := [
	"res://assets/ui/NotoSansSC-Regular.otf",
	"res://assets/ui/NotoSansSC-Bold.otf",
	"res://assets/ui/NotoSerifSC-Bold.otf",
]

const SKIP_FILES := {
	"res://scripts/qa_ui_capture.gd": true,
	"res://scripts/advisor_check.gd": true,
	"res://scripts/advisor_smoke.gd": true,
	"res://scripts/bgm_check.gd": true,
	"res://scripts/qa_audio_real.gd": true,
	"res://scripts/glyph_subset_check.gd": true,
	"res://scripts/v031_check.gd": true,
	"res://scripts/qa_v031_shots.gd": true,
}


func _init() -> void:
	var fonts: Array[FontFile] = []
	for path in FONTS:
		var font := load(path) as FontFile
		if font == null:
			print("GLYPH_SUBSET_FAIL 字体没有载入 %s" % path)
			quit(1)
			return
		font.allow_system_fallback = false
		font.fallbacks.clear()
		if font.get_supported_chars().length() < 100:
			print("GLYPH_SUBSET_FAIL 子集是空的 %s" % path)
			quit(1)
			return
		fonts.append(font)
	var seen := {}
	var files := 0
	for path in _sources():
		files += 1
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			continue
		for literal in _string_literals(text):
			if not _player_visible(literal):
				continue
			var i := 0
			while i < literal.length():
				var code := literal.unicode_at(i)
				i += 1
				if code <= 32 or code == 0xFEFF or code == 0x200B:
					continue
				if not seen.has(code):
					seen[code] = {}
				seen[code][path] = true
	var missing := {}
	for code in seen:
		for font in fonts:
			if not font.has_char(int(code)):
				if not missing.has(code):
					missing[code] = []
				missing[code].append(font.resource_path.get_file())
	var codes: Array = missing.keys()
	codes.sort()
	if codes.is_empty():
		print("GLYPH_SUBSET_OK files=%d chars=%d subset=%d missing=0" % [files, seen.size(), fonts[0].get_supported_chars().length()])
		quit(0)
		return
	var shown := ""
	for code in codes:
		var where: Array = seen[code].keys()
		where.sort()
		shown += "%s U+%04X %s @ %s\n" % [char(int(code)), int(code), ", ".join(missing[code]), ", ".join(where)]
	print("GLYPH_SUBSET_MISSING count=%d" % codes.size())
	print(shown)
	quit(1)


func _sources() -> Array[String]:
	var found: Array[String] = []
	_walk("res://scripts", found)
	_walk("res://data", found)
	_walk("res://scenes", found)
	if FileAccess.file_exists("res://project.godot"):
		found.append("res://project.godot")
	return found


func _walk(root: String, found: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var path := root.path_join(name)
			if dir.current_is_dir():
				_walk(path, found)
			elif _keep(path):
				found.append(path)
		name = dir.get_next()
	dir.list_dir_end()


func _keep(path: String) -> bool:
	if SKIP_FILES.has(path):
		return false
	return path.ends_with(".gd") or path.ends_with(".tscn")


func _player_visible(literal: String) -> bool:
	# 纯英文的资源路径、存档键和调试标记不是界面文案。含汉字的字符串里，标点也要能画出来。
	if literal.contains("res://") or literal.contains("user://"):
		return false
	var i := 0
	while i < literal.length():
		if literal.unicode_at(i) > 127:
			return true
		i += 1
	return false


func _string_literals(text: String) -> Array[String]:
	var found: Array[String] = []
	var i := 0
	var n := text.length()
	while i < n:
		var c := text.unicode_at(i)
		if c == 35:
			while i < n and text.unicode_at(i) != 10:
				i += 1
			continue
		if c == 34 or c == 39:
			var quote := c
			var triple := i + 2 < n and text.unicode_at(i + 1) == quote and text.unicode_at(i + 2) == quote
			var literal := ""
			if triple:
				i += 3
				while i < n:
					if i + 2 < n and text.unicode_at(i) == quote and text.unicode_at(i + 1) == quote and text.unicode_at(i + 2) == quote:
						i += 3
						break
					literal += char(text.unicode_at(i))
					i += 1
				found.append(literal)
				continue
			i += 1
			while i < n:
				var d := text.unicode_at(i)
				if d == 92:
					i += 1
					if i < n:
						literal += char(text.unicode_at(i))
						i += 1
					continue
				if d == quote or d == 10:
					i += 1
					break
				literal += char(d)
				i += 1
			found.append(literal)
			continue
		i += 1
	return found
