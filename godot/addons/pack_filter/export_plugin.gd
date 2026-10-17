@tool
extends EditorExportPlugin
## exclude_filter 能挡 qa、检查脚本、冒烟脚本和 woff2 本体。
## res://.godot/uid_cache.bin 是强制导出文件，不经过这道过滤，里面仍写着这些路径。
## 导出开始时把缓存改成不含这些路径的副本，结束时还原编辑器里的原文件。

var _cache_path := "res://.godot/uid_cache.bin"
var _backup := PackedByteArray()
var _rewritten := false


func _get_name() -> String:
	return "PackFilter"


func _export_begin(_features, _is_debug, _path, _flags) -> void:
	if not FileAccess.file_exists(_cache_path):
		return
	_backup = FileAccess.get_file_as_bytes(_cache_path)
	var filtered := _filter_cache(_backup)
	if filtered.size() == _backup.size() and filtered == _backup:
		_rewritten = false
		return
	var out := FileAccess.open(_cache_path, FileAccess.WRITE)
	if out == null:
		_rewritten = false
		return
	out.store_buffer(filtered)
	out.close()
	_rewritten = true


func _export_end() -> void:
	if not _rewritten:
		return
	var out := FileAccess.open(_cache_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_buffer(_backup)
	out.close()
	_rewritten = false
	_backup = PackedByteArray()


func _export_file(path, _type, _features) -> void:
	if _forbidden(str(path)):
		skip()


func _forbidden(path: String) -> bool:
	if path.begins_with("res://addons/pack_filter/") or "/addons/pack_filter/" in path:
		return true
	var name := path.get_file()
	if name.begins_with("qa_"):
		return true
	if name.ends_with("_check.gd") or name.ends_with("_check.gdc") or name.ends_with("_check.tscn"):
		return true
	if name.ends_with("_check.gd.remap") or name.ends_with("_check.gd.uid") or name.ends_with("_check.tscn.remap"):
		return true
	if "_smoke.gd" in name or name.ends_with("_smoke.gdc") or name.ends_with("_smoke.gd.remap") or name.ends_with("_smoke.gd.uid"):
		return true
	if ".woff2" in name:
		return true
	return false


func _filter_cache(data: PackedByteArray) -> PackedByteArray:
	if data.size() < 4:
		return data
	var count := data.decode_u32(0)
	var offset := 4
	var kept: Array[PackedByteArray] = []
	for _i in count:
		if offset + 12 > data.size():
			return data
		var uid := data.slice(offset, offset + 8)
		offset += 8
		var length := data.decode_u32(offset)
		offset += 4
		if length < 0 or offset + length > data.size():
			return data
		var path := data.slice(offset, offset + length).get_string_from_utf8()
		offset += length
		if _forbidden(path):
			continue
		var raw := path.to_utf8_buffer()
		var row := PackedByteArray()
		row.append_array(uid)
		row.append_array(_u32(raw.size()))
		row.append_array(raw)
		kept.append(row)
	if offset != data.size():
		return data
	var out := _u32(kept.size())
	for row in kept:
		out.append_array(row)
	return out


func _u32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes
