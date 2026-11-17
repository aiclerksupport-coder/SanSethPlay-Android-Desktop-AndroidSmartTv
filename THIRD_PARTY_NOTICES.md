# Third-Party Notices and Release Gate

SanSeth Play uses Flutter and packages specified in `pubspec.yaml` / the actual
resolved `pubspec.lock`. These components are not covered by SanSeth's proprietary
source LICENSE, and each must be redistributed under its own license.

Relevant direct packages include `media_kit`, `media_kit_video`, native playback
libraries, `smtc_windows`, `share_plus`, `http`, `crypto`, `xml`, `sqflite`,
`flutter_secure_storage`, `path_provider` and Flutter itself. Native video codecs,
FFmpeg/libmpv builds, Google Cast SDK components, Windows installer toolchain and
platform runtime components require special attention.

Do **not** invent a license attribution. Before release: use the actual resolved
package versions, retrieve each author's LICENSE and notices, review transitive
and native dependencies, ship applicable license texts and notices with app/source,
and check redistribution/commercial-use compatibility. This file is a release
checklist, not a completed compliance certificate.
