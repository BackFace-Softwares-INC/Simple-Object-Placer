@tool
extends HBoxContainer

@onready var enabled : bool = false
@onready var OffsetX : SpinBox = %X
@onready var OffsetY : SpinBox = %Y
@onready var OffsetZ : SpinBox = %Z
@onready var tree : Tree = %Tree

var object_path

var GIZMO : MeshInstance3D = null
var gizmo_scene := preload("res://addons/BFObjectPlacer/gizmo/gizmo.tscn")

func _ready() -> void:
	tree.set_hide_root(true)
	tree.set_columns(1)
	tree.set_column_title(0,"Object Placer")
	tree.connect("item_selected", _on_item_selected)

func add_items_to_tree(path: String, parent: TreeItem) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		print("Can't open: ", path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)
		var is_folder := dir.current_is_dir()

		var item := tree.create_item(parent)
		item.set_text(0, file_name)
		item.set_metadata(0, full_path)

		var icon: Texture2D
		if is_folder:
			icon = EditorInterface.get_editor_theme().get_icon("Folder", "EditorIcons")
		else:
			icon = EditorInterface.get_editor_theme().get_icon("File", "EditorIcons")

		item.set_icon(0, icon)

		if is_folder:
			add_items_to_tree(full_path, item)

		file_name = dir.get_next()
	dir.list_dir_end()

func _on_enable_button_toggled(toggled_on: bool) -> void:
	enabled = toggled_on
	var edited_scene = EditorInterface.get_edited_scene_root()
	if enabled:
		tree.clear()

		var root := tree.create_item()
		add_items_to_tree("res://", root)
		if not GIZMO:
			GIZMO = gizmo_scene.instantiate()
		edited_scene.add_child(GIZMO)
	else:
		if GIZMO:
			GIZMO.queue_free()
			GIZMO = null


func _process(delta: float) -> void:
	if enabled and collision():
		GIZMO.position = collision().get("position")

func collision() -> Dictionary:
	var camera : Camera3D = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	var range : int = 1000
	var mouse_pos : Vector2 = EditorInterface.get_editor_viewport_3d().get_mouse_position()
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_end : Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * range
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var collision : Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if collision:
		return collision
	return collision

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.is_echo() and enabled and object_path != null:
			
			if collision():
				var obj = load(object_path).instantiate()
				obj.position = collision().get("position") + Vector3(OffsetX.value, OffsetY.value, OffsetZ.value)
					
				var edited_scene = EditorInterface.get_edited_scene_root()
				if not edited_scene:
					return

				var undo_redo = EditorInterface.get_editor_undo_redo()
				undo_redo.create_action("Place Object")
				undo_redo.add_do_method(edited_scene, "add_child", obj)
				undo_redo.add_do_method(obj, "set_owner", edited_scene)
				undo_redo.add_undo_method(edited_scene, "remove_child", obj)
				undo_redo.commit_action()

func _on_item_selected() -> void:
	var selected = tree.get_selected()
	if selected:
		print("A")
		var path = selected.get_metadata(0)
		object_path = path
