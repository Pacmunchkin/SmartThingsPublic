# =============================================================================
# SCRIPT-ONLY UTILITY — name_pool.gd (no scene, no node; static functions).
#
# Draws warlord names from warlord_names.csv (project root). CSV format,
# one warlord per row, authored in any spreadsheet:
#
#   name,epithet
#   Halfdan,the Black
#   Aud,the Deep-Minded
#
# The header row is skipped. Epithet is optional. Names are drawn WITHOUT
# replacement, so no two warlords share a name; if the pool runs dry the
# fallback "Warlord" is returned. The pool lives for the whole game
# process — names drawn in an earlier level stay used.
#
# Usage: NamePool.draw()  ->  "Halfdan the Black"
# =============================================================================

class_name NamePool

const CSV_PATH: String = "res://warlord_names.csv"

static var _names: Array[String] = []
static var _loaded: bool = false

static func draw() -> String:
	if not _loaded:
		_load()
	if _names.is_empty():
		return "Warlord"
	return _names.pop_at(randi() % _names.size())

static func _load() -> void:
	_loaded = true
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("NamePool: could not open %s" % CSV_PATH)
		return
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0 or row[0].strip_edges().is_empty():
			continue
		if row[0].strip_edges().to_lower() == "name":
			continue  # header row
		var full_name := row[0].strip_edges()
		if row.size() >= 2 and not row[1].strip_edges().is_empty():
			full_name += " " + row[1].strip_edges()
		_names.append(full_name)
