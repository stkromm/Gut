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

func match_conditional(condition):
	match condition:
		1:
			print("First!")
		2:
			print("Second!")
		_:
			print("Defualt!")
	print("End")

func multi_conditional(condition_a, condition_b):
	match condition_a:
		1:
			if condition_b in range(0, 10):
				match condition_b:
					5:
						print("1-5")
					_:
						print("1-Deff")
		2:
			print("2")
		3:
			match condition_b:
				1:
					print("3-1")
				2:
					print("3-2")
				_:
					print("3-deff")
