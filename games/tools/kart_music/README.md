# Kart Race music renderer (#43)

Renders Kart Race's music offline to OGG Vorbis in `games/kart_race/music/` and writes
`games/kart_race/audio/KartMusicIndex.gd`. Everything is original and synthesised here: no
samples, no soundfonts, no third-party material.

```
python3 -m venv /tmp/kartmusic && /tmp/kartmusic/bin/pip install numpy scipy soundfile
/tmp/kartmusic/bin/python games/tools/kart_music/render_kart_music.py     # about 45 s
```

`--only meadow` renders one theme; `--wav DIR` also writes float WAVs for analysis. The output
is deterministic. Re-run Godot's import after rendering.

## Contents

- `themes.py`: the four themes (chords, melodies, arrangement per section), the results loop
  and the podium fanfare.
  - Meadow Ring is sunny funk-pop at 150 bpm in D.
  - Canyon Dash is twangy desert rock at 156 bpm in E Mixolydian.
  - Harbor Lights is a sunset groove at 140 bpm in F.
  - Frost Pass is bright, with sleigh bells, at 152 bpm in A.
- `arrange.py`: the parts.
  - Drums: funk, train-beat, disco or pop grooves, fills, half-time breakdowns, builds and
    double-time hats.
  - Bass: slap, picked, octave or synth.
  - Comping: double-tracked guitar chops, power chords, Rhodes, piano, brass stabs, pads and
    plucked arpeggios.
  - Lines: the leads, a third-below harmony and an automatic countermelody.
- `instruments.py`: the instruments.
  - Drums: synthesised kick, snare, clap, hats, shaker, tambourine, sleigh bells, toms, crash
    and ride.
  - Strings: Karplus-Strong bass and guitars.
  - Keys: an FM electric piano, an additive piano, glockenspiel and organ.
  - Synths and horns: supersaw, synth brass, a breathy FM lead, a reedy sax-like lead and a pad.
- `dsp.py`: the signal chain. Band-limited oscillators, filters, chorus, ping-pong delay,
  convolution reverb with synthetic impulse responses, compression, a look-ahead limiter and
  BS.1770 loudness.
- `compose.py`: the theory helpers and `Song`, which schedules notes onto buses. Its mix
  balances each bus to a target RMS and adds the kick-keyed pump, the sends, glue compression
  and the limiter, then sets the loudness. The files come out at -15 LUFS with true peak under
  -1 dBTP.

## Form and loops

- **Race theme.** A 4-bar intro, then a 40-bar body that loops: verse, chorus, verse 2 (new
  lead, countermelody), bridge (half-time, then a build), and chorus 2 (harmony, counter). It
  lasts about 64 s, so a 3-minute race hears about 2.5 passes.
- **Final-lap version.** A 2-bar pickup, then two choruses two semitones up, with double-time
  hats and the hook doubled an octave up.
- **Seamless loops.** The body is rendered twice, and the file keeps the intro plus the second
  pass. The second pass starts with the first pass's tails, and both passes use the same seeds,
  so the loop point is seamless. `loop_from` in the index is where the body starts.
