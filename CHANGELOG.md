# Changelog

All notable changes to Lrc-R are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

> Changes staged for the next release go here. Move them down when you cut a tag.>

---

## [0.2.8] - 2026-06-23

### Added
- Editable [ti], [ar] & [al] metadata fields
- Option to add [ti], [ar] & [al] fields when entering lyrics, with backwards parsing if those fields already exist in the current .lrc or .txt metadata
- Auto [length] metadata field detected from the current song length

### Fixed
- Audio player hanging and getting stuck after a song finishes

### Changed
- General optimizations and bug fixes

---

## [0.2.6] - 2026-06-12

### Added
- Initial release
- Tap a timestamp in the lyrics view to seek to that position during playback
- Confetti animation plays after all lines have been tagged
- Multi-language lyric tag support
- Improved parse system and import feature for .lrc files

### Changed
- Switched audio backend to the `audioplayers` package
- Added dependency override to work around [dart-lang/native#3263](https://github.com/dart-lang/native/issues/3263)
- Upgraded Flutter dependencies

### Removed
- Dead/unused widgets cleaned up

---

<!--
HOW TO MAINTAIN THIS FILE
When you're ready to cut a new release:
1. Rename [Unreleased] to the new version and today's date, e.g.:
   ## [0.3.0] - 2026-07-01
2. Add a fresh empty [Unreleased] section at the top.
3. Use these section headers (only include the ones that apply):
   ### Added      — new features
   ### Changed    — changes to existing behaviour
   ### Deprecated — features to be removed in a future release
   ### Removed    — removed features
   ### Fixed      — bug fixes
   ### Security   — security-related changes
4. Keep entries short and user-facing. Write for someone reading the F-Droid
   update description, not for another developer reading the diff.
5. Commit the CHANGELOG update in the same commit as the pubspec version bump.
-->
