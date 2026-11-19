import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';

import '../core/channel.dart';
import '../core/direct_ts_recorder.dart';
import '../core/hls_ts_recorder.dart';
import '../core/hls_timeshift.dart';
import '../core/recording_storage_guard.dart';
import '../core/vod_resume_store.dart';
import '../core/subtitle_source.dart';
import 'remote_commands.dart';
import 'latest_channel_request.dart';
import 'android_media_session.dart';
import 'windows_media_session.dart';
import 'android_cast.dart';

/// Scoped controls: seek is disabled for non-seekable live streams; audio boost
/// requires explicit consent; channel navigation is owned by the parent list.
class PlayerView extends StatefulWidget {
  const PlayerView({
    super.key,
    required this.channel,
    this.onPrevious,
    this.onNext,
    this.initialVolume = 100,
    this.enableSystemMediaSession = true,
    this.compact = false,
    this.onExitFullscreen,
    this.onControlsInteraction,
    this.onPlaybackHealth,
  });

  final StreamChannel channel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final double initialVolume;
  final bool enableSystemMediaSession;

  /// Hide interactive video overlays while embedded in the floating mini-player.
  final bool compact;
  final VoidCallback? onExitFullscreen;
  final VoidCallback? onControlsInteraction;

  /// Called only by the real playback session, never by a URL preflight.
  final void Function(Uri url, bool playing)? onPlaybackHealth;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _video;
  StreamSubscription<String>? _errors;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<Track>? _trackSubscription;
  Timer? _retryTimer;
  Timer? _errorConfirmationTimer;
  Timer? _bufferingHintTimer;
  Timer? _startupWatchdog;
  Timer? _stallWatchdog;
  Timer? _healthConfirmationTimer;
  DateTime? _stallSince;
  int _healthReportedGeneration = -1;
  bool _recoveringFromStall = false;
  Timer? _overlayHideTimer;
  bool _overlayVisible = true;
  bool _phoneLandscape = false;
  bool _manualFullscreen = false;
  bool _showBufferingHint = false;
  int _generation = 0;
  int _attempts = 0;
  bool _loading = true;
  bool _opening = false;
  final LatestChannelRequest _channelRequests = LatestChannelRequest();
  late final AndroidMediaSession _mediaSession;
  late final WindowsMediaSession _windowsMediaSession;
  Timer? _mediaSync;
  bool _playing = false;
  bool _muted = false;
  bool _buffering = false;
  bool _volumeActionRunning = false;
  bool _boostApproved = false;
  bool _transportBusy = false;
  bool _orientationLocked = false;
  bool _pipEntering = false;
  bool _inPictureInPicture = false;
  static const MethodChannel _pipChannel =
      MethodChannel('sanseth_play/android_pip');
  bool _trackActionRunning = false;
  Tracks _availableTracks = const Tracks();
  Track _selectedTracks = const Track();
  double _volume = 100;
  final _resumeStore = VodResumeStore();
  bool _resumeChecked = false;
  bool _resumeBusy = false;
  int _lastSavedSecond = -1;
  Future<void> _resumeWrite = Future<void>.value();
  double _priorVolume = 100;
  double _speed = 1;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  BoxFit _fit = BoxFit.contain;
  static const _videoFits = <BoxFit>[
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
    BoxFit.none,
  ];
  static const _videoFitLabels = <String>[
    'Fit',
    'Crop',
    'Stretch',
    'Original',
  ];
  int get _videoFitIndex => _videoFits.indexOf(_fit);
  String get _videoFitLabel => _videoFitLabels[_videoFitIndex];

  // No player recreation or stream reload: only the Video widget's fit changes.
  void _cycleVideoFit() {
    if (!mounted) {
      return;
    }
    setState(() {
      _fit = _videoFits[(_videoFitIndex + 1) % _videoFits.length];
    });
  }

  final FocusNode _playerFocus = FocusNode(debugLabel: 'SanSethPlayerRemote');
  String? _error;
  DirectTsRecorder? _recorder;
  HlsTsRecorder? _hlsRecorder;
  bool _recording = false;
  HlsTimeshift? _timeshift;
  bool _timeshiftStarting = false;

  static const _retryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];

  // This controls only the on-video overlay. The underlying Player and
  // decoder are never recreated when the overlay appears or disappears.
  void _scheduleOverlayHide() {
    _overlayHideTimer?.cancel();
    if (widget.compact) {
      return;
    }
    _overlayHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !widget.compact && _overlayVisible) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _showOverlay() {
    widget.onControlsInteraction?.call();
    if (!mounted || widget.compact) {
      return;
    }
    if (!_overlayVisible) {
      setState(() => _overlayVisible = true);
    }
    _scheduleOverlayHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final phoneLandscape = Platform.isAndroid &&
        size.width > size.height &&
        size.shortestSide < 600;
    if (phoneLandscape != _phoneLandscape) {
      _phoneLandscape = phoneLandscape;
      _overlayVisible = true;
      _overlayHideTimer?.cancel();
    }
    // The home portrait player, Android TV, and Windows custom overlays use
    // the same inactivity timeout as the phone landscape player.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleOverlayHide();
      }
    });
  }

  Future<void> _toggleManualFullscreen() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      if (_phoneLandscape) {
        _manualFullscreen = false;
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        // When the phone is still physically sideways the parent can show
        // the standard layout, instead of forcing a conflicting orientation.
        widget.onExitFullscreen?.call();
      } else {
        _manualFullscreen = true;
        await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        );
      }
      _showOverlay();
    } catch (_) {
      if (mounted) {
        _notice('Fullscreen orientation unavailable.');
      }
    }
  }

  bool get _canSeek => _duration.inMilliseconds > 0;
  bool get _canRotate => Platform.isAndroid;

  void _confirmPlaybackWhenStable() {
    _healthConfirmationTimer?.cancel();
    if (!_playing ||
        _buffering ||
        _loading ||
        _healthReportedGeneration == _generation) {
      return;
    }
    final generation = _generation;
    _healthConfirmationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted ||
          generation != _generation ||
          !_playing ||
          _buffering ||
          _loading ||
          _healthReportedGeneration == generation) {
        return;
      }
      _healthReportedGeneration = generation;
      _attempts = 0;
      widget.onPlaybackHealth?.call(widget.channel.url, true);
    });
  }

  void _armLiveStallWatchdog() {
    if (widget.channel.isVod ||
        !_playing ||
        !_buffering ||
        _stallSince != null) {
      return;
    }
    final generation = _generation;
    _stallSince = DateTime.now();
    _stallWatchdog?.cancel();
    _stallWatchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted ||
          generation != _generation ||
          !_buffering ||
          !_playing ||
          _recoveringFromStall ||
          _channelRequests.hasPending ||
          _recording) {
        return;
      }
      // Do not reload during a short segment transition or ongoing capture.
      _recoveringFromStall = true;
      _attempts = 0;
      unawaited(_open());
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mediaSession = AndroidMediaSession(_onNativeMediaCommand);
    _windowsMediaSession = WindowsMediaSession(_onNativeMediaCommand);
    if (widget.enableSystemMediaSession) {
      _mediaSession.attach();
      unawaited(_windowsMediaSession.attach());
    }
    // Moderate demuxer memory; do not increase startup latency with a huge cache.
    _player = Player(
        configuration: const PlayerConfiguration(bufferSize: 12 * 1024 * 1024));
    _volume = widget.initialVolume.clamp(0.0, 100.0);
    _muted = _volume == 0;
    if (_volume != 100) {
      unawaited(_player.setVolume(_volume));
    }
    _video = VideoController(_player);
    // Native decoders can emit recoverable errors while frames are still
    // playing. Never replace valid video with a reconnect dialog on the first
    // error callback. Confirm playback really stopped before retrying.
    _errors = _player.stream.error.listen((_) {
      if (!mounted || _playing) {
        return;
      }
      _errorConfirmationTimer?.cancel();
      final generation = _generation;
      _errorConfirmationTimer = Timer(const Duration(seconds: 3), () {
        if (mounted &&
            generation == _generation &&
            !_playing &&
            !_channelRequests.hasPending) {
          _scheduleRetry();
        }
      });
    });
    _playingSubscription = _player.stream.playing.listen((value) {
      if (!mounted) {
        return;
      }
      if (value) {
        _retryTimer?.cancel();
        _errorConfirmationTimer?.cancel();
        _startupWatchdog?.cancel();
      }
      setState(() {
        _playing = value;
        if (value) {
          _loading = false;
          _error = null;
        }
      });
      if (value) {
        _armLiveStallWatchdog();
        _confirmPlaybackWhenStable();
      } else {
        _healthConfirmationTimer?.cancel();
      }
      _scheduleMediaSync();
    });
    _durationSubscription = _player.stream.duration.listen((value) {
      if (mounted) {
        setState(() => _duration = value);
        unawaited(_restoreVodPosition(value));
        _scheduleMediaSync();
      }
    });
    _positionSubscription = _player.stream.position.listen((value) {
      if (mounted && (_position.inSeconds != value.inSeconds)) {
        if (value.inSeconds % 5 == 0) {
          _scheduleMediaSync();
        }
        setState(() => _position = value);
        if (widget.channel.isVod &&
            _resumeChecked &&
            _duration >= const Duration(minutes: 5) &&
            value.inSeconds ~/ 15 != _lastSavedSecond) {
          _lastSavedSecond = value.inSeconds ~/ 15;
          _resumeWrite = _resumeWrite
              .catchError((Object _) {})
              .then((_) => _saveVodPosition());
          unawaited(_resumeWrite.catchError((Object _) {}));
        }
      }
    });
    _bufferingSubscription = _player.stream.buffering.listen((value) {
      if (!mounted) {
        return;
      }
      _bufferingHintTimer?.cancel();
      if (!value) {
        _stallWatchdog?.cancel();
        _stallSince = null;
        _recoveringFromStall = false;
        _confirmPlaybackWhenStable();
        if (_buffering || _showBufferingHint) {
          setState(() {
            _buffering = false;
            _showBufferingHint = false;
          });
        }
      } else {
        _buffering = true;
        _healthConfirmationTimer?.cancel();
        _armLiveStallWatchdog();
        // Short decoder/network stalls are common on live HLS. Do not flash
        // a buffering banner for every segment transition.
        _bufferingHintTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _buffering && !_loading && _error == null) {
            setState(() => _showBufferingHint = true);
          }
        });
      }
    });
    _tracksSubscription = _player.stream.tracks.listen((value) {
      if (mounted) {
        setState(() => _availableTracks = value);
      }
    });
    _trackSubscription = _player.stream.track.listen((value) {
      if (mounted) {
        setState(() => _selectedTracks = value);
      }
    });
    _open();
  }

  Future<void> _restoreVodPosition(Duration duration) async {
    if (!widget.channel.isVod ||
        _resumeChecked ||
        _resumeBusy ||
        duration < const Duration(minutes: 5)) {
      return;
    }
    _resumeBusy = true;
    final currentGeneration = _generation;
    final url = widget.channel.url;
    try {
      final saved = await _resumeStore.read(url, duration);
      if (!mounted ||
          currentGeneration != _generation ||
          widget.channel.url != url) {
        return;
      }
      _resumeChecked = true;
      if (saved != null) {
        await _player.seek(saved);
        if (mounted) {
          _notice('Continuing from saved position');
        }
      }
    } catch (_) {
      _resumeChecked = true;
      // Resume is optional and must never stop playback.
    } finally {
      _resumeBusy = false;
    }
  }

  Future<void> _saveVodPosition() async {
    if (!widget.channel.isVod || _duration < const Duration(minutes: 5)) {
      return;
    }
    try {
      await _resumeStore.write(widget.channel.url, _position, _duration);
    } catch (_) {
      // Disk full / preferences failure must not affect playback.
    }
  }

  // Latest-request-wins: while the decoder opens a stream, retain the newest
  // channel URL and open it after the current async operation completes.
  // Never drop a channel selection simply because a prior open is in-flight.
  bool _liveCacheConfigured = false;

  Future<void> _tuneLiveStartup() async {
    if (_liveCacheConfigured || widget.channel.isVod) return;
    _liveCacheConfigured = true;
    // Native libmpv options are best-effort: media-kit backend may differ.
    // Avoid cache-pause-initial so the first frame needn't wait for a large
    // prefetch; retain a short rebuffer safety window for unstable networks.
    final backend = _player.platform;
    if (backend is NativePlayer) {
      for (final entry in <(String, String)>[
        ('cache-pause-initial', 'no'),
        ('cache-pause-wait', '0.6'),
        ('cache-secs', '4'),
      ]) {
        try {
          await backend.setProperty(entry.$1, entry.$2);
        } catch (_) {
          // Older libmpv versions can reject an option. Default remains safe.
        }
      }
    }
  }

  Future<void> _open() async {
    _channelRequests.request(widget.channel.url.toString());
    if (_opening) {
      return;
    }
    _opening = true;
    try {
      while (mounted && _channelRequests.hasPending) {
        final url = _channelRequests.take()!;
        _retryTimer?.cancel();
        _errorConfirmationTimer?.cancel();
        _bufferingHintTimer?.cancel();
        _startupWatchdog?.cancel();
        _stallWatchdog?.cancel();
        _healthConfirmationTimer?.cancel();
        _stallSince = null;
        final generation = ++_generation;
        _resumeChecked = false;
        _lastSavedSecond = -1;
        setState(() {
          // During an automatic stall recovery retain the last video frame
          // and avoid flashing a fullscreen loader or reconnect banner.
          _loading = !_recoveringFromStall;
          _playing = false;
          _error = null;
          _showBufferingHint = false;
          _buffering = false;
          _duration = Duration.zero;
          _position = Duration.zero;
        });
        try {
          await _tuneLiveStartup();
          if (!mounted || generation != _generation) return;
          await _player.open(Media(url));
          _scheduleMediaSync();
          // Some IPTV URLs never emit a decoder error even when no frames
          // arrive. Bound initial waiting, but do not disrupt live playback.
          _startupWatchdog?.cancel();
          _startupWatchdog = Timer(const Duration(seconds: 12), () {
            if (mounted &&
                generation == _generation &&
                !_playing &&
                !_channelRequests.hasPending) {
              _scheduleRetry();
            }
          });
          // A newer channel may have arrived while opening. Never display
          // success or an error for an obsolete request.
          if (!mounted) {
            return;
          }
          if (!_channelRequests.hasPending && generation == _generation) {
            // open() signals that a media request was accepted, not that the
            // first video frame has decoded. Preserve the loading indicator
            // until playback is confirmed or buffering is reported.
            if (_playing) {
              setState(() {
                _loading = false;
                _error = null;
              });
            }
          }
        } catch (_) {
          if (!mounted) {
            return;
          }
          if (!_channelRequests.hasPending && generation == _generation) {
            _scheduleRetry();
          }
        }
      }
    } finally {
      _opening = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Switching to another application is NOT an explicit Stop or Exit.
    // Keep media_kit playback alive; on Android, actual video visibility while
    // backgrounded depends on PiP / OS restrictions and device policy.
    if (state == AppLifecycleState.resumed && _inPictureInPicture) {
      _inPictureInPicture = false;
    }
  }

  void _scheduleRetry() {
    if (!mounted ||
        _playing ||
        _channelRequests.hasPending ||
        _retryTimer?.isActive == true) {
      return;
    }
    if (_attempts >= _retryDelays.length) {
      widget.onPlaybackHealth?.call(widget.channel.url, false);
      setState(() {
        _loading = false;
        _error = 'Stream unavailable. Link, network ya codec check karein.';
      });
      return;
    }
    final delay = _retryDelays[_attempts++];
    if (!_recoveringFromStall) {
      setState(() {
        _loading = false;
        _error =
            'Stream reconnect ho raha hai ($_attempts/${_retryDelays.length})';
      });
    }
    _retryTimer = Timer(delay, () {
      if (mounted) {
        _open();
      }
    });
  }

  void _onNativeMediaCommand(String command, Object? arguments) {
    if (!mounted) {
      return;
    }
    switch (command) {
      case 'play':
        unawaited(_transport(_player.play));
      case 'pause':
        unawaited(_transport(_player.pause));
      case 'stop':
        unawaited(_transport(_player.pause));
      case 'next':
        widget.onNext?.call();
      case 'previous':
        widget.onPrevious?.call();
      case 'seekTo':
        if (_canSeek && arguments is num) {
          final ms = arguments.toInt().clamp(0, _duration.inMilliseconds);
          unawaited(_transport(() => _player.seek(Duration(milliseconds: ms))));
        }
    }
  }

  void _scheduleMediaSync() {
    if (!mounted || !widget.enableSystemMediaSession) {
      return;
    }
    _mediaSync?.cancel();
    _mediaSync = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      _windowsMediaSession.update(
          title: widget.channel.name, playing: _playing);
      unawaited(_mediaSession.update(
        title: widget.channel.name,
        playing: _playing,
        live: !widget.channel.isVod,
        duration: _duration,
        position: _position,
      ));
    });
  }

  void _manualRetry() {
    _attempts = 0;
    _errorConfirmationTimer?.cancel();
    _startupWatchdog?.cancel();
    _retryTimer?.cancel();
    unawaited(_open());
  }

  Future<void> _seekBy(int seconds) async {
    if (!_canSeek) {
      return;
    }
    final target = (_position.inMilliseconds + seconds * 1000)
        .clamp(0, _duration.inMilliseconds);
    await _player.seek(Duration(milliseconds: target));
  }

  Future<void> _setVolume(double target) async {
    // Serialize volume operations: slider/remote repeat cannot open competing
    // safety dialogs or let an older setVolume finish after a newer one.
    if (_volumeActionRunning) {
      return;
    }
    _volumeActionRunning = true;
    try {
      final next = target.clamp(0.0, 200.0);
      if (next > 100 && !_boostApproved) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('High volume warning'),
            content: const Text(
                '100% se upar software boost se hearing damage aur audio '
                'distortion ka risk badh sakta hai. Kam volume safe rakhein. '
                'Continue?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Enable boost')),
            ],
          ),
        );
        if (!mounted || accepted != true) {
          return;
        }
        _boostApproved = true; // In-memory only; resets when player recreated.
      }
      await _player.setVolume(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _volume = next;
        _muted = next == 0;
      });
    } catch (_) {
      if (mounted) {
        _notice('Audio level is not supported by this device.');
      }
    } finally {
      _volumeActionRunning = false;
    }
  }

  Future<void> _transport(Future<void> Function() operation) async {
    if (_transportBusy) {
      return;
    }
    _transportBusy = true;
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        _notice('Playback command failed.');
      }
    } finally {
      _transportBusy = false;
    }
  }

  KeyEventResult _onRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Windows keyboard / Android TV keyboard: A cycles aspect modes live.
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyA) {
      _cycleVideoFit();
      return KeyEventResult.handled;
    }
    final command = playerRemoteCommandFor(event.logicalKey);
    if (command == null) {
      return KeyEventResult.ignored;
    }
    // A non-DVR live feed must leave arrow navigation to Flutter focus / TV UI.
    if (!_canSeek &&
        (command == PlayerRemoteCommand.seekForward ||
            command == PlayerRemoteCommand.seekBackward)) {
      return KeyEventResult.ignored;
    }
    switch (command) {
      case PlayerRemoteCommand.playPause:
        _transport(_player.playOrPause);
      case PlayerRemoteCommand.next:
        widget.onNext?.call();
      case PlayerRemoteCommand.previous:
        widget.onPrevious?.call();
      case PlayerRemoteCommand.seekForward:
        if (_canSeek) {
          _transport(() => _seekBy(10));
        }
      case PlayerRemoteCommand.seekBackward:
        if (_canSeek) {
          _transport(() => _seekBy(-10));
        }
      case PlayerRemoteCommand.mute:
        _toggleMute();
      case PlayerRemoteCommand.volumeUp:
        _setVolume(_volume + 10);
      case PlayerRemoteCommand.volumeDown:
        _setVolume(_volume - 10);
    }
    return KeyEventResult.handled;
  }

  Future<void> _toggleMute() async {
    if (_muted) {
      await _setVolume(_priorVolume <= 0 ? 50 : _priorVolume);
    } else {
      _priorVolume = _volume;
      await _setVolume(0);
    }
  }

  Future<void> _setOrientationLock() async {
    if (!_canRotate) {
      return;
    }
    try {
      if (_orientationLocked) {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      } else {
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        await SystemChrome.setPreferredOrientations(isPortrait
            ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
            : [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight
              ]);
      }
      if (mounted) {
        setState(() => _orientationLocked = !_orientationLocked);
      }
    } catch (_) {
      if (mounted) {
        _notice('Orientation lock unavailable.');
      }
    }
  }

  Future<void> _enterPictureInPicture() async {
    if (!Platform.isAndroid || _pipEntering) {
      return;
    }
    _pipEntering = true;
    try {
      final supported =
          await _pipChannel.invokeMethod<bool>('isSupported') ?? false;
      if (!mounted) {
        return;
      }
      if (!supported) {
        _notice('Picture-in-Picture is not supported on this device.');
        return;
      }
      // PiP is initiated by an explicit user action; never enter on background.
      _inPictureInPicture = true; // Set before native transition events.
      final entered = await _pipChannel.invokeMethod<bool>('enter') ?? false;
      if (!entered) {
        _inPictureInPicture = false;
      }
      if (mounted && !entered) {
        _notice('Picture-in-Picture could not start.');
      }
    } on PlatformException {
      _inPictureInPicture = false;
      if (mounted) {
        _notice('Picture-in-Picture is unavailable.');
      }
    } on MissingPluginException {
      _inPictureInPicture = false;
      if (mounted) {
        _notice('PiP requires the prepared native Android runner.');
      }
    } finally {
      _pipEntering = false;
    }
  }

  Future<void> _castCurrent() async {
    const cast = AndroidCast();
    if (!AndroidCast.isPublicCastUri(widget.channel.url)) {
      _notice(
          'Cast requires a public HTTPS stream without embedded credentials.');
      return;
    }
    if (!await cast.available()) {
      _notice('Google Cast is unavailable on this device.');
      return;
    }
    if (!await cast.connected()) {
      await cast.showPicker();
      if (mounted) {
        _notice('Select a Cast device, then tap Cast again to play.');
      }
      return;
    }
    final submitted = await cast.load(widget.channel.url, widget.channel.name);
    if (mounted) {
      _notice(submitted
          ? 'Cast request sent. Playback depends on receiver compatibility.'
          : 'Cast request unavailable. Check receiver and stream format.');
    }
  }

  Future<void> _toggleTimeshift() async {
    if (_timeshiftStarting) {
      return;
    }
    final existing = _timeshift;
    if (existing != null) {
      _timeshift = null;
      // Return to the original channel BEFORE deleting its local HLS files.
      try {
        await _player.open(Media(widget.channel.url.toString()));
      } finally {
        await existing.stop();
        if (mounted) {
          setState(() {});
        }
      }
      return;
    }
    if (!HlsTimeshift.supports(widget.channel.url)) {
      _notice('Timeshift requires compatible unencrypted HLS MPEG-TS.');
      return;
    }
    if (!await const RecordingStorageGuard().canStart()) {
      if (mounted) {
        _notice('Not enough free storage for timeshift.');
      }
      return;
    }
    final generation = _generation;
    _timeshiftStarting = true;
    if (mounted) {
      setState(() {});
    }
    final session = HlsTimeshift();
    try {
      final local = await session.start(widget.channel.url);
      if (!mounted || generation != _generation) {
        await session.stop();
        return;
      }
      _timeshift = session;
      await _player.open(Media(local.toString()));
      if (mounted) {
        _notice('Timeshift active. Pause or seek within cached window.');
      }
    } catch (_) {
      if (identical(_timeshift, session)) {
        _timeshift = null;
      }
      await session.stop();
      if (mounted && generation == _generation) {
        try {
          await _player.open(Media(widget.channel.url.toString()));
        } catch (_) {}
        _notice('Timeshift unavailable for this stream.');
      }
    } finally {
      _timeshiftStarting = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _recorder?.stop();
      _hlsRecorder?.stop();
      return;
    }
    final url = widget.channel.url;
    final recordingGeneration = _generation;
    if (!DirectTsRecorder.supports(url) && !HlsTsRecorder.supports(url)) {
      _notice(
          'Recording supports direct TS or compatible TS-segment HLS only.');
      return;
    }
    if (!await const RecordingStorageGuard().canStart()) {
      if (mounted) {
        _notice('Storage low: free at least 256 MB to record.');
      }
      return;
    }
    if (!mounted || recordingGeneration != _generation) {
      return;
    }
    final ts = DirectTsRecorder.supports(url) ? DirectTsRecorder() : null;
    final hls = HlsTsRecorder.supports(url) ? HlsTsRecorder() : null;
    _recorder = ts;
    _hlsRecorder = hls;
    setState(() => _recording = true);
    try {
      final output = ts != null ? await ts.start(url) : await hls!.start(url);
      if (mounted && recordingGeneration == _generation && output != null) {
        _notice('Recording saved in app documents.');
        if (Platform.isAndroid || Platform.isWindows) {
          final shouldShare = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Recording saved'),
              content: Text('Share or export ${output.uri.pathSegments.last}?',
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep in app')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Share / Export')),
              ],
            ),
          );
          if (shouldShare == true && mounted) {
            try {
              await SharePlus.instance.share(ShareParams(
                files: [XFile(output.path, mimeType: 'video/mp2t')],
                subject: 'SanSeth Play recording',
              ));
            } catch (_) {
              if (mounted) {
                _notice('Sharing not available on this device.');
              }
            }
          }
        }
      } else if (mounted && recordingGeneration == _generation) {
        _notice('No recording data received.');
      }
    } catch (_) {
      if (mounted) {
        _notice('Recording unavailable. Check source format or storage.');
      }
    } finally {
      if (identical(_recorder, ts)) {
        _recorder = null;
      }
      if (identical(_hlsRecorder, hls)) {
        _hlsRecorder = null;
      }
      if (mounted) {
        setState(() => _recording = false);
      }
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
          content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis)),
    );
  }

  // Only user-provided HTTP(S) subtitles are accepted here; local device file
  // access needs a separate platform file-picker permission flow.

  String _trackLabel(String id, String? title, String? language) {
    if (id == 'auto') {
      return 'Automatic';
    }
    if (id == 'no') {
      return 'Disabled';
    }
    final names = <String>[
      if (title != null && title.trim().isNotEmpty) title.trim(),
      if (language != null && language.trim().isNotEmpty) language.trim(),
    ];
    return names.isEmpty ? 'Track $id' : names.join(' • ');
  }

  Future<void> _chooseAudio() async {
    final tracks = _availableTracks.audio;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          SimpleDialog(title: const Text('Audio language'), children: [
        for (final track in tracks)
          SimpleDialogOption(
            onPressed: _trackActionRunning
                ? null
                : () async {
                    Navigator.pop(dialogContext);
                    if (_trackActionRunning) {
                      return;
                    }
                    _trackActionRunning = true;
                    try {
                      await _player.setAudioTrack(track);
                    } catch (_) {
                      if (mounted) {
                        _notice('Audio track unavailable.');
                      }
                    } finally {
                      _trackActionRunning = false;
                    }
                  },
            child: Row(children: [
              Icon(
                  _selectedTracks.audio.id == track.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      _trackLabel(track.id, track.title, track.language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ]),
    );
  }

  Future<void> _chooseSubtitles() async {
    final tracks = _availableTracks.subtitle;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          SimpleDialog(title: const Text('Subtitles'), children: [
        for (final track in tracks)
          SimpleDialogOption(
            onPressed: _trackActionRunning
                ? null
                : () async {
                    Navigator.pop(dialogContext);
                    if (_trackActionRunning) {
                      return;
                    }
                    _trackActionRunning = true;
                    try {
                      await _player.setSubtitleTrack(track);
                    } catch (_) {
                      if (mounted) {
                        _notice('Subtitle track unavailable.');
                      }
                    } finally {
                      _trackActionRunning = false;
                    }
                  },
            child: Row(children: [
              Icon(
                  _selectedTracks.subtitle.id == track.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      _trackLabel(track.id, track.title, track.language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ]),
    );
  }

  Future<void> _externalSubtitle() async {
    final field = TextEditingController();
    try {
      final url = await showDialog<Uri>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('External subtitle URL'),
                content: SizedBox(
                    width: 420,
                    child: TextField(
                      controller: field,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'HTTPS SRT / WebVTT URL',
                        hintText: 'https://example.org/subtitles.vtt',
                      ),
                    )),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final uri = parseExternalSubtitleUrl(field.text);
                        if (uri == null) {
                          ScaffoldMessenger.maybeOf(dialogContext)
                              ?.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Enter a valid HTTP(S) subtitle URL.')));
                          return;
                        }
                        Navigator.pop(dialogContext, uri);
                      },
                      child: const Text('Load')),
                ],
              ));
      if (!mounted || url == null || _trackActionRunning) {
        return;
      }
      _trackActionRunning = true;
      try {
        await _player.setSubtitleTrack(
            SubtitleTrack.uri(url.toString(), title: 'External subtitles'));
      } catch (_) {
        if (mounted) {
          _notice('Subtitle load failed. Check format and URL.');
        }
      } finally {
        _trackActionRunning = false;
      }
    } finally {
      field.dispose();
    }
  }

  // Recording is intentionally limited to supported MPEG-TS sources. Android
  // microphone capture / MediaProjection audio mixing and transcoding are NOT
  // provided by the transport-stream recorder, so never silently claim them.
  Future<void> _showRecordingOptions() async {
    if (_recording) {
      await _toggleRecording();
      return;
    }
    final supported = DirectTsRecorder.supports(widget.channel.url) ||
        HlsTsRecorder.supports(widget.channel.url);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.fiber_manual_record_rounded,
                    color: Color(0xFFF4C65B)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Record Stream',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: 'Close recording options',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 7),
              const Text('Record the currently playing live TV stream.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              const Text('AUDIO SOURCE',
                  style: TextStyle(
                      color: Color(0xFFF4C65B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 9),
              const Card(
                  child: ListTile(
                leading:
                    Icon(Icons.volume_up_rounded, color: Color(0xFFF4C65B)),
                title: Text('System / channel audio'),
                subtitle: Text(
                    'Original video and channel sound, if provided by source'),
                trailing:
                    Icon(Icons.check_circle_rounded, color: Color(0xFFF4C65B)),
              )),
              const Card(
                  child: ListTile(
                enabled: false,
                leading: Icon(Icons.mic_none_rounded),
                title: Text('Mic / outer voice'),
                subtitle: Text(
                    'Requires microphone capture and a separate encoder; not yet supported'),
              )),
              const Card(
                  child: ListTile(
                enabled: false,
                leading: Icon(Icons.mic_rounded),
                title: Text('System + Mic'),
                subtitle: Text('Audio mixing is not available in this build'),
              )),
              const SizedBox(height: 14),
              const Text('RECORDING OPTIONS',
                  style: TextStyle(
                      color: Color(0xFFF4C65B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Card(
                  child: ListTile(
                leading:
                    Icon(Icons.high_quality_rounded, color: Color(0xFFF4C65B)),
                title: Text('Video quality'),
                subtitle: Text('Original stream quality (no re-encoding)'),
              )),
              const Card(
                  child: ListTile(
                leading: Icon(Icons.movie_creation_outlined,
                    color: Color(0xFFF4C65B)),
                title: Text('Output format'),
                subtitle: Text('MPEG transport stream (.ts)'),
              )),
              const Card(
                  child: ListTile(
                leading:
                    Icon(Icons.folder_open_rounded, color: Color(0xFFF4C65B)),
                title: Text('Save location'),
                subtitle:
                    Text('SanSeth Play app documents; export after recording'),
              )),
              const SizedBox(height: 10),
              Text(
                  supported
                      ? 'The current channel keeps playing while the source is recorded.'
                      : 'This source does not support direct TS / compatible HLS recording.',
                  style: TextStyle(
                      color: supported
                          ? const Color(0xFFF4C65B)
                          : Colors.orangeAccent)),
              const SizedBox(height: 17),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: supported
                            ? () {
                                Navigator.pop(sheetContext);
                                unawaited(_toggleRecording());
                              }
                            : null,
                        icon: const Icon(Icons.fiber_manual_record_rounded),
                        label: const Text('Start recording',
                            maxLines: 1, overflow: TextOverflow.ellipsis))),
              ]),
            ],
          )),
        ),
      ),
    );
  }

  Future<void> _settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: StatefulBuilder(
        builder: (ctx, update) {
          Widget action(String label, IconData icon, VoidCallback? onTap) =>
              SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    icon: Icon(icon, size: 22, color: const Color(0xFFF4C65B)),
                    label: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFC9A25C)),
                        shape: const StadiumBorder()),
                  ));
          Widget paired(Widget first, Widget second) => Row(children: [
                Expanded(child: first),
                const SizedBox(width: 10),
                Expanded(child: second),
              ]);
          Widget section(String title, IconData icon) => Padding(
                padding: const EdgeInsets.only(top: 19, bottom: 10),
                child: Row(children: [
                  Icon(icon, color: const Color(0xFFF4C65B), size: 21),
                  const SizedBox(width: 9),
                  Flexible(
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17))),
                  const SizedBox(width: 12),
                  const Expanded(child: Divider()),
                ]),
              );
          Future<void> apply(Future<void> Function() operation) async {
            await operation();
            if (ctx.mounted) {
              update(() {});
            }
          }

          return ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.play_circle_outline_rounded,
                          size: 27, color: Color(0xFFF4C65B)),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('Player Controls',
                              style: TextStyle(
                                  fontSize: 23, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx)),
                    ]),
                    section('Quick controls', Icons.bolt_rounded),
                    paired(
                        action('Previous', Icons.skip_previous_rounded,
                            widget.onPrevious),
                        action(
                            _playing ? 'Pause' : 'Play',
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            () => apply(_player.playOrPause))),
                    const SizedBox(height: 9),
                    paired(
                        action('Next', Icons.skip_next_rounded, widget.onNext),
                        action('Replay stream', Icons.replay_rounded,
                            () => apply(_open))),
                    section('Live tools', Icons.settings_input_antenna_rounded),
                    paired(
                        action(
                            _recording ? 'Stop recording' : 'Record stream',
                            _recording
                                ? Icons.stop_circle_outlined
                                : Icons.fiber_manual_record_rounded, () {
                          unawaited(_showRecordingOptions());
                        }),
                        action(
                            _timeshift != null
                                ? 'Go Live'
                                : (_timeshiftStarting
                                    ? 'Starting DVR...'
                                    : 'Start Timeshift'),
                            Icons.history_toggle_off_rounded,
                            widget.enableSystemMediaSession &&
                                    HlsTimeshift.supports(widget.channel.url) &&
                                    !_timeshiftStarting
                                ? () => apply(_toggleTimeshift)
                                : null)),
                    const SizedBox(height: 9),
                    paired(
                        action(
                            'Cast to TV',
                            Icons.cast_rounded,
                            Platform.isAndroid &&
                                    AndroidCast.isPublicCastUri(
                                        widget.channel.url)
                                ? _castCurrent
                                : null),
                        action(
                            'Picture-in-Picture',
                            Icons.picture_in_picture_alt_rounded,
                            Platform.isAndroid
                                ? _enterPictureInPicture
                                : null)),
                    section('Video size / aspect', Icons.aspect_ratio_rounded),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      for (final entry in <(String, BoxFit)>[
                        ('Fit', BoxFit.contain),
                        ('Crop', BoxFit.cover),
                        ('Stretch', BoxFit.fill),
                        ('Original', BoxFit.none),
                      ])
                        ChoiceChip(
                          label: Text(entry.$1),
                          selected: _fit == entry.$2,
                          onSelected: (_) {
                            setState(() => _fit = entry.$2);
                            update(() {});
                          },
                        ),
                    ]),
                    section(
                        'Languages and captions', Icons.closed_caption_rounded),
                    paired(
                        action('Audio tracks', Icons.audiotrack_rounded,
                            _chooseAudio),
                        action('Subtitle tracks', Icons.subtitles_rounded,
                            _chooseSubtitles)),
                    const SizedBox(height: 9),
                    action('External SRT/VTT URL',
                        Icons.closed_caption_outlined, _externalSubtitle),
                    section('Playback', Icons.play_circle_outline_rounded),
                    Row(children: [
                      IconButton(
                          tooltip: _muted ? 'Unmute' : 'Mute',
                          onPressed: () => apply(_toggleMute),
                          icon: Icon(_muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded)),
                      Text('${_volume.toStringAsFixed(0)}%'),
                      IconButton(
                          tooltip: 'Volume down',
                          onPressed: () =>
                              apply(() => _setVolume(_volume - 10)),
                          icon: const Icon(Icons.remove_circle_outline)),
                      Expanded(
                          child: Slider(
                              value: _volume.clamp(0.0, 200.0),
                              max: 200,
                              divisions: 20,
                              onChanged: (value) =>
                                  apply(() => _setVolume(value)))),
                      IconButton(
                          tooltip: 'Volume up',
                          onPressed: () =>
                              apply(() => _setVolume(_volume + 10)),
                          icon: const Icon(Icons.add_circle_outline)),
                    ]),
                    if (_volume > 100)
                      const Text(
                          'High boost: possible distortion and hearing risk.',
                          style: TextStyle(
                              color: Colors.orangeAccent, fontSize: 12)),
                    const SizedBox(height: 9),
                    Row(children: [
                      const Text('Playback speed'),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DropdownButton<double>(
                        isExpanded: true,
                        value: _speed,
                        items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                            .map((rate) => DropdownMenuItem(
                                value: rate, child: Text('${rate}x')))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            apply(() async {
                              await _player.setRate(value);
                              if (mounted) {
                                setState(() => _speed = value);
                              }
                            });
                          }
                        },
                      )),
                    ]),
                    const SizedBox(height: 9),
                    action(
                        'Rotate lock ${_orientationLocked ? 'ON' : 'OFF'}',
                        _orientationLocked
                            ? Icons.screen_lock_rotation
                            : Icons.screen_rotation,
                        _canRotate ? () => apply(_setOrientationLock) : null),
                    if (_canSeek) ...[
                      const SizedBox(height: 9),
                      paired(
                          action('-10 sec', Icons.replay_10_rounded,
                              () => apply(() => _seekBy(-10))),
                          action('+10 sec', Icons.forward_10_rounded,
                              () => apply(() => _seekBy(10)))),
                    ] else
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'Live stream: seeking requires DVR support.',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12))),
                    const SizedBox(height: 13),
                    const Text(
                        'Fullscreen: use the video fullscreen button, or F on desktop.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
            ),
          );
        },
      )),
    );
  }

  @override
  void didUpdateWidget(covariant PlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact != oldWidget.compact) {
      _overlayHideTimer?.cancel();
      if (!widget.compact) {
        _overlayVisible = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scheduleOverlayHide();
          }
        });
      }
    }
    if (widget.channel.url != oldWidget.channel.url) {
      _recorder?.stop();
      _hlsRecorder?.stop();
      final oldTimeshift = _timeshift;
      _timeshift = null;
      if (oldTimeshift != null) {
        unawaited(oldTimeshift.stop());
      }
      _retryTimer?.cancel();
      _errorConfirmationTimer?.cancel();
      _bufferingHintTimer?.cancel();
      _startupWatchdog?.cancel();
      _stallWatchdog?.cancel();
      _healthConfirmationTimer?.cancel();
      _stallSince = null;
      _healthReportedGeneration = -1;
      _recoveringFromStall = false;
      _attempts = 0;
      unawaited(_open());
      _scheduleMediaSync();
    }
  }

  @override
  void dispose() {
    _recorder?.stop();
    _hlsRecorder?.stop();
    final oldTimeshift = _timeshift;
    _timeshift = null;
    if (oldTimeshift != null) {
      unawaited(oldTimeshift.stop());
    }
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _channelRequests.clear();
    _retryTimer?.cancel();
    _errorConfirmationTimer?.cancel();
    _bufferingHintTimer?.cancel();
    _startupWatchdog?.cancel();
    _stallWatchdog?.cancel();
    _healthConfirmationTimer?.cancel();
    _overlayHideTimer?.cancel();
    _mediaSync?.cancel();
    unawaited(_mediaSession.dispose());
    unawaited(_windowsMediaSession.dispose());
    _errors?.cancel();
    _playingSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _tracksSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _playerFocus.dispose();
    _trackSubscription?.cancel();
    if (_orientationLocked || _manualFullscreen) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _resumeWrite =
        _resumeWrite.catchError((Object _) {}).then((_) => _saveVodPosition());
    unawaited(_resumeWrite.catchError((Object _) {}));
    _player.dispose();
    super.dispose();
  }

  // Unified non-overlapping controls. Native media controls were removed
  // from the Android surface because they competed with SanSeth overlays for
  // the same fullscreen and aspect button hit targets.
  Widget _overlayButton(String tooltip, IconData icon, VoidCallback? action,
          {double size = 24}) =>
      IconButton(
        tooltip: tooltip,
        onPressed: action == null
            ? null
            : () {
                _showOverlay();
                action();
              },
        icon: Icon(icon, size: size),
        color: Colors.white,
        disabledColor: Colors.white38,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _playerFocus,
        // TV needs a D-pad target; phones must not steal keyboard focus.
        autofocus: Platform.isAndroid &&
            MediaQuery.sizeOf(context).shortestSide >= 600,
        onKeyEvent: _onRemoteKey,
        child: MouseRegion(
          onHover: (_) {
            if (!Platform.isAndroid) {
              _showOverlay();
            }
          },
          child: ColoredBox(
            color: Colors.black,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showOverlay,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(
                    child: Video(
                  controller: _video,
                  controls: widget.compact || Platform.isAndroid
                      ? NoVideoControls
                      : AdaptiveVideoControls,
                  fit: _fit,
                )),
                if (!widget.compact &&
                    _overlayVisible &&
                    Platform.isAndroid) ...[
                  // Central controls do not overlap fullscreen, aspect or settings.
                  Center(
                      child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xB9161921),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _overlayButton('Previous channel', Icons.skip_previous,
                          widget.onPrevious,
                          size: 29),
                      _overlayButton(
                          _playing ? 'Pause' : 'Play',
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded, () {
                        unawaited(_transport(_player.playOrPause));
                      }, size: 36),
                      _overlayButton(
                          'Next channel', Icons.skip_next, widget.onNext,
                          size: 29),
                    ]),
                  )),
                  Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC151820),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (Platform.isAndroid)
                            _overlayButton(
                                _phoneLandscape
                                    ? 'Exit fullscreen'
                                    : 'Fullscreen',
                                _phoneLandscape
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen, () {
                              unawaited(_toggleManualFullscreen());
                            }),
                          _overlayButton(
                              'Player settings', Icons.tune_rounded, _settings),
                        ]),
                      )),
                  Positioned(
                      bottom: 8,
                      right: 8,
                      child: Material(
                        color: const Color(0xDD151820),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _showOverlay();
                            _cycleVideoFit();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.aspect_ratio_rounded,
                                  size: 19, color: Color(0xFFF4C65B)),
                              const SizedBox(width: 6),
                              Text(_videoFitLabel,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      )),
                ],
                // Keep desktop media_kit controls (seek, window fullscreen,
                // keyboard shortcuts) intact. Native Windows controls should not
                // be replaced by Android orientation-only buttons.
                if (!widget.compact &&
                    _overlayVisible &&
                    !Platform.isAndroid) ...[
                  Positioned(
                      top: 2,
                      right: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xC8000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (widget.onPrevious != null)
                            _overlayButton('Previous channel',
                                Icons.skip_previous, widget.onPrevious),
                          if (widget.onNext != null)
                            _overlayButton(
                                'Next channel', Icons.skip_next, widget.onNext),
                          _overlayButton(
                              'Player settings', Icons.tune, _settings),
                        ]),
                      )),
                  Positioned(
                      bottom: 8,
                      right: 8,
                      child: Material(
                        color: const Color(0xD9141720),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _cycleVideoFit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Text(_videoFitLabel,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      )),
                ],
                if (!widget.compact &&
                    _showBufferingHint &&
                    !_loading &&
                    _error == null)
                  const Positioned(
                      bottom: 8,
                      left: 8,
                      child: IgnorePointer(
                          child: Chip(
                              label: Text('Buffering...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)))),
                if (_loading)
                  const IgnorePointer(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: const Color(0xED161616),
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!,
                              maxLines: widget.compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                          TextButton.icon(
                              onPressed: _manualRetry,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry')),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}
