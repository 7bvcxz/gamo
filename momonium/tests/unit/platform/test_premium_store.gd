extends "res://tests/framework/test_case.gd"

## The Premium Shop's model (Step 59): a data catalog, prices only from a
## storefront, and with none connected (the web, Android until billing is a
## validated step) nothing can be bought -- a tap is refused, never treated
## as a payment, and never touches the island.


## A storefront for tests only: prices and owned counts as a real one would
## report them. Purchases still go nowhere.
class FakeStorefront:
	extends Storefront
	var prices := {}
	var counts := {}
	var asked: Array[String] = []

	func available() -> bool:
		return true

	func price_text(sku: String) -> String:
		return String(prices.get(sku, ""))

	func owned(sku: String) -> int:
		return int(counts.get(sku, 0))

	func purchase(sku: String) -> Dictionary:
		asked.append(sku)
		return {"ok": true, "pending": true}


func test_the_catalog_is_data_and_proposed() -> void:
	var s := PremiumStore.from_data(GameData.load_default())
	assert_eq(String(s.catalog["status"]), "proposed", "proposed until the storefront and the owner approve it")
	var p := s.product("accelerator")
	assert_false(p.is_empty(), "the Accelerator is in the catalog")
	assert_eq(int(p["max_purchases"]), 5, "five at most")
	assert_eq(s.steps(p), [2, 4, 8, 16, 32] as Array[int], "x2 each: x2, x4, x8, x16, x32")
	assert_eq(String(p["name"]), "store.accelerator.name", "its name is a translation key")
	assert_eq(int(p["proposed_price"]["amount"]), 2000, "the proposed price is written down (KRW 2,000)")


func test_with_no_storefront_nothing_can_be_bought() -> void:
	var s := PremiumStore.from_data(GameData.load_default())
	var st := s.state("accelerator")
	assert_false(st["available"], "not purchasable")
	assert_eq(st["reason"], "store.coming_soon", "it says Coming soon")
	assert_eq(st["price"], "", "and shows no price: never the proposed one")
	assert_eq(int(st["owned"]), 0, "nothing owned")
	var r := s.request_purchase("accelerator")
	assert_false(r["ok"], "a Buy tap is refused")
	assert_false(s.can_restore(), "nothing to restore from")


func test_a_storefront_supplies_the_price_and_the_count() -> void:
	var f := FakeStorefront.new()
	f.prices["momonium_accelerator_x2"] = "₩2,000"
	f.counts["momonium_accelerator_x2"] = 2
	var s := PremiumStore.from_data(GameData.load_default(), f)
	var st := s.state("accelerator")
	assert_true(st["available"], "a connected storefront with a price can sell")
	assert_eq(st["price"], "₩2,000", "the storefront's own price")
	assert_eq(int(st["owned"]), 2, "two owned, as the storefront says")
	s.request_purchase("accelerator")
	assert_eq(f.asked, ["momonium_accelerator_x2"] as Array[String], "the tap goes to the storefront by its SKU")
	f.counts["momonium_accelerator_x2"] = 5
	st = s.state("accelerator")
	assert_false(st["available"], "five is the most")
	assert_eq(st["reason"], "store.maxed", "all owned")
	f.counts["momonium_accelerator_x2"] = 0
	f.prices.clear()
	assert_eq(s.state("accelerator")["reason"], "store.no_price", "no price from the storefront: not on sale")


func test_the_shop_never_touches_the_island() -> void:
	var sim := Simulation.new_game()
	var before := JSON.stringify(sim.save_state())
	var s := PremiumStore.from_data(GameData.load_default())
	for i in 3:
		s.request_purchase("accelerator")
	assert_eq(JSON.stringify(sim.save_state()), before, "no money, no Momo, nothing changed")
	var src := FileAccess.get_file_as_string("res://src/platform/premium_store.gd") + FileAccess.get_file_as_string("res://src/ui/premium_shop_view.gd")
	for word: String in ["Simulation", "execute(", "earn(", "spend("]:
		assert_false(src.contains(word), "the shop's code does not reach the simulation (%s)" % word)
