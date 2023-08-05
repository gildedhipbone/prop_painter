#settings.gd
extends Resource
class_name PropPainterSettings

@export var libraries : Dictionary
@export var parent : Node3D
@export var rotation : Vector3 = Vector3.ZERO
@export var scale : float = 0.0
@export var base_scale : float = 1.0
@export var brush_size : float = 2.0
@export var margin : float = 5.0
@export var tab_order : Array
