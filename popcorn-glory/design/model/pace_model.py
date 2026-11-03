#!/usr/bin/env python3
"""Hand model of the three Popcorn experiments -- NOT the game.

It turns the Step 02 economic hypotheses (design/EXPERIMENTS.md) into first-reward,
first-upgrade and 60/180-second numbers under stated player assumptions, so the
spec says what it expects before any code exists. Step 06 replaces this with a
simulation runner that drives the real game rules; when they disagree, the game
is right and this file is a record of what was guessed.

    python3 popcorn-glory/design/model/pace_model.py

Standard library only. Deterministic (fixed seeds).
"""
import random

DT = 0.01          # seconds per model tick
HORIZON = 180.0
REACT = 1.5        # seconds between "the upgrade is affordable" and the purchase
FIRST_INPUT = 2.0  # a newcomer's first input, seconds after the first frame

# ---------------------------------------------------------------- hypotheses --
A_POPS = [1, 2, 3, 4, 6, 8, 11, 15, 20, 27, 36, 48]   # every upgrade adds at least one pop per tap
A = dict(pops=lambda L: A_POPS[L] if L < len(A_POPS) else round(A_POPS[-1] * 1.33 ** (L - len(A_POPS) + 1)),
         cost=lambda L: round(30 * 1.7 ** L))
B = dict(batch=lambda L: round(5 * 1.6 ** L),
         window_start=1.4, window=lambda L: min(0.45 + 0.05 * L, 0.8), burn_after=0.6,
         early=0.3, perfect=2.0, late=0.6, burnt=0.25, cooldown=0.4,
         cost=lambda L: round(25 * 1.9 ** L))
C = dict(slots=8, burst=lambda L: round(10 * 2.2 ** L),
         show=lambda L: min(1.2 + 0.3 * L, 3.0),
         cost=lambda L: round(30 * 2.6 ** L))


def run_click(taps_per_s):
    money, level, t, nxt, buy_at = 0, 0, 0.0, FIRST_INPUT, None
    log = {'first_earn': None, 'affordable': [], 'bought': [], 'income': 0}
    while t < HORIZON:
        if t >= nxt:
            nxt += 1.0 / taps_per_s
            money += A['pops'](level); log['income'] += A['pops'](level)
            log['first_earn'] = log['first_earn'] or t
        cost = A['cost'](level)
        if buy_at is None and money >= cost:
            buy_at = t + REACT; log['affordable'].append(t)
        if buy_at is not None and t >= buy_at:
            money -= cost; level += 1; buy_at = None; log['bought'].append(t)
        t += DT
    log['level'], log['next_cost'], log['money'] = level, A['cost'](level), money
    log['rate'] = A['pops'](level) * taps_per_s
    log['max_wait'] = 1.0 / taps_per_s
    return log


def run_perfect(mix, seed):
    """mix = {'early': p, 'perfect': p, 'late': p, 'burnt': p}."""
    rng = random.Random(seed)
    money, level, t, buy_at = 0, 0, FIRST_INPUT, None
    log = {'first_earn': None, 'affordable': [], 'bought': [], 'income': 0, 'outcomes': {}}
    while t < HORIZON:
        w0, w = B['window_start'], B['window'](level)
        kind = rng.choices(list(mix), weights=list(mix.values()))[0]
        hold = {'early': w0 * 0.7, 'perfect': w0 + w / 2,
                'late': w0 + w + B['burn_after'] / 2, 'burnt': w0 + w + B['burn_after']}[kind]
        t += hold
        got = max(1, int(B['batch'](level) * B[kind]))
        money += got; log['income'] += got
        log['outcomes'][kind] = log['outcomes'].get(kind, 0) + 1
        log['first_earn'] = log['first_earn'] or t
        t += B['cooldown'] + 0.3   # the pop, then the thumb comes back
        cost = B['cost'](level)
        if money >= cost:
            log['affordable'].append(t); t += REACT
            money -= cost; level += 1; log['bought'].append(t)
    log['level'], log['next_cost'], log['money'] = level, B['cost'](level), money
    avg_cycle = 2.6
    exp_mult = sum(B[k] * p for k, p in mix.items())
    log['rate'] = B['batch'](level) * exp_mult / avg_cycle
    log['max_wait'] = B['cooldown']
    return log


def run_explosion(taps_per_s):
    money, level, t, nxt, loaded, show_end, buy_at = 0, 0, 0.0, FIRST_INPUT, 0, 0.0, None
    log = {'first_earn': None, 'affordable': [], 'bought': [], 'income': 0, 'bursts': 0}
    while t < HORIZON:
        if t >= nxt:
            nxt += 1.0 / taps_per_s
            loaded += 1
            if loaded >= C['slots'] and t >= show_end:
                loaded = 0; log['bursts'] += 1
                show_end = t + C['show'](level)
                got = C['burst'](level)
                money += got; log['income'] += got
                log['first_earn'] = log['first_earn'] or t
            loaded = min(loaded, C['slots'])
        cost = C['cost'](level)
        if buy_at is None and money >= cost:
            buy_at = t + REACT; log['affordable'].append(t)
        if buy_at is not None and t >= buy_at:
            money -= cost; level += 1; buy_at = None; log['bought'].append(t)
        t += DT
    log['level'], log['next_cost'], log['money'] = level, C['cost'](level), money
    cycle = max(C['slots'] / taps_per_s, C['show'](level))
    log['rate'] = C['burst'](level) / cycle
    log['max_wait'] = max(0.0, C['show'](level) - C['slots'] / taps_per_s)
    return log


def row(name, log):
    b = log['bought']
    by = lambda s: sum(1 for x in b if x <= s)
    gap_180 = max(0.0, (log['next_cost'] - log['money']) / log['rate'])
    f = lambda v: '-' if v is None else f'{v:5.1f}'
    return (f"| {name} | Lv{log['level']} | {f(log['first_earn'])} | {f(log['affordable'][0] if log['affordable'] else None)} | "
            f"{f(b[0] if b else None)} | {by(60)} | {by(180)} | {gap_180:5.1f} | {log['max_wait']:.1f} |")


if __name__ == '__main__':
    print('| player model | level at 3:00 | first $ (s) | 1st upgrade affordable (s) | 1st bought (s) | upgrades by 60 s | by 180 s | next upgrade at 3:00 (s away) | longest forced wait (s) |')
    print('|---|---|---|---|---|---|---|---|---|')
    print(row('A steady 2.5 taps/s', run_click(2.5)))
    print(row('A slow 1.2 taps/s', run_click(1.2)))
    print(row('B skilled (80% perfect)', run_perfect({'early': .05, 'perfect': .80, 'late': .15}, 1)))
    print(row('B novice (35% perfect)', run_perfect({'early': .20, 'perfect': .35, 'late': .35, 'burnt': .10}, 2)))
    print(row('C steady 2.5 taps/s', run_explosion(2.5)))
    print(row('C slow 1.2 taps/s', run_explosion(1.2)))
