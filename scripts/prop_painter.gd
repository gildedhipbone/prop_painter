@tool
extends EditorPlugin

const ACTION_NONE = -1
const ACTION_STROKE = 0
const ACTION_ERASE = 1

var _editor: EditorInterface
var _preview: EditorResourcePreview
var _scene_root : Node3D
var _prop_painter_dock
var _current_camera : Camera3D = null
var _brush : MeshInstance3D
var _brush_material : ShaderMaterial
var _align_to_surface_normal : bool = false
var _mouse_position : Vector2
var _current_action := ACTION_NONE
var _current_selection : Array
var _placed_props : Array
var _last_placed_prop : Node
var _current_tab_title : String
var _scene_info : Dictionary
var _parent : Node3D

@onready var _tabbar : TabBar = _prop_painter_dock.tabbar
@onready var _palette : ItemList = _prop_painter_dock.palette_item_list
@onready var _parent_field : Button = _prop_painter_dock.parent
@onready var _prop_painter_settings = load("res://addons/prop_painter/resources/settings.tres") as PropPainterSettings

const RAY_LENGTH = 1000.0


func _enter_tree():
	add_custom_type("PropPainterSettings", "Resource", preload("../scripts/prop_painter_settings.gd"), null)
	# Create a settings resource file if one doesn't exist.
	if (!ResourceLoader.exists("res://addons/prop_painter/resources/settings.tres")):
		var pp_settings = PropPainterSettings.new()
		pp_settings.libraries["All"] = []
		ResourceSaver.save(pp_settings, "res://addons/prop_painter/resources/settings.tres")

	_prop_painter_dock = preload("../scenes/prop_painter.tscn").instantiate()
	add_control_to_bottom_panel(_prop_painter_dock, "Prop Painter")

	_brush_material = preload("../materials/brush_material.tres")

	_editor = get_editor_interface()
	_preview = _editor.get_resource_previewer()


func _ready():
	# Load settings.
	_prop_painter_dock.set_rotation_vector3(_prop_painter_settings.rotation)
	_prop_painter_dock.set_margin_value(_prop_painter_settings.margin)
	_prop_painter_dock.set_scale_value(_prop_painter_settings.scale)
	_prop_painter_dock.set_base_scale(_prop_painter_settings.base_scale)

	_prop_painter_dock.palette_drop_data_added.connect(_add_prop)
	_prop_painter_dock.parent.drop_data_added.connect(_set_parent)
	_prop_painter_dock.rotation_values_changed.connect(_set_rotation)
	_prop_painter_dock.scale_mult_changed.connect(_set_scale)
	_prop_painter_dock.base_scale_changed.connect(_set_base_scale)
	_prop_painter_dock.margin_value_changed.connect(_set_margin)
	_prop_painter_dock.alignment_toggled.connect(_set_alignment)
	_prop_painter_dock.tab_selected.connect(_update_selected_tab)
	_prop_painter_dock.palette_remove_selected.connect(_remove_prop)
	_prop_painter_dock.tabbar_remove_tab.connect(_remove_tab)
	_prop_painter_dock.tabbar_rename_tab.connect(_rename_tab)
	_prop_painter_dock.tab_order_on_exit.connect(_tab_order)
	_prop_painter_dock.add_tab.connect(_add_tab)
	_prop_painter_dock.import_library.connect(_import_library)
	_prop_painter_dock.export_confirmed.connect(_export_library)
	_prop_painter_dock.import_confirmed.connect(_import_library)
	self.scene_closed.connect(_scene_closed)
	self.scene_changed.connect(_switched_scene)

	if !_prop_painter_settings.tab_order.is_empty():
		for lib in _prop_painter_settings.tab_order:
			_tabbar.add_tab(lib)
	else:
		for lib in _prop_painter_settings.libraries:
			_tabbar.add_tab(lib)
			_prop_painter_settings.tab_order.append(lib)

	_current_tab_title = _tabbar.get_tab_title(_tabbar.current_tab)

	_update_master_uid_list()
	_update_selected_tab(_tabbar.get_tab_title(_tabbar.current_tab))


func _exit_tree():
	remove_custom_type("PropPainterSettings")

	if _brush != null and _brush.get_parent() != null:
		_scene_root.remove_child(_brush)

	if _brush != null:
		_brush.queue_free()

	remove_control_from_bottom_panel(_prop_painter_dock)
	_prop_painter_dock.queue_free()


func _handles(_object):
	# Handle everything.
	return true


func _forward_3d_gui_input(viewport_camera, event):
	if _parent == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if _palette.get_selected_items().size() == 0:
		_brush.hide()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	_brush.show()
	# Get the editor camera. Is there a better way?
	if _current_camera != viewport_camera:
		_current_camera = viewport_camera

	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			_brush.hide()
			_palette.deselect_all()
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		_mouse_position = event.position

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						_current_action = ACTION_STROKE
					MOUSE_BUTTON_MASK_RIGHT:
						_current_action = ACTION_ERASE
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				_current_action = ACTION_NONE
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _physics_process(delta):
	if _current_camera == null:
		return

	var origin = _current_camera.project_ray_origin(_mouse_position)
	var end = origin + _current_camera.project_ray_normal(_mouse_position) * RAY_LENGTH

	_paint(origin, end)

# Move to util.gd
func _create_sphere(radius) -> MeshInstance3D:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = _brush_material

	return mesh_instance


func _paint(origin, end):
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	var space_state = _current_camera.get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return

	_brush.position = result.position

	if _current_action == ACTION_STROKE:
		_stroke(result.position, result.normal)
	elif _current_action == ACTION_ERASE:
		_erase(result.position)


func _stroke(position : Vector3, normal : Vector3):
	_current_selection.clear()

	var selected_in_palette = _palette.get_selected_items()

	for idx in selected_in_palette:
		var uid = _prop_painter_settings.libraries[_current_tab_title][idx]
		_current_selection.append(uid[1])

	var random_prop = randi_range(0, _current_selection.size()) - 1

	_instantiate_prop(_current_selection[random_prop], position, normal)


func _erase(brush_pos : Vector3):
	var idx : int = 0
	for a in _placed_props:
		if (brush_pos.distance_to(a.position) < 1.0):
			var child = _parent.find_child(a.name)
			# Add option to allow erase to target any of parent's children?
			_parent.remove_child(child)
			# Regarding undo/redo: How many can we keep in memory until we must queue_free?
			child.queue_free()
			_placed_props.remove_at(idx)
		idx += 1


func _instantiate_prop(uid, position : Vector3, normal : Vector3):
	if _last_placed_prop != null:
		if !_distance_ok(position):
			return

	var prop_path : String = ResourceUID.get_id_path(uid)
	var filename : String = prop_path.get_basename().get_file()

	var prop_instance

	if _prop_painter_settings.scene_formats.has(prop_path.get_extension()):
		prop_instance = load(prop_path).instantiate()
		_parent.add_child(prop_instance)
		prop_instance.owner = _scene_root
		prop_instance.position = position

	elif _prop_painter_settings.res_formats.has(prop_path.get_extension()):
		var res = load(prop_path)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = res
		prop_instance = mesh_instance
		_parent.add_child(prop_instance)
		prop_instance.owner = _scene_root
		prop_instance.global_transform.origin = position
	# Gets pretty slow.
	prop_instance.name = filename

	prop_instance.rotate_x(randf_range(-1.0, 1.0) * TAU * _prop_painter_settings.rotation.x)
	prop_instance.rotate_y(randf_range(-1.0, 1.0) * TAU * _prop_painter_settings.rotation.y)
	prop_instance.rotate_z(randf_range(-1.0, 1.0) * TAU * _prop_painter_settings.rotation.z)

	var _rand_scale : float = 1.0 + ((_prop_painter_settings.scale) * randf_range(-1.0, 1.0))
	prop_instance.scale *= _prop_painter_settings.base_scale * _rand_scale

	if _align_to_surface_normal:
		prop_instance.transform = _align_with_y(prop_instance.transform, normal)

	_placed_props.append(prop_instance)
	_last_placed_prop = prop_instance


func _distance_ok(position : Vector3) -> bool:
	# Pretty bad...
	if position.distance_to(_last_placed_prop.position) > _prop_painter_settings.margin:
		return true
	return false

# move to util.gd
func _align_with_y(transf : Transform3D, normal : Vector3):
	var scale = transf.basis.get_scale()

	transf.basis.x = normal.cross(transf.basis.z)
	transf.basis.y = normal
	transf.basis.z = transf.basis.x.cross(normal)

	transf.basis = transf.basis.orthonormalized()

	transf.basis.x *= scale.x
	transf.basis.y *= scale.y
	transf.basis.z *= scale.z

	return transf


func _update_selected_tab(tab : String):
	_palette.clear()

	_current_tab_title = _tabbar.get_tab_title(_tabbar.current_tab)

	var sorted_library = _sort_library(_prop_painter_settings.libraries[_current_tab_title])
	_prop_painter_settings.libraries[_current_tab_title] = sorted_library

	if _prop_painter_settings.libraries[_current_tab_title].size() != 0:

		for uid in _prop_painter_settings.libraries[_current_tab_title]:
			var prop_path : String = ResourceUID.get_id_path(uid[1])

			var preview : ImageTexture

			if _prop_painter_settings.previews.has(uid[1]):
				preview = _prop_painter_settings.previews[uid[1]]

			else:
				var _asset_to_preview

				if _prop_painter_settings.scene_formats.has(prop_path.get_extension()):
					_asset_to_preview = load(prop_path).instantiate()

				elif _prop_painter_settings.res_formats.has(prop_path.get_extension()):
					_asset_to_preview = load(prop_path)
					var mesh_instance := MeshInstance3D.new()
					mesh_instance.mesh = _asset_to_preview
					_asset_to_preview = mesh_instance

				preview = await _prop_painter_dock.get_preview_texture(_asset_to_preview, _prop_painter_settings.icon_size)
				_prop_painter_settings.previews[uid[1]] = preview

			_palette.add_to_list(prop_path, preview)

	notify_property_list_changed()


func _update_master_uid_list():
	_prop_painter_settings.libraries["All"].clear()
	var uids = []

	for key in _prop_painter_settings.libraries:

		if !key == "All" and !key.is_empty():

			for asset in _prop_painter_settings.libraries[key]:

				if !uids.has(asset[1]):
					_prop_painter_settings.libraries["All"].append(asset)
					uids.append(asset[1])
	# Erase preview images that no longer have matching UIDs.
	var erase_us = []

	if _prop_painter_settings.previews.size() != 0:
		for uid in _prop_painter_settings.previews:
			if !uids.has(uid):
				erase_us.append(uid)
	for uid in erase_us:
		_prop_painter_settings.previews.erase(uid)

	notify_property_list_changed()


func _add_prop(file_paths : Array, tab: String, update_tab : bool = true):
	var uids : Array = []

	for asset in _prop_painter_settings.libraries[tab]:
			uids.append(asset[1])

	for path in file_paths:
		var asset_name : String = path.get_basename().get_file()
		var uid = ResourceLoader.get_resource_uid(path)

		if !uids.has(uid):
			_prop_painter_settings.libraries[tab].append([asset_name, uid])

	_update_master_uid_list()
	if update_tab:
		_update_selected_tab(_tabbar.get_tab_title(_tabbar.current_tab))


func _remove_prop(marked_props):
	if _current_tab_title == "All":
		return

	var original : Array = marked_props
	var idx_shift : int = 0

	for idx in marked_props:
		_prop_painter_settings.libraries[_current_tab_title].remove_at(idx - idx_shift)
		_palette.remove_item(idx - idx_shift)
		idx_shift += 1

	_update_master_uid_list()
	_update_selected_tab(_tabbar.get_tab_title(_tabbar.current_tab))


func _add_tab(tab_title):
	if !_prop_painter_settings.libraries.has(tab_title):
		_prop_painter_settings.libraries[tab_title] = []
		_tabbar.add_tab(tab_title)


func _remove_tab(tab_idx):
	var tab_title = _tabbar.get_tab_title(tab_idx)
	_prop_painter_settings.libraries.erase(tab_title)
	_tabbar.remove_tab(tab_idx)

	_update_master_uid_list()
	_update_selected_tab(_tabbar.get_tab_title(_tabbar.current_tab))


func _rename_tab(tab_idx, new_title):
	if _prop_painter_settings.libraries.has(new_title):
		print("Library requires a unique name.")
		return

	var org_title = _tabbar.get_tab_title(tab_idx)
	var value_copy = _prop_painter_settings.libraries.get(org_title)

	_prop_painter_settings.libraries[new_title] = value_copy
	_prop_painter_settings.libraries.erase(org_title)
	_tabbar.set_tab_title(tab_idx, new_title)

	_prop_painter_settings.tab_order.clear()

	for i in _tabbar.tab_count:
		var title = _tabbar.get_tab_title(i)
		_prop_painter_settings.tab_order.append(title)
	_tabbar.clear_tabs()

	for t in _prop_painter_settings.tab_order:
		_tabbar.add_tab(t)

	_tabbar.current_tab = tab_idx


func _tab_order(tab_order : Array):
	_prop_painter_settings.tab_order = tab_order

func _set_rotation(rotation : Vector3):
	_prop_painter_settings.rotation = rotation

func _set_scale(value : float):
	_prop_painter_settings.scale = value

func _set_base_scale(value : float):
	_prop_painter_settings.base_scale = value

func _set_margin(value : float):
	_prop_painter_settings.margin = value

func _set_alignment(toggled : bool):
	_align_to_surface_normal = toggled

func _add_library(library_title: String):
	# Check for duplicates.
	_prop_painter_settings.libraries[library_title] = []


func _set_parent(new_parent : Node3D):
	_scene_root = _editor.get_edited_scene_root()
	_parent = new_parent
	_scene_info[_scene_root] = _parent
	_brush = _create_sphere(_prop_painter_settings.brush_size)
	_scene_root.add_child(_brush)
	_brush.hide()


func _switched_scene(new_scene : Node):
	_brush = _create_sphere(_prop_painter_settings.brush_size)

	if _scene_info.has(new_scene) and new_scene is Node3D:
		_scene_root = new_scene
		_scene_root.add_child(_brush)
		_parent = _scene_info.get(new_scene)
		_parent_field.text = _parent.name
	else:
		_scene_root = null
		_parent = null
		_parent_field.text = "..."


func _scene_closed(filepath : String):
	# Signal fires before the scene is closed, hence the timer.
	await get_tree().create_timer(.1).timeout
	# Not pretty. But for some reason is_instance_valid() returns true on closed scenes.
	for scene in _scene_info:
		if str(scene) == "<Freed Object>":
			_scene_info.erase(scene)

# Move to util.gd
func _import_library(path : String):
	var import_file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse((import_file.get_as_text()))
	var libraries = json.get_data() as Dictionary
	import_file.close()
	# Sloppy solution to ensure that the palette doesn't create duplicates.
	var count : int = 1
	var idx_last_tab : int = libraries.size()

	for tab in libraries:
		_add_tab(tab)

		var asset_paths = []

		for uid_path in libraries[tab]:
			var uid = ResourceUID.text_to_id(uid_path)
			# Check if the uid is known to the cache
			if ResourceUID.has_id(uid):
				var asset_path = ResourceUID.get_id_path(uid)
				asset_paths.append(asset_path)

		if !asset_paths.is_empty():
			if count != idx_last_tab:
				_add_prop(asset_paths, tab, false)
			else:
				_add_prop(asset_paths, tab, true)

		count += 1


# Move to util.gd
func _export_library(path : String):
	var data_to_send = {}
	for lib in _prop_painter_settings.libraries:
		if lib != "All":
			var uids = []
			for asset in _prop_painter_settings.libraries[lib]:
				var uid_string = ResourceUID.id_to_text(asset[1])
				uids.append(uid_string)
			data_to_send[lib] = uids

	var json_string = JSON.stringify(data_to_send)
	var export_file = FileAccess.open(path, FileAccess.WRITE)
	export_file.store_string(json_string)
	export_file.close()

func _custom_sort(a, b) -> bool:
	if a[0].naturalnocasecmp_to(b[0]) <= 0:
		return true
	else:
		return false

func _sort_library(library : Array) -> Array:
	# Create array [["name", uid]]
	var names_uids = []

	for uid in library:
		var asset_name : String = ResourceUID.get_id_path(uid[1]).get_basename().get_file()
		names_uids.append([asset_name, uid[1]])

	names_uids.sort_custom(_custom_sort)

	return names_uids
