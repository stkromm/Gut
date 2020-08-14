extends 'res://addons/gut/test.gd'

var loaded_dummy = load("res://scripts/dummy.gd")
var dummy

func before_each():
	dummy = loaded_dummy.new()
	add_child(dummy)
	

func test_test():
	var t = load("res://addons/gut/test.gd").new()
	add_child(t)
	dummy.conditional(true)

func after_all():
	for child in get_children():
		remove_child(child)
