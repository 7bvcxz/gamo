# The loops' hiss, measured (ffmpeg volumedetect on the synthesised WAV, before Ogg encoding)

"above 4 kHz" = the same file through two 4 kHz high-pass filters. The bigger the gap from the
mean, the less hiss. The factory's heat replaces the B experiment's sizzle in the factory only.

| loop | mean | above 4 kHz | gap |
|---|---|---|---|
| sizzle (B experiment, Step 05; unchanged) | -20.7 dB | -27.7 dB | 7.0 dB |
| heat (factory kettle, Step 43) | -23.7 dB | -41.9 dB | 18.2 dB |
| hum (bed) | -16.5 dB | -56.7 dB | 40.2 dB |
| belt (bed) | -28.0 dB | -44.5 dB | 16.5 dB |
| murmur (bed) | -26.6 dB | -37.5 dB | 10.9 dB |
| chug (bed) | -26.8 dB | -47.5 dB | 20.7 dB |
| rise (anticipation pad) | -20.5 dB | -90.3 dB | 69.8 dB |

The beds then play 15-18 dB under their files (design/SOUND.md section 3) and 8 dB more of headroom.
