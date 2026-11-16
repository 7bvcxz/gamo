extends "res://variants/perfect/perfect_rules.gd"

## The three-floor factory (Step 16 -> design/FACTORY_FLOW.md). For now the
## bottom floor's hand kettle only: B's hold and release with the stand's 40 ms
## edge grace, paying on the pop as #stand does. Step 17 replaces the pay with
## the conserved flow (a real lot -> packing -> a customer's purchase); until
## then the middle and top floors are scenery. Numbers in data/economy.json ("factory").

func _init(p_economy: PopEconomy = null) -> void:
	super(p_economy)
	variant = "factory"


func _judge(ms: int) -> String:
	var g := int(economy.table(variant).get("edge_grace_ms", 0))
	if ms >= window_start() - g and ms <= window_end() + g:
		return PERFECT
	return super(ms)
