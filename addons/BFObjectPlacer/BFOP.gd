@tool
extends EditorPlugin

var ui : HBoxContainer
const UI : PackedScene = preload("res://addons/BFObjectPlacer/ui/ui.tscn")

func _enter_tree() -> void:
	ui = UI.instantiate()
	add_control_to_bottom_panel(ui, "Object Placer")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(ui)
	ui.queue_free()
