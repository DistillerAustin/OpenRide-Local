"""Kart Race music renderer (#43): the four track themes, the results loop and the podium sting.
All melodies, progressions and arrangements were written for this repo (Apache-2.0); none is
taken from or modelled on any existing game's music."""
from compose import MAJOR, MIXO

THEMES = {
    # Meadow Ring: sunny funk-pop. Slap bass, chicken-scratch guitar, Rhodes, horn stabs, a
    # whistly verse lead, a supersaw-and-brass chorus hook.
    "meadow_ring": dict(
        title="Sunny Side Lap", bpm=150, key="D", scale=MAJOR, final_shift=2,
        drums="funk", bass="slap",
        chords=dict(
            intro=["D", "D", "Gmaj7", "A7sus4"],
            verse=["Dmaj9", "Bm7", "Gmaj7", "A7sus4", "Dmaj9", "Bm7", "Gmaj7", "A7sus4"],
            chorus=["G", "A", "F#m7", "Bm7", "Gmaj7", "A7sus4 A7", "D", "D"],
            bridge=["Em7", "A7", "F#m7", "Bm7", "Gmaj7", "Gm6", "A7sus4", "A7"],
            pickup=["A7sus4", "A7"],
        ),
        melody=dict(
            verse="r:1 A4:0.5 B4:0.5 D5:1 E5:1 | F#5:1.5 E5:0.5 D5:1 r:1 | r:1 B4:0.5 D5:0.5 E5:1 D5:0.5 B4:0.5 | A4:2 r:2 |"
                  " r:1 A4:0.5 B4:0.5 D5:1 F#5:1 | A5:1.5 F#5:0.5 E5:1 D5:1 | B4:0.5 D5:0.5 E5:1 G5:1 F#5:0.5 E5:0.5 | E5:2 r:2",
            chorus="r:0.5 D5:0.5 E5:0.5 F#5:0.5 A5:1 F#5:0.5 E5:0.5 | E5:0.5 C#5:0.5 E5:1 A4:1 r:1 |"
                   " r:0.5 C#5:0.5 E5:0.5 F#5:0.5 A5:1 B5:0.5 A5:0.5 | F#5:1.5 D5:0.5 B4:1 r:1 |"
                   " r:0.5 D5:0.5 E5:0.5 F#5:0.5 B5:1 A5:0.5 F#5:0.5 | G5:0.5 F#5:0.5 E5:0.5 D5:0.5 E5:1 C#5:1 |"
                   " D5:0.5 F#5:0.5 A5:0.5 D6:1.5 r:1 | r:2 A5:0.5 B5:0.5 A5:0.5 F#5:0.5",
            bridge="B4:1 D5:1 E5:2 | C#5:1 E5:1 G5:2 | A5:1.5 F#5:0.5 E5:2 | F#5:3 r:1 |"
                   " r:0.5 B4:0.5 D5:0.5 F#5:0.5 A5:2 | G5:1 Bb4:1 D5:2 | E5:1 D5:1 E5:1 G5:1 | A5:2 r:2",
        ),
        parts=dict(
            intro=[("comp", "pad", 0.6), ("comp", "ep_hold", 0.6)],
            verse=[("comp", "funk_gtr", 1.0), ("comp", "ep", 0.8), ("lead", "verse", "flute", "lead", 0, 0.9)],
            chorus=[("comp", "funk_gtr", 1.0), ("comp", "stabs", 1.0), ("comp", "pad", 0.7),
                    ("lead", "chorus", "supersaw", "lead", 0, 0.9), ("lead", "chorus", "brass", "lead2", -12, 0.6)],
            verse2=[("comp", "funk_gtr", 1.0), ("comp", "ep", 0.8), ("lead", "verse", "brass", "lead", 0, 0.75),
                    ("counter", "ep", "lead2", 0.55)],
            bridge=[("comp", "pad", 0.8), ("comp", "ep_hold", 0.7), ("lead", "bridge", "brass", "lead", 0, 0.8)],
            chorus2=[("comp", "funk_gtr", 1.0), ("comp", "stabs", 1.0), ("comp", "pad", 0.7),
                     ("lead", "chorus", "supersaw", "lead", 0, 0.9, True), ("counter", "strings", "lead2", 0.6)],
        ),
    ),
    # Canyon Dash: twangy, driving desert rock. Train-beat drums, picked bass, a single-coil
    # twang lead, palm-muted chugs and open power chords, a horn-and-supersaw chorus.
    "canyon_dash": dict(
        title="Dust Devil Run", bpm=156, key="E", scale=MIXO, final_shift=2,
        drums="drive", bass="pick8",
        chords=dict(
            intro=["E5", "E5", "D", "A"],
            verse=["E", "E", "D", "A", "E", "E", "C", "D"],
            chorus=["C", "D", "E", "E", "C", "D", "E", "B7"],
            bridge=["Am", "C", "G", "D", "Am", "C", "B7sus4", "B7"],
            pickup=["B7sus4", "B7"],
        ),
        melody=dict(
            verse="E4:0.5 G#4:0.5 B4:1 B4:0.5 C#5:0.5 B4:1 | A4:0.5 G#4:0.5 E4:1 r:2 |"
                  " D5:0.5 C#5:0.5 A4:1 F#4:0.5 A4:0.5 D5:1 | C#5:1.5 A4:0.5 E4:2 |"
                  " E4:0.5 G#4:0.5 B4:1 D5:0.5 C#5:0.5 B4:1 | G#4:1 E4:1 r:2 |"
                  " C5:0.5 B4:0.5 G4:1 E4:0.5 G4:0.5 C5:1 | D5:1.5 A4:0.5 F#4:1 r:1",
            chorus="E5:1 G5:1 E5:0.5 D5:0.5 C5:1 | D5:1 F#5:1 A5:1.5 r:0.5 | G#5:1.5 F#5:0.5 E5:1 B4:1 | E5:3 r:1 |"
                   " E5:1 G5:1 C6:1 B5:0.5 A5:0.5 | A5:1 F#5:1 D5:1 F#5:1 | G#5:1 B5:1 E6:1.5 r:0.5 | D#5:1 F#5:1 A5:1 F#5:1",
            bridge="A4:1 C5:1 E5:2 | G5:1 E5:1 C5:2 | D5:1 G5:1 B5:2 | A5:3 r:1 |"
                   " E5:1 A5:1 C6:2 | B5:1 G5:1 E5:2 | E5:1 F#5:1 A5:2 | D#5:2 F#5:2",
        ),
        parts=dict(
            intro=[("comp", "chug", 0.6)],
            verse=[("comp", "chug", 0.8), ("lead", "verse", "twang", "lead", 0, 1.0)],
            chorus=[("comp", "power", 0.9), ("comp", "stabs_hold", 0.9), ("comp", "pad", 0.5),
                    ("lead", "chorus", "supersaw", "lead", 0, 0.85), ("lead", "chorus", "brass", "lead2", -12, 0.6)],
            verse2=[("comp", "chug", 0.8), ("lead", "verse", "twang", "lead", 12, 0.85),
                    ("counter", "brass", "lead2", 0.45)],
            bridge=[("comp", "pad", 0.8), ("comp", "chug", 0.5), ("lead", "bridge", "twang", "lead", 0, 0.9)],
            chorus2=[("comp", "power", 0.9), ("comp", "stabs_hold", 0.9), ("comp", "pad", 0.5),
                     ("lead", "chorus", "supersaw", "lead", 0, 0.85, True), ("lead", "chorus", "twang", "lead2", -12, 0.6)],
        ),
    ),
    # Harbor Lights: groovy at sunset. Four-on-the-floor, octave disco bass, Rhodes and
    # off-beat guitar, a reedy sax-like verse lead, strings, a sweeping chorus.
    "harbor_lights": dict(
        title="Lights on the Water", bpm=140, key="F", scale=MAJOR, final_shift=2,
        drums="disco", bass="octave",
        chords=dict(
            intro=["Bbmaj7", "Am7", "Gm7", "C9"],
            verse=["Bbmaj7", "Am7", "Gm7", "C9", "Bbmaj7", "Am7", "Gm7", "C9"],
            chorus=["Fmaj7", "Em7 A7", "Dm7", "Gm7 C7", "Fmaj7", "Em7 A7", "Dm7 G7", "Gm7 C7"],
            bridge=["Dbmaj7", "Cm7 F7", "Bbmaj7", "Am7 D7", "Gm7", "C7sus4", "C7", "C7"],
            pickup=["Gm7", "C7"],
        ),
        melody=dict(
            verse="r:0.5 F5:0.5 A5:0.5 G5:0.5 F5:1 D5:1 | E5:1.5 C5:0.5 A4:1 r:1 | r:0.5 Bb4:0.5 D5:0.5 F5:0.5 A5:1 G5:0.5 F5:0.5 | E5:2 D5:1 r:1 |"
                  " r:0.5 F5:0.5 A5:0.5 C6:0.5 A5:1 F5:1 | G5:1.5 E5:0.5 C5:2 | r:0.5 D5:0.5 F5:0.5 A5:0.5 G5:1 F5:0.5 D5:0.5 | E5:3 r:1",
            chorus="A5:1 G5:0.5 A5:0.5 C6:1 A5:1 | G5:1 E5:1 C#5:1 E5:1 | F5:1.5 E5:0.5 D5:1 A4:1 | Bb4:1 D5:1 E5:1 G5:1 |"
                   " A5:1 G5:0.5 A5:0.5 C6:1 E6:1 | D6:1 C6:0.5 Bb5:0.5 A5:1 G5:1 | F5:1 A5:1 B5:1 G5:1 | Bb5:1 A5:1 G5:1 E5:1",
            bridge="F5:1 Ab5:1 C6:2 | Bb5:1 G5:1 A5:2 | F5:1 D5:1 A5:2 | G5:1 E5:1 F#5:2 |"
                   " Bb5:1 A5:1 G5:1 D5:1 | F5:3 r:1 | E5:1 G5:1 Bb5:1 C6:1 | E6:2 r:2",
        ),
        parts=dict(
            intro=[("comp", "ep_hold", 0.7), ("comp", "pad", 0.5)],
            verse=[("comp", "disco_gtr", 0.9), ("comp", "ep", 0.8), ("lead", "verse", "sax", "lead", 0, 0.9)],
            chorus=[("comp", "disco_gtr", 0.9), ("comp", "pad", 0.8), ("comp", "stabs", 0.8),
                    ("lead", "chorus", "supersaw", "lead", 0, 0.85), ("lead", "chorus", "ep", "lead2", -12, 0.7)],
            verse2=[("comp", "disco_gtr", 0.9), ("comp", "ep", 0.8), ("lead", "verse", "sax", "lead", 0, 0.85),
                    ("counter", "strings", "lead2", 0.6)],
            bridge=[("comp", "pad", 0.8), ("comp", "ep_hold", 0.7), ("lead", "bridge", "sax", "lead", 0, 0.85)],
            chorus2=[("comp", "disco_gtr", 0.9), ("comp", "pad", 0.8), ("comp", "stabs", 0.8),
                     ("lead", "chorus", "supersaw", "lead", 0, 0.85, True), ("lead", "chorus", "sax", "lead2", -12, 0.55)],
        ),
    ),
    # Frost Pass: bright and sparkly. Sleigh bells, pumping piano, a glockenspiel verse, plucked
    # arpeggios, a supersaw chorus with bells an octave up.
    "frost_pass": dict(
        title="Snowline Sprint", bpm=152, key="A", scale=MAJOR, final_shift=2,
        drums="pop", bass="pop",
        chords=dict(
            intro=["A", "A", "D", "E"],
            verse=["A", "E/G#", "F#m", "D", "A", "E", "D", "E"],
            chorus=["D", "E", "C#m", "F#m", "D", "E", "A", "A"],
            bridge=["Bm", "C#m", "D", "E", "Bm", "C#m", "Dmaj7", "E7sus4 E"],
            pickup=["Esus4", "E"],
        ),
        melody=dict(
            verse="C#6:0.5 E6:0.5 A5:1 C#6:0.5 B5:0.5 A5:1 | G#5:1 B5:1 E5:2 | A5:0.5 C#6:0.5 F#5:1 A5:0.5 G#5:0.5 F#5:1 | F#5:1 A5:1 D6:2 |"
                  " C#6:0.5 E6:0.5 A5:1 C#6:0.5 E6:0.5 A6:1 | G#6:1 F#6:1 E6:2 | F#6:0.5 E6:0.5 D6:1 A5:0.5 B5:0.5 C#6:1 | B5:3 r:1",
            chorus="r:0.5 A4:0.5 D5:0.5 E5:0.5 F#5:1.5 E5:0.5 | G#5:1 E5:1 B4:1.5 r:0.5 | r:0.5 G#4:0.5 C#5:0.5 E5:0.5 G#5:1.5 F#5:0.5 | A5:1 F#5:1 C#5:1.5 r:0.5 |"
                   " r:0.5 A4:0.5 D5:0.5 F#5:0.5 A5:1.5 B5:0.5 | G#5:1 B5:1 E6:1 D6:0.5 C#6:0.5 | C#6:1.5 B5:0.5 A5:1 E5:1 | A5:2 r:2",
            bridge="D5:1 F#5:1 B5:2 | E5:1 G#5:1 C#6:2 | F#5:1 A5:1 D6:2 | E6:2 B5:2 |"
                   " D6:1 C#6:1 B5:2 | C#6:1 B5:1 G#5:2 | A5:1 C#6:1 F#6:2 | E6:2 G#5:2",
        ),
        parts=dict(
            intro=[("comp", "arp", 0.7), ("comp", "pad", 0.5)],
            verse=[("comp", "piano", 0.8), ("comp", "arp", 0.6), ("lead", "verse", "bells", "lead", -12, 0.9)],
            chorus=[("comp", "piano8", 0.85), ("comp", "pad", 0.7),
                    ("lead", "chorus", "supersaw", "lead", 0, 0.85), ("lead", "chorus", "bells", "lead2", 12, 0.6)],
            verse2=[("comp", "piano", 0.8), ("comp", "arp", 0.6), ("lead", "verse", "pluck", "lead", -12, 0.9),
                    ("lead", "verse", "bells", "lead2", 0, 0.45)],
            bridge=[("comp", "pad", 0.8), ("comp", "piano", 0.6), ("lead", "bridge", "strings", "lead", 0, 0.9)],
            chorus2=[("comp", "piano8", 0.85), ("comp", "pad", 0.7),
                     ("lead", "chorus", "supersaw", "lead", 0, 0.85, True), ("lead", "chorus", "bells", "lead2", 12, 0.6),
                     ("counter", "strings", "lead2", 0.5)],
        ),
    ),
}

# The results loop (laid back, on Meadow's chorus chords) and the podium fanfare, both in D.
RESULTS = dict(
    bpm=150, key="D", scale=MAJOR, drums="funk", bass="pick8",
    chords=["Gmaj7", "A7sus4", "F#m7", "Bm7", "Gmaj7", "A7sus4", "Dmaj9", "Dmaj9"],
    melody="r:0.5 D5:0.5 E5:0.5 F#5:0.5 A5:2 | E5:2 r:2 | r:0.5 C#5:0.5 E5:0.5 F#5:0.5 A5:2 | F#5:2 r:2 |"
           " r:0.5 D5:0.5 E5:0.5 F#5:0.5 B5:2 | A5:1 G5:1 E5:2 | F#5:4 | r:4",
)
PODIUM = dict(
    bpm=120, key="D",
    chords=["D", "G A", "Bm G", "D"],
    melody="D5:0.5 D5:0.5 D5:0.5 A5:1.5 r:1 | G5:0.5 F#5:0.5 E5:0.5 F#5:1 D5:1.5 | B5:1 A5:1 D6:2 | D6:4",
)
