@tool
extends HBoxContainer

#region Global variables
@onready var enabled : bool = false # Store the current status of the object placer.
@onready var offset_x : SpinBox = %X # X Axis position for the offset.
@onready var offset_y : SpinBox = %Y # Y Axis position for the offset.
@onready var offset_z : SpinBox = %Z # Z Axis position for the offset.
@onready var placement_density : SpinBox = %Density # Density of objects.
@onready var placement_range : SpinBox = %Range # Range distance of the objects.
@onready var scale_range_min : SpinBox = %RandomScaleRangeMin # Random scale min value spin box.
@onready var scale_range_max : SpinBox = %RandomScaleRangeMax # Random scale max value spin box.
@onready var random_scale_enabler : CheckBox = %RandomScaleEnabler # Random scale enable check box.
@onready var random_rotation_enabler : CheckBox = %RandomRotationEnabler # Random rotation enable check box.
@onready var tree : Tree = %Tree # Tree node path.

@onready var pre_view : Node3D = $PreViewAndConfig/PreViewContainer/PreView/PreView # Preview 3D scene.

var can_rotate : bool = false # Define the current status of the random rotation.
var can_scale : bool = false # Define the current status of the random scale.

# Scene path on the filesystem.
var object_path # The path of the object that will be placed.

# 3D gizmo scene path.
var GIZMO : Node3D = null # Variable to store the 3D scene of the gizmo
var gizmo_scene : PackedScene = preload("res://addons/BFObjectPlacer/gizmo/gizmo.tscn") # 3D scene path.

#endregion

#region File tree and gizmo/enable the placement

# Define tree nodes attributes, like hide root, names and others.
func _ready() -> void:
	tree.set_hide_root(true) # Hide the root folder from the tree node.
	tree.set_columns(1) # Set the number of columns.
	tree.set_column_title(0,"Object Placer") # Name the first column as "Object Placer".
	tree.connect("item_selected", _on_item_selected) # Connect the _on_item_selected to the item_selected func.

# Look for every file on the filesystem and put the .tscn scenes on tree.
func add_items_to_tree(path: String, parent: TreeItem) -> void:
	var dir : DirAccess = DirAccess.open(path) # Variable to store ever path in the filesystem
	if dir == null: # Return if there's no path or if they can't open.
		print("Can't open: ", path)
		return

	dir.list_dir_begin() # Start to open files.
	var file_name : String = dir.get_next() # Get the file name.
	while file_name != "": # Ignore the path's with no name or if they being with "."
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path : String = path.path_join(file_name) # Get the full path.
		var is_folder : bool = dir.current_is_dir() # Verify if is a folder

		if is_folder: # If is folder, read every file.
			add_items_to_tree(full_path, parent)
		else:
			if file_name.ends_with(".tscn"): # Add the .tscn file to tree
				var item : TreeItem = tree.create_item(parent)
				item.set_text(0, file_name)
				item.set_metadata(0, full_path)
				item.set_icon(0, EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons"))

		file_name = dir.get_next() # Go to next file.
	dir.list_dir_end() # Stop reading

# Update the tree node and enable the placement.
func _on_enable_button_toggled(toggled_on: bool) -> void:
	enabled = toggled_on # Enable the placement.
	var edited_scene : Node = EditorInterface.get_edited_scene_root() # Get the root scene.
	if enabled:
		tree.clear() # Clear the tree wen enable is true

		var root : TreeItem = tree.create_item() # Root folder.
		add_items_to_tree("res://", root)
		if not GIZMO: # Gizmo stantiate and logic.
			GIZMO = gizmo_scene.instantiate()
		if edited_scene:
			edited_scene.add_child(GIZMO)
	else:
		if GIZMO:
			GIZMO.queue_free()
			GIZMO = null

#endregion

#region Gizmo on mouse position and the collision function

# Put the gizmo on the mouse position
func _process(delta: float) -> void:
	if enabled and GIZMO and collision(): # If the placement is enabled and the mouse is on a collision object, put the gizmo on mouse pos.
		GIZMO.position = collision().get("position") + Vector3(offset_x.value, offset_y.value, offset_z.value)
		if placement_range.value > 0.1:
			GIZMO.scale = Vector3(placement_range.value, placement_range.value, placement_range.value)

# Get the ssmp (Screen Space Mouse Position).
func collision() -> Dictionary:
	var camera : Camera3D = EditorInterface.get_editor_viewport_3d().get_camera_3d() # Get the editor camera.
	var range : int = 1000 # Ray lenght.
	var mouse_pos : Vector2 = EditorInterface.get_editor_viewport_3d().get_mouse_position() # Editor mouse position
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_pos) # Origin of ray.
	var ray_end : Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * range # End point of ray.
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)  # Make the raycast.
	if GIZMO:
		var exclude_rids : Array = []
		for child in GIZMO.get_children():
			if child is CollisionObject3D:
				exclude_rids.append(child.get_rid())
		query.exclude = exclude_rids

	var collision : Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if collision:
		return collision
	return collision

#endregion

#region 3D placement logic
func _input(event):
	if not enabled:
		return

	if event is InputEventMouseButton and event.pressed: # Verify if the mouse button was pressed and if the mouse is on the viewport.
		var vp_rect = EditorInterface.get_editor_viewport_3d().get_visible_rect() # Get the viewport.
		var mouse_pos : Vector2 = event.position

		if not vp_rect.has_point(mouse_pos): # Return if the click position was off the viewport.
			return

	# Make sure that the input is from the left mouse position.
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed and not event.is_echo() \
	and object_path != null:

# If the mouse position is on a object, make the placement logic.
		if collision():
			randomize()
			var center_pos : Vector3 = collision().get("position")
			var edited_scene : Node = EditorInterface.get_edited_scene_root()
			if not edited_scene:
				return
			# Undo redo

			var undo_redo : EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Place Objects")

			for i in range(placement_density.value): # Placement Density
				var obj : Node = load(object_path).instantiate()
				var random_offset : Vector3 = Vector3(
					randf_range(0, placement_range.value), # Placement Range
					0,
					randf_range(0, placement_range.value)
				)
				var random_scale : float = randf_range(scale_range_min.value, scale_range_max.value)

				if can_rotate:
					obj.rotation.y = randf_range(0.0, 360.0)
				if can_scale:
					obj.position = center_pos + random_offset + (Vector3(offset_x.value, offset_y.value, offset_z.value) * random_scale)
					obj.scale = Vector3(random_scale, random_scale, random_scale)
				else:
					obj.position = center_pos + random_offset + Vector3(offset_x.value, offset_y.value, offset_z.value)
				undo_redo.add_do_method(edited_scene, "add_child", obj)
				undo_redo.add_do_method(obj, "set_owner", edited_scene)
				undo_redo.add_undo_method(edited_scene, "remove_child", obj)

			undo_redo.commit_action()

# Update the obect_path with the item selected.
func _on_item_selected() -> void:
	var selected : TreeItem = tree.get_selected()
	if selected:
		var path : String = selected.get_metadata(0)
		object_path = path

		if GIZMO:
			GIZMO.queue_free()
			GIZMO = null

		if object_path and ResourceLoader.exists(object_path):
			var new_scene : PackedScene = load(object_path)
			if new_scene is PackedScene:

				for i in pre_view.get_node("Holder").get_children():
					i.queue_free()

				pre_view.get_node("Holder").add_child(new_scene.instantiate())

				if not placement_range.value > 0.1:
					GIZMO = new_scene.instantiate()
				else:
					GIZMO = gizmo_scene.instantiate()

				_disable_collision(GIZMO)

				var edited_scene : Node = EditorInterface.get_edited_scene_root()
				if edited_scene:
					edited_scene.add_child(GIZMO)
					GIZMO.owner = null

func _disable_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0

	# CSGs
	if node is CSGShape3D:
		node.use_collision = false

	for child in node.get_children():
		if child is CSGShape3D:
			child.use_collision = false
		_disable_collision(child)

func _on_random_rotation_enabler_toggled(toggled_on: bool) -> void:
	can_rotate = toggled_on

func _on_random_scale_enabler_toggled(toggled_on: bool) -> void:
	can_scale = toggled_on
	scale_range_max.editable = toggled_on
	scale_range_min.editable = toggled_on

#endregion
