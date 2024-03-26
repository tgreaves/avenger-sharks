extends Control

signal credits_return_button_pressed

enum { INACTIVE, ACTIVE }

var scrolling = INACTIVE


# Called when the node enters the scene tree for the first time.
func _ready():
    pass


func prepare_content():
    var content = ""
    var i = 0

    while i < 35:
        content += "\n"
        i += 1

    var file = FileAccess.open("res://CREDITS.txt", FileAccess.READ)
    content += file.get_as_text()

    var fresh_content = ""
    var content_array = content.split("\n", true, 0)
    for single_line in content_array:
        if SteamClient.STEAM_RUNNING:
            if single_line.contains("itch"):
                continue

        fresh_content += single_line + "\n"

    $CanvasLayer/VBoxContainer/ScrollContainer/Label.text = fresh_content


func commence_scroll():
    scrolling = ACTIVE
    #$CanvasLayer/VBoxContainer/ScrollContainer.scroll_vertical


func stop_scroll():
    scrolling = INACTIVE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if scrolling == ACTIVE:
        $CanvasLayer/VBoxContainer/ScrollContainer.scroll_vertical += 2


func _on_return_button_pressed():
    stop_scroll()
    $CanvasLayer/VBoxContainer/ScrollContainer.scroll_vertical = 0
    emit_signal("credits_return_button_pressed")
