extends Node2D

class_name Suite, "res://addons/gut/suite.gd"

var test_data = {}

func _ready():
	pass 

func register_new_script(key, data):
	test_data[key] = data

func on_visit(name, line_nr, res_path):
	test_data[res_path].blocks[line_nr].visited = true
	test_data[res_path].methods[name] = true
	
func get_test_data():
	return test_data
	
func generate_report():
	var report = {}
	for key in test_data:
		report[key] = test_data[key].generate_report()
	return report
