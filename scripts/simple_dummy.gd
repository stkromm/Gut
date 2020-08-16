extends Node

class_name SimpleDummy, "res://scripts/simple_dummy.gd"
	
func conditional(condition):
	if condition:
		print("Hello")
	else:
		print("Bye")

func match_conditional(condition):
	match condition:
		"a":
			print(condition)
		_:
			print("Default")
