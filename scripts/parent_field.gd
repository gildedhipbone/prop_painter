@tool
extends Button

signal drop_data_added(parent)

func _can_drop_data(at_position, data):
	# Implement better checks.
	return data.has("nodes") and get_node(data["nodes"][0]) is Node3D

func _drop_data(at_position, data):
	var parent : Node3D = get_node(data["nodes"][0])
	self.text = parent.name
	drop_data_added.emit(parent)
