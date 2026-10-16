"""Tug of War (#40, #55): "Heave Together", a stomp-clap sea shanty at 132 bpm in D minor, for a
tug on the pier. Stomps and claps, a tambourine, double-tracked acoustic strums, an accordion
oom-pah, a picked root-fifth bass; a tin whistle sings the verse and brass with the accordion
an octave down carry the chorus. The harmony comes in once the rope is tight, the lead in a
surge. Written for this repo."""
import numpy as np

import instruments as ins
import sfx as fx
from compose import note

PREFIX = "Tug"

SONG = dict(
    file="heave_together", title="Heave Together", bpm=132, key="D", scale=[0, 2, 3, 5, 7, 8, 10], seed=21,
    drums="stomp", bass="root5", verb_sec=1.4,
    form=([("intro", 4)], [("verse", 8), ("chorus", 8), ("bridge", 8), ("chorus2", 8)]),
    chords=dict(
        intro=["Dm", "Dm", "C", "A7"],
        verse=["Dm", "C", "Dm", "A7", "Dm", "F", "C", "Dm"],
        chorus=["F", "C", "Dm", "A7", "F", "C", "Bb A7", "Dm"],
        bridge=["Bb", "F", "C", "Dm", "Bb", "F", "Gm", "A7"],
    ),
    melody=dict(
        verse="D5:0.5 D5:0.5 F5:0.5 A5:0.5 A5:1 G5:0.5 F5:0.5 | E5:1 C5:0.5 E5:0.5 G5:1 r:1 |"
              " D5:0.5 D5:0.5 F5:0.5 A5:0.5 D6:1 C6:0.5 A5:0.5 | C#6:1.5 A5:0.5 E5:1 r:1 |"
              " D5:0.5 F5:0.5 A5:0.5 D6:0.5 C6:1 A5:1 | C6:0.5 A5:0.5 F5:0.5 A5:0.5 C6:1 r:1 |"
              " G5:0.5 A5:0.5 G5:0.5 E5:0.5 C5:1 E5:1 | D5:3 r:1",
        chorus="A4:1 A4:1 C5:1.5 A4:0.5 | G4:1 E4:1 C4:2 | F4:1 A4:1 D5:1.5 C5:0.5 | A4:1 G4:0.5 F4:0.5 E4:2 |"
               " A4:1 A4:1 C5:1.5 D5:0.5 | E5:1 D5:0.5 C5:0.5 G4:2 | F4:1 D5:1 C#5:1 E4:1 | D4:2 r:2",
        bridge="D5:2 F5:2 | C5:2 A4:2 | E5:1 G5:1 C6:2 | A5:3 r:1 | D6:2 F5:2 | A5:2 C6:2 | Bb5:1 G5:1 D5:2 | E5:2 C#5:2",
    ),
    parts=dict(
        intro=[("comp", "strum", 0.7)],
        verse=[("comp", "strum", 0.9), ("comp", "oompah", 0.6), ("lead", "verse", "whistle", "lead", 0, 0.9)],
        chorus=[("comp", "strum", 0.9), ("comp", "acc_hold", 0.55), ("comp", "stabs", 0.6),
                ("lead", "chorus", "brass", "lead", 12, 0.9), ("lead", "chorus", "accordion", "lead2", 0, 0.6)],
        bridge=[("comp", "acc_hold", 0.7), ("comp", "pad", 0.5), ("lead", "bridge", "accordion", "lead", 0, 0.8)],
        chorus2=[("comp", "strum", 0.9), ("comp", "acc_hold", 0.55), ("comp", "stabs", 0.6),
                 ("lead", "chorus", "brass", "lead", 12, 0.9, True), ("lead", "chorus", "whistle", "lead2", 12, 0.4)],
    ),
)

BEAT = 60 / 132


def rope_creak(rng):
    return fx.creak(0.55, 130, rng)


def surge_drumroll(rng):
    # The bot surges: a snare roll swelling into a floor-tom hit and a low brass stab.
    roll = fx.drumroll(1.1, rng)
    hit = fx.mix((0, ins.tom(1.0, rng, pitch=0.6)), (0, ins.crash(0.5, rng)[: int(0.8 * 32000)]),
                  (0, fx.chord([note("D3"), note("A3"), note("D4")], 0.4, "brass", 0.8, rng)))
    return fx.mix((0, roll * 0.8), (1.1, hit))


def crowd_swell(rng):
    return fx.crowd(2.2, rng)


def win_sting(rng):
    # A round won: the brass jumps to D major, with a stomp and a crash.
    notes = [(0, 0.5, note("A4")), (0.5, 0.5, note("D5")), (1, 0.5, note("F#5")), (1.5, 2.5, note("A5"))]
    top = fx.fanfare(notes, BEAT, "brass", rng)
    under = fx.fanfare([(1.5, 2.5, note("D5")), (1.5, 2.5, note("F#4"))], BEAT, "brass", rng, vel=0.6)
    acc = fx.fanfare([(1.5, 2.5, note("D4"))], BEAT, "accordion", rng, vel=0.8)
    return fx.mix((0, top), (0, under), (0, acc), (0, ins.stomp(1.0, rng) * 0.8), (1.5 * BEAT, ins.stomp(1.0, rng)),
                  (1.5 * BEAT, ins.crash(0.6, rng)))


def lose_sting(rng):
    # A round lost: the brass slumps down the minor scale.
    notes = [(0, 0.5, note("A4")), (0.5, 0.5, note("F4")), (1, 0.5, note("E4")), (1.5, 2.0, note("D4"))]
    return fx.mix((0, fx.fanfare(notes, BEAT, "brass", rng)), (0, fx.fanfare([(1.5, 2.0, note("D3"))], BEAT, "brass", rng, vel=0.7)),
                  (1.5 * BEAT, ins.stomp(0.8, rng)))


def splash(rng):
    return fx.splash(1.3, rng)


SFX = {"rope_creak": rope_creak, "surge_drumroll": surge_drumroll, "crowd_swell": crowd_swell,
       "win_sting": win_sting, "lose_sting": lose_sting, "splash": splash}
