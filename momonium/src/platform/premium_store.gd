class_name PremiumStore
extends RefCounted

## The Premium Shop's model (Step 59): the catalog (the data's `store`
## table, data/store.json) and what the storefront says about each product. It never touches the island
## -- no money, no Momo, no boost -- and never treats a tap as a payment:
## buying goes to the storefront, and with none connected it is refused.
##
## Two kinds of product (Step 75): the Accelerator, bought up to five times,
## and one-time products (`non_consumable`) such as Remove Ads, owned once
## and for good. A `planned` product, or one that removes ads while the game
## shows none, is never on sale, whatever the storefront says.

## Google Play Billing's Purchase.PurchaseState: only PURCHASED grants.
const PURCHASED := 1

var catalog: Dictionary = {}
var storefront: Storefront


## With no storefront given, the one in use everywhere today: none.
static func from_data(data: GameData, p_storefront: Storefront = null) -> PremiumStore:
	var s := PremiumStore.new()
	s.catalog = data.table("store")
	s.storefront = p_storefront if p_storefront != null else Storefront.new()
	return s


func products() -> Array:
	return catalog.get("products", [])


func product(id: String) -> Dictionary:
	for p: Dictionary in products():
		if String(p["id"]) == id:
			return p
	return {}


## Bought once and owned for good (Remove Ads), not stepped (the Accelerator).
static func one_time(p: Dictionary) -> bool:
	return String(p.get("kind", "")) == "non_consumable"


## Whether the game shows ads at all. It does not (data/store.json).
func ads_shown() -> bool:
	return bool(catalog.get("ads_shown", false))


## What each purchase would bring the speed to: x2, x4, x8, x16, x32. A
## one-time product has no steps.
func steps(p: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if one_time(p):
		return out
	var f := int(p.get("factor", 2))
	var m := 1
	for i in int(p.get("max_purchases", 0)):
		m *= f
		out.append(m)
	return out


## Everything the shop shows for a product: whether it can be bought now and
## why not, the storefront's price (or ""), how many are owned of how many.
func state(id: String) -> Dictionary:
	var p := product(id)
	var sku := String(p.get("sku", ""))
	var most := 1 if one_time(p) else int(p.get("max_purchases", 0))
	var owned := mini(storefront.owned(sku), most) if sku != "" else 0
	var maxed := owned >= most
	var price := storefront.price_text(sku) if sku != "" else ""
	var reason := ""
	if String(p.get("status", catalog.get("status", ""))) == "planned" or (bool(p.get("requires_ads", false)) and not ads_shown()):
		reason = "store.not_yet"
	elif not storefront.available():
		reason = "store.coming_soon"
	elif maxed:
		reason = "store.purchased" if one_time(p) else "store.maxed"
	elif price == "":
		reason = "store.no_price"
	return {"available": reason == "", "reason": reason, "price": price, "owned": owned, "max": most,
		"one_time": one_time(p), "steps": steps(p), "proposed": String(catalog.get("status", "")) == "proposed"}


## A Buy tap: handed to the storefront when it can sell, refused otherwise.
## Nothing is granted here -- an entitlement comes only from the storefront's
## verified purchase.
func request_purchase(id: String) -> Dictionary:
	var st := state(id)
	if not st["available"]:
		return {"ok": false, "reason": st["reason"]}
	return storefront.purchase(String(product(id)["sku"]))


func can_restore() -> bool:
	return storefront.available()


## Step 75, for a future billing step: what one purchase record would grant.
## The record is Google Play's Purchase (productId or products, purchaseState,
## purchaseToken) plus `verified`, set only after our check of its token.
## Anything else -- a pending or unknown purchase, a product with no SKU, a
## consumable, a malformed record -- grants nothing. Pure: it reads the
## catalog and returns; nothing calls it with a real purchase yet.
func parse_purchase(record: Variant) -> Dictionary:
	if typeof(record) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "malformed"}
	var r: Dictionary = record
	var skus: Array = []
	if typeof(r.get("products")) == TYPE_ARRAY:
		skus = r["products"]
	elif typeof(r.get("productId")) == TYPE_STRING:
		skus = [r["productId"]]
	if skus.size() != 1 or typeof(skus[0]) != TYPE_STRING or String(skus[0]) == "":
		return {"ok": false, "reason": "malformed"}
	var p := {}
	for q: Dictionary in products():
		if String(q.get("sku", "")) != "" and String(q["sku"]) == String(skus[0]):
			p = q
	if p.is_empty():
		return {"ok": false, "reason": "unknown_product"}
	if not one_time(p):
		return {"ok": false, "reason": "not_an_entitlement"}
	var purchase_state: Variant = r.get("purchaseState")
	if typeof(purchase_state) not in [TYPE_INT, TYPE_FLOAT] or int(purchase_state) != PURCHASED:
		return {"ok": false, "reason": "not_purchased"}
	if typeof(r.get("purchaseToken")) != TYPE_STRING or String(r["purchaseToken"]) == "":
		return {"ok": false, "reason": "malformed"}
	if typeof(r.get("verified")) != TYPE_BOOL or not bool(r["verified"]):
		return {"ok": false, "reason": "unverified"}
	return {"ok": true, "product": String(p["id"]), "entitlement": String(p["entitlement"])}


## The entitlements a set of purchase records grants (a restore's answer):
## {"no_ads": true}, or {} -- which is every answer today.
func entitlements(records: Array) -> Dictionary:
	var out := {}
	for r: Variant in records:
		var e := parse_purchase(r)
		if e["ok"]:
			out[e["entitlement"]] = true
	return out
