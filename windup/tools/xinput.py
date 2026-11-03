#!/usr/bin/env python3
"""OS-level mouse/keyboard input on an X display (Xvfb) through the XTEST
extension, with ctypes only (libX11 + libXtst; no xdotool on this machine,
no packages to install). Used to play the real desktop window.

    DISPLAY=:97 python3 windup/tools/xinput.py click 960 570
    DISPLAY=:97 python3 windup/tools/xinput.py down 960 570      # press and keep holding
    DISPLAY=:97 python3 windup/tools/xinput.py up                # release button 1
    DISPLAY=:97 python3 windup/tools/xinput.py key space         # tap a key
    DISPLAY=:97 python3 windup/tools/xinput.py script steps.txt  # one command per line, `sleep S` allowed
"""
import ctypes
import os
import sys
import time

x11 = ctypes.CDLL('libX11.so.6')
xtst = ctypes.CDLL('libXtst.so.6')
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XStringToKeysym.restype = ctypes.c_ulong
x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
x11.XKeysymToKeycode.restype = ctypes.c_ubyte
x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]

dpy = x11.XOpenDisplay(os.environ.get('DISPLAY', ':0').encode())
if not dpy:
    sys.exit('xinput: cannot open display %s' % os.environ.get('DISPLAY'))


def move(x, y):
    xtst.XTestFakeMotionEvent(dpy, -1, int(x), int(y), 0)
    x11.XFlush(dpy)


def button(down):
    xtst.XTestFakeButtonEvent(dpy, 1, 1 if down else 0, 0)
    x11.XFlush(dpy)


def key(name):
    code = x11.XKeysymToKeycode(dpy, x11.XStringToKeysym(name.encode()))
    xtst.XTestFakeKeyEvent(dpy, code, 1, 0)
    x11.XFlush(dpy)
    time.sleep(0.05)
    xtst.XTestFakeKeyEvent(dpy, code, 0, 0)
    x11.XFlush(dpy)


def run(cmd):
    op = cmd[0]
    if op == 'click':
        move(cmd[1], cmd[2]); time.sleep(0.03); button(True); time.sleep(0.06); button(False)
    elif op == 'down':
        move(cmd[1], cmd[2]); time.sleep(0.03); button(True)
    elif op == 'up':
        button(False)
    elif op == 'move':
        move(cmd[1], cmd[2])
    elif op == 'key':
        key(cmd[1])
    elif op == 'sleep':
        time.sleep(float(cmd[1]))
    else:
        sys.exit('xinput: unknown command %s' % op)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args and args[0] == 'script':
        for line in open(args[1]):
            line = line.split('#')[0].strip()
            if line:
                run(line.split())
    elif args:
        run(args)
