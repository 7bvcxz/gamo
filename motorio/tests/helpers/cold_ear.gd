extends RefCounted

## Shared by the cold-sound tests (World Visual Pass 01).
##
## The complaint was that the freezing sound played once -- as she stepped out
## of the warm -- and never again, however long she stood in the snow going
## numb. These tests drive the real ambience path (`Main._update_ambience`, the
## one Main runs every frame) with her warmth moving the way the world moves it,
## and read what the audio manager started and when (`Audio.chill_log`).

const DT := 1.0 / 30.0

## A fresh run with her far out on the snow, past the fire's reach.
static func out_in_the_cold(main: Node) -> void:
	main.clear_save()
	main._start_run(4242)
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.player.position = main.sim.core_centre() + Vector2(Grid.px(Defs.WARM_BASE + 6.0), 0.0)
	main.player.warmth = 95.0
	main._update_ambience(DT)
	main.audio.advance(1.0)

## Runs `seconds` of ambience with her warmth moving by `rate` a second (negative
## is cooling), kept inside [floor, 100] so a long test does not freeze her.
static func run(main: Node, seconds: float, rate: float, floor: float = 30.0) -> void:
	for step in int(seconds / DT):
		main.player.warmth = clampf(main.player.warmth + rate * DT, floor, 100.0)
		if rate < 0.0 and main.player.warmth <= floor:
			# Held at the floor, it is not falling any more; lift it so the fall
			# goes on, the way a long walk out would.
			main.player.warmth = floor + 20.0
		main._update_ambience(DT)
		main.audio.advance(DT)

static func chills(main: Node) -> int:
	return (main.audio.chill_log as Array).size()
