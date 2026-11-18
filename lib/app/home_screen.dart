import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../core/channel.dart';
import '../core/channel_health.dart';
import '../core/channel_categories.dart';
import '../core/channel_cache.dart';
import '../core/epg_repository.dart';
import '../core/epg_cache.dart';
import '../core/favorite_store.dart';
import '../core/recent_channel_store.dart';
import '../core/playlist_repository.dart';
import '../core/playlist_store.dart';
import '../core/saved_playlist.dart';
import '../core/playlist_privacy.dart';
import '../core/last_watched_store.dart';
import '../player/player_view.dart';
import 'mobile_landscape_policy.dart';
import 'android_immersive_mode.dart';
import 'tv_guide_dialog.dart';
import 'xtream_browser.dart';
import 'recordings_dialog.dart';
import 'about_dialog.dart';

const _gold = Color(0xFFF4C65B);
const _panel = Color(0xFF0D1C31);

enum ChannelFilter { all, favorites, recent }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _repository = PlaylistRepository();
  final _favoritesStore = FavoriteStore();
  final _recentStore = RecentChannelStore();
  List<String> _recentHashes = const [];
  Future<void> _recentWrite = Future<void>.value();
  final _cache = ChannelCache();
  final _health = ChannelHealthStore();
  late final ChannelHealthScanner _healthScanner =
      ChannelHealthScanner(_health);
  bool _hideUnavailable = true;
  int _scanCursor = 0;
  Timer? _scanTimer;

  void _onPlaybackHealth(Uri url, bool healthy) {
    if (healthy) {
      _health.playing(url);
    } else {
      _health.playbackFailed(url);
    }
  }

  void _enqueueHealthBatch() {
    if (!mounted || _channels.isEmpty) return;
    // Prioritize currently displayed/favorite channels, then scan the rest
    // incrementally. Never probe current playback (no competing decoder).
    _healthScanner.activePlayback = _selected?.url;
    final eligible = _visibleChannels().take(15).map((c) => c.url);
    _healthScanner.enqueue(eligible);
    final next = <Uri>[];
    for (var i = 0; i < 15 && _channels.isNotEmpty; i++) {
      next.add(_channels[_scanCursor % _channels.length].url);
      _scanCursor++;
    }
    _healthScanner.enqueue(next);
  }

  void _scheduleHealthChecks() {
    if (_channels.isEmpty) return;
    _scanTimer ??= Timer.periodic(const Duration(seconds: 25), (_) {
      _health.expire();
      _enqueueHealthBatch();
    });
    _enqueueHealthBatch();
  }

  final _epgRepository = EpgRepository();
  final _epgCache = EpgCache();
  Map<String, List<EpgProgram>> _programs = const {};
  String? _epgMessage;
  int _epgGeneration = 0;
  static const _epgStorage = FlutterSecureStorage();
  static const _epgUrlKey = 'sanseth.epg.source.v1';
  Uri? _epgSource;
  Timer? _epgRefreshTimer;
  bool _epgFetching = false;
  bool _epgRefreshQueued = false;
  final PlaylistStore _playlistStore = SecurePlaylistStore();
  final PlaylistPrivacyStore _privacyStore = PlaylistPrivacyStore();
  final LocalAuthentication _localAuth = LocalAuthentication();
  Map<String, PlaylistPrivacy> _privacy = {};
  final Set<String> _unlockedPlaylists = {};
  bool _ownerPromptBusy = false;
  bool _privacyChangeBusy = false;
  bool _hiddenManagementOpen = false;
  int _failedOwnerAttempts = 0;
  DateTime? _ownerRetryAfter;

  bool _protected(SavedPlaylist item) => _privacy[item.id]?.protected ?? false;
  bool _hidden(SavedPlaylist item) => _privacy[item.id]?.hidden ?? false;
  bool _locked(SavedPlaylist item) => _privacy[item.id]?.locked ?? false;
  bool _canOpen(SavedPlaylist item) =>
      !_protected(item) || _unlockedPlaylists.contains(item.id);

  Future<String?> _requestSecret(String heading,
      {bool allowRecovery = false}) async {
    if (!mounted) return null;
    var input = '';
    final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(heading),
              content: TextField(
                onChanged: (value) => input = value,
                autofocus: false,
                obscureText: true,
                keyboardType:
                    allowRecovery ? TextInputType.text : TextInputType.number,
                maxLength: allowRecovery ? 32 : 12,
                decoration: InputDecoration(
                    hintText: allowRecovery
                        ? 'Owner recovery code'
                        : '6–12 digit owner PIN'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, input),
                    child: const Text('Continue')),
              ],
            ));
    return result;
  }

  Future<void> _showRecoveryCode(String code) async {
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              title: const Text('Save your owner recovery code'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Ye code sirf ek baar dikhega. Paper par likhkar secure jagah rakhein. App ke andar dobara show nahi hoga.'),
                const SizedBox(height: 16),
                SelectableText(code,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
              ]),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('I saved the code'))
              ],
            ));
  }

  Future<bool> _ensureOwnerPin() async {
    if (await _privacyStore.hasPin) return true;
    final first = await _requestSecret('Set owner PIN');
    if (first == null) return false;
    final confirm = await _requestSecret('Confirm owner PIN');
    if (first != confirm || !PlaylistPrivacyStore.isAcceptablePin(first)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN mismatch. Use 6–12 digits.')));
      }
      return false;
    }
    await _privacyStore.setPin(first);
    final code = await _privacyStore.makeRecoveryCode();
    await _showRecoveryCode(code);
    return true;
  }

  Future<bool> _authenticateOwner({bool allowSetup = true}) async {
    if (_ownerPromptBusy || !mounted) return false;
    final now = DateTime.now();
    if (_ownerRetryAfter != null && now.isBefore(_ownerRetryAfter!)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Too many attempts. Try again later.')));
      return false;
    }
    _ownerPromptBusy = true;
    try {
      // OS authentication is preferred for phones and Windows Hello.
      // Android TV without biometric/credential setup falls back to owner PIN.
      try {
        if (await _localAuth.isDeviceSupported()) {
          final allowed = await _localAuth.authenticate(
            localizedReason: 'Verify owner to manage protected playlists',
            biometricOnly: false,
            persistAcrossBackgrounding: true,
          );
          if (allowed) _failedOwnerAttempts = 0;
          return allowed; // Explicit OS denial/cancel must never fall back to PIN setup.
        }
      } catch (_) {/* Unsupported devices use owner PIN/recovery. */}
      if (!await _privacyStore.hasPin) {
        if (!allowSetup) return false;
        return await _ensureOwnerPin();
      }
      final pin = await _requestSecret('Owner verification');
      if (pin == null) return false;
      if (await _privacyStore.verifyPin(pin)) {
        _failedOwnerAttempts = 0;
        return true;
      }
      // Recovery entry is separate: arbitrary wrong PIN never unlocks.
      final recovery = await _requestSecret('Forgot PIN? Enter recovery code',
          allowRecovery: true);
      if (recovery != null && await _privacyStore.verifyRecovery(recovery)) {
        _failedOwnerAttempts = 0;
        final newPin = await _requestSecret('New owner PIN');
        if (newPin != null && PlaylistPrivacyStore.isAcceptablePin(newPin)) {
          await _privacyStore.setPin(newPin);
          final code = await _privacyStore.makeRecoveryCode();
          await _showRecoveryCode(code);
          return true;
        }
      }
      _failedOwnerAttempts++;
      if (_failedOwnerAttempts >= 5) {
        _ownerRetryAfter = DateTime.now().add(const Duration(minutes: 2));
        _failedOwnerAttempts = 0;
      }
      return false;
    } finally {
      _ownerPromptBusy = false;
    }
  }

  Future<void> _configurePrivacy(SavedPlaylist item,
      {required bool hidden, required bool locked}) async {
    if (_privacyChangeBusy) return;
    _privacyChangeBusy = true;
    try {
      if (!await _authenticateOwner()) return;
      if (!mounted) return;
      final next = Map<String, PlaylistPrivacy>.of(_privacy);
      final updated = PlaylistPrivacy(hidden: hidden, locked: locked);
      if (updated.protected) {
        next[item.id] = updated;
      } else {
        next.remove(item.id);
      }
      await _privacyStore.save(next);
      if (!mounted) return;
      setState(() {
        _privacy = next;
        if (updated.protected) _unlockedPlaylists.remove(item.id);
      });
      if (updated.protected && _activePlaylistId == item.id) {
        _clearSession(); // stop decoding/mini-player immediately, no title leak
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playlist privacy save failed.')));
      }
    } finally {
      _privacyChangeBusy = false;
    }
  }

  Future<void> _manageHiddenPlaylists() async {
    if (!await _authenticateOwner()) return;
    if (!mounted) return;
    _hiddenManagementOpen = true;
    try {
      await _browseSavedPlaylists(includeHidden: true);
    } finally {
      _hiddenManagementOpen = false;
    }
  }

  Future<void> _changeOwnerPin() async {
    if (!await _authenticateOwner()) return;
    if (!mounted) return;
    final pin = await _requestSecret('Enter new owner PIN');
    if (pin == null) return;
    final confirm = await _requestSecret('Confirm new owner PIN');
    if (confirm != pin || !PlaylistPrivacyStore.isAcceptablePin(pin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN mismatch or invalid length.')));
      }
      return;
    }
    await _privacyStore.setPin(pin);
    final code = await _privacyStore.makeRecoveryCode();
    await _showRecoveryCode(code);
  }

  final _lastWatchedStore = LastWatchedStore();
  LastWatched? _lastWatched;
  Future<void> _lastWatchedWrite = Future<void>.value();
  List<SavedPlaylist> _savedPlaylists = const [];
  String? _activePlaylistId;
  int _loadGeneration = 0;
  Future<void> _playlistWrite = Future<void>.value();
  bool _sourceMutationBusy = false;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _shortcutsFocus = FocusNode();
  List<StreamChannel> _channels = const [];
  StreamChannel? _selected;
  Set<String> _favorites = {};
  String _group = 'All groups';
  ChannelFilter _filter = ChannelFilter.all;
  bool _busy = false;
  String _query = '';
  Timer? _searchDebounce;
  Future<void> _favoriteWrite = Future<void>.value();
  String? _message;
  bool _tvPreview = false;
  StreamChannel? _multiviewSecondary;
  bool _systemUiImmersive = false;
  bool _landscapeControlsVisible = true;
  Timer? _landscapeControlTimer;

  void _restartLandscapeControlTimer() {
    _landscapeControlTimer?.cancel();
    if (!_systemUiImmersive) {
      return;
    }
    _landscapeControlTimer = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          _systemUiImmersive &&
          _landscapeControlsVisible &&
          !_channelSheetOpen) {
        setState(() => _landscapeControlsVisible = false);
      }
    });
  }

  void _revealLandscapeControls() {
    if (!_systemUiImmersive) {
      return;
    }
    if (!_landscapeControlsVisible) {
      setState(() => _landscapeControlsVisible = true);
    }
    _restartLandscapeControlTimer();
  }

  bool _landscapeFullscreenDismissed = false;
  bool _miniPlayer = false;
  int _navIndex = 0;
  bool _channelSheetOpen = false;
  BuildContext? _channelSheetContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _health.addListener(_healthChanged);
    unawaited(_health.restore());
    _loadFavorites();
    _loadRecent();
    _restorePlaylists();
    _restoreEpgSource();
    _epgRefreshTimer = Timer.periodic(const Duration(minutes: 90), (_) {
      if (_epgSource != null) {
        _refreshEpg();
      }
    });
  }

  Future<void> _loadRecent() async {
    try {
      final history = await _recentStore.load();
      if (mounted) {
        setState(() => _recentHashes = history);
      }
    } catch (_) {
      // History is optional; do not delay opening the player.
    }
  }

  void _recordRecent(StreamChannel channel) {
    final history = RecentChannelStore.record(_recentHashes, channel.url);
    setState(() => _recentHashes = history);
    // Serialize snapshots to avoid stale writes on rapid remote navigation.
    _recentWrite = _recentWrite.catchError((Object _) {}).then(
          (_) => _recentStore.save(history),
        );
    unawaited(_recentWrite.catchError((Object _) {}));
  }

  Future<void> _clearRecent() async {
    try {
      // Wait for outstanding saves; then clear atomically from UI perspective.
      await _recentWrite.catchError((Object _) {});
      await _recentStore.clear();
      if (mounted) {
        setState(() => _recentHashes = const []);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Recent history clear nahi hui.');
      }
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final saved = await _favoritesStore.load();
      if (mounted) {
        setState(() => _favorites = saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Favorites load nahi hue.');
      }
    }
  }

  void _syncSystemUi(bool immersive) {
    if (_systemUiImmersive == immersive) {
      return;
    }
    _systemUiImmersive = immersive;
    _landscapeControlTimer?.cancel();
    _landscapeControlsVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (immersive) {
        _restartLandscapeControlTimer();
      }
      if (!mounted || _systemUiImmersive != immersive) {
        return;
      }
      // A focused home search must not keep the software keyboard above video.
      // A separate open dialog owns its own focus and is left untouched.
      if (immersive && _searchFocus.hasFocus) {
        _shortcutsFocus.requestFocus();
      }
      unawaited(AndroidImmersiveMode.setEnabled(immersive));
    });
  }

  Future<void> _showLandscapeChannels() async {
    if (_channelSheetOpen) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _channelSheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: const Color(0xFF10213A),
        builder: (sheetContext) {
          _channelSheetContext = sheetContext;
          return FractionallySizedBox(
            heightFactor: .92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: _sidebar(_visibleChannels(), false),
            ),
          );
        },
      );
    } finally {
      _channelSheetContext = null;
      if (mounted) {
        setState(() => _channelSheetOpen = false);
      }
    }
  }

  void _healthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleHealthChecks();
    } else {
      // Do not keep health network requests queued while not visible.
      _scanTimer?.cancel();
      _scanTimer = null;
      _healthScanner.clear();
      // Never leave hidden playlist names visible in an open owner dialog
      // after the app backgrounds and a different household user returns.
      if (_hiddenManagementOpen && mounted) {
        _hiddenManagementOpen = false;
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }
      if (_unlockedPlaylists.isNotEmpty) {
        _unlockedPlaylists.clear();
        if (_activePlaylistId != null &&
            _savedPlaylists
                .any((p) => p.id == _activePlaylistId && _protected(p))) {
          _clearSession();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _landscapeControlTimer?.cancel();
    _scanTimer?.cancel();
    _healthScanner.dispose();
    _health.removeListener(_healthChanged);
    _health.dispose();
    if (_systemUiImmersive) {
      unawaited(AndroidImmersiveMode.setEnabled(false));
    }
    _loadGeneration++;
    _searchDebounce?.cancel();
    _epgRefreshTimer?.cancel();
    ++_epgGeneration;
    _repository.dispose();
    _epgRepository.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _shortcutsFocus.dispose();
    super.dispose();
  }

  void _select(StreamChannel channel) {
    if (_activePlaylistId != null &&
        _savedPlaylists.any((p) => p.id == _activePlaylistId && !_canOpen(p))) {
      return;
    }
    // Selecting a channel must close the software keyboard if the user was
    // searching; keep keyboard/remote shortcuts on the non-editable root.
    if (_searchFocus.hasFocus) {
      _shortcutsFocus.requestFocus();
    }
    final sheetContext = _channelSheetContext;
    if (sheetContext != null &&
        sheetContext.mounted &&
        ModalRoute.of(sheetContext)?.isCurrent == true) {
      Navigator.of(sheetContext).pop();
    }
    if (_selected?.url == channel.url) {
      return;
    }
    // PlayerView already serializes opens with latest-channel-wins.
    // Do not silently drop the last remote key selection during a throttle.
    setState(() => _selected = channel);
    _healthScanner.activePlayback = channel.url;
    _recordRecent(channel);
    final playlistId = _activePlaylistId;
    if (playlistId != null) {
      _lastWatched = LastWatched(playlistId, channel);
      _lastWatchedWrite = _lastWatchedWrite
          .catchError((Object _) {})
          .then((_) => _lastWatchedStore.save(playlistId, channel));
      unawaited(_lastWatchedWrite.catchError((Object _) {}));
    }
  }

  Future<void> _toggleFavorite(StreamChannel channel) async {
    final key = FavoriteStore.identifier(channel.url);
    final previous = Set<String>.of(_favorites);
    setState(() {
      if (!_favorites.add(key)) {
        _favorites.remove(key);
      }
    });
    // Serialize writes: fast remote presses must not let an older snapshot
    // overwrite the newest favorite state.
    final snapshot = Set<String>.of(_favorites);
    try {
      _favoriteWrite = _favoriteWrite
          .catchError((Object _) {})
          .then((_) => _favoritesStore.save(snapshot));
      await _favoriteWrite;
    } catch (_) {
      if (mounted) {
        setState(() {
          _favorites = previous;
          _message = 'Favorite save nahi hua. Dobara try karein.';
        });
      }
    }
  }

  Future<void> _restorePlaylists() async {
    try {
      final states = await _privacyStore.load();
      final saved = await _playlistStore.load();
      if (!mounted) {
        return;
      }
      final last = await _lastWatchedStore.load();
      if (!mounted) {
        return;
      }
      final restored = last != null &&
              saved.any((item) =>
                  item.id == last.playlistId &&
                  !(states[item.id]?.protected ?? false))
          ? last
          : null;
      setState(() {
        _savedPlaylists = saved;
        _privacy = states;
        _lastWatched = restored;
      });
      final accessible = saved
          .where((item) => !(states[item.id]?.protected ?? false))
          .toList();
      if (accessible.isNotEmpty) {
        final match = restored == null
            ? null
            : saved.where((p) => p.id == restored.playlistId);
        await _openPlaylist(
            match != null && match.isNotEmpty ? match.first : accessible.first);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Saved playlists access nahi ho pa raha. Device secure storage check karein.');
      }
    }
  }

  Future<void> _persistPlaylists(List<SavedPlaylist> next) async {
    // Serialize storage operations to prevent fast TV remote taps from
    // allowing stale snapshots to overwrite newer playlist records.
    _playlistWrite = _playlistWrite.catchError((Object _) {}).then(
          (_) => _playlistStore.save(next),
        );
    await _playlistWrite;
  }

  // Restore only a channel that still exists in its saved playlist.
  // Avoid launching stale URL tokens from a deleted/changed source.
  void _restoreSelectedFrom(List<StreamChannel> channels, String playlistId) {
    final last = _lastWatched;
    if (last == null || last.playlistId != playlistId) {
      return;
    }
    for (final item in channels) {
      if (item.url == last.channel.url) {
        _selected = item;
        _lastWatched = null; // one-time startup restoration
        return;
      }
    }
  }

  Future<void> _openPlaylist(SavedPlaylist playlist) async {
    if (_busy) return;
    if (!_canOpen(playlist)) {
      if (!await _authenticateOwner(allowSetup: false)) return;
      if (!mounted) return;
      _unlockedPlaylists.add(playlist.id);
    }

    if (_activePlaylistId != null && _activePlaylistId != playlist.id) {
      _unlockedPlaylists.remove(_activePlaylistId);
    }
    final generation = ++_loadGeneration;
    setState(() {
      _busy = true;
      _activePlaylistId = playlist.id;
      _selected = null;
      _multiviewSecondary = null;
      _channels = const [];
      _healthScanner.clear();
      _scanCursor = 0;
      _message = 'Opening saved playlist...';
    });
    // Offline-first: show last-known-good cache BEFORE doing network work.
    // Network errors must not erase cached channels or the saved URL.
    try {
      final cached = await _cache.load(playlist.id);
      if (mounted && generation == _loadGeneration && cached.isNotEmpty) {
        setState(() {
          _channels = cached;
          _restoreSelectedFrom(cached, playlist.id);
          _group = 'All groups';
          _filter = ChannelFilter.all;
          _query = '';
          _search.clear();
          _message = '${cached.length} cached channels • Checking for updates';
        });
        _scheduleHealthChecks();
      }
    } catch (_) {
      // Cache may be unavailable following OS credential reset; network still works.
    }
    try {
      final loaded = playlist.kind == PlaylistKind.directStream
          ? [_repository.directChannel(playlist.url, name: playlist.name)]
          : await _repository.fromUrl(playlist.url);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      if (loaded.isEmpty) {
        setState(() => _message = _channels.isEmpty
            ? 'Playlist empty.'
            : 'Source empty • Showing saved channels');
        return;
      }
      setState(() {
        _channels = loaded;
        if (_selected != null &&
            !loaded.any((channel) => channel.url == _selected!.url)) {
          _selected = null;
        }
        _restoreSelectedFrom(loaded, playlist.id);
        _group = 'All groups';
        _filter = ChannelFilter.all;
        _query = '';
        _search.clear();
        _message = '${loaded.length} channels updated';
      });
      _healthScanner.clear();
      _scanCursor = 0;
      _scheduleHealthChecks();
      // Cache is a best-effort optimization, never a reason to fail import.
      try {
        final stored = await _cache.save(playlist.id, loaded);
        if (!stored && mounted && generation == _loadGeneration) {
          setState(() => _message =
              '${loaded.length} channels ready • Offline cache capacity reached');
        }
      } catch (_) {
        if (mounted && generation == _loadGeneration) {
          setState(() =>
              _message = '${loaded.length} channels ready • Cache unavailable');
        }
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _message = _channels.isNotEmpty
            ? 'Offline/source unavailable • Showing saved channels'
            : 'Saved link retained • No cached channels yet. Refresh when online.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreEpgSource() async {
    try {
      final raw = await _epgStorage.read(key: _epgUrlKey);
      if (raw == null) {
        return;
      }
      final parsed = Uri.tryParse(raw);
      if (parsed == null ||
          !(parsed.isScheme('https') || parsed.isScheme('http')) ||
          parsed.host.isEmpty ||
          parsed.userInfo.isNotEmpty) {
        return;
      }
      _epgSource = parsed;
      final cached = await _epgCache.load(parsed);
      if (!mounted || _epgSource != parsed) {
        return;
      }
      if (cached.isNotEmpty) {
        setState(() {
          _programs = cached;
          _epgMessage = 'Offline guide ready • Updating in background';
        });
      }
      await _refreshEpg();
    } catch (_) {
      if (mounted) {
        setState(() => _epgMessage = 'Saved guide access unavailable.');
      }
    }
  }

  Future<void> _refreshEpg() async {
    final source = _epgSource;
    if (source == null) {
      return;
    }
    if (_epgFetching) {
      _epgRefreshQueued = true;
      return;
    }
    _epgFetching = true;
    final generation = ++_epgGeneration;
    if (mounted) {
      setState(() => _epgMessage = 'Refreshing TV guide...');
    }
    try {
      final result = await _epgRepository.fetch(source);
      if (!mounted || generation != _epgGeneration || source != _epgSource) {
        return;
      }
      setState(() {
        _programs = result;
        _epgMessage = 'Guide updated • ${result.length} channels';
      });
      // Persist successful results only; keep the last good guide on failure.
      try {
        await _epgCache.save(source, result);
      } catch (_) {
        // Network guide remains usable even if local secure cache is full.
      }
    } catch (_) {
      if (mounted && generation == _epgGeneration && source == _epgSource) {
        setState(() => _epgMessage = _programs.isNotEmpty
            ? 'Guide refresh failed • Showing previous guide'
            : 'Guide unavailable. Check XMLTV link or size limit.');
      }
    } finally {
      _epgFetching = false;
      if (mounted && _epgRefreshQueued) {
        _epgRefreshQueued = false;
        // Schedule after completion rather than overlapping downloads.
        unawaited(_refreshEpg());
      }
    }
  }

  Future<void> _loadEpg() async {
    final value = TextEditingController(text: _epgSource?.toString() ?? '');
    final input = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('XMLTV Guide URL'),
              content: SizedBox(
                  width: 420,
                  child: TextField(
                      controller: value,
                      decoration: const InputDecoration(
                          hintText: 'https://example.com/guide.xml'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, value.text.trim()),
                    child: const Text('Save & Load'))
              ],
            ));
    WidgetsBinding.instance.addPostFrameCallback((_) => value.dispose());
    if (input == null || input.isEmpty || !mounted) {
      return;
    }
    final source = Uri.tryParse(input);
    if (source == null ||
        !(source.isScheme('https') || source.isScheme('http')) ||
        source.host.isEmpty ||
        source.userInfo.isNotEmpty) {
      setState(() => _epgMessage = 'Valid HTTP(S) guide URL daalein.');
      return;
    }
    try {
      await _epgStorage.write(key: _epgUrlKey, value: source.toString());
      if (!mounted) {
        return;
      }
      _epgSource = source;
      final cached = await _epgCache.load(source);
      if (!mounted || _epgSource != source) {
        return;
      }
      setState(() {
        _programs = cached;
        _epgMessage = cached.isEmpty
            ? 'Loading TV guide...'
            : 'Saved guide ready • Updating';
      });
      await _refreshEpg();
    } catch (_) {
      if (mounted) {
        setState(
            () => _epgMessage = 'Guide URL secure storage mein save nahi hui.');
      }
    }
  }

  Future<void> _openProvider() async {
    final channel = await showDialog<StreamChannel>(
      context: context,
      builder: (_) => const XtreamBrowser(),
    );
    if (!mounted || channel == null) {
      return;
    }
    // Provider catalogue is separate from the loaded M3U list, but uses
    // the very same native playback widget and controls.
    _select(channel);
  }

  Future<void> _chooseMultiview() async {
    if (_selected == null) {
      return;
    }
    final choices =
        _channels.where((c) => c.url != _selected!.url).toList(growable: false);
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Multiview ke liye playlist mein second channel chahiye.')));
      return;
    }
    final picked = await showDialog<StreamChannel>(
        context: context,
        builder: (ctx) =>
            AlertDialog(
                title: const Text('Select second channel',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                content: SizedBox(
                    width: 440,
                    height: 380,
                    child: ListView.builder(
                        itemCount: choices.length,
                        itemBuilder: (ctx, index) => ListTile(
                            title: Text(choices[index].name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () =>
                                Navigator.of(ctx).pop(choices[index])))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'))
                ]));
    if (mounted && picked != null) {
      setState(() => _multiviewSecondary = picked);
    }
  }

  void _showTvGuide() {
    if (_programs.isEmpty || _channels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pehle playlist aur XMLTV guide load karein.'),
      ));
      return;
    }
    showDialog<void>(
        context: context,
        builder: (context) => TvGuideDialog(
              channels: _channels,
              programs: _programs,
              onPlay: _select,
            ));
  }

  EpgProgram? _currentProgram(StreamChannel channel) {
    final id = channel.tvgId;
    if (id == null) {
      return null;
    }
    final now = DateTime.now().toUtc();
    for (final program in _programs[id] ?? const <EpgProgram>[]) {
      if (!now.isBefore(program.start) && now.isBefore(program.stop)) {
        return program;
      }
    }
    return null;
  }

  void _showHowToUse() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to use SanSeth Play'),
        content: const SizedBox(
          width: 430,
          child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Tap Import, then choose M3U / GitHub playlist URL.'),
              SizedBox(height: 12),
              Text('2. Paste your authorized source URL and tap Add.'),
              SizedBox(height: 12),
              Text('3. Choose categories, search channels or save favorites.'),
              SizedBox(height: 12),
              Text(
                  '4. Tap the mini-player icon beside a playing channel to browse while watching.'),
              SizedBox(height: 12),
              Text(
                  '5. Restore the mini-player or tap a different channel to switch.'),
              SizedBox(height: 12),
              Text(
                  'Stream playback depends on compatible sources and the network.'),
            ],
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (_) => const SanSethAboutDialog(),
    );
  }

  Future<void> _showImportOptions() async {
    if (_busy || _sourceMutationBusy) {
      return;
    }
    final selectedMode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Import',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final option in <(String, IconData, String, String)>[
            (
              'playlist',
              Icons.link_rounded,
              'M3U / GitHub playlist URL',
              'Save channels by category'
            ),
            (
              'direct',
              Icons.live_tv_rounded,
              'Direct live stream',
              'Play a compatible stream URL'
            ),
            (
              'text',
              Icons.paste_rounded,
              'Paste M3U text',
              'Temporary channel list'
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  leading: Icon(option.$2, color: _gold),
                  title: Text(option.$3,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(option.$4,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(option.$1),
                ),
              ),
            ),
        ]),
      ),
    );
    if (!mounted || selectedMode == null) {
      return;
    }
    _sourceMutationBusy = true;
    try {
      await _showAddPlaylistDialog(initialMode: selectedMode);
    } finally {
      _sourceMutationBusy = false;
    }
  }

  Future<void> _addPlaylist() async {
    if (_busy || _sourceMutationBusy) {
      return;
    }
    _sourceMutationBusy = true;
    try {
      await _showAddPlaylistDialog();
    } finally {
      _sourceMutationBusy = false;
    }
  }

  Future<void> _showAddPlaylistDialog({String initialMode = 'playlist'}) async {
    final input = TextEditingController();
    final titleInput = TextEditingController();
    String mode = initialMode;
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.playlist_add_rounded, color: _gold),
            SizedBox(width: 10),
            Expanded(child: Text('Add Playlist / Live Stream', maxLines: 2)),
          ]),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Sirf authorized streams add karein. Saved links app restart ke baad bhi rahenge.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'playlist',
                          child: Text('M3U URL / GitHub Link')),
                      DropdownMenuItem(
                          value: 'direct',
                          child: Text('Direct Live Stream URL')),
                      DropdownMenuItem(
                          value: 'text',
                          child: Text('Paste M3U Text (session only)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => mode = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (mode != 'text') ...[
                    TextField(
                      controller: titleInput,
                      maxLines: 1,
                      decoration: const InputDecoration(
                          hintText: 'Playlist name (optional)'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: input,
                    autofocus: false,
                    minLines: 1,
                    maxLines: mode == 'text' ? 6 : 3,
                    decoration: InputDecoration(
                      hintText: mode == 'text'
                          ? '#EXTM3U...'
                          : mode == 'direct'
                              ? 'https://example.com/live/index.m3u8'
                              : 'https://raw.githubusercontent.com/.../playlist.m3u',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'URL secure device storage mein save hoga. M3U text sirf session mein rahega.',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext,
                  (mode, titleInput.text.trim(), input.text.trim())),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      input.dispose();
      titleInput.dispose();
    });
    if (!mounted || result == null || result.$3.isEmpty) {
      return;
    }
    if (result.$1 == 'text') {
      setState(() {
        _busy = true;
        _message = null;
      });
      try {
        final loaded = await _repository.fromText(result.$3);
        if (!mounted) {
          return;
        }
        setState(() {
          _activePlaylistId = null;
          _channels = loaded;
          _selected = null;
          _group = 'All groups';
          _filter = ChannelFilter.all;
          _message = '${loaded.length} temporary channels ready';
        });
      } catch (_) {
        if (mounted) {
          setState(() => _message = 'M3U text invalid hai.');
        }
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
      return;
    }

    try {
      final url = normalizePlaylistUrl(Uri.parse(result.$3));
      final kind = result.$1 == 'direct'
          ? PlaylistKind.directStream
          : PlaylistKind.remoteM3u;
      final name = result.$2.isNotEmpty
          ? result.$2
          : (url.pathSegments.isNotEmpty && url.pathSegments.last.isNotEmpty
              ? url.pathSegments.last
              : url.host);
      if (containsPlaylistSource(_savedPlaylists, url)) {
        setState(() => _message = 'Ye playlist pehle se saved hai.');
        return;
      }
      final source = SavedPlaylist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        url: url,
        kind: kind,
      );
      final next = [..._savedPlaylists, source];
      // Persist before downloading so temporary network failure does not
      // discard the URL that the user explicitly added.
      await _persistPlaylists(next);
      if (!mounted) {
        return;
      }
      setState(() => _savedPlaylists = next);
      await _openPlaylist(source);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Playlist save nahi hui. URL aur secure storage check karein.');
      }
    }
  }

  Future<void> _removeActivePlaylist() async {
    if (_busy) {
      return;
    }
    final active = _activePlaylistId;
    if (active == null) {
      _clearSession();
      return;
    }
    final next = _savedPlaylists.where((p) => p.id != active).toList();
    try {
      await _persistPlaylists(next);
      if (!mounted) {
        return;
      }
      setState(() => _savedPlaylists = next);
      _clearSession();
      await _lastWatchedWrite.catchError((Object _) {});
      final remembered = await _lastWatchedStore.load();
      if (remembered?.playlistId == active) {
        _lastWatched = null;
        await _lastWatchedStore.clear();
      }
      try {
        await _privacyStore.clearPlaylist(active);
      } catch (_) {}
      try {
        await _cache.remove(active);
      } catch (_) {/* stale cache only */}
      final available = next.where((p) => !_protected(p));
      if (available.isNotEmpty) {
        await _openPlaylist(available.first);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Playlist remove nahi hui.');
      }
    }
  }

  void _clearSession() {
    ++_loadGeneration;
    setState(() {
      _channels = const [];
      _selected = null;
      _multiviewSecondary = null;
      _miniPlayer = false;
      _healthScanner.clear();
      _activePlaylistId = null;
      _busy = false;
      _group = 'All groups';
      _filter = ChannelFilter.all;
      _search.clear();
      _query = '';
      _message = 'Playlist closed. Saved links remain available.';
    });
  }

  void _refreshActive() {
    if (_busy) {
      return;
    }
    final active = _savedPlaylists.where((p) => p.id == _activePlaylistId);
    if (active.isNotEmpty && _canOpen(active.first)) {
      _openPlaylist(active.first);
    }
  }

  /// Searchable source management. Each row offers Open, Edit and Delete;
  /// commit to secure storage BEFORE updating visible state.
  Future<void> _browseSavedPlaylists({bool includeHidden = false}) async {
    if (_sourceMutationBusy) {
      return;
    }
    var query = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (dialogContext, setDialogState) {
        final filtered = _savedPlaylists
            .where((item) =>
                (includeHidden || !_hidden(item)) &&
                item.name.toLowerCase().contains(query))
            .toList(growable: false);
        final available = MediaQuery.sizeOf(dialogContext);
        final keyboard = MediaQuery.viewInsetsOf(dialogContext).bottom;
        final dialogHeight = (available.height - keyboard - 185.0)
            .clamp(170.0, 580.0)
            .toDouble();
        final dialogWidth =
            (available.width - 80.0).clamp(180.0, 620.0).toDouble();
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.video_library_rounded, color: _gold),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    includeHidden
                        ? 'Manage protected playlists'
                        : 'Saved playlists (${_savedPlaylists.where((p) => !_hidden(p)).length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(children: [
                TextField(
                    onChanged: (value) => setDialogState(
                        () => query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search playlists')),
                const SizedBox(height: 12),
                Expanded(
                    child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                        margin: const EdgeInsets.only(bottom: 11),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(children: [
                              const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Icon(Icons.live_tv_rounded,
                                      color: _gold)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(_locked(item)
                                    ? 'Locked • PIN required'
                                    : (_hidden(item)
                                        ? 'Hidden'
                                        : (item.kind ==
                                                PlaylistKind.directStream
                                            ? 'Direct stream'
                                            : 'M3U playlist'))),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  unawaited(_openPlaylist(item));
                                },
                              )),
                              PopupMenuButton<String>(
                                tooltip: 'Edit or delete ${item.name}',
                                icon: const Icon(Icons.more_vert_rounded,
                                    color: _gold),
                                onSelected: (action) async {
                                  if (_sourceMutationBusy) {
                                    return;
                                  }
                                  if ((action == 'edit' ||
                                          action == 'delete') &&
                                      _protected(item) &&
                                      !await _authenticateOwner()) {
                                    return;
                                  }
                                  if (action == 'hide') {
                                    await _configurePrivacy(item,
                                        hidden: !_hidden(item),
                                        locked: _locked(item));
                                  } else if (action == 'lock') {
                                    await _configurePrivacy(item,
                                        hidden: _hidden(item),
                                        locked: !_locked(item));
                                  } else if (action == 'edit') {
                                    await _editSavedPlaylist(item);
                                  } else if (action == 'delete') {
                                    await _deleteSavedPlaylist(item);
                                  }
                                  if (dialogContext.mounted) {
                                    setDialogState(() {});
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'hide',
                                      child: Text(_hidden(item)
                                          ? 'Unhide playlist'
                                          : 'Hide playlist')),
                                  PopupMenuItem(
                                      value: 'lock',
                                      child: Text(_locked(item)
                                          ? 'Remove playlist lock'
                                          : 'Lock playlist')),
                                  const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit name / URL')),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete playlist')),
                                ],
                              ),
                            ])));
                  },
                )),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'))
          ],
        );
      }),
    );
  }

  Future<void> _editSavedPlaylist(SavedPlaylist item) async {
    final nameController = TextEditingController(text: item.name);
    final urlController = TextEditingController(text: item.url.toString());
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit playlist'),
        content: SizedBox(
            width: 470,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Playlist name'),
                  maxLength: 100),
              const SizedBox(height: 12),
              TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'Playlist URL'),
                  maxLines: 2),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, (nameController.text.trim(), urlController.text.trim())),
              child: const Text('Save changes')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      urlController.dispose();
    });
    if (result == null || !mounted) {
      return;
    }
    final newName = result.$1;
    Uri newUrl;
    try {
      if (newName.isEmpty) {
        throw const FormatException();
      }
      newUrl = normalizePlaylistUrl(Uri.parse(result.$2));
      if (_savedPlaylists.any((p) =>
          p.id != item.id &&
          playlistSourceKey(p.url) == playlistSourceKey(newUrl))) {
        throw const FormatException('Same URL already saved.');
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Valid name/URL daalein; duplicate playlist allowed nahi hai.')));
      return;
    }
    if (_sourceMutationBusy) {
      return;
    }
    _sourceMutationBusy = true;
    try {
      final current = _savedPlaylists.where((p) => p.id == item.id);
      if (current.isEmpty) {
        return;
      }
      final edited = SavedPlaylist(
          id: item.id, name: newName, url: newUrl, kind: item.kind);
      final changedUrl =
          playlistSourceKey(item.url) != playlistSourceKey(newUrl);
      final next =
          _savedPlaylists.map((p) => p.id == item.id ? edited : p).toList();
      await _persistPlaylists(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedPlaylists = next;
      });
      if (changedUrl) {
        ++_loadGeneration; // invalidate any obsolete download
        try {
          await _privacyStore.clearPlaylist(item.id);
        } catch (_) {}
        _unlockedPlaylists.remove(item.id);
        try {
          await _cache.remove(item.id);
        } catch (_) {/* cache best effort */}
        await _lastWatchedWrite.catchError((Object _) {});
        final remembered = await _lastWatchedStore.load();
        if (remembered?.playlistId == item.id) {
          _lastWatched = null;
          await _lastWatchedStore.clear();
        }
        if (_activePlaylistId == item.id) {
          _clearSession();
          await _openPlaylist(edited);
        }
      } else if (_activePlaylistId == item.id &&
          item.kind == PlaylistKind.directStream) {
        final renamed = _repository.directChannel(newUrl, name: newName);
        setState(() {
          _channels = [renamed];
          if (_selected?.url == renamed.url) {
            _selected = renamed;
          }
          _message = 'Playlist renamed';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Playlist update save nahi hua.');
      }
    } finally {
      _sourceMutationBusy = false;
    }
  }

  Future<void> _deleteSavedPlaylist(SavedPlaylist item) async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete playlist?'),
              content:
                  Text('"${item.name}" saved list se remove hogi. Continue?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ));
    if (approved != true || !mounted || _sourceMutationBusy) {
      return;
    }
    _sourceMutationBusy = true;
    try {
      final next = _savedPlaylists.where((p) => p.id != item.id).toList();
      await _persistPlaylists(next);
      if (!mounted) {
        return;
      }
      setState(() => _savedPlaylists = next);
      await _lastWatchedWrite.catchError((Object _) {});
      final remembered = await _lastWatchedStore.load();
      if (remembered?.playlistId == item.id) {
        _lastWatched = null;
        await _lastWatchedStore.clear();
      }
      try {
        await _privacyStore.clearPlaylist(item.id);
      } catch (_) {}
      _unlockedPlaylists.remove(item.id);
      try {
        await _cache.remove(item.id);
      } catch (_) {/* noncritical */}
      if (_activePlaylistId == item.id) {
        _clearSession();
        final available = next.where((p) => !_protected(p));
        if (available.isNotEmpty) {
          await _openPlaylist(available.first);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Playlist delete nahi hui.');
      }
    } finally {
      _sourceMutationBusy = false;
    }
  }

  Future<void> _browseCategories() async {
    final counts = ChannelCategories.counts(_channels);
    final categories = ChannelCategories.labels(_channels);
    final chosen = await showDialog<String>(
        context: context,
        builder: (context) => _SearchableChoiceDialog<String>(
              title: 'Categories (${counts.length})',
              items: categories,
              label: (item) => item,
              detail: (item) => item == ChannelCategories.all
                  ? '${_channels.length} channels'
                  : '${counts[item] ?? 0} channels',
            ));
    if (chosen != null && mounted) {
      setState(() => _group = chosen);
    }
  }

  List<StreamChannel> _visibleChannels() {
    final recentOrder = <String, int>{
      for (var i = 0; i < _recentHashes.length; i++) _recentHashes[i]: i,
    };
    final result = _channels.where((channel) {
      if (_hideUnavailable &&
          _health.hasConfirmedUnavailable &&
          channel.url != _selected?.url &&
          _health.status(channel.url) == ChannelHealth.unavailable) {
        return false;
      }
      // Hash only when the corresponding filter is selected. On 50k+
      // channels, SHA-256 for every item on every normal build causes jank.
      if (_filter == ChannelFilter.recent &&
          !recentOrder
              .containsKey(RecentChannelStore.identifier(channel.url))) {
        return false;
      }
      if (_filter == ChannelFilter.favorites &&
          !_favorites.contains(FavoriteStore.identifier(channel.url))) {
        return false;
      }
      if (_group != 'All groups' && channel.group != _group) {
        return false;
      }
      if (_query.isEmpty) {
        return true;
      }
      return channel.name.toLowerCase().contains(_query) ||
          channel.group.toLowerCase().contains(_query);
    }).toList(growable: false);
    if (_filter == ChannelFilter.recent) {
      result.sort((a, b) => recentOrder[RecentChannelStore.identifier(a.url)]!
          .compareTo(recentOrder[RecentChannelStore.identifier(b.url)]!));
    }
    return result;
  }

  // Keep available for D-pad navigation integration; not yet wired to an event.
  // ignore: unused_element
  void _moveSelection(int delta) {
    if (_searchFocus.hasFocus || _busy) {
      return;
    }
    final visible = _visibleChannels();
    if (visible.isEmpty) {
      return;
    }
    final index = visible.indexWhere((item) => item.url == _selected?.url);
    final next = (index < 0
        ? (delta > 0 ? 0 : visible.length - 1)
        : (index + delta).clamp(0, visible.length - 1));
    _select(visible[next]);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobileLandscape = shouldUseMobileLandscapePlayer(
      isAndroid: Platform.isAndroid,
      size: size,
      hasChannel: _selected != null,
      disabledByUser: _landscapeFullscreenDismissed || _miniPlayer,
    );
    if (size.height >= size.width) {
      _landscapeFullscreenDismissed = false;
    }
    _syncSystemUi(mobileLandscape);
    final desktop = size.width >= 850;
    final tv = _tvPreview || (size.width >= 1250 && size.height >= 650);
    final visible = _visibleChannels();
    final mini = _miniPlayer && _selected != null && !mobileLandscape;
    // On compact screens, an empty player preview used to reduce the sidebar
    // below 300 px and hide playlist/filter controls entirely. Show the channel
    // browser first until a stream is selected; keep normal playback unchanged.
    final compactEmptyLibrary =
        _selected == null && size.width < 850 && size.height < 720;
    final channelBrowserOnly = (_navIndex == 2 || compactEmptyLibrary) &&
        _selected == null &&
        !mobileLandscape;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _addPlaylist,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            FocusManager.instance.primaryFocus?.unfocus(),
      },
      child: Focus(
        focusNode: _shortcutsFocus,
        autofocus: true,
        child: Scaffold(
          appBar: mobileLandscape
              ? null
              : AppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  titleSpacing: 12,
                  title: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset(
                        'assets/branding/app_icon_header_transparent.png',
                        height: 49,
                        width: 49,
                        semanticLabel: 'SanSeth Play'),
                    if (size.width >= 390)
                      const Flexible(
                          child: Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: Text('SanSeth Play',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                      )),
                  ]),
                  actions: [
                    if (_savedPlaylists.isNotEmpty)
                      IconButton(
                        tooltip: 'My playlists',
                        onPressed: _browseSavedPlaylists,
                        icon: const Icon(Icons.video_library_rounded),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      constraints: BoxConstraints(
                        minWidth: (size.width * .68).clamp(240.0, 330.0),
                        maxWidth: (size.width * .86).clamp(260.0, 380.0),
                        maxHeight: size.height * .82,
                      ),
                      offset: const Offset(-22, 10),
                      iconColor: _gold,
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (value) {
                        if (value == 'provider') {
                          _openProvider();
                        }
                        if (value == 'recordings') {
                          showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  RecordingsDialog(onPlay: (channel) {
                                    if (_activePlaylistId == null ||
                                        _savedPlaylists.any((p) =>
                                            p.id == _activePlaylistId &&
                                            _canOpen(p))) {
                                      _select(channel);
                                    }
                                  }));
                        }
                        if (value == 'epg') {
                          _loadEpg();
                        }
                        if (value == 'epg-refresh') {
                          _refreshEpg();
                        }
                        if (value == 'guide') {
                          _showTvGuide();
                        }
                        if (value == 'clear-recent') {
                          _clearRecent();
                        }
                        if (value == 'refresh') {
                          _refreshActive();
                        }
                        if (value == 'remove') {
                          _removeActivePlaylist();
                        }
                        if (value == 'saved') {
                          _browseSavedPlaylists();
                        }
                        if (value == 'hidden') {
                          _manageHiddenPlaylists();
                        }
                        if (value == 'owner-pin') {
                          _changeOwnerPin();
                        }
                        if (value == 'about') {
                          _showAbout();
                        }
                        if (value == 'help') {
                          _showHowToUse();
                        }
                        if (value == 'tv') {
                          setState(() => _tvPreview = !_tvPreview);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                            enabled: false,
                            height: 40,
                            child: Text('PLAYLIST & CONTENT',
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2))),
                        if (_savedPlaylists.isNotEmpty)
                          const PopupMenuItem(
                              value: 'saved',
                              height: 58,
                              child: Row(children: [
                                Icon(Icons.video_library_outlined,
                                    color: _gold, size: 23),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Text('My playlists',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right_rounded,
                                    size: 19, color: _gold)
                              ])),
                        const PopupMenuItem(
                            value: 'hidden',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.shield_outlined,
                                  color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('Manage hidden playlists',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)))
                            ])),
                        const PopupMenuItem(
                            value: 'owner-pin',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.password_rounded,
                                  color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('Set / change owner PIN',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis))
                            ])),
                        const PopupMenuItem(
                            value: 'provider',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.dns_outlined, color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('Xtream provider (optional)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: _gold)
                            ])),
                        const PopupMenuItem(
                            value: 'recordings',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.videocam_outlined,
                                  color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('My recordings',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: _gold)
                            ])),
                        const PopupMenuItem(
                            value: 'guide',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.live_tv_outlined,
                                  color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('TV guide',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: _gold)
                            ])),
                        const PopupMenuItem<String>(
                            enabled: false,
                            height: 38,
                            child: Text('HELP & INFO',
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2))),
                        const PopupMenuItem(
                            value: 'help',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.help_outline_rounded,
                                  color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('How to use',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: _gold)
                            ])),
                        const PopupMenuItem(
                            value: 'about',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('About / Version',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: _gold)
                            ])),
                        const PopupMenuItem<String>(
                            enabled: false,
                            height: 38,
                            child: Text('TOOLS',
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2))),
                        const PopupMenuItem(
                            value: 'epg',
                            height: 58,
                            child: Row(children: [
                              Icon(Icons.link_rounded, color: _gold, size: 23),
                              SizedBox(width: 14),
                              Expanded(
                                  child: Text('Load XMLTV URL',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: _gold)
                            ])),
                        if (size.width >= 600)
                          const PopupMenuItem(
                              value: 'tv',
                              height: 58,
                              child: Row(children: [
                                Icon(Icons.tv_rounded, color: _gold, size: 23),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Text('TV layout preview',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right_rounded,
                                    size: 19, color: _gold)
                              ])),
                        if (_recentHashes.isNotEmpty)
                          const PopupMenuItem(
                              value: 'clear-recent',
                              height: 58,
                              child: Row(children: [
                                Icon(Icons.history_rounded,
                                    color: _gold, size: 23),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Text('Clear recent history',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right_rounded,
                                    size: 19, color: _gold)
                              ])),
                        if (_epgSource != null)
                          const PopupMenuItem(
                              value: 'epg-refresh',
                              height: 58,
                              child: Row(children: [
                                Icon(Icons.refresh_rounded,
                                    color: _gold, size: 23),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Text('Refresh TV guide',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right_rounded,
                                    size: 19, color: _gold)
                              ])),
                        if (_activePlaylistId != null) ...[
                          const PopupMenuItem(
                              value: 'refresh',
                              height: 58,
                              child: Row(children: [
                                Icon(Icons.sync_rounded,
                                    color: _gold, size: 23),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Text('Refresh playlist',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right_rounded,
                                    size: 19, color: _gold)
                              ])),
                          const PopupMenuItem(
                              value: 'remove',
                              height: 58,
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 23),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Text('Remove playlist',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right_rounded,
                                    size: 19, color: _gold)
                              ])),
                        ],
                      ],
                    ),
                    if (_busy && size.width >= 450)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 19,
                              height: 19,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _showImportOptions,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(size.width < 390 ? 'Add' : 'Import',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: !mobileLandscape && size.width < 700
              ? NavigationBar(
                  height: 74,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  indicatorColor: _gold.withValues(alpha: .16),
                  selectedIndex: _navIndex,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home'),
                    NavigationDestination(
                        icon: Icon(Icons.add_circle_outline_rounded),
                        label: 'Import'),
                    NavigationDestination(
                        icon: Icon(Icons.live_tv_outlined),
                        selectedIcon: Icon(Icons.live_tv_rounded),
                        label: 'Channels'),
                  ],
                  onDestinationSelected: (index) {
                    if (index == 1) {
                      _showImportOptions();
                      return;
                    }
                    setState(() {
                      _navIndex = index;
                      _miniPlayer = index == 2 && _selected != null;
                    });
                  },
                )
              : null,
          body: SafeArea(
            top: !mobileLandscape,
            bottom: !mobileLandscape,
            left: !mobileLandscape,
            right: !mobileLandscape,
            child: LayoutBuilder(builder: (context, bounds) {
              final gap = desktop ? 18.0 : 10.0;
              final pad = mobileLandscape ? 0.0 : (desktop ? 20.0 : 10.0);
              final sideWidth = tv ? 360.0 : 320.0;
              final portraitPlayerHeight = (bounds.maxWidth * 9 / 16 + 64)
                  .clamp(0.0, bounds.maxHeight * .52)
                  .toDouble();
              // Give the repositioned player a stable key so resizing into the
              // mini-player does not intentionally create a second decoder.
              // Actual native texture continuity must be verified on devices.
              return Stack(children: [
                if (!mobileLandscape && !_channelSheetOpen)
                  Positioned(
                    left: pad,
                    right: desktop && !mini && !channelBrowserOnly ? null : pad,
                    width: desktop && !mini && !channelBrowserOnly
                        ? sideWidth
                        : null,
                    top: mini || channelBrowserOnly
                        ? pad
                        : (desktop ? pad : pad + portraitPlayerHeight + gap),
                    bottom: pad,
                    child: _sidebar(visible, tv, mini: mini),
                  ),
                if (!channelBrowserOnly)
                  Positioned(
                    key: const ValueKey('persistent-player-pane'),
                    left: mini
                        ? null
                        : (mobileLandscape
                            ? 0
                            : (desktop ? pad + sideWidth + gap : pad)),
                    width: mini
                        ? (bounds.maxWidth - 32).clamp(160.0, 260.0).toDouble()
                        : null,
                    right: mobileLandscape ? 0 : pad,
                    top: mini ? null : (mobileLandscape ? 0 : pad),
                    height: mini ? 170 : null,
                    bottom: mobileLandscape
                        ? 0
                        : (mini
                            ? pad + 6
                            : (desktop
                                ? pad
                                : bounds.maxHeight -
                                    pad -
                                    portraitPlayerHeight)),
                    // Very short landscape windows cannot fit the full player caption
                    // beneath the video. Keep the video visible and omit only
                    // secondary caption rows; this is a real layout fix rather
                    // than loosening the responsive overflow test.
                    child: _content(
                      tv,
                      immersive: mobileLandscape,
                      compact: mini ||
                          (!mobileLandscape &&
                              bounds.maxHeight < 330 &&
                              bounds.maxWidth > bounds.maxHeight),
                    ),
                  ),
                if (mini)
                  Positioned(
                    right: pad + 5,
                    bottom: pad + 10,
                    child: Material(
                      color: const Color(0xD9080B11),
                      borderRadius: BorderRadius.circular(20),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          key: const Key('restore_mini_player'),
                          tooltip: 'Restore player',
                          icon:
                              const Icon(Icons.open_in_full_rounded, size: 19),
                          onPressed: () => setState(() {
                            _miniPlayer = false;
                            _navIndex = 0;
                          }),
                        ),
                        IconButton(
                          key: const Key('close_mini_player'),
                          tooltip: 'Stop and close mini player',
                          icon: const Icon(Icons.close_rounded, size: 19),
                          onPressed: () => setState(() {
                            _miniPlayer = false;
                            _navIndex = 0;
                            _selected = null;
                            _multiviewSecondary = null;
                          }),
                        ),
                      ]),
                    ),
                  ),
                if (mobileLandscape && _landscapeControlsVisible)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: const Color(0xC9141720),
                      borderRadius: BorderRadius.circular(28),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Channels and search',
                          icon: const Icon(Icons.list_rounded),
                          onPressed: _showLandscapeChannels,
                        ),
                        IconButton(
                          tooltip: 'My playlists',
                          icon: const Icon(Icons.video_library_outlined),
                          onPressed: _savedPlaylists.isEmpty
                              ? _showImportOptions
                              : _browseSavedPlaylists,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More landscape actions',
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (value) {
                            if (value == 'guide') {
                              _showTvGuide();
                            }
                            if (value == 'recordings') {
                              showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      RecordingsDialog(onPlay: (channel) {
                                        if (_activePlaylistId == null ||
                                            _savedPlaylists.any((p) =>
                                                p.id == _activePlaylistId &&
                                                _canOpen(p))) {
                                          _select(channel);
                                        }
                                      }));
                            }
                            if (value == 'provider') {
                              _openProvider();
                            }
                            if (value == 'about') {
                              _showAbout();
                            }
                            if (value == 'help') {
                              _showHowToUse();
                            }
                            if (value == 'favorite' && _selected != null) {
                              _toggleFavorite(_selected!);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'guide', child: Text('TV guide')),
                            PopupMenuItem(
                                value: 'recordings', child: Text('Recordings')),
                            PopupMenuItem(
                                value: 'provider',
                                child: Text('Xtream provider')),
                            PopupMenuItem(
                                value: 'favorite',
                                child: Text('Toggle favorite')),
                            PopupMenuItem(
                                value: 'help', child: Text('How to use')),
                            PopupMenuItem(
                                value: 'about', child: Text('About / Version')),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Exit fullscreen layout',
                          icon: const Icon(Icons.close_fullscreen_rounded),
                          onPressed: () => setState(() {
                            _landscapeFullscreenDismissed = true;
                          }),
                        ),
                      ]),
                    ),
                  ),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _content(bool tv, {bool immersive = false, bool compact = false}) =>
      LayoutBuilder(builder: (context, constraints) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: immersive && constraints.maxHeight > 0
                          ? constraints.maxWidth / constraints.maxHeight
                          : 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFF020810),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: const Color(0xFFB78E3C), width: 1.2)),
                        clipBehavior: Clip.antiAlias,
                        child: _selected == null
                            ? Center(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.smart_display_rounded,
                                                  size: tv ? 75 : 42,
                                                  color: _gold),
                                              const SizedBox(height: 5),
                                              const Text(
                                                  'Your entertainment starts here',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              const Text(
                                                  'Import your authorized playlist',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white54)),
                                            ]))))
                            : _multiviewSecondary != null
                                ? Row(children: [
                                    Expanded(
                                        child: PlayerView(
                                            key: const ValueKey(
                                                'sanseth-multiview-primary'),
                                            channel: _selected!,
                                            onPlaybackHealth:
                                                _onPlaybackHealth)),
                                    const VerticalDivider(
                                        width: 3, color: Color(0xFFF4C65B)),
                                    Expanded(
                                        child: PlayerView(
                                            key: const ValueKey(
                                                'sanseth-multiview-secondary'),
                                            channel: _multiviewSecondary!,
                                            initialVolume: 0,
                                            enableSystemMediaSession: false,
                                            onPlaybackHealth:
                                                _onPlaybackHealth)),
                                  ])
                                : PlayerView(
                                    key: const ValueKey(
                                        'sanseth-primary-player'),
                                    channel: _selected!,
                                    onPlaybackHealth: _onPlaybackHealth,
                                    compact: compact,
                                    onControlsInteraction:
                                        _revealLandscapeControls,
                                    onExitFullscreen: () => setState(() {
                                      _landscapeFullscreenDismissed = true;
                                    }),
                                    onPrevious: _channels.indexWhere(
                                                (channel) =>
                                                    channel.url ==
                                                    _selected!.url) >
                                            0
                                        ? () {
                                            final index = _channels.indexWhere(
                                                (channel) =>
                                                    channel.url ==
                                                    _selected!.url);
                                            if (index > 0) {
                                              _select(_channels[index - 1]);
                                            }
                                          }
                                        : null,
                                    onNext: (() {
                                      final index = _channels.indexWhere(
                                          (channel) =>
                                              channel.url == _selected!.url);
                                      return index >= 0 &&
                                          index + 1 < _channels.length;
                                    })()
                                        ? () {
                                            final index = _channels.indexWhere(
                                                (channel) =>
                                                    channel.url ==
                                                    _selected!.url);
                                            if (index >= 0 &&
                                                index + 1 < _channels.length) {
                                              _select(_channels[index + 1]);
                                            }
                                          }
                                        : null,
                                  ),
                      ),
                    )),
              ),
              if (!immersive && !compact) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Text(_selected?.name ?? 'SanSeth Play',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: tv ? 28 : 20,
                              fontWeight: FontWeight.w800))),
                  if (_selected != null &&
                      _multiviewSecondary == null &&
                      !_miniPlayer)
                    IconButton(
                        key: const Key('minimize_player'),
                        tooltip: 'Minimize player and browse channels',
                        onPressed: () => setState(() {
                              _miniPlayer = true;
                              _navIndex = 2;
                            }),
                        icon: const Icon(Icons.picture_in_picture_alt_rounded,
                            color: _gold)),
                  if (_selected != null)
                    IconButton(
                        tooltip: _multiviewSecondary == null
                            ? 'Open 2-channel multiview'
                            : 'Close multiview',
                        onPressed: _multiviewSecondary == null
                            ? _chooseMultiview
                            : () => setState(() => _multiviewSecondary = null),
                        icon: Icon(
                            _multiviewSecondary == null
                                ? Icons.view_week_outlined
                                : Icons.close_fullscreen,
                            color: _gold)),
                  if (_selected != null)
                    IconButton(
                        tooltip: 'Toggle favorite',
                        onPressed: () => _toggleFavorite(_selected!),
                        icon: Icon(
                            _favorites.contains(
                                    FavoriteStore.identifier(_selected!.url))
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: _gold)),
                ]),
                Text(_selected?.group ?? 'LIVE TV  •  MOVIES  •  SERIES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _gold, fontSize: 11, letterSpacing: 1.1)),
                if (_selected != null && _currentProgram(_selected!) != null)
                  Text('NOW: ${_currentProgram(_selected!)!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                if (_epgMessage != null)
                  Text(_epgMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _gold, fontSize: 11)),
                if (_message != null)
                  Text(_message!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ]);
      });

  Widget _importCard(
      String label, IconData icon, String subtitle, String mode) {
    return Card(
        child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      leading: Icon(icon, color: _gold, size: 28),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        if (_busy || _sourceMutationBusy) {
          return;
        }
        _sourceMutationBusy = true;
        try {
          await _showAddPlaylistDialog(initialMode: mode);
        } finally {
          _sourceMutationBusy = false;
        }
      },
    ));
  }

  Widget _sidebar(List<StreamChannel> visible, bool tv, {bool mini = false}) =>
      Container(
        decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF31547D))),
        child: LayoutBuilder(
            builder: (context, sidebarBounds) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: Row(children: [
                            const Expanded(
                                child: Text('CHANNELS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.3))),
                            Text('${visible.length}',
                                style: const TextStyle(color: _gold)),
                          ])),
                      if (sidebarBounds.maxHeight >= 300)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: (sidebarBounds.maxHeight * .47)
                                .clamp(24.0, 240.0)
                                .toDouble(),
                          ),
                          child: SingleChildScrollView(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                child: Row(children: [
                                  Expanded(
                                      child: OutlinedButton.icon(
                                    onPressed: _savedPlaylists.isEmpty
                                        ? _addPlaylist
                                        : _browseSavedPlaylists,
                                    icon: const Icon(
                                        Icons.video_library_outlined,
                                        size: 17),
                                    label: Text(
                                        'Playlists (${_savedPlaylists.where((p) => !_hidden(p)).length})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11)),
                                  )),
                                  const SizedBox(width: 6),
                                  IconButton.outlined(
                                    tooltip: 'TV guide',
                                    onPressed: _showTvGuide,
                                    icon: const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 19),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton.outlined(
                                    tooltip: 'Recordings',
                                    onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) =>
                                            RecordingsDialog(onPlay: (channel) {
                                              if (_activePlaylistId == null ||
                                                  _savedPlaylists.any((p) =>
                                                      p.id ==
                                                          _activePlaylistId &&
                                                      _canOpen(p))) {
                                                _select(channel);
                                              }
                                            })),
                                    icon: const Icon(
                                        Icons.video_collection_outlined,
                                        size: 19),
                                  ),
                                ]),
                              ),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: TextField(
                                    focusNode: _searchFocus,
                                    controller: _search,
                                    onChanged: (text) {
                                      _searchDebounce?.cancel();
                                      _searchDebounce = Timer(
                                          const Duration(milliseconds: 140),
                                          () {
                                        if (mounted) {
                                          setState(() => _query =
                                              text.trim().toLowerCase());
                                        }
                                      });
                                    },
                                    decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.search),
                                        hintText: 'Search channels',
                                        isDense: true),
                                  )),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  child: Row(children: [
                                    Expanded(
                                        child: OutlinedButton.icon(
                                      onPressed: _channels.isEmpty
                                          ? null
                                          : _browseCategories,
                                      icon: const Icon(Icons.category_outlined,
                                          size: 18),
                                      label: Text(
                                          _group == ChannelCategories.all
                                              ? 'All categories (${_channels.length})'
                                              : '$_group (${ChannelCategories.counts(_channels)[_group] ?? 0})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                    if (_filter == ChannelFilter.recent &&
                                        _recentHashes.isNotEmpty)
                                      IconButton(
                                          tooltip: 'Clear recent history',
                                          onPressed: _clearRecent,
                                          icon: const Icon(
                                              Icons.delete_sweep_outlined)),
                                  ])),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 10, 5),
                                child: Row(children: [
                                  for (final option
                                      in <(ChannelFilter, String, IconData)>[
                                    (
                                      ChannelFilter.all,
                                      'All',
                                      Icons.grid_view_rounded
                                    ),
                                    (
                                      ChannelFilter.favorites,
                                      'Favorites',
                                      Icons.star_outline_rounded
                                    ),
                                    (
                                      ChannelFilter.recent,
                                      'Recent',
                                      Icons.history_rounded
                                    ),
                                  ])
                                    Expanded(
                                        child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: ChoiceChip(
                                        showCheckmark: false,
                                        avatar: Icon(option.$3,
                                            size: 15,
                                            color: _filter == option.$1
                                                ? const Color(0xFF17140B)
                                                : _gold),
                                        label: Text(option.$2,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                        selected: _filter == option.$1,
                                        onSelected: (_) =>
                                            setState(() => _filter = option.$1),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )),
                                ]),
                              ),
                            ],
                          )),
                        ),
                      if (sidebarBounds.maxHeight >= 300)
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(children: [
                              Expanded(
                                  child: Text(
                                      _hideUnavailable
                                          ? 'Hide confirmed unavailable • Others stay visible'
                                          : 'Show all channels',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70))),
                              Switch.adaptive(
                                key: const Key('hide_unavailable_channels'),
                                value: _hideUnavailable,
                                onChanged: (value) =>
                                    setState(() => _hideUnavailable = value),
                              ),
                              IconButton(
                                tooltip: 'Recheck channels in background',
                                icon: const Icon(Icons.sync_rounded, size: 20),
                                onPressed: () {
                                  _healthScanner.clear();
                                  _scanCursor = 0;
                                  _enqueueHealthBatch();
                                },
                              ),
                            ])),
                      Expanded(
                          child: visible.isEmpty
                              ? _channels.isEmpty
                                  ? ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 8, 10, 20),
                                      children: [
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: Text('Start watching',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 19)),
                                          ),
                                          _importCard(
                                              'Import M3U URL',
                                              Icons.link_rounded,
                                              'GitHub or provider playlist',
                                              'playlist'),
                                          _importCard(
                                              'Direct live stream',
                                              Icons.live_tv_rounded,
                                              'Paste a compatible stream',
                                              'direct'),
                                          _importCard(
                                              'Paste M3U text',
                                              Icons.paste_rounded,
                                              'Use a temporary channel list',
                                              'text'),
                                          if (_savedPlaylists.isNotEmpty)
                                            Card(
                                                child: ListTile(
                                              leading: const Icon(
                                                  Icons.video_library_rounded,
                                                  color: _gold),
                                              title: const Text(
                                                  'My saved playlists'),
                                              trailing: const Icon(
                                                  Icons.chevron_right_rounded),
                                              onTap: _browseSavedPlaylists,
                                            )),
                                        ])
                                  : const Center(
                                      child: Padding(
                                      padding: EdgeInsets.all(14),
                                      child: Text('No matching channels.',
                                          textAlign: TextAlign.center),
                                    ))
                              : ListView.builder(
                                  padding:
                                      EdgeInsets.only(bottom: mini ? 175 : 0),
                                  itemCount: visible.length,
                                  itemExtent: tv ? 88 : 76,
                                  itemBuilder: (context, index) {
                                    final channel = visible[index];
                                    final selected =
                                        channel.url == _selected?.url;
                                    final favorite = _favorites.contains(
                                        FavoriteStore.identifier(channel.url));
                                    return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        child: Material(
                                          color: selected
                                              ? _gold.withValues(alpha: .13)
                                              : const Color(0xFF102139),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Row(children: [
                                            Expanded(
                                                child: Focus(
                                              onKeyEvent: (node, event) {
                                                if (event is KeyDownEvent &&
                                                    (event.logicalKey ==
                                                            LogicalKeyboardKey
                                                                .select ||
                                                        event.logicalKey ==
                                                            LogicalKeyboardKey
                                                                .enter)) {
                                                  _select(channel);
                                                  return KeyEventResult.handled;
                                                }
                                                return KeyEventResult.ignored;
                                              },
                                              child: Builder(
                                                  builder: (focusContext) {
                                                final focused =
                                                    Focus.of(focusContext)
                                                        .hasFocus;
                                                return Container(
                                                    decoration: BoxDecoration(
                                                        border: Border.all(
                                                            color: focused
                                                                ? _gold
                                                                : Colors
                                                                    .transparent,
                                                            width: 2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14)),
                                                    child: ListTile(
                                                      contentPadding:
                                                          const EdgeInsets.only(
                                                              left: 14,
                                                              right: 3),
                                                      dense: false,
                                                      leading: Icon(
                                                          Icons.live_tv_rounded,
                                                          size: tv ? 27 : 23,
                                                          color: selected
                                                              ? _gold
                                                              : Colors.white60),
                                                      title: Text(channel.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              fontSize:
                                                                  tv ? 19 : 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700)),
                                                      subtitle: Text(
                                                          _currentProgram(
                                                                      channel)
                                                                  ?.title ??
                                                              channel.group,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12)),
                                                      onTap: () =>
                                                          _select(channel),
                                                    ));
                                              }),
                                            )),
                                            IconButton(
                                              tooltip: favorite
                                                  ? 'Remove favorite'
                                                  : 'Add favorite',
                                              onPressed: () =>
                                                  _toggleFavorite(channel),
                                              icon: Icon(
                                                  favorite
                                                      ? Icons.star_rounded
                                                      : Icons
                                                          .star_border_rounded,
                                                  size: 21,
                                                  color: favorite
                                                      ? _gold
                                                      : Colors.white54),
                                            ),
                                          ]),
                                        ));
                                  },
                                )),
                    ])),
      );
}

/// Shared mobile, Windows and Android TV-friendly searchable selection view.
/// No nested dropdown/menu that eagerly builds thousands of children.
class _SearchableChoiceDialog<T> extends StatefulWidget {
  const _SearchableChoiceDialog(
      {required this.title,
      required this.items,
      required this.label,
      required this.detail});
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) detail;

  @override
  State<_SearchableChoiceDialog<T>> createState() =>
      _SearchableChoiceDialogState<T>();
}

class _SearchableChoiceDialogState<T>
    extends State<_SearchableChoiceDialog<T>> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((item) => widget.label(item).toLowerCase().contains(_query))
        .toList(growable: false);
    return AlertDialog(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 460,
        height: 440,
        child: Column(children: [
          TextField(
              autofocus: false,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                  isDense: true)),
          const SizedBox(height: 8),
          Expanded(
              child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return ListTile(
                dense: true,
                title: Text(widget.label(item),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(widget.detail(item),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          )),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'))
      ],
    );
  }
}
