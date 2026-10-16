"""The framework's cues (#36, #55), shared by every game: the countdown's 3-2-1, go, a segment's
end, pause, resume and the summary. Key-neutral (they play over every game's music): marimba-like
bells and plucks on A, short and bright. Written for this repo."""
import instruments as ins
import sfx as fx
from compose import note

SONG = None
OUT = "audio/cues"
INDEX = "audio/CueSounds.gd"


def countdown(rng):
    return fx.mix((0, ins.bells(note("A5"), 0.12, 1.0, rng)), (0, ins.pluck(note("A4"), 0.15, 0.8, rng)),
                  (0, fx.tick(3500, 0.03, rng) * 0.3))


def go(rng):
    return fx.mix((0, fx.chord([note("A4"), note("C#5"), note("E5"), note("A5")], 0.45, "supersaw", 0.6, rng)),
                  (0, ins.bells(note("A6"), 0.3, 1.0, rng)), (0, fx.whoosh(0.35, 1500, 8000, True, rng, 0.15) * 0.4),
                  (0, ins.kick(0.6, rng)))


def segment_end(rng):
    return fx.mix((0, fx.arp([note("E5"), note("A5")], 0.12, "bells", 0.5, 1.0, rng)),
                  (0.12, ins.pluck(note("A4"), 0.5, 0.6, rng)))


def pause(rng):
    return fx.arp([note("E5"), note("A4")], 0.09, "pluck", 0.2, 0.9, rng)


def resume(rng):
    return fx.arp([note("A4"), note("E5")], 0.09, "pluck", 0.2, 0.9, rng)


def summary(rng):
    beat = 0.16
    top = fx.fanfare([(0, 1, note("A4")), (1, 1, note("C#5")), (2, 1, note("E5")), (3, 5, note("A5"))], beat, "brass", rng, vel=0.8)
    bell = fx.arp([note("A5"), note("C#6"), note("E6"), note("A6")], beat, "bells", 0.5, 0.7, rng)
    return fx.mix((0, top), (0, bell))


SFX = {"countdown": countdown, "go": go, "segment_end": segment_end, "pause": pause, "resume": resume, "summary": summary}
