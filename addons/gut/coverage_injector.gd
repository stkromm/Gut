extends Node

class_name TestCoverageMetricsInjector, "res://addons/gut/coverage_injector.gd"

var regex = {}

var blocks = {}
var current_block = {}
var methods = {}
var script_injections = {}
var line_nr = 0
var skipped_lines = 0
var res_key = ""
var suite : Suite
var exclude_path = "res://test"
var match_block_stack : Array = []


func _ready():
	suite = Suite.new()
	suite._ready()
	add_child(suite)
	regex["func"] = _regex_factory("^(?<indentation>\t*)func (?<symbol>.*)\\(.*:?(.*)$")
	regex["skip"] = _regex_factory("^\\s$")
	regex["pass"] = _regex_factory("^\\spass$")
	regex["branch"] = _regex_factory("^(?<indentation>\t+)(if.*:|else:|elif:)\\s*(#.*)*$")
	regex["match"] = _regex_factory("^(?<indentation>\t*)match[ ].*:.*$")
	regex["match_condition"] = _regex_factory("^((?!if|else|elif|match|func)(?<indentation>\t+).)*:$")
	regex["indentation"] = _regex_factory("^(?<indentation>\t*)")

func get_test_report():
	return suite.generate_report()

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

	obj.add_user_signal("visited")
	obj.connect("visited", suite, "on_visit")

	var script = fetch_script(obj)

	if len(blocks) == 0:
		return

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
	methods = {}
	blocks = {}
	var script : Script = GDScript.new()
	var line = ""
	var source = ""
	for c in obj.get_script().get_source_code():
		if c != '\n':
			line += c
		else:
			source += _process_line(line)
			line = ""
	if "start" in current_block:
		_terminate_current_block()
	print(source)
	script.set_source_code(source)
	script.reload()
	var t_data = ReportData.new()
	t_data.methods = methods
	t_data.blocks = blocks
	suite.register_new_script(res_key, t_data)
	return script

func _process_line(line):
	line_nr += 1
	
	var result = regex["func"].search(line)
	if result:
		var name = result.get_string("symbol")
		line = _new_block(name, line, "\t")
		
	if regex["skip"].search(line):
		skipped_lines += 1
		return ""
		
	if regex["pass"].search(line) and "start" in current_block:
		_terminate_current_block()
		
	result = regex["branch"].search(line)
	if result and len(current_block) != 0:
		line = _new_block(current_block["name"], line, result.get_string("indentation") + "\t")
		return line + "\n"
		
	result = regex["indentation"].search(line)
	if len(match_block_stack) > 0 and len(result.get_string("indentation")) <= len(match_block_stack.back()):
		line = _new_block(current_block["name"], line, match_block_stack.back(), true)
		match_block_stack.pop_back()
		
	if len(match_block_stack) > 0:
		result = regex["match_condition"].search(line)
		if result and len(current_block) != 0:
			line = _new_block(current_block["name"], line, result.get_string("indentation") + "\t")
			return line + "\n"
	
	result = regex["match"].search(line)
	if result and len(current_block) != 0:
		match_block_stack.append(result.get_string("indentation"))

	#TODO indentation stack with if/else/elif/match

	return line + "\n"

func _terminate_current_block():
	blocks[current_block["start"]].end = line_nr - skipped_lines
	skipped_lines = 0
	current_block = {}

func _regex_factory(pattern):
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex

func _new_block(name, line, indentation, before = false):
	if "start" in current_block:
		_terminate_current_block()
	if not name in methods:
		methods[name] = false
	current_block = {"visited": false, "start": line_nr, "name": name}
	blocks[line_nr] = current_block
	var content = indentation + "emit_signal(\"visited\", \"" + name + "\", " + str(line_nr) + ",\"" + res_key + "\")"
	if before:
		return content + "\n" + line
	return line + "\n" + content

class Suite:
	extends Node2D
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


class ReportData:
	extends Node
	var blocks = {}
	var methods = {}
	
	func generate_report() -> Dictionary:
		var lines_covered = 0
		var lines_total = 0
		var visited_methods = 0
		var uncovered_lines = []
		for key in blocks:
			if blocks[key].visited:
				lines_covered += blocks[key].end - blocks[key].start
			else:
				for line_number in range(blocks[key].start, blocks[key].end + 1):
					uncovered_lines.append(line_number)
			lines_total += blocks[key].end - blocks[key].start
		for key in methods:
			if methods[key]:
				visited_methods += 1
		
		if lines_total == 0:
			return {"missing":"missing"}
		
		return {
			"line_coverage" : str(lines_covered / float(lines_total) * 100) + "%",
			"method_coverage": str(visited_methods / float(len(methods)) * 100) + "%",
			"uncovered_lines": str(uncovered_lines)
		}
