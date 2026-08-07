# res://scripts/managers/element_factory.gd
class_name ElementFactory
extends Node

var _registry: Dictionary = {}

const DEFAULT_ELEMENT_SCRIPTS := {
	"box": "res://scripts/elements/concrete/box_element.gd",
	"snow": "res://scripts/elements/concrete/snow_element.gd",
	"ivy": "res://scripts/elements/concrete/ivy_element.gd",
	"column": "res://scripts/elements/concrete/column_element.gd",
	"birdhouse": "res://scripts/elements/concrete/birdhouse_element.gd",
	"steam_bomb": "res://scripts/elements/concrete/steam_bomb_element.gd",
	"dragon_box": "res://scripts/elements/concrete/dragon_box_element.gd",
}

func _init() -> void:
	_register_defaults()

func _register_defaults() -> void:
	for elem_id in DEFAULT_ELEMENT_SCRIPTS:
		var path: String = DEFAULT_ELEMENT_SCRIPTS[elem_id]
		if ResourceLoader.exists(path):
			_registry[elem_id] = load(path)

func register_element_script(element_id: String, script_res: Script) -> void:
	_registry[element_id] = script_res

func create_element(element_id: String) -> BaseElement:
	if not _registry.has(element_id):
		if DEFAULT_ELEMENT_SCRIPTS.has(element_id):
			var path: String = DEFAULT_ELEMENT_SCRIPTS[element_id]
			if ResourceLoader.exists(path):
				_registry[element_id] = load(path)

	if not _registry.has(element_id):
		push_warning("ElementFactory: Unregistered element_id '%s'" % element_id)
		return null
	
	var script_res: Script = _registry[element_id]
	var element: BaseElement = script_res.new() as BaseElement
	if element != null:
		element.element_id = element_id
	return element

