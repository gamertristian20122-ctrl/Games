class_name BotReport
## Turns the bot's saved results into a plain-language balance report.
##
##   godot --headless --path . -- --report=bot_out --out=docs/balance_report.md
##
## reads every .json file in the folder and writes one Markdown report.

const SKILL_ORDER := ["new", "ok", "pro"]
const SKILL_NAMES := {"new": "Beginner", "ok": "Average", "pro": "Expert"}
const SOURCE_NAMES := {
	"shot": "Your shots", "echo": "Echo shots", "burn": "Fire (Storm Lantern)",
	"lightning": "Lightning (Storm Glass)", "flare": "Flares", "moth": "Lamp Moths",
	"beacon": "Beacon", "echo_beacon": "Echo's beacon", "foghorn": "Foghorn",
	"afterglow": "Afterglow bursts", "salt_fire": "Salt Fire",
}


static func write_from_folder(folder: String, out_path: String) -> void:
	var runs: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("No such folder: " + folder)
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(folder.path_join(file_name))
		var data: Variant = JSON.parse_string(text)
		if data is Array:
			runs.append_array(data)
	var report := build(runs)
	var out_dir := out_path.get_base_dir()
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + out_path)
		return
	file.store_string(report)
	print("Wrote %s from %d runs." % [out_path, runs.size()])


static func summary_line(skill: String, runs: Array) -> String:
	var s := _summarise(runs)
	return "Skill %s: %d runs, %.0f%% won, %.1f rooms cleared on average." % [
		skill, s["runs"], s["win_rate"] * 100.0, s["avg_rooms"]]


static func _by_skill(runs: Array) -> Dictionary:
	var out := {}
	for run: Dictionary in runs:
		var skill: String = run.get("skill", "ok")
		if not out.has(skill):
			out[skill] = []
		out[skill].append(run)
	return out


static func _summarise(runs: Array) -> Dictionary:
	var wins := 0
	var stalled := 0
	var rooms := 0.0
	var time := 0.0
	var floor_deaths := [0, 0, 0]
	var boss_deaths := 0
	for run: Dictionary in runs:
		rooms += float(run.get("rooms_cleared", 0))
		time += float(run.get("time", 0.0))
		match run.get("result", ""):
			"win":
				wins += 1
			"stalled":
				stalled += 1
			_:
				var floor_index := clampi(int(run.get("floor", 0)), 0, 2)
				floor_deaths[floor_index] += 1
				if EnemyDB.get_enemy(run.get("killer", "")).get("boss", false):
					boss_deaths += 1
	var n := maxi(runs.size(), 1)
	return {
		"runs": runs.size(), "wins": wins, "stalled": stalled,
		"win_rate": float(wins) / n, "avg_rooms": rooms / n, "avg_time": time / n,
		"floor_deaths": floor_deaths, "boss_deaths": boss_deaths,
	}


static func build(runs: Array) -> String:
	var total_rooms := FloorDB.total_rooms()
	var groups := _by_skill(runs)
	var lines: Array[String] = []
	lines.append("# Balance report")
	lines.append("")
	lines.append("Made by the test bot. It plays the real game through the same controls a person uses, at three skill levels. %d runs in total." % runs.size())
	lines.append("")
	lines.append("**How to read this:** the bot is not a person. Treat the numbers as a compass, not a verdict. If something looks off here, play it and see how it feels.")
	lines.append("")

	# ---- Overview ----
	lines.append("## How far do runs get?")
	lines.append("")
	lines.append("A full run is %d rooms (3 floors, each 5 fights and a boss)." % total_rooms)
	lines.append("")
	lines.append("| Player | Runs | Won | Rooms cleared (average) | Died on floor 1 / 2 / 3 | Died to a boss | Average length |")
	lines.append("|---|---|---|---|---|---|---|")
	for skill: String in SKILL_ORDER:
		if not groups.has(skill):
			continue
		var s := _summarise(groups[skill])
		var fd: Array = s["floor_deaths"]
		lines.append("| %s | %d | %.0f%% | %.1f of %d | %d / %d / %d | %d | %s |" % [
			SKILL_NAMES[skill], s["runs"], s["win_rate"] * 100.0, s["avg_rooms"], total_rooms,
			fd[0], fd[1], fd[2], s["boss_deaths"], _clock(s["avg_time"])])
		if int(s["stalled"]) > 0:
			lines.append("| | | | | | | *%d runs got stuck and were stopped: worth a look* |" % s["stalled"])
	lines.append("")

	# ---- Killers ----
	lines.append("## What ends runs?")
	lines.append("")
	var killers := {}
	var hearts := {}
	for run: Dictionary in runs:
		if run.get("result", "") == "death":
			var k: String = run.get("killer", "?")
			killers[k] = int(killers.get(k, 0)) + 1
		var hits: Dictionary = run.get("hits_by", {})
		for source: String in hits:
			hearts[source] = float(hearts.get(source, 0.0)) + float(hits[source])
	lines.append("| Enemy | Final blows | Hearts taken per run |")
	lines.append("|---|---|---|")
	var names: Array = hearts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return float(hearts[a]) > float(hearts[b]))
	for source: String in names:
		lines.append("| %s | %d | %.2f |" % [
			EnemyDB.get_enemy(source).get("name", source), int(killers.get(source, 0)),
			float(hearts[source]) / maxi(runs.size(), 1)])
	lines.append("")

	# ---- Rooms ----
	lines.append("## How long do rooms take, and how much do they hurt?")
	lines.append("")
	lines.append("| Floor | Fights: seconds | Fights: hearts lost | Boss: seconds | Boss: hearts lost | Boss fights won |")
	lines.append("|---|---|---|---|---|---|")
	for floor_index in FloorDB.count():
		var fight_time := 0.0
		var fight_hits := 0.0
		var fights := 0
		var boss_time := 0.0
		var boss_hits := 0.0
		var bosses := 0
		for run: Dictionary in runs:
			for r: Dictionary in run.get("rooms", []):
				if int(r.get("floor", -1)) != floor_index:
					continue
				if r.get("kind", "") == "boss":
					bosses += 1
					boss_time += float(r.get("time", 0.0))
					boss_hits += float(r.get("hits", 0))
				else:
					fights += 1
					fight_time += float(r.get("time", 0.0))
					fight_hits += float(r.get("hits", 0))
		lines.append("| %s | %.0f | %.2f | %.0f | %.2f | %d |" % [
			FloorDB.get_floor(floor_index)["name"],
			fight_time / maxi(fights, 1), fight_hits / maxi(fights, 1),
			boss_time / maxi(bosses, 1), boss_hits / maxi(bosses, 1), bosses])
	lines.append("")

	# ---- Damage sources ----
	lines.append("## Where does the damage come from?")
	lines.append("")
	lines.append("The echo's share shows how much the twist matters.")
	lines.append("")
	var damage := {}
	var damage_total := 0.0
	for run: Dictionary in runs:
		var by: Dictionary = run.get("damage_by", {})
		for source: String in by:
			if source == "self":
				continue
			damage[source] = float(damage.get(source, 0.0)) + float(by[source])
			damage_total += float(by[source])
	lines.append("| Source | Share of all damage |")
	lines.append("|---|---|")
	var sources: Array = damage.keys()
	sources.sort_custom(func(a: String, b: String) -> bool: return float(damage[a]) > float(damage[b]))
	for source: String in sources:
		lines.append("| %s | %.1f%% |" % [SOURCE_NAMES.get(source, source), 100.0 * float(damage[source]) / maxf(damage_total, 1.0)])
	lines.append("")

	# ---- Items ----
	lines.append("## Items")
	lines.append("")
	lines.append("\"Rooms with\" is the average number of rooms cleared by runs that held the item. Compare it with the overall average of %.1f. Much higher can mean too strong (or just picked late by runs already doing well). Much lower can mean too weak. Items held in fewer than 8 runs are marked with `?`." % _summarise(runs)["avg_rooms"])
	lines.append("")
	lines.append("| Item | Runs that held it | Rooms with | Won with |")
	lines.append("|---|---|---|---|")
	var rows: Array = []
	for id: String in ItemDB.ITEMS:
		var held_runs := 0
		var held_rooms := 0.0
		var held_wins := 0
		for run: Dictionary in runs:
			var held: Dictionary = run.get("held", {})
			if int(held.get(id, 0)) > 0:
				held_runs += 1
				held_rooms += float(run.get("rooms_cleared", 0))
				if run.get("result", "") == "win":
					held_wins += 1
		rows.append([id, held_runs, held_rooms / maxi(held_runs, 1), float(held_wins) / maxi(held_runs, 1)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	for row: Array in rows:
		var few := " `?`" if int(row[1]) < 8 else ""
		lines.append("| %s | %d%s | %.1f | %.0f%% |" % [ItemDB.ITEMS[row[0]]["name"], row[1], few, row[2], float(row[3]) * 100.0])
	lines.append("")

	# ---- Combos ----
	lines.append("## Combos")
	lines.append("")
	lines.append("| Combo | Runs that found it | Rooms with | Won with |")
	lines.append("|---|---|---|---|")
	for combo_id: String in ItemDB.COMBOS:
		var found := 0
		var found_rooms := 0.0
		var found_wins := 0
		for run: Dictionary in runs:
			if (run.get("combos", []) as Array).has(combo_id):
				found += 1
				found_rooms += float(run.get("rooms_cleared", 0))
				if run.get("result", "") == "win":
					found_wins += 1
		lines.append("| %s | %d | %.1f | %.0f%% |" % [
			ItemDB.COMBOS[combo_id]["name"], found, found_rooms / maxi(found, 1),
			100.0 * float(found_wins) / maxi(found, 1)])
	lines.append("")
	return "\n".join(lines)


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
