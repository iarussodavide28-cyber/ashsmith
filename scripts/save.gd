extends Node
## Salvataggio automatico di oro, gemme e record (resta anche chiudendo il gioco).

const PATH := "user://ashsmith_save.json"

var gold := 0
var gems := 0
var best_room := 0
var runs := 0
var wins := 0
var weapons := ["sword", "bow"]   # ultime armi scelte

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	gold = int(d.get("gold", 0))
	gems = int(d.get("gems", 0))
	best_room = int(d.get("best_room", 0))
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	var w = d.get("weapons", weapons)
	if typeof(w) == TYPE_ARRAY and w.size() == 2:
		weapons = [str(w[0]), str(w[1])]

func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"gold": gold, "gems": gems, "best_room": best_room,
		"runs": runs, "wins": wins, "weapons": weapons,
	}))
