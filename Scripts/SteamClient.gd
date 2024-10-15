extends Node

@export var steam_running = false
var steam_id
var steam_name
var steam_subscribed
var SteamEngine

func steam_setup():
	SteamEngine = Engine.get_singleton('Steam')
	SteamEngine.steamInit()

	steam_running = SteamEngine.isSteamRunning()

	if !steam_running:
		Logging.log_entry("Steam not running.")
		get_tree().quit()

	steam_id = SteamEngine.getSteamID()
	steam_name = SteamEngine.getFriendPersonaName(steam_id)
	steam_subscribed = SteamEngine.isSubscribed()

	Logging.log_entry("Your steam name: " + str(steam_name))
	Logging.log_entry("Subscribed: " + str(steam_subscribed))

	if !steam_subscribed:
		Logging.log_entry("Game not owned.")
		get_tree().quit()
