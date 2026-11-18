#!/usr/bin/env python3
"""Step 39: the career sim's segments as a table (AUTOMATIC SIMULATION, not players).
   python3 career39_table.py <dir> [<dir2>]  -- with two dirs: before -> after per cell."""
import csv, sys, collections
SEG = [(0, 3), (3, 10), (10, 20), (20, 30), (30, 60), (60, 90)]
def load(d):
    rows = list(csv.DictReader(open(d + '/career.csv')))
    by = collections.defaultdict(list)
    for r in rows:
        by[r['run']].append(r)
    return by
def seg(rs, a, b):
    s = [r for r in rs if a < int(r['min']) <= b]
    if not s:
        return None
    avg = lambda k: sum(float(r[k]) for r in s) / len(s)
    bn = collections.Counter(r['bottleneck'] or '-' for r in s)
    last = s[-1]
    return {'net': avg('net_pm'), 'rev': avg('revenue_pm'), 'upk': avg('upkeep_pm') + avg('inputs_pm'), 'sold': avg('sold_pm'), 'made': avg('made_pm'),
            'lost': avg('lost_pm'), 'left': avg('left_pm'), 'shelf': avg('shelf'), 'queue': avg('queue'), 'machines': int(last['machines']), 'running': int(last['running']),
            'sign': last['sign'], 'station': last['station'], 'kettle': last['kettle'], 'bn': bn.most_common(1)[0][0], 'presses': avg('presses_pm'), 'money': int(last['money'])}
if __name__ == '__main__':
    a = load(sys.argv[1])
    b = load(sys.argv[2]) if len(sys.argv) > 2 else None
    print('| run | segment | net/min | revenue | costs | sold/min | made/min | lost/min (left) | shelf | queue | machines (running) | sign/station/kettle | bottleneck | presses/min |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    for run in a:
        for (x, y) in SEG:
            s = seg(a[run], x, y)
            if not s:
                continue
            t = seg(b[run], x, y) if b and run in b else None
            f = lambda k, fmt='%.1f': (fmt % s[k]) + ((' → ' + fmt % t[k]) if t else '')
            g = lambda k: str(s[k]) + ((' → ' + str(t[k])) if t else '')
            print(f"| {run} | {x}–{y} | {f('net')} | {f('rev')} | {f('upk')} | {f('sold')} | {f('made')} | {f('lost')} ({f('left')}) | {f('shelf')} | {f('queue')} | {g('machines')} ({g('running')}) | {g('sign')}/{g('station')}/{g('kettle')} | {g('bn')} | {f('presses')} |")
