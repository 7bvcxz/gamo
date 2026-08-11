# graphic/proposals

Object art up for a decision, before anything is drawn as pixels.

Each subject arrives as three candidates. `_<subject>.png` puts them side by side
at **128** and at **64**, on a checkerboard so transparency reads as
transparency. Both sizes are there on purpose: 128 is what a pixel pass would be
traced from, 64 is nearer what the game actually shows, and a design that reads
at 128 and turns to mush at 64 is the whole reason to look before tracing.

Individual renders are `<subject><n>-128.png` and `<subject><n>-64.png`.

The originals live in `motorio-oneshot/tools/sprite/objects/`, beside the `refs/`
and `tiles/` that feed the other two kinds of art. They stay in the repository
and out of the Web export, because everything under `tools/` is excluded from it.

Regenerate:

```
python3 motorio-oneshot/tools/sprite/build_objects.py
```

It picks up `*-Photoroom.png` from `~/Workspace/Download`, drops the suffix,
moves the original into `objects/`, and writes both sizes plus the sheets. Two
things it handles that are easy to get wrong by hand, and both are in the
script's own comments: the cutouts carry a film of `alpha=1` dust that makes a
plain bounding box return the whole canvas, and Pillow resizes colour without
regard to alpha, which puts a halo of the matting colour around every edge.
