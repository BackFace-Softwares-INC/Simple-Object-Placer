@tool
extends HBoxContainer

# Global variables.
@onready var enabled : bool = false # Store the current status of the object placer.
@onready var OffsetX : SpinBox = %X # X Axis position for the offset.
@onready var OffsetY : SpinBox = %Y # Y Axis position for the offset.
@onready var OffsetZ : SpinBox = %Z # Z Axis position for the offset.
@onready var placementdensity : SpinBox = %Density # Density of objects.
@onready var placementrange : SpinBox = %Range # Range distance of the objects.
@onready var scaleRangeMin : SpinBox = %RandomScaleRangeMin
@onready var scaleRangeMax : SpinBox = %RandomScaleRangeMax
@onready var randomScaleEnabler : CheckBox = %RandomScaleEnabler
@onready var randomRotationEnabler : CheckBox = %RandomRotationEnabler
@onready var tree : Tree = %Tree # Tree node path.

var can_rotate : bool = false
var can_scale : bool = false

# Scene path on the filesystem.
var object_path # The path of the object that will be placed.

# 3D gizmo scene path.
var GIZMO : MeshInstance3D = null # Variable to store the 3D scene of the gizmo
var gizmo_scene := preload("res://addons/BFObjectPlacer/gizmo/gizmo.tscn") # 3D scene path.

# Define tree nodes attributes, like hide root, names and others.
func _ready() -> void:
	tree.set_hide_root(true) # Hide the root folder from the tree node.
	tree.set_columns(1) # Set the number of columns.
	tree.set_column_title(0,"Object Placer") # Name the first column as "Object Placer".
	tree.connect("item_selected", _on_item_selected) # Connect the _on_item_selected to the item_selected func.

# Look for every file on the filesystem and put the .tscn scenes on tree.
func add_items_to_tree(path: String, parent: TreeItem) -> void:
	var dir := DirAccess.open(path) # Variable to store ever path in the filesystem
	if dir == null: # Return if there's no path or if they can't open.
		print("Can't open: ", path)
		return

	dir.list_dir_begin() # Start to open files.
	var file_name := dir.get_next() # Get the file name.
	while file_name != "": # Ignore the path's with no name or if they being with "."
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name) # Get the full path.
		var is_folder := dir.current_is_dir() # Verify if is a folder

		if is_folder: # If is folder, read every file.
			add_items_to_tree(full_path, parent)
		else:
			if file_name.ends_with(".tscn"): # Add the .tscn file to tree
				var item := tree.create_item(parent)
				item.set_text(0, file_name)
				item.set_metadata(0, full_path)
				item.set_icon(0, EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons"))

		file_name = dir.get_next() # Go to next file.
	dir.list_dir_end() # Stop reading



# Update the tree node and enable the placement.
func _on_enable_button_toggled(toggled_on: bool) -> void:
	enabled = toggled_on # Enable the placement.
	var edited_scene = EditorInterface.get_edited_scene_root() # Get the root scene.
	if enabled:
		tree.clear() # Clear the tree wen enable is true

		var root := tree.create_item() # Root folder.
		add_items_to_tree("res://", root)
		if not GIZMO: # Gizmo stantiate and logic.
			GIZMO = gizmo_scene.instantiate()
		edited_scene.add_child(GIZMO)
	else:
		if GIZMO:
			GIZMO.queue_free()
			GIZMO = null

# Put the gizmo on the mouse position
func _process(delta: float) -> void:
	if enabled and collision(): # If the placement is enabled and the mouse is on a collision object, put the gizmo on mouse pos.
		GIZMO.position = collision().get("position")
		GIZMO.scale = Vector3(placementrange.value, placementrange.value, placementrange.value)

# Get the ssmp (Screen Space Mouse Position).
func collision() -> Dictionary:
	var camera : Camera3D = EditorInterface.get_editor_viewport_3d().get_camera_3d() # Get the editor camera.
	var range : int = 1000 # Ray lenght.
	var mouse_pos : Vector2 = EditorInterface.get_editor_viewport_3d().get_mouse_position() # Editor mouse position
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_pos) # Origin of ray.
	var ray_end : Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * range # End point of ray.
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)  # Make the raycast.
	var collision : Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query) # Get the info of the object that collided with the ray.
	if collision: # Return the dictionary
		return collision
	return collision

# 3D placement logic.
func _input(event):
	if not enabled:
		return

	if event is InputEventMouseButton and event.pressed: # Verify if the mouse button was pressed and if the mouse is on the viewport.
		var vp_rect = EditorInterface.get_editor_viewport_3d().get_visible_rect() # Get the viewport.
		var mouse_pos = event.position

		if not vp_rect.has_point(mouse_pos): # Return if the click position was off the viewport.
			return

	# Make sure that the input is from the left mouse position.

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed and not event.is_echo() \
	and object_path != null:

# If the mouse position is on a object, make the placement logic.

		if collision():
			var center_pos = collision().get("position")
			var edited_scene = EditorInterface.get_edited_scene_root()
			if not edited_scene:
				return
			# Undo redo

			var undo_redo = EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Place Objects")

			for i in range(placementdensity.value): # Placement Density
				var obj = load(object_path).instantiate()
				var random_offset = Vector3(
					randf_range(0, placementrange.value), # Placement Range
					0,
					randf_range(0, placementrange.value)
				)
				var random_scale : float = randf_range(scaleRangeMin.value, scaleRangeMax.value)

				if can_rotate:
					obj.rotation.y = randf()
				if can_scale:
					obj.position = center_pos + random_offset + (Vector3(OffsetX.value, OffsetY.value, OffsetZ.value) * random_scale)
					obj.scale = Vector3(random_scale, random_scale, random_scale)
				else:
					obj.position = center_pos + random_offset + Vector3(OffsetX.value, OffsetY.value, OffsetZ.value)
				undo_redo.add_do_method(edited_scene, "add_child", obj)
				undo_redo.add_do_method(obj, "set_owner", edited_scene)
				undo_redo.add_undo_method(edited_scene, "remove_child", obj)

			undo_redo.commit_action()




# Update the obect_path with the item selected.
func _on_item_selected() -> void:
	var selected = tree.get_selected()
	if selected:
		var path = selected.get_metadata(0)
		object_path = path

func _on_random_rotation_enabler_toggled(toggled_on: bool) -> void:
	can_rotate = toggled_on

func _on_random_scale_enabler_toggled(toggled_on: bool) -> void:
	can_scale = toggled_on
	scaleRangeMax.editable = toggled_on
	scaleRangeMin.editable = toggled_on
