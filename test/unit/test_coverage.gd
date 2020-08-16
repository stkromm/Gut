extends 'res://addons/gut/test.gd'

var loaded_dummy = load("res://scripts/dummy.gd")
var simple
var dummy

func before_each():
	dummy = loaded_dummy.new()
	#simple = SimpleDummy.new()
	add_child(dummy)
	#add_child(simple)

func test_test():
	var report = _utils.get_coverage_injector().get_test_report()
	pass

func after_all():
	for child in get_children():
		remove_child(child)
		child.queue_free()
