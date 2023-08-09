@tool
extends Control

var _rotation : Vector3
var _current_tab : String
var _current_context : String
var _fd_export_path : String
var _fd_import_path : String

@onready var palette_item_list = find_child("Props Palette") as ItemList
@onready var tabbar = find_child("TabBar") as TabBar
@onready var parent = find_child("Parent")
@onready var _right_click_menu = $PopupMenu as PopupMenu
@onready var _lineedit_popup = $LineEditPopup as PopupPanel
@onready var _icon_size_spinbox = find_child("icon_size_spinbox") as SpinBox
@onready var _lineedit = _lineedit_popup.get_child(0) as LineEdit
@onready var _palette_context_menu := ["Remove"]
@onready var _tabbar_context_menu := ["Remove", "Rename"]
@onready var _tab_name_lineedit = find_child("Add tab") as LineEdit
@onready var _options_mb = find_child("Options") as MenuButton
@onready var _import_dialog = find_child("ImportDialog") as FileDialog
@onready var _export_dialog = find_child("ExportDialog") as FileDialog

const CONTEXT_PALETTE := "Palette"
const CONTEXT_TABBAR := "TabBar"

signal rotation_values_changed(_rotation : Vector3)
signal scale_mult_changed(value : float)
signal base_scale_changed(value : float)
signal margin_value_changed(value : float)
signal alignment_toggled(value : bool)
signal tab_selected()
signal palette_remove_selected(selected_items : Array)
signal add_tab(library : String)
signal tabbar_remove_tab(selected_tab : int)
signal tabbar_rename_tab(selected_tab : int, title : String)
signal tab_order_on_exit(tab_order : Array)
signal import_library()
signal export_confirmed(path : String)
signal import_confirmed(path : String)
signal palette_drop_data_added(file_paths : Array, tab: String)
signal icon_size_submitted(size : int)

func _ready():
	# Had issues with titles not updating in Editor.
	_import_dialog.title = "Import Asset Library"
	_export_dialog.title = "Export Asset Library"

	palette_item_list.p_drop_data_added.connect(_palette_drop_data)
	_options_mb.get_popup().index_pressed.connect(_options_pressed)
	_icon_size_spinbox.get_line_edit().text_submitted.connect(_on_icon_size_submitted)


func _exit_tree():
	var tab_order := []
	for idx in tabbar.tab_count:
		tab_order.append(tabbar.get_tab_title(idx))
	tab_order_on_exit.emit(tab_order)


func set_rotation_vector3(rot : Vector3):
	self.find_child("Rotation X").value = rot.x
	self.find_child("Rotation Y").value = rot.y
	self.find_child("Rotation Z").value = rot.z
	_rotation = rot

func _on_rotation_x_value_changed(value):
	_rotation.x = value

	rotation_values_changed.emit(_rotation)
func _on_rotation_y_value_changed(value):
	_rotation.y = value
	rotation_values_changed.emit(_rotation)

func _on_rotation_z_value_changed(value):
	_rotation.z = value
	rotation_values_changed.emit(_rotation)


func set_scale_value(value : float):
	self.find_child("Scale").value = value
func _on_scale_value_changed(value):
	scale_mult_changed.emit(value)

func set_base_scale(value : float):
	self.find_child("Base Scale").value = value
func _on_base_scale_value_changed(value):
	base_scale_changed.emit(value)

func set_margin_value(value : float):
	self.find_child("Margin").value = value
func _on_margin_value_changed(value):
	margin_value_changed.emit(value)

func set_icon_size(value: int):
	_icon_size_spinbox.value = value
func _on_icon_size_submitted(value : String):
	var int_value = value.to_int()
	if !int_value > 0:
		printerr("Icon size must be a positive integer.")
		return

	icon_size_submitted.emit(int_value)


func _on_alignment_toggle_toggled(button_pressed):
	alignment_toggled.emit(button_pressed)


func _on_library_name_text_submitted(tab_title : String):
	_tab_name_lineedit.clear()
	add_tab.emit(tab_title)


func _on_tab_bar_tab_selected(idx):
	_current_tab = tabbar.get_tab_title(idx)
	tab_selected.emit()


func _on_props_palette_item_clicked(index, at_position, mouse_button_index):
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_current_context = CONTEXT_PALETTE
		_context_popup()


func _on_tab_bar_tab_rmb_clicked(tab):
	_current_context = CONTEXT_TABBAR
	_context_popup()


func _context_popup():
	_right_click_menu.clear()

	if _current_context == CONTEXT_PALETTE:
		for menu_item in _palette_context_menu:
			_right_click_menu.add_item(menu_item)

	if _current_context == CONTEXT_TABBAR:
		for menu_item in _tabbar_context_menu:
			_right_click_menu.add_item(menu_item)

	if _current_tab == "All":
		_right_click_menu.set_item_disabled(0, true)
		if _current_context == CONTEXT_TABBAR:
			_right_click_menu.set_item_disabled(1, true)

	var mouse_pos = DisplayServer.mouse_get_position()
	_right_click_menu.set_position(mouse_pos)
	_right_click_menu.popup()


func _on_popup_menu_index_pressed(index):
	if _current_context == CONTEXT_PALETTE:
		if index == 0:
			palette_remove_selected.emit(palette_item_list.get_selected_items())
	if _current_context == CONTEXT_TABBAR:
		if index == 0:
			tabbar_remove_tab.emit(tabbar.current_tab)
		if index == 1:
			lineedit_popup()


func lineedit_popup():
	var mouse_pos = DisplayServer.mouse_get_position()
	var lineedit_popup_size = _lineedit_popup.size
	_lineedit_popup.set_position(mouse_pos - lineedit_popup_size/2)
	_lineedit_popup.popup()


func _on_line_edit_text_submitted(new_text):
	tabbar_rename_tab.emit(tabbar.current_tab, new_text)
	_lineedit.clear()
	_lineedit_popup.hide()


func _on_line_edit_popup_popup_hide():
	_lineedit.clear()

func _options_pressed(idx : int):
	if idx == 0:
		_import_dialog.visible = true
	elif idx == 1:
		_export_dialog.visible = true

# Import/export libraries
func _on_import_dialog_file_selected(path):
	import_confirmed.emit(path)
	_import_dialog.get_line_edit().clear()
	_fd_import_path = path

func _on_export_dialog_file_selected(path):
	export_confirmed.emit(path)
	_export_dialog.get_line_edit().clear()
	_fd_export_path = path

# User drops files onto the palette
func _palette_drop_data(file_paths : Array):
	palette_drop_data_added.emit(file_paths, _current_tab)

func get_preview_texture(child : Node3D, resolution: int) -> ImageTexture:
	var child_aabb : AABB = _get_aabb(child)
	var child_size : Vector3 = abs(child_aabb.size)
	var max_dim = max(child_size.x, child_size.y, child_size.z)

	var _viewport : SubViewport = get_node("SubViewport") as SubViewport
	_viewport.size = Vector2i(resolution, resolution)

	_viewport.add_child(child)
	var _child = _viewport.get_child(2)
	# Rotate 45 degrees
	_child.rotate_y(TAU/8.0)

	var camera : Camera3D = _viewport.get_child(0)
	var cam_pos = camera.position
	camera.size = max_dim
	# Looks okay for now. To-do: get the transformed AABB.
	camera.position += Vector3(0, child_aabb.end.y * 0.5, 0)

	await RenderingServer.frame_post_draw
	var img = camera.get_viewport().get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)

	_viewport.remove_child(child)
	child.queue_free()
	camera.position = cam_pos

	return tex

# Move to util.gd
func _get_aabb(visual_instance : Node3D) -> AABB:
	# To-do: In case of multiple meshes, merge them and get the combined AABB.
	var meshes = visual_instance.find_children("*", "MeshInstance3D", true, false)
	var aabb : AABB = meshes[0].mesh.get_aabb()

	return aabb
