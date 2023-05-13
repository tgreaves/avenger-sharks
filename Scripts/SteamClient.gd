extends Node

var STEAM_RUNNING
var STEAM_ID
var STEAM_NAME
var STEAM_SUBSCRIBED

func SteamSetup():
    Steam.steamInit()
    
    STEAM_RUNNING = Steam.isSteamRunning()
    
    if !STEAM_RUNNING:
        print("Steam not running.")
        get_tree().quit()

    STEAM_ID = Steam.getSteamID()
    STEAM_NAME = Steam.getFriendPersonaName(STEAM_ID)
    STEAM_SUBSCRIBED = Steam.isSubscribed()
    
    print("Your steam name: " + str(STEAM_NAME))
    print("Subscribed: " + str(STEAM_SUBSCRIBED))
    
    if !STEAM_SUBSCRIBED:
        print("Game not owned.")
        get_tree().quit()
