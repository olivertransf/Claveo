# Translation guidance (Claveo)

## Languages
- Source: English (`en`)
- Supported: Spanish (`es`) — neutral Latin American / Spain-friendly music app Spanish

## Do not translate
- Brand name: **Claveo**
- Musical pitch tokens: A432, A440, A435, A415, A430, A466
- Units alone: BPM, Hz
- Playback speed labels: 0.75x, 1x, 1.25x, 1.5x, 2x
- Time signatures: 2/2, 3/4, 4/4, etc.
- Note letter names used as pitch class labels (A–G) when shown alone

## Preferred Spanish terms
| English | Spanish |
|---------|---------|
| Recordings | Grabaciones |
| Metronome | Metrónomo |
| Tuner | Afinador |
| Practice | Práctica |
| Exercises | Ejercicios |
| Dictionary | Diccionario |
| Settings | Ajustes |
| Chords | Acordes |
| Warm-up | Calentamiento |
| Rehearsal | Ensayo |
| Audition | Audición |
| Done | Listo |
| Sharps / Flats / Naturals | Sostenidos / Bemoles / Becuadros |

## Music dictionary content
- English source: `Claveo/Resources/musicDictionary.json`
- Spanish: `Claveo/Resources/musicDictionary.es.json`
- Keep Italian/Latin/German/French headwords when they are international musical terms
- Translate definitions (and English descriptive headwords) per locale file
- Keep `category` keys in English for filtering; localize display via `MusicTerm.localizedCategory` / browse titles

## Style
- Clear, natural UI Spanish — not overly formal
- Keep accessibility strings concise
- Preserve all format placeholders (`%@`, `%lld`, `%1$@`, …)
