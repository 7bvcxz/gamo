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


## Step 75: the store table with Remove Ads changed by `f` (a hypothetical
## future catalog), validated like the real one.
func _store_with(f: Callable) -> GameData:
	var store: Dictionary = GameData.load_default().table("store").duplicate(true)
	f.call(store)
	return GameData.from_tables({"store": store})


func _remove_ads(store: Dictionary) -> Dictionary:
	for p: Dictionary in store["products"]:
		if p["id"] == "remove_ads":
			return p
	return {}


func test_remove_ads_is_a_planned_one_time_entitlement_with_no_sku_or_price() -> void:
	var data := GameData.load_default()
	assert_true(data.is_valid(), "the catalog is valid: %s" % [data.errors])
	var s := PremiumStore.from_data(data)
	assert_eq(s.products().map(func(p: Dictionary) -> String: return p["id"]), ["accelerator", "remove_ads"], "two distinct products")
	var p := s.product("remove_ads")
	assert_eq(String(p["kind"]), "non_consumable", "one-time, unlike the Accelerator")
	assert_true(PremiumStore.one_time(p), "owned once, for good")
	assert_false(PremiumStore.one_time(s.product("accelerator")), "the Accelerator is bought again and again")
	assert_eq(String(p["status"]), "planned", "planned, not proposed")
	assert_eq(String(p["sku"]), "", "no SKU until the owner chooses it at the billing step")
	assert_false(p.has("proposed_price"), "and no price, not even a proposed one")
	assert_eq(String(p["entitlement"]), "no_ads", "what a verified purchase would grant")
	assert_true(bool(p["requires_ads"]), "only ever offered when there are ads")
	assert_false(s.ads_shown(), "and the game shows none")
	assert_eq(s.steps(p), [] as Array[int], "no steps")
	assert_eq(String(p["name"]), "store.remove_ads.name", "a translation key")
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas/sprites.json"))
	assert_true((atlas["sprites"] as Dictionary).has(String(p["icon"])), "its own icon is in the atlas (ui_no_ads)")
	assert_ne(String(p["icon"]), String(s.product("accelerator")["icon"]), "not the Accelerator's")


func test_remove_ads_is_not_available_yet_even_with_a_storefront() -> void:
	var s := PremiumStore.from_data(GameData.load_default())
	var st := s.state("remove_ads")
	assert_false(st["available"], "not purchasable")
	assert_eq(st["reason"], "store.not_yet", "it says Not available yet")
	assert_eq(st["price"], "", "no price")
	assert_true(st["one_time"], "one-time")
	assert_eq([int(st["owned"]), int(st["max"])], [0, 1], "nothing owned, one at most")
	assert_eq(s.request_purchase("remove_ads"), {"ok": false, "reason": "store.not_yet"}, "a tap is refused")
	# A connected storefront that sells everything: still not Remove Ads.
	var f := FakeStorefront.new()
	f.prices[""] = "₩0"
	f.counts[""] = 1
	s = PremiumStore.from_data(GameData.load_default(), f)
	st = s.state("remove_ads")
	assert_eq(st["reason"], "store.not_yet", "planned and no ads: never on sale, whatever the storefront says")
	assert_eq(st["price"], "", "never a phantom price (not even ₩0)")
	assert_eq(int(st["owned"]), 0, "never owned through an empty SKU")
	s.request_purchase("remove_ads")
	assert_eq(f.asked, [] as Array[String], "the storefront is never even asked")


func test_a_future_catalog_could_sell_it_once() -> void:
	var data := _store_with(func(store: Dictionary) -> void:
		store["ads_shown"] = true
		var p := _remove_ads(store)
		p["status"] = "on_sale"
		p["sku"] = "momonium_remove_ads")
	assert_true(data.is_valid(), "with ads and a SKU it may be on sale: %s" % [data.errors])
	var f := FakeStorefront.new()
	f.prices["momonium_remove_ads"] = "₩3,000"
	var s := PremiumStore.from_data(data, f)
	assert_true(s.state("remove_ads")["available"], "then a storefront with a price can sell it")
	s.request_purchase("remove_ads")
	assert_eq(f.asked, ["momonium_remove_ads"] as Array[String], "by its SKU")
	f.counts["momonium_remove_ads"] = 3
	var st := s.state("remove_ads")
	assert_eq([int(st["owned"]), int(st["max"])], [1, 1], "owned once, however the count reads")
	assert_eq(st["reason"], "store.purchased", "and says Purchased")


func test_the_catalog_rules() -> void:
	var cases := {
		"on sale with no ads": func(store: Dictionary) -> void:
			var p := _remove_ads(store)
			p["status"] = "on_sale"
			p["sku"] = "x",
		"no SKU but proposed": func(store: Dictionary) -> void:
			_remove_ads(store)["status"] = "proposed",
		"one-time with steps": func(store: Dictionary) -> void:
			_remove_ads(store)["max_purchases"] = 5,
		"one-time with no entitlement": func(store: Dictionary) -> void:
			_remove_ads(store).erase("entitlement"),
		"an unknown kind": func(store: Dictionary) -> void:
			_remove_ads(store)["kind"] = "subscription",
		"a repeated id": func(store: Dictionary) -> void:
			_remove_ads(store)["id"] = "accelerator",
		"no icon": func(store: Dictionary) -> void:
			_remove_ads(store)["icon"] = "",
	}
	for name: String in cases:
		var data := _store_with(cases[name])
		assert_false(data.is_valid(), "%s: refused" % name)
		assert_true(data.errors.any(func(e: String) -> bool: return e.begins_with("store:")), "%s: as a store error" % name)


func test_future_purchase_records_parse_safely() -> void:
	var real := PremiumStore.from_data(GameData.load_default())
	var data := _store_with(func(store: Dictionary) -> void:
		_remove_ads(store)["sku"] = "momonium_remove_ads")
	var s := PremiumStore.from_data(data)
	var good := {"products": ["momonium_remove_ads"], "purchaseState": 1, "purchaseToken": "tok", "verified": true}
	assert_eq(s.parse_purchase(good), {"ok": true, "product": "remove_ads", "entitlement": "no_ads"}, "a verified purchase grants no_ads")
	assert_true(s.parse_purchase({"productId": "momonium_remove_ads", "purchaseState": 1.0, "purchaseToken": "tok", "verified": true})["ok"], "the older productId shape, a JSON number")
	var bad := {
		"not a dictionary": "momonium_remove_ads",
		"null": null,
		"empty": {},
		"two products": {"products": ["momonium_remove_ads", "momonium_accelerator_x2"], "purchaseState": 1, "purchaseToken": "t", "verified": true},
		"a product that is not a string": {"products": [7], "purchaseState": 1, "purchaseToken": "t", "verified": true},
		"an unknown product": {"products": ["something_else"], "purchaseState": 1, "purchaseToken": "t", "verified": true},
		"the Accelerator (no entitlement)": {"products": ["momonium_accelerator_x2"], "purchaseState": 1, "purchaseToken": "t", "verified": true},
		"pending": {"products": ["momonium_remove_ads"], "purchaseState": 2, "purchaseToken": "t", "verified": true},
		"no state": {"products": ["momonium_remove_ads"], "purchaseToken": "t", "verified": true},
		"no token": {"products": ["momonium_remove_ads"], "purchaseState": 1, "verified": true},
		"not verified": {"products": ["momonium_remove_ads"], "purchaseState": 1, "purchaseToken": "t"},
		"verified as a string": {"products": ["momonium_remove_ads"], "purchaseState": 1, "purchaseToken": "t", "verified": "true"},
	}
	for name: String in bad:
		var r := s.parse_purchase(bad[name])
		assert_false(r["ok"], "%s: grants nothing" % name)
		assert_false(r.has("entitlement"), "%s: no entitlement in the answer" % name)
	assert_eq(s.entitlements([bad["pending"], good, good, null]), {"no_ads": true}, "a restore's answer: once, from the good record")
	assert_eq(s.entitlements([]), {}, "nothing: nothing")
	for sku: String in ["", "remove_ads", "momonium_remove_ads"]:
		assert_false(real.parse_purchase({"products": [sku], "purchaseState": 1, "purchaseToken": "t", "verified": true})["ok"], "today's catalog has no SKU to match (%s)" % sku)
