extends Node


func log_entry(text):
	if constants.DEV_LOGGING == false:
		return

	var source = get_stack()[1]["function"]

	if source == "design_wave" and !constants.DEV_LOG_WAVE_DESIGN:
		return

	var text_split = text.split("\n")

	for single_line in text_split:
		print("[" + source + "] " + single_line)
