@tool
extends Control

var _rotation : Vector3
var _current_tab : String
var _current_context : String
var _fd_export_path : String
var _fd_import_path : String

@onready var _right_click_menu = $PopupMenu as PopupMenu
@onready var _lineedit_popup = $LineEditPopup as PopupPanel
@onready var _lineedit = _lineedit_popup.get_child(0) as LineEdit
@onready var palette_item_list = find_child("Props Palette") as ItemList
@onready var tabbar = find_child("TabBar") as TabBar
@onready var _palette_context_menu := ["Remove"]
@onready var _tabbar_context_menu := ["Remove", "Rename"]
@onready var _tab_name_lineedit = find_child("Add tab") as LineEdit
@onready var parent = find_child("Parent")
@onready var _import_dialog = find_child("ImportDialog") as FileDialog
@onready var _export_dialog = find_child("ExportDialog") as FileDialog

const CONTEXT_PALETTE := "Palette"
const CONTEXT_TABBAR := "TabBar"

signal rotation_values_changed(_rotation : Vector3)
signal scale_mult_changed(value : float)
signal base_scale_changed(value : float)
signal margin_value_changed(value : float)
signal alignment_toggled(value : bool)
signal tab_selected(tab : String)
signal palette_remove_selected(selected_items : Array)
signal add_tab(library : String)
signal tabbar_remove_tab(selected_tab : int)
signal tabbar_rename_tab(selected_tab : int, title : String)
signal tab_order_on_exit(tab_order : Array)
signal import_library()
signal export_confirmed(path : String)
signal import_confirmed(path : String)
signal palette_drop_data_added(path: String, tab: String)


func _ready():

	_import_dialog.title = "Import Asset Library"
	_export_dialog.title = "Export Asset Library"
	palette_item_list.p_drop_data_added.connect(_palette_drop_data)

	# _on_export_dialog_confirmed() doesn't emit when the user confirms with the Enter key.
	# Hence this solution.
	#_export_dialog.get_line_edit().text_submitted.connect(_export_submitted)
	#_import_dialog.get_line_edit().text_submitted.connect(_import_submitted)
	pass


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


func set_scale_value(value : float):
	self.find_child("Scale").value = value

func set_base_scale(value : float):
	self.find_child("Base Scale").value = value

func set_margin_value(value : float):
	self.find_child("Margin").value = value


func _on_rotation_x_value_changed(value):
	_rotation.x = value
	rotation_values_changed.emit(_rotation)
func _on_rotation_y_value_changed(value):
	_rotation.y = value
	rotation_values_changed.emit(_rotation)
func _on_rotation_z_value_changed(value):
	_rotation.z = value
	rotation_values_changed.emit(_rotation)


func _on_scale_value_changed(value):
	scale_mult_changed.emit(value)

func _on_base_scale_value_changed(value):
	base_scale_changed.emit(value)

func _on_margin_value_changed(value):
	margin_value_changed.emit(value)


func _on_alignment_toggle_toggled(button_pressed):
	alignment_toggled.emit(button_pressed)


func _on_library_name_text_submitted(tab_title : String):
	# Check for duplicates!
	_tab_name_lineedit.clear()
	add_tab.emit(tab_title)


func _on_tab_bar_tab_selected(idx):
	_current_tab = tabbar.get_tab_title(idx)
	#_previous_tab_idx = idx
	tab_selected.emit(_current_tab)


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


func _on_import_pressed():
	_import_dialog.visible = true
	pass # Replace with function body.


func _on_export_pressed():
	_export_dialog.visible = true
	pass # Replace with function body.


func _on_export_dialog_file_selected(path):
	export_confirmed.emit(path)
	_export_dialog.get_line_edit().clear()
	_fd_export_path = path
	pass # Replace with function body.


func _on_import_dialog_file_selected(path):
	import_confirmed.emit(path)
	_import_dialog.get_line_edit().clear()
	_fd_import_path = path
	pass # Replace with function body.

func _palette_drop_data(path : String):
	palette_drop_data_added.emit(path, _current_tab)
	pass
