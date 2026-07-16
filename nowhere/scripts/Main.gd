extends Node2D

var coins_collected := 0
var total_coins := 0

@onready var score_label: Label = $UI/ScoreLabel

func _ready() -> void:
	var coins := get_tree().get_nodes_in_group("coins")
	total_coins = coins.size()
	for coin in coins:
		coin.collected.connect(_on_coin_collected)
	_update_label()

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_label()

func _update_label() -> void:
	if coins_collected >= total_coins:
		score_label.text = "All coins collected!"
	else:
		score_label.text = "Coins: %d / %d" % [coins_collected, total_coins]
