extends Node

class_name TestCoverageMetricsInjector, "res://addons/gut/coverage_injector.gd"

var regex = {}

var blocks = {}
var current_block = {}
var methods = {}
var script_injections = {}
var line_nr = 0
var skipped_lines = 0
var total_lines = 0
var res_key = ""
var suite : Suite
var exclude_path = "res://test"

func _ready():
	suite = Suite.new()
	suite._ready()
	add_child(suite)

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
	
	regex["func"] = _regex_factory("^func (?<symbol>.*)\\(.*:?(.*)$")
	regex["skip"] = _regex_factory("^\\s$")
	regex["pass"] = _regex_factory("^\\spass$")
	regex["branch"] = _regex_factory("^(?<indentation>\t*)((el)?if\\t+.*|else):?(\\t*#*)$")
	
		
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
		line = _new_block(name, line, "")
		
	if regex["skip"].search(line):
		skipped_lines += 1
		return ""
	if regex["pass"].search(line) and "start" in current_block:
		_terminate_current_block()
	result = regex["branch"].search(line)
	if result and len(current_block) != 0:
		line = _new_block(current_block["name"], line, result.get_string("indentation"))
	total_lines += 1
	return line + "\n"

func _terminate_current_block():
	blocks[current_block["start"]].end = line_nr - skipped_lines
	skipped_lines = 0
	current_block = {}

func _regex_factory(pattern):
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex

func _new_block(name, line, indentation):
	if "start" in current_block:
			_terminate_current_block()
	if not name in methods:
		methods[name] = false
	current_block = {"visited": false, "start": line_nr, "name": name}
	blocks[line_nr] = current_block
	var content = indentation + "\temit_signal(\"visited\", \"" + name + "\", " + str(line_nr) + ",\"" + res_key + "\")"
	return line + "\n" + content

