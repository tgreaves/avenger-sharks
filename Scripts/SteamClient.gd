extends Node

@export var STEAM_RUNNING = false
var STEAM_ID
var STEAM_NAME
var STEAM_SUBSCRIBED

func SteamSetup():
    Steam.steamInit()
    
    STEAM_RUNNING = Steam.isSteamRunning()
    
    if !STEAM_RUNNING:
        Logging.log_entry("Steam not running.")
        get_tree().quit()

    STEAM_ID = Steam.getSteamID()
    STEAM_NAME = Steam.getFriendPersonaName(STEAM_ID)
    STEAM_SUBSCRIBED = Steam.isSubscribed()
    
    Logging.log_entry("Your steam name: " + str(STEAM_NAME))
    Logging.log_entry("Subscribed: " + str(STEAM_SUBSCRIBED))
    
    if !STEAM_SUBSCRIBED:
        Logging.log_entry("Game not owned.")
        get_tree().quit()

    
