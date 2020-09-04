extends Node

class_name TestCoverageMetricsInjector, "res://addons/gut/coverage_injector.gd"

var regex = {}

var blocks = []
var current_block = {}
var methods = {}
var script_injections = {}
var line_nr = 0
var skipped_lines = 0
var res_key = ""
var exclude_path = "res://test"
var match_block_stack : Array = []
var index = 1

## MAKE SURE THERE IS WHITESPACE BETWEEN AND AFTER FUNCTIONS
## REGEX SPLIT BLOCKS [\s\S]*?[\r\n]{2}
## LOOP LINES, RECURSIVE, IF INDENTATION IS SAME, COLLECT, LOWER RETURN HIGHER RETURN D+1

func _ready():
	regex["func"] = _regex_factory("^(?<indentation>\t*)func (?<symbol>.*)\\(.*:?(.*)$")
	regex["skip"] = _regex_factory("^\\s$")
	regex["pass"] = _regex_factory("^\\spass$")
	regex["branch"] = _regex_factory("^(?<indentation>\t+)((?<conditional>if|else|elif|while|for|match).*:)\\s*(#.*)*$")
	regex["match_condition"] = _regex_factory("^((?!if|else|elif|match|func|while|for)(?<indentation>\t+)\"*.)*\"*:$")
	regex["indentation"] = _regex_factory("^(?<indentation>\t*)")
	regex["line"] = _regex_factory("^(?<indentation>\t*)(?<other>.*)")

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
	match_block_stack = []
	var script : Script = GDScript.new()
	var line = ""
	var lines = {}
	var source = ""
	var nr = 1
	for c in obj.get_script().get_source_code():
		if c != '\n':
			line += c
		else:
			source += line + "\n"
			lines[nr] = line
			nr += 1
			line = ""
	source += line + "\n"
	lines[nr] = line
	nr += 1
	line = ""
	_generate_tree(lines)
	
	script.set_source_code(source)
	script.reload()
	return script

func _regex_factory(pattern):
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex

func indentation(line) -> int:
	var result = regex["indentation"].search(line)
	if result:
		return len(result.get_string("indentation"))
	return 0
	
func _generate_tree(lines):
	index = 1
	while index <= len(lines):
		var current_line = lines[index]
		var result = regex["func"].search(current_line)
		if result:
			blocks.append({"lines": [], "method_name": result.get_string("symbol")})
			index += 1
			blocks.back().lines = _gather_lines(lines, indentation(lines[index]))
		index += 1
	print(blocks)

func _gather_lines(lines, indentation):
	var result = []
	while index <= len(lines):
		var current_line = lines[index]
		if indentation(current_line) == indentation:
			result.append({"line": current_line, "line_nr": index})
			index += 1
		if indentation(current_line) > indentation:
			result.back().children = _gather_lines(lines, indentation + 1)
		if indentation(current_line) < indentation:
			return result
	return result
