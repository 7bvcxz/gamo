class_name SimResult
extends RefCounted

## Shape of every command answer: {"ok": bool, "reason": String, ...extra}.
## `reason` is a localisation key (e.g. "err.not_enough_money"), never prose, so
## the UI decides how to say it and tests compare stable strings.


static func ok(extra: Dictionary = {}) -> Dictionary:
	var out := {"ok": true, "reason": ""}
	out.merge(extra, true)
	return out


static func fail(reason: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "reason": reason}
	out.merge(extra, true)
	return out
