extends Node

class_name TestCoverageMetricsInjector, "res://addons/gut/coverage_injector.gd"

var script_injections = {}
var res_key = ""
var exclude_path = "res://test"

func get_test_report():
	return {}

func get_object_script(obj):
	if obj is Reference:
		return obj.script
	return obj.get_script()

func get_object_script_path(obj):
	if obj is Reference:
		return obj.script.resource_path
	return obj.get_script().resource_path

func not_injectable(obj):
	var object_script = get_object_script(obj)
	if object_script == null:
		return true
	var object_script_path = get_object_script_path(obj)

func inject_test_metrics(obj):
	var object_script = get_object_script(obj)
	if object_script == null:
		return
	var object_script_path = get_object_script_path(obj)
	if exclude_path in object_script_path:
		return
	if "res://" == object_script_path:
		return

	var script = fetch_script(obj)
	obj.set_script(script)
	return

func fetch_script(obj):
	if obj.get_script() == null:
		return null
	res_key = obj.get_script().resource_path
	if res_key in script_injections:
		return script_injections[res_key]
	var script = generate_script(obj)
	script_injections[res_key] = script
	return script

func generate_script(obj):
	var script : Script = GDScript.new()
	var generator = TreeGenerator.new()
	var blocks = generator.generate_tree(obj)
	var consumer = TreeConsumer.new()
	consumer.print_dot(blocks["blocks"])
	consumer.print_source(blocks)
	
	script.set_source_code(obj.get_script().get_source_code())
	script.reload()
	return script

class TreeConsumer:
	
	var node_counter = 0
	var testSuite = TestSuite.new()
	
	func print_dot(blocks):
		print("digraph G {")
		for block in blocks:
			_traverse_dot(block, block["method_name"])
		print("}")
		
	func _traverse_dot(block, name):
		for line in block["lines"]:
			var id = str(node_counter)
			node_counter += 1
			print(str(id) + " [label=\"" + line["line"].strip_edges().replace("\"", "\\\"")  + "\"];");
			print(name + " -> " + str(id))
			if "lines" in line and len(line["lines"]) != 0:
				_traverse_dot(line, id)
	
	func print_source(blocks):
		#IF current line is IF/Match/For/While -> Create new metadata
		#IF current line is match condition, else, elif -> Connect to previous metadata
		#At start of method -> Create new metadata
		#After any control flow -> Create new metadata
		#If line is empty, mark line as skip line
		#At metadata terminate, add all previous lines to metadata
		for line in blocks["header"]:
			print(line)
		
		for block in blocks["blocks"]:
			print(block["line"])
			testSuite.new_test_data(block["lines"].front()["line_nr"])
			_print_source(block)
			print()
	
		print(testSuite.test_data)
	
	func _print_source(block):
		for line in block["lines"]:
			testSuite.add_line(line["line_nr"])
			print(line["line"])
			if "lines" in line and len(line["lines"]) != 0:
				testSuite.new_test_data(block["lines"].front()["line_nr"])
				_print_source(line)
				


class TestSuite:
	
	var test_data = {}
	var block_counter = 0
	
	#TODO blocks have the correct lines
	#TODO control flows connect to correct previous blocks
	#TODO signals are generated
	
	func new_test_data(index) -> String:
		test_data[block_counter] = {"line_nrs": []}
		block_counter += 1
		return _generate_signal_string()
		
	func add_line(index) -> void:
		test_data[block_counter - 1].line_nrs.append(index)
		
	func connect_to_previous(lines, index) -> String:
		return _generate_signal_string()
		
	func _generate_signal_string() -> String:
		return ""

class TreeGenerator:
	var regex = {}
	var index = 1
	var blocks = []
	var lines = {}
		
	func _indentation(line) -> int:
		var result = regex["indentation"].search(line)
		if result:
			return len(result.get_string("indentation"))
		return 0
		
	func generate_tree(obj):
		__init_regex()
		lines = _source_to_dictionary(obj)
		index = 1
		
		while index <= len(lines):
			var current_line = lines[index]
			var result = regex["func"].search(current_line)
			if result:
				blocks.append({"lines": [], "method_name": result.get_string("symbol"), "line": current_line})
				index += 1
				blocks.back().lines = _gather_lines(lines, _indentation(lines[index]))
			index += 1
		
		var header = []
		if len(blocks) > 0:
			var end = blocks.front().lines.front()["line_nr"] - 1
			for x in range(1, end):
				header.append(lines[x])
		
		return {"blocks": blocks, "header": header}
	
	func _gather_lines(lines, indentation):
		var result = []
		while index <= len(lines):
			var current_line = lines[index]
			if _indentation(current_line) == indentation:
				result.append({"line": current_line, "line_nr": index})
				index += 1
			if _indentation(current_line) > indentation:
				result.back().lines = _gather_lines(lines, indentation + 1)
			if _indentation(current_line) < indentation:
				return result
		return result

	func _source_to_dictionary(obj):
		var lines = {}
		var line = ""
		var nr = 1
		for c in obj.get_script().get_source_code():
			if c != '\n':
				line += c
			else:
				lines[nr] = line
				nr += 1
				line = ""
		lines[nr] = line
		nr += 1
		line = ""
		return lines

	func __init_regex():
		if len(regex) == 0:
			regex["func"] = __regex_factory("^(?<indentation>\t*)func (?<symbol>.*)\\(.*:?(.*)$")
			regex["skip"] = __regex_factory("^\\s$")
			regex["pass"] = __regex_factory("^\\spass$")
			regex["branch"] = __regex_factory("^(?<indentation>\t+)((?<conditional>if|else|elif|while|for|match).*:)\\s*(#.*)*$")
			regex["match_condition"] = __regex_factory("^((?!if|else|elif|match|func|while|for)(?<indentation>\t+)\"*.)*\"*:$")
			regex["indentation"] = __regex_factory("^(?<indentation>\t*)")
			regex["line"] = __regex_factory("^(?<indentation>\t*)(?<other>.*)")

	func __regex_factory(pattern):
			var regex = RegEx.new()
			regex.compile(pattern)
			return regex
