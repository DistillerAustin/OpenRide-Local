"""The demo game (#31, #55): "Warm Up", bright, easy house at 122 bpm in F. Four on the floor,
off-beat open hats, a round sub bass, off-beat piano chords and a pad; a plucked lead in the
verse and a supersaw hook with bells in the chorus. The harmony and lead come in as cadence
nears the target. Written for this repo."""
import sfx as fx
import instruments as ins
from compose import note

PREFIX = "Demo"

SONG = dict(
    file="warm_up", title="Warm Up", bpm=122, key="F", scale=[0, 2, 4, 5, 7, 9, 11], seed=41,
    drums="house", bass="sub",
    form=([("intro", 4)], [("verse", 8), ("chorus", 8), ("chorus2", 8)]),
    chords=dict(
        intro=["Fmaj7", "Fmaj7", "Bbmaj7", "C"],
        verse=["Fmaj7", "Am7", "Bbmaj7", "C", "Fmaj7", "Am7", "Gm7", "C"],
        chorus=["Bb", "C", "Am7", "Dm7", "Bb", "C", "F", "F"],
    ),
    melody=dict(
        verse="A5:0.5 C6:0.5 E6:1 C6:0.5 A5:0.5 G5:1 | E5:1 G5:0.5 A5:0.5 C6:1 r:1 |"
              " D6:0.5 C6:0.5 A5:1 F5:0.5 A5:0.5 D6:1 | C6:1.5 G5:0.5 E5:1 r:1 |"
              " A5:0.5 C6:0.5 F6:1 E6:0.5 C6:0.5 A5:1 | G5:1 E5:0.5 G5:0.5 C6:1 r:1 |"
              " Bb5:0.5 A5:0.5 G5:0.5 F5:0.5 D5:1 F5:1 | E5:2 r:2",
        chorus="F5:1 D5:0.5 F5:0.5 Bb5:1 A5:1 | G5:1.5 E5:0.5 C5:1 r:1 | E5:0.5 G5:0.5 A5:1 C6:1 A5:1 |"
               " C6:1.5 A5:0.5 F5:1 r:1 | F5:1 D5:0.5 F5:0.5 D6:1 C6:1 | Bb5:1 A5:0.5 G5:0.5 E5:1 C6:1 |"
               " A5:1 C6:1 F6:1.5 E6:0.5 | F6:2 r:2",
    ),
    parts=dict(
        intro=[("comp", "pad", 0.7)],
        verse=[("comp", "piano_off", 0.8), ("comp", "pad", 0.5), ("lead", "verse", "pluck", "lead", 0, 0.9)],
        chorus=[("comp", "piano_off", 0.8), ("comp", "disco_gtr", 0.7), ("comp", "pad", 0.6),
                ("lead", "chorus", "supersaw", "lead", 0, 0.85), ("lead", "chorus", "bells", "lead2", 12, 0.4)],
        chorus2=[("comp", "piano_off", 0.8), ("comp", "disco_gtr", 0.7), ("comp", "pad", 0.6),
                 ("lead", "chorus", "supersaw", "lead", 0, 0.85, True), ("counter", "strings", "lead2", 0.5)],
    ),
)


def dodge(rng):
    # A clean dodge: a bright pluck on the key's fifth and a little swish.
    return fx.mix((0, ins.pluck(note("C6"), 0.15, 1.0, rng)), (0, ins.bells(note("C7"), 0.1, 0.3, rng)),
                  (0, fx.whoosh(0.14, 3000, 9000, False, rng, 0.2) * 0.5))


def hit(rng):
    # Hit: a soft thud and a falling minor second.
    return fx.mix((0, fx.thud(0.35, 70, 60, rng, 0.6)), (0.02, fx.arp([note("Db5"), note("C5")], 0.08, "pluck", 0.2, 0.8, rng)))


SFX = {"dodge": dodge, "hit": hit}
