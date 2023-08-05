@tool
extends ItemList

var _prop_preview: Texture2D

signal palette_drop_data_added(path)


func add_to_list(path: String, preview: Texture2D, thumbnail_preview: Texture2D, userdata):
	var item_len = get_item_count()
	#add_item(path.get_file(), null, true)
	add_item(path.get_file(), preview, true)
	set_item_metadata(item_len, path)
	notify_property_list_changed()


func _can_drop_data(at_position, data):
	# need to implement checks.
	return true


func _drop_data(at_position, data):
	var file_paths = data["files"]
	for p in file_paths:
		palette_drop_data_added.emit(p)


func _on_deselect_pressed():
	deselect_all()
