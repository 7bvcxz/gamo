class_name Storefront
extends RefCounted

## Where real-money purchases would be made and verified (Google Play Billing
## on Android). This base is the one in use everywhere today: no storefront is
## connected, so it knows no prices, owns nothing and sells nothing -- the
## Premium Shop shows 'Coming soon'. A real storefront is a separately
## validated step (purchase verification, repeat-purchase semantics,
## entitlement persistence, refunds, restore) and overrides these.


## Whether purchases can be made here at all.
func available() -> bool:
	return false


## The storefront's own localized price for `sku` ("₩2,000"), or "" when it
## has not supplied one. Never a price assumed by the game.
func price_text(_sku: String) -> String:
	return ""


## How many of `sku` the player verifiably owns.
func owned(_sku: String) -> int:
	return 0


## Starts a purchase; the outcome arrives from the storefront, never here.
func purchase(_sku: String) -> Dictionary:
	return {"ok": false, "reason": "store.unavailable"}


func restore() -> Dictionary:
	return {"ok": false, "reason": "store.unavailable"}
