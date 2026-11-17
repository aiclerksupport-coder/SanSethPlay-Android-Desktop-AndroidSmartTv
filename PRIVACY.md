# SanSeth Play — Privacy Information (Draft for Owner Review)

Effective draft: 18 November 2026. Developer display name: Kalpesh Patel. Legal operator name (pending registration): Kalpesh Chhabhaiya.
Sanwariya is a proposed/unregistered brand; this draft does not assert a registered company.

## Data handled by the current application

The application can store user-entered playlist URLs, saved playlist metadata,
recent-channel identifiers, favorites and application preferences locally.
Xtream credentials, where provided, should be stored using OS-backed secure
storage; storage behavior and all backups must be independently validated.
Recordings and temporary media segments, if used, are stored in device files.

## Network destinations

The application connects to network hosts selected by the user for playlists,
streams, guide data and authorized provider APIs. Those hosts may observe IP
addresses and requests; a media URL may itself contain a credential. Optional
casting can send an eligible stream URL to a connected receiver. Do not submit
private URLs to untrusted providers or receivers.

## Collection by the application developer

This source release does not intentionally include an account-registration or
central telemetry endpoint. This statement is *not* a guarantee about third-party
media servers, operating-system services, plugins, crash reports or later versions.

## Deletion and control

Users should be able to remove saved playlist sources, clear recent history and
manage recordings using the application's implemented functions. Platform backups,
external shares and remote media providers may retain data outside the app.

## Contact and review

For project security disclosures, use the repository's private vulnerability
reporting feature if enabled; do not publish access credentials or private URLs.
A final privacy notice must be checked against the shipped binary, every plugin,
platform policies and applicable law before public distribution.
