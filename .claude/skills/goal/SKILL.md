---
name: goal
description: Autonomous development loop for one game folder. Reads GOAL.md, implements one unmet condition at a time, verifies headless, and repeats without asking until every condition is met. Invoke as /goal <game-folder>.
---

# /goal — autonomous development loop

Argument: a game folder at the repository root, e.g. `/goal gunslinger`.

Everything below is about **one** folder. Do not touch another game's files.

## How far this loop actually reaches

It runs while a turn is running and stops when the turn ends. There is no
background process; the next cycle happens when the user says something.

Say so, and act accordingly:

- Do as many cycles as you can in one turn. Every stop costs the user a message.
- When you do stop, say which condition you are on and what is next, so the
  answer to "is it still going?" is already on the screen.
- Do not open by describing what is missing. Reporting "PROGRESS.md does not
  exist" as the first thing reads as nothing having happened; create it and
  report the first condition instead.

## 1. Read before doing anything

- `<folder>/GOAL.md` — the target. Its checkboxes are the definition of done.
- `<folder>/PROGRESS.md` — the record. **Create it if missing** with the headings
  `## 로그`, `## 제안`, `## 막힌 것`.

If `GOAL.md` is missing, stop and say so. Do not invent a goal.

## 2. Pick exactly one condition

Choose one unchecked box from `GOAL.md`. Prefer the one that unblocks the most
others; otherwise take them in order.

Append to `PROGRESS.md` under `## 로그` before writing any code:

```
- [진행 중] <condition text> — <timestamp>
```

**One condition per cycle.** Finishing two at once means neither was verified on
its own, and when the headless run fails you will not know which change caused
it.

## 3. Implement

- Obey the **하지 말 것** section of `GOAL.md` absolutely. It is not advice. If a
  condition seems to require something that section forbids, record the conflict
  under `## 막힌 것` and move to another condition.
- **Art is shapes and colour only.** `draw_rect`, `draw_circle`, `draw_polygon`,
  `draw_line`. No image files, no fonts beyond what the project already has, no
  sourced assets. A rectangle of the right colour in the right place is finished
  art for this purpose.
- Anything you think of that is **not** in `GOAL.md` — a mechanic, a screen, a
  polish idea — goes under `## 제안` in `PROGRESS.md` as one line. Do not build
  it. The goal is the scope; a loop that widens its own scope never terminates.

## 4. Verify

Two checks, and the first one alone is never enough.

**The project still loads:**

```
godot --headless --path <folder> --quit-after 5
```

Read the **output**, not just the exit code. Godot exits 0 with a broken script,
so treat any `SCRIPT ERROR`, `ERROR`, or parse failure in the output as a
failure even when the command "succeeded". Leaked-resource warnings at shutdown
count too.

**The condition is actually true.** Loading proves the script parses. It does
not prove the flow cycles, the wait is random, the reaction is measured, or the
match ends at two wins -- and ticking a box on a clean load is how a goal gets
declared met without evidence. Write a `tests/test_<thing>.gd` that drives the
thing and asserts it, run it, and cite it when you tick the box.

Two real bugs in one game came from this and neither was findable by playing:
a rival that never fired if the player pressed nothing, because that only
reproduces when you sit still; and a tap counting twice on a phone, which turned
the next round into an instant foul the player did not cause.

**Anything visual or exported: look at it.** Take a screenshot at the size it
will be used -- a phone viewport for a touch condition -- and read it. One export
"succeeded" while the game drew into the top 40% of a phone screen and left the
rest grey, and the export log said nothing about that. For a web export also
measure how long it takes to become *playable*, not merely to exist: wait for the
canvas to contain more than one colour, because engines create their canvas long
before they can draw into it.

Expect earlier tests to break as conditions accumulate: the foul rule made "an
early press is ignored" false, best-of-three made "the result always leads to a
duel" false. That happened four times in nine conditions and none were
regressions. When one breaks, decide which is stale -- the test or the code --
and say which in `PROGRESS.md`. Once it was the test that had the game wrong.

On failure: fix and run again. **Three attempts on one condition, then stop
attempting it** — record under `## 막힌 것`:

```
- <condition text> — 3회 실패. 마지막 오류: <the actual message>. 추정 원인: <yours>
```

Then leave its checkbox unchecked and move to the next condition. Do not delete
the work; leave it in a state that still passes headless, reverting your changes
if that is what it takes.

## 5. Record success

Only after a clean headless run:

- Tick the checkbox in `GOAL.md`.
- One line under `## 로그` in `PROGRESS.md`: what now works, and how it was
  verified. Not what you edited — what a player can now do.

## 6. Repeat

If any box is unchecked and not in `## 막힌 것`, **go back to step 2 immediately.
Do not ask the user whether to continue.** The loop is the point; stopping to
check in defeats it.

## 7. Finish

When every box is either ticked or recorded as blocked:

1. HTML5 export to `docs/<folder>/` — the repository's `./deploy-web.sh <folder>`
   already does this and knows the conventions.
2. Commit and push the folder plus `docs/<folder>/`.
3. Print:

```
DONE: <folder>
```

followed by a summary: which conditions passed, which are blocked and why, what
is under `## 제안`, and your own answer to the 핵심 검증 질문 in `GOAL.md` —
whether the thing is actually fun, said plainly, including if the answer is no.
That question is why the POC exists; a summary that dodges it is worth nothing.

## Mistakes and lessons

When something bites you — a Godot API that does not exist, a type inference
error, a wrong assumption about the engine — write it down where the next run
will read it before starting. That is `CLAUDE.md`. **In this repository
`CLAUDE.md` only imports `AGENTS.md`, so the lesson goes in `AGENTS.md` under
"실수와 교훈"**; splitting rules across both files is what that import exists to
prevent.

Write the cause and the prevention, not the symptom. "It failed" helps nobody;
"`Rect2` has no `translated()`, construct `Rect2(pos + offset, size)` instead"
stops it happening again.
