@tool
extends ItemList


signal p_drop_data_added(file_paths : Array)

# Move to gui_handler
func add_to_list(path: String, preview: Texture2D):
	var item_len = get_item_count()
	add_item(path.get_file(), preview, true)
	set_item_metadata(item_len, path)
	notify_property_list_changed()


func _can_drop_data(at_position, data):
	# need to implement checks.
	return true


func _drop_data(at_position, data):
	var file_paths = data["files"]
	p_drop_data_added.emit(file_paths)


func _on_deselect_pressed():
	deselect_all()
