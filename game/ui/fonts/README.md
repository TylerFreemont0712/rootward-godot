Rootward's optional interface faces are bundled locally, unchanged from the Google Fonts repository:

- [Cinzel](https://github.com/google/fonts/tree/main/ofl/cinzel): engraved brass / inscriptions.
- [Alegreya](https://github.com/google/fonts/tree/main/ofl/alegreya): warm storybook.
- [Lora](https://github.com/google/fonts/tree/main/ofl/lora): journal.
- [Spectral](https://github.com/google/fonts/tree/main/ofl/spectral): scholarly notes.
- [Exo 2](https://github.com/google/fonts/tree/main/ofl/exo2): precise instruments.

Each family has its complete `OFL-<family>.txt` license alongside it. `candidates-provenance.json` records the
original binary URLs and SHA-256 hashes. File names map to the stable setting ids; internal family names and font
contents are unchanged. Four fonts contain variable weights; Spectral provides Regular and SemiBold files.

The existing IBM Plex Mono / VT323 combination remains the default. All source-code roles continue to use IBM
Plex Mono. Japanese and missing symbols use system fallbacks, with Noto Serif CJK JP for serif candidates and
Noto Sans CJK JP for Exo 2 when available. No fonts are fetched during play.
