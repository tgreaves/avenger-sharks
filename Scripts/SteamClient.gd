extends Node

@export var steam_running = false
var steam_id
var steam_name
var steam_subscribed


func steam_setup():
	Steam.steamInit()

	steam_running = Steam.isSteamRunning()

	if !steam_running:
		Logging.log_entry("Steam not running.")
		get_tree().quit()

	steam_id = Steam.getSteamID()
	steam_name = Steam.getFriendPersonaName(steam_id)
	steam_subscribed = Steam.isSubscribed()

	Logging.log_entry("Your steam name: " + str(steam_name))
	Logging.log_entry("Subscribed: " + str(steam_subscribed))

	if !steam_subscribed:
		Logging.log_entry("Game not owned.")
		get_tree().quit()
