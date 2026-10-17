@tool
extends EditorPlugin
## 编辑器启动时挂上导出过滤。正式包不需要这份脚本。

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/pack_filter/export_plugin.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
		_export = null
