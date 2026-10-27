class_name PremiumStore
extends RefCounted

## The Premium Shop's model (Step 59): the catalog (the data's `store`
## table, data/store.json) and what the storefront says about each product. It never touches the island
## -- no money, no Momo, no boost -- and never treats a tap as a payment:
## buying goes to the storefront, and with none connected it is refused.

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


## What each purchase would bring the speed to: x2, x4, x8, x16, x32.
func steps(p: Dictionary) -> Array[int]:
	var out: Array[int] = []
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
	var owned := mini(storefront.owned(sku), int(p.get("max_purchases", 0)))
	var maxed := owned >= int(p.get("max_purchases", 0))
	var price := storefront.price_text(sku)
	var can := storefront.available() and price != "" and not maxed
	var reason := ""
	if not storefront.available():
		reason = "store.coming_soon"
	elif maxed:
		reason = "store.maxed"
	elif price == "":
		reason = "store.no_price"
	return {"available": can, "reason": reason, "price": price, "owned": owned, "max": int(p.get("max_purchases", 0)),
		"steps": steps(p), "proposed": String(catalog.get("status", "")) == "proposed"}


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
