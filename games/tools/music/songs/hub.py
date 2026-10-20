"""The Games hub (spec §8.5): "Lobby Loop", an upbeat, sunny pop-funk theme at 108 bpm in G major,
built for long idling between games. Funk drums with a light touch, a picked eighth-note bass,
an electric piano and a pad; vibes sing the verse, a flute with bells an octave up carries the
chorus, and a short breakdown on the pad and vibes lets it breathe before it loops. The bed
always plays; the harmony and the lead come in as the rider pedals. Written for this repo:
original melody and arrangement, everything synthesised (no samples)."""

PREFIX = "Hub"
DIR = "hub"  # games/hub/music/, not a game's folder
INDEX = "HubMusicIndex.gd"
CLASS_NAME = "HubMusicIndex"
OUT = "hub/music"  # no effects of its own: the hub's clicks are the framework's

SONG = dict(
    file="lobby_loop", title="Lobby Loop", bpm=108, key="G", scale=[0, 2, 4, 5, 7, 9, 11], seed=57,
    drums="funk", bass="pick8", verb_sec=1.6,
    form=([("intro", 4)], [("verse", 8), ("chorus", 8), ("bridge", 4)]),
    chords=dict(
        intro=["Gmaj7", "Em7", "Cmaj7", "D"],
        verse=["Gmaj7", "Em7", "Cmaj7", "D", "Gmaj7", "Bm7", "Cmaj7 D", "G"],
        chorus=["C", "D", "Bm7", "Em7", "Am7", "D", "G", "G"],
        bridge=["Cmaj7", "Bm7", "Am7", "D"],
    ),
    melody=dict(
        verse="B5:0.5 D6:0.5 G6:1 F#6:0.5 D6:0.5 B5:1 | G5:0.5 B5:0.5 E6:1.5 D6:0.5 r:1 |"
              " E6:0.5 C6:0.5 G5:0.5 C6:0.5 E6:1 D6:1 | A5:1 F#5:0.5 A5:0.5 D6:1 r:1 |"
              " B5:0.5 D6:0.5 G6:1 A6:0.5 G6:0.5 D6:1 | F#6:1 D6:0.5 B5:0.5 A5:1 r:1 |"
              " G5:0.5 A5:0.5 B5:0.5 C6:0.5 D6:0.5 E6:0.5 F#6:1 | G6:2 r:2",
        chorus="E5:1 G5:0.5 E5:0.5 C6:1 B5:1 | A5:1.5 F#5:0.5 D5:1 r:1 | D5:0.5 F#5:0.5 B5:1 A5:1 F#5:1 |"
               " G5:1.5 E5:0.5 B4:1 r:1 | C5:1 E5:0.5 A5:0.5 C6:1 B5:1 | A5:1 F#5:0.5 A5:0.5 D6:1 C6:1 |"
               " B5:1 D6:1 G6:1.5 F#6:0.5 | G6:2 r:2",
        bridge="E6:2 D6:2 | D6:2 B5:2 | C6:2 A5:2 | F#5:2 A5:1 D6:1",
    ),
    parts=dict(
        intro=[("comp", "pad", 0.7), ("comp", "ep_hold", 0.5)],
        verse=[("comp", "ep", 0.8), ("comp", "pad", 0.45), ("lead", "verse", "vibes", "lead", 0, 0.85)],
        chorus=[("comp", "ep", 0.8), ("comp", "disco_gtr", 0.6), ("comp", "pad", 0.55),
                ("lead", "chorus", "flute", "lead", 0, 0.9), ("lead", "chorus", "bells", "lead2", 12, 0.35)],
        bridge=[("comp", "pad", 0.75), ("comp", "ep_hold", 0.5), ("lead", "bridge", "vibes", "lead", 0, 0.8)],
    ),
)

SFX = {}
