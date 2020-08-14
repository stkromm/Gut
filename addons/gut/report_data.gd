extends Node

class_name ReportData, "res://addons/gut/report_data.gd"

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
