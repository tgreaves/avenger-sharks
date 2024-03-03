extends Node


var Config
var Stats

# -- SYSTEM CONFIGURATION --
# Per-system.  Should NOT be Cloud Saved.  And so deliberately a different file.

func load_config():
    Config = ConfigFile.new()
    
    var err = Config.load("user://config.ini")

    if err != OK:
        Config.set_value('config','screen_mode','FULL_SCREEN')
        Config.set_value('config','master_volume',1.0)
        Config.set_value('config','music_volume',1.0)
        Config.set_value('config','effects_volume',1.0)
        Config.set_value('config','enable_haptics',false)
    
func save_config():
    if OS.has_feature('web'):
        return

    var err = Config.save("user://config.ini")
    
    if err != OK:
        print("config(): Fail")

# -- STATISTICS --

func load_stats():
    Stats = ConfigFile.new()
    
    var err = Stats.load("user://cloud-stats.ini")
       
    if err != OK:
        # Could not load stats.  That's OK, might be first run.
        Stats.set_value('player','high_score',0)
        Stats.set_value('player','games_played', 0)
        Stats.set_value('player','shots_fired', 0)
        Stats.set_value('player','enemies_defeated', 0)
        Stats.set_value('player','furthest_wave', 0)
        Stats.set_value('player','fish_rescued', 0)
        
func save_stats():
    if OS.has_feature('web'):
        return
        
    var err = Stats.save("user://cloud-stats.ini")
    
    if err != OK:
        print("save_stats(): Fail")

func increase_stat(stat_category, stat_name, delta):
    Stats.set_value(stat_category, stat_name, Stats.get_value(stat_category,stat_name,0)+delta)
