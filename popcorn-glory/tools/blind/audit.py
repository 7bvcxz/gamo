#!/usr/bin/env python3
"""Blind-condition audit: did a player agent touch anything but the phone?

Reads a player agent's own transcript (Claude Code subagent JSONL) and lists
every tool call. A call is flagged when it
  - is a Bash command whose tokens (after dropping the note text) name a
    program other than the phone tool and shell glue, or a path other than the
    phone tool and the player's own run folder;
  - is a Read of anything but that run's screenshots;
  - uses any other tool (web, search, edit ...).
Pipes like `| tail -1` that only filter the phone tool's own output are listed
separately: they read nothing else.

    python3 -I audit.py RUN_NAME TRANSCRIPT.jsonl [RUN_NAME TRANSCRIPT.jsonl ...]

Exit code 1 if anything was flagged. The audit is evidence, not enforcement:
the agents could have read files; this shows whether they did.
"""
import json
import re
import shlex
import sys

GLUE = {"node", "sleep", "for", "do", "done", "in", "seq", "echo", "true", "if", "then", "fi",
        "while", "break", "printf", "look", "tap", "hold", "drag", "path", "wait", "status"}
FILTERS = {"tail", "head", "grep"}


def calls(path):
    for line in open(path, encoding="utf-8"):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        m = o.get("message")
        c = m.get("content") if isinstance(m, dict) else None
        if not isinstance(c, list):
            continue
        for b in c:
            if isinstance(b, dict) and b.get("type") == "tool_use":
                yield b["name"], b.get("input", {})


def audit(run, path):
    counts, flagged, filters = {}, [], set()
    own = re.compile(r"(scratchpad|\$\w+|\$\{\w+\})(/phone(/play\.mjs)?|/blind\w*/" + re.escape(run) + r")?/?$")
    for name, inp in calls(path):
        counts[name] = counts.get(name, 0) + 1
        if name == "Read":
            if not re.search(r"/" + re.escape(run) + r"/player/shots/\d+\.png$", inp.get("file_path", "")):
                flagged.append("Read " + inp.get("file_path", ""))
            continue
        if name != "Bash":
            flagged.append("tool " + name)
            continue
        cmd = inp.get("command", "")
        try:
            toks = shlex.split(re.sub(r"(;|&&|\|\||\n)", r" \1 ", cmd).replace("|", " | "))
        except ValueError:
            flagged.append("unparseable: " + cmd[:160])
            continue
        out, skip, after_pipe, standalone, filter_args, filter_files = [], False, False, False, False, []
        for t in toks:
            if skip:
                skip = False
                continue
            if t in ("|", ";", "&&", "||"):
                filter_args = False
            elif filter_args:
                # A piped filter's own pattern and flags (`grep -v screenshot`):
                # not programs; a path here would be a file read.
                if "/" in t:
                    filter_files.append(t)
                continue
            if t == "note":
                skip = True
                continue
            if t in FILTERS:
                if after_pipe:
                    filters.add(t)
                    filter_args = True
                else:
                    standalone = True  # `tail somefile` reads a file
            after_pipe = t == "|"
            out.append(t)
        progs = {t for t in out if re.fullmatch(r"[a-z][a-z0-9_.-]*", t)} - GLUE - FILTERS
        progs = {p for p in progs if not re.fullmatch(r"-?[a-z]", p)}  # loop variables
        paths = [re.sub(r"^\d?>>?|^&>", "", t.split("=", 1)[-1]) for t in out if "/" in t]
        paths = [p for p in paths if p and p != "/dev/null"]
        paths = [p for p in paths if not own.search(p)]
        files_to_filters = filter_files
        if progs or paths or files_to_filters or standalone:
            why = sorted(progs) + paths + files_to_filters + (["filter on a file"] if standalone else [])
            flagged.append("%s  <- %s" % (cmd[:160].replace("\n", " "), why))
    return counts, flagged, filters


def main(argv):
    if len(argv) < 2 or len(argv) % 2:
        print(__doc__)
        return 2
    bad = 0
    for i in range(0, len(argv), 2):
        counts, flagged, filters = audit(argv[i], argv[i + 1])
        bad += len(flagged)
        note = " (pipes only filter the phone tool's output: %s)" % ", ".join(sorted(filters)) if filters else ""
        print("%s: tool calls %s; flagged %d%s" % (argv[i], counts, len(flagged), note))
        for f in flagged:
            print("    " + f)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
