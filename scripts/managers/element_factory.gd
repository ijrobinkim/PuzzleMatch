# res://scripts/managers/element_factory.gd
class_name ElementFactory
extends Node

var _registry: Dictionary = {}

func register_element_script(element_id: String, script_res: Script) -> void:
	_registry[element_id] = script_res

func create_element(element_id: String) -> BaseElement:
	if not _registry.has(element_id):
		push_warning("ElementFactory: Unregistered element_id '%s'" % element_id)
		return null
	
	var script_res: Script = _registry[element_id]
	var element: BaseElement = script_res.new() as BaseElement
	if element != null:
		element.element_id = element_id
	return element
