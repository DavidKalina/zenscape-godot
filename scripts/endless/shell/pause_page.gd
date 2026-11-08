extends "res://scripts/endless/shell/shell_page.gd"
## Pause, over the held flight (scripts/endless/shell/shell.gd): Resume,
## Settings, Controls, Quit to Title, Quit. Esc, B or the pad's Menu resume.

func _init(shell: Node) -> void:
	super()
	title = "Paused"
	width = 420.0
	button_size = 26
	button_height = 52.0
	foot = "RESUME"
	set_rows([
		{"kind":"gap"},
		{"kind":"button","text":"Resume","act":shell.resume},
		{"kind":"button","text":"Settings","act":shell.open_page.bind("settings")},
		{"kind":"button","text":"Controls","act":shell.open_page.bind("controls")},
		{"kind":"gap"},
		{"kind":"button","text":"Quit to Title","act":shell.quit_to_title},
		{"kind":"button","text":"Quit","act":shell.quit},
	])
