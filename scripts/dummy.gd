extends Node

class_name Dummy, "res://scripts/dummy.gd"
	
func conditional(condition):
	if condition:
		print("Hello")
	else:
		print("Bye")

func a_conditional(condition): #Something goes here
	if condition: #Test here
		print("Condition") #	else:
	else:
		print("Hi")
	#	if a == b:
	print(condition)
