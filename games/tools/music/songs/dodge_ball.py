"""Dodge Ball (#39, #55): "Incoming!", punchy electro-rock at 150 bpm in E minor. Syncopated rock
drums with a ride in the chorus, a synth bass, palm-muted chugs and brass stabs in the verse,
open power chords, a pad and a supersaw hook in the chorus. The lead (the melody) comes in over
the power target, the harmony once the rider is over the cadence floor. Written for this repo."""
import numpy as np

import instruments as ins
import sfx as fx
from compose import note
from dsp import secs

PREFIX = "Dodge"

SONG = dict(
    file="incoming", title="Incoming!", bpm=150, key="E", scale=[0, 2, 3, 5, 7, 8, 10], seed=11,
    drums="drive", bass="pop",
    form=([("intro", 4)], [("verse", 8), ("chorus", 8), ("bridge", 8), ("chorus2", 8)]),
    chords=dict(
        intro=["Em", "Em", "C", "D"],
        verse=["Em", "Em", "C", "D", "Em", "Em", "Am", "B7"],
        chorus=["C", "D", "Em", "Bm7", "C", "D", "B7sus4", "B7"],
        bridge=["Am7", "Bm7", "Cmaj7", "D", "Am7", "Bm7", "C", "B7"],
    ),
    melody=dict(
        verse="r:0.5 E4:0.5 G4:0.5 B4:0.5 E5:1 D5:0.5 B4:0.5 | D5:1 B4:0.5 G4:0.5 A4:1 r:1 |"
              " r:0.5 C5:0.5 E5:0.5 G5:0.5 E5:1 C5:0.5 E5:0.5 | F#5:1.5 E5:0.5 D5:1 r:1 |"
              " r:0.5 E4:0.5 G4:0.5 B4:0.5 E5:1 G5:0.5 E5:0.5 | F#5:1 E5:0.5 D5:0.5 B4:1 r:1 |"
              " C5:0.5 B4:0.5 A4:0.5 C5:0.5 E5:1 A5:1 | F#5:1 D#5:1 B4:1 r:1",
        chorus="G5:1 E5:0.5 G5:0.5 C6:1 B5:0.5 G5:0.5 | A5:1.5 F#5:0.5 D5:1 r:1 |"
               " G5:0.5 F#5:0.5 E5:0.5 F#5:0.5 G5:1 B5:1 | A5:1.5 F#5:0.5 D5:1 r:1 |"
               " G5:1 E5:0.5 G5:0.5 C6:1 D6:0.5 C6:0.5 | B5:1 A5:0.5 F#5:0.5 D6:1 r:1 |"
               " E5:0.5 F#5:0.5 A5:0.5 B5:0.5 E6:1 D#6:1 | D#6:1 B5:1 F#5:1 r:1",
        bridge="E5:2 C5:1 A4:1 | D5:2 B4:1 F#4:1 | E5:1 G5:1 B5:2 | A5:3 r:1 |"
               " C6:2 A5:1 E5:1 | D6:2 B5:1 F#5:1 | G5:1 E5:1 C5:1 E5:1 | F#5:2 D#5:2",
    ),
    parts=dict(
        intro=[("comp", "pad", 0.6), ("comp", "chug", 0.5)],
        verse=[("comp", "chug", 0.8), ("comp", "stabs", 0.7), ("lead", "verse", "brass", "lead", 0, 0.85)],
        chorus=[("comp", "power", 0.9), ("comp", "pad", 0.6), ("comp", "stabs", 0.7),
                ("lead", "chorus", "supersaw", "lead", 0, 0.9), ("lead", "chorus", "brass", "lead2", -12, 0.55)],
        bridge=[("comp", "pad", 0.8), ("comp", "arp", 0.6), ("lead", "bridge", "supersaw", "lead", 0, 0.75)],
        chorus2=[("comp", "power", 0.9), ("comp", "pad", 0.6), ("comp", "stabs", 0.7),
                 ("lead", "chorus", "supersaw", "lead", 0, 0.9, True), ("counter", "strings", "lead2", 0.55)],
    ),
)

E = note("E5")


def launch_whoosh(rng):
    # The ball leaves the launcher: a low thump and a rising rush of air.
    return fx.mix((0, fx.thud(0.25, 60, 50, rng, 0.3) * 0.5), (0.02, fx.whoosh(0.5, 400, 4500, True, rng, 0.7)))


def dodge_tick(rng):
    # A clean dodge: a bright swish past and a plucked "tink" on the key's fifth.
    return fx.mix((0, fx.whoosh(0.16, 2000, 9000, False, rng, 0.2) * 0.6), (0.03, ins.pluck(note("B5"), 0.12, 1.0, rng) * 1.3),
                  (0.03, fx.tick(5200, 0.05, rng) * 0.3))


def catch_chime(rng):
    # A catch: two bells up a fourth, with a palm slap.
    return fx.mix((0, fx.thud(0.12, 160, 100, rng, 1.0) * 0.4), (0.02, ins.bells(note("B5"), 0.15, 1.0, rng)),
                  (0.1, ins.bells(note("E6"), 0.3, 1.0, rng)), (0.02, ins.pluck(note("B4"), 0.25, 0.8, rng)))


def miss_whiff(rng):
    # A missed catch: an empty swipe falling away and a low "bwomp".
    return fx.mix((0, fx.whoosh(0.3, 3000, 400, True, rng, 0.3)), (0.08, fx.env(fx.sweep(0.3, 220, 110, "saw"), 0.01, 0.15) * 0.25))


def fumble_thud(rng):
    return fx.mix((0, fx.thud(0.4, 90, 70, rng, 0.8)), (0.12, fx.thud(0.2, 110, 40, rng, 0.6) * 0.5))


def streak_chime(rng):
    # A streak: a quick E major arpeggio (the lift from the minor key) on bells and supersaw.
    notes = [note(n) for n in ("E5", "G#5", "B5", "E6")]
    return fx.mix((0, fx.arp(notes, 0.055, "bells", 0.3, 1.0, rng)), (0, fx.arp(notes, 0.055, "supersaw", 0.25, 0.4, rng)))


def hit_body(rng):
    # Hit: a deep body blow with a crunchy edge, under the recorded punch.
    n = secs(0.5)
    t = np.arange(n) / 32000
    crunch = fx.bp(rng.uniform(-1, 1, n), 400, 3000) * np.exp(-t / 0.04)
    return fx.mix((0, fx.thud(0.5, 50, 90, rng, 1.0)), (0, crunch * 0.5))


def shield_zap(rng):
    return fx.zap(0.4, 2400, 160, rng)


def shield_ready(rng):
    # The shield charged: a rising shimmer that lands on a bright fifth.
    up = fx.env(fx.sweep(0.35, 500, 1500, "saw") * 0.15 + fx.sweep(0.35, 1000, 3000) * 0.3, 0.05, 0.05)
    return fx.mix((0, up), (0.33, fx.chord([note("E6"), note("B6")], 0.4, "bells", 1.0, rng)))


def game_over(rng):
    # Out of lives: a falling minor brass line over a low hit.
    beat = 60 / 150
    line = fx.fanfare([(0, 0.5, note("B4")), (0.5, 0.5, note("G4")), (1, 0.5, note("F#4")), (1.5, 2.5, note("E4"))], beat, "brass", rng)
    low = fx.fanfare([(1.5, 2.5, note("E3"))], beat, "brass", rng, vel=0.7)
    return fx.mix((0, line), (0, low), (1.5 * beat, fx.thud(0.6, 45, 40, rng, 0.4) * 0.8))


SFX = {
    "launch_whoosh": launch_whoosh, "dodge_tick": dodge_tick, "catch_chime": catch_chime, "miss_whiff": miss_whiff,
    "fumble_thud": fumble_thud, "streak_chime": streak_chime, "hit_body": hit_body, "shield_zap": shield_zap,
    "shield_ready": shield_ready, "game_over": game_over,
}
