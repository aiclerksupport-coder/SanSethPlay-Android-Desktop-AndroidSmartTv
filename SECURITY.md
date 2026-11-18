# Security Policy — SanSeth Play

Current version: v0.1.1+2 candidate source. No release build is certified across
all target platforms. Security reports should use GitHub private vulnerability
reporting where available in repository Settings > Security; otherwise contact the
repository owner privately. Never post provider credentials or tokenized playlist
URLs in public GitHub issues, crash logs, or screenshots.

Security boundaries: arbitrary user URLs, redirects, playlist size limits, device
storage, external decoders, Web/HTTP traffic, media file parsers, Chromecast and
local timeshift HTTP bridge require ongoing review and on-device testing.

Before merging or pushing: format, analyze, widget/unit tests, native build, release
lint, install/smoke tests, secret scan and diff against authoritative source.
