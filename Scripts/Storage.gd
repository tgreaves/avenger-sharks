extends Node

var config
var stats

# -- SYSTEM CONFIGURATION --
# Per-system.  Should NOT be Cloud Saved.  And so deliberately a different file.


func load_config():
	config = ConfigFile.new()

	var err = config.load("user://config.ini")

	if err != OK:
		config.set_value("config", "screen_mode", "FULL_SCREEN")
		config.set_value("config", "master_volume", 1.0)
		config.set_value("config", "music_volume", 1.0)
		config.set_value("config", "effects_volume", 1.0)
		config.set_value("config", "enable_haptics", false)


func save_config():
	if OS.has_feature("web"):
		return

	var err = config.save("user://config.ini")

	if err != OK:
		print("config(): Fail")


# -- STATISTICS --


func load_stats():
	stats = ConfigFile.new()

	var err = stats.load("user://cloud-stats.ini")

	if err != OK:
		# Could not load stats.  That's OK, might be first run.
		stats.set_value("player", "high_score", 0)
		stats.set_value("player", "games_played", 0)
		stats.set_value("player", "shots_fired", 0)
		stats.set_value("player", "enemies_defeated", 0)
		stats.set_value("player", "furthest_wave", 0)
		stats.set_value("player", "fish_rescued", 0)


func save_stats():
	if OS.has_feature("web"):
		return

	var err = stats.save("user://cloud-stats.ini")

	if err != OK:
		print("save_stats(): Fail")


func increase_stat(stat_category, stat_name, delta):
	stats.set_value(stat_category, stat_name, stats.get_value(stat_category, stat_name, 0) + delta)
