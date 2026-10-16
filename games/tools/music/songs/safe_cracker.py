"""Safe Cracker (#41, #55): "Night Shift", swung spy-jazz at 120 bpm in C minor, for a heist.
The ride's ding-ding-a-ding, cross-stick and finger snaps, a walking bass; vibraphone and Rhodes
comping, muted-trumpet stabs; a reedy sax-like lead in the verse and a low, twangy spy guitar
in the chorus. The harmony and lead come in while the rider is steady and drop out while the
alarm rings. Written for this repo."""
import numpy as np

import instruments as ins
import sfx as fx
from compose import note

PREFIX = "Safe"

SONG = dict(
    file="night_shift", title="Night Shift", bpm=120, key="C", scale=[0, 2, 3, 5, 7, 8, 11], seed=31,
    drums="spy", bass="walk", swing=0.08, verb_sec=2.0,
    form=([("intro", 4)], [("verse", 8), ("chorus", 8), ("bridge", 8)]),
    chords=dict(
        intro=["Cm", "Cm", "Ab7", "G7"],
        verse=["Cm", "Cmmaj7", "Cm7", "Cm6", "Fm", "Fm7", "Ab7", "G7"],
        chorus=["Abmaj7", "Fm7", "Dm7b5", "G7", "Abmaj7", "Fm7", "Dm7b5 G7", "Cm"],
        bridge=["Ebmaj7", "Abmaj7", "Dm7b5", "G7", "Ebmaj7", "Abmaj7", "Fm7", "G7b9"],
    ),
    melody=dict(
        verse="G4:1.5 Eb5:0.5 D5:1 C5:1 | B4:2 r:0.5 G4:0.5 B4:0.5 D5:0.5 | Bb4:1.5 C5:0.5 Eb5:1 G5:1 |"
              " A4:2 r:1 G4:1 | Ab4:1 C5:1 F5:1.5 Eb5:0.5 | Eb5:1 C5:0.5 Ab4:0.5 F4:2 |"
              " Gb4:1 Ab4:1 C5:1 Eb5:1 | D5:1 B4:1 G4:2",
        chorus="C5:1 Eb5:1 G5:2 | Ab5:1 G5:0.5 F5:0.5 Eb5:2 | F5:1 Ab5:1 C6:1 Ab5:1 | B5:2 G5:1 F5:1 |"
               " Eb5:1 G5:1 C6:1.5 Bb5:0.5 | Ab5:1 F5:1 C5:2 | D5:1 F5:1 B4:1 D5:1 | C5:3 r:1",
        bridge="G5:2 Bb5:1 D6:1 | C6:2 G5:2 | Ab5:1 F5:1 D5:2 | B4:2 r:2 | Bb4:1 D5:1 G5:2 | Eb5:1 G5:1 C6:2 |"
               " Ab5:1 F5:1 Eb5:1 C5:1 | Ab5:1 F5:1 D5:1 B4:1",
    ),
    parts=dict(
        intro=[("comp", "ep_hold", 0.6)],
        verse=[("comp", "vibes", 0.8), ("comp", "ep_hold", 0.4), ("lead", "verse", "sax", "lead", 0, 0.85)],
        chorus=[("comp", "muted_stabs", 0.8), ("comp", "ep", 0.6), ("lead", "chorus", "twang", "lead", -12, 0.95),
                ("counter", "muted", "lead2", 0.5)],
        bridge=[("comp", "vibes", 0.7), ("comp", "pad", 0.45), ("lead", "bridge", "vibes", "lead", 0, 0.9)],
    ),
    levels={"cym": -28, "perc": -30, "snare": -23},
)

BEAT = 0.5


def tumbler_click(rng):
    # A tumbler falls: a crisp mechanical click with a small metallic ring on the key's fifth.
    return fx.mix((0, fx.tick(2600, 0.05, rng)), (0.004, fx.tick(4100, 0.04, rng) * 0.6),
                  (0.01, ins.vibes(note("G6"), 0.1, 0.5, rng)), (0, fx.thud(0.08, 300, 200, rng, 1.0) * 0.4))


def proximity_tick(rng):
    # Warm: a soft wooden tick (the game plays it faster and higher as the dial nears the number).
    return fx.mix((0, ins.rim(0.8, rng)), (0, fx.tick(1800, 0.04, rng) * 0.4))


def soft_alarm(rng):
    # Too hard: a soft two-tone alarm bell (vibes on a tritone, pulsing) under a low buzz.
    parts = []
    for i in range(4):
        parts.append((i * 0.28, ins.vibes(note("F#6") if i % 2 == 0 else note("C6"), 0.22, 0.9, rng, tremolo=11)))
    buzz = fx.env(fx.sweep(1.1, 110, 110, "square") * 0.06, 0.05, 0.3)
    return fx.mix(*parts, (0, buzz))


def vault_open(rng):
    # Cracked: the bolts clunk back, then a sly C major lift (vibes and muted brass).
    clunks = fx.mix((0, fx.thud(0.3, 80, 60, rng, 1.0)), (0.12, fx.thud(0.25, 95, 50, rng, 1.0) * 0.8),
                    (0.22, fx.tick(1500, 0.05, rng) * 0.5))
    lift = fx.mix((0, fx.chord([note("C5"), note("E5"), note("G5"), note("B5")], 1.2, "vibes", 0.8, rng, spread=0.04)),
                  (0, fx.fanfare([(0, 0.5, note("G4")), (0.5, 0.5, note("C5")), (1, 2, note("E5"))], 0.2, "muted", rng, vel=0.8)))
    return fx.mix((0, clunks), (0.3, lift))


def door_creak(rng):
    return fx.creak(1.2, 70, rng) * 0.8


SFX = {"tumbler_click": tumbler_click, "proximity_tick": proximity_tick, "soft_alarm": soft_alarm,
       "vault_open": vault_open, "door_creak": door_creak}
