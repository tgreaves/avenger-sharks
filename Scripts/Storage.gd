extends Node


var Config

var Stats

func load_stats():
    print ("load_stats() called")
    Stats = ConfigFile.new()
    
    var err = Stats.load("user://stats.ini")
        
    if err != OK:
        # Could not load stats.  That's OK, might be first run.
        Stats.set_value('player','high_score',0)
        Stats.set_value('player','games_played', 0)
        Stats.set_value('player','shots_fired', 0)
        
        print("load_stat(): Error, setting defaults.")
        
        return
        
func save_stats():
    print("save_stats() called")
    var err = Stats.save("user://stats.ini")
    
    if err != OK:
        print("save_stats(): Fail")

func increase_stat(stat_category, stat_name, delta):
    Stats.set_value(stat_category, stat_name, Stats.get_value(stat_category,stat_name,0)+delta)
