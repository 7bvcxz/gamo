class_name Zone
## Where the game is, and what is true there.
##
## Two places, one table. The plateau and the shelter are not two scenes in
## Godot's sense -- nothing is loaded or unloaded and no tree is swapped. She
## walks between them on the same grid with the same legs, and that is the
## property that keeps her speed, her collision and her animation identical in
## both; the moment they became two implementations they disagreed, twice, in
## opposite directions. So this is not a scene manager. It is a rule table, and
## what differs between the two places is only ever a rule.
##
## Written after the same leak four times. The shelter sits six hundred cells
## north of the fire, so every rule that reads a world coordinate answers
## "outside, freezing, in the dark" about a warm lit room -- and each of those
## answers arrived as a separate bug: she froze at her own hearth, the outdoor
## toolbelt hung under the floorboards, the key prompt offered a torch to a room
## with no fog, and the procedural rock that exists under a fair share of every
## cell in the world told her the floorboards were frozen to the ground, once
## every three seconds, forever.
##
## The fix for a leak is not another `if` at the leak. It is that anything which
## behaves differently indoors asks here, and that adding a place means adding a
## column rather than finding the seventeen places that assumed there was one.

enum { FIELD, HOME }

## Every rule, for every place. Both rows carry every key -- a missing key is a
## silent `false`, which is the shape all four of those bugs had.
const RULES := {
	FIELD: {
		"id": "field",
		## Does the cold reach her here?
		"cold": true,
		## Does the day advance?
		"clock": true,
		## Does night fall on the screen?
		"dark": true,
		## Is there a world underfoot -- ore, rock, dropped cargo, a base?
		"world": true,
		## Wind and the cold shimmer, which are outdoor sounds.
		"weather": true,
		## What plays under it. Empty is not silence-by-accident: the plateau is
		## carried by its two beds, and a loop under a twelve-minute day comes
		## round often enough to stop being atmosphere.
		"score": "",
	},
	HOME: {
		"id": "home",
		"cold": false,
		"clock": false,
		"dark": false,
		"world": false,
		"weather": false,
		## The one room in the game with music in it. It is also the only room
		## where nothing is being asked of the player.
		"score": "home",
	},
}

static func of(indoors: bool) -> int:
	return HOME if indoors else FIELD

static func id(zone: int) -> String:
	return String(_row(zone)["id"])

## Whether the cold reaches her. False does not mean "not falling" -- it means
## the place warms her, which is what a fire in a hearth does.
static func freezes(zone: int) -> bool:
	return bool(_row(zone)["cold"])

static func clock_runs(zone: int) -> bool:
	return bool(_row(zone)["clock"])

static func darkens(zone: int) -> bool:
	return bool(_row(zone)["dark"])

## Whether there is anything under her feet to pick up, mine, or be refused by.
static func has_world(zone: int) -> bool:
	return bool(_row(zone)["world"])

static func has_weather(zone: int) -> bool:
	return bool(_row(zone)["weather"])

static func score(zone: int) -> String:
	return String(_row(zone)["score"])

static func _row(zone: int) -> Dictionary:
	return RULES.get(zone, RULES[FIELD])
