import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/recordings_library.dart';
import '../core/channel.dart';

/// Remote/keyboard-friendly bounded listing of the app's own recordings.
class RecordingsDialog extends StatefulWidget {
  const RecordingsDialog(
      {super.key, this.library = const RecordingsLibrary(), this.onPlay});
  final RecordingsLibrary library;
  final ValueChanged<StreamChannel>? onPlay;

  @override
  State<RecordingsDialog> createState() => _RecordingsDialogState();
}

class _RecordingsDialogState extends State<RecordingsDialog> {
  late Future<List<RecordedVideo>> _items = widget.library.list();
  bool _busy = false;

  void _reload() => setState(() => _items = widget.library.list());

  Future<void> _share(RecordedVideo video) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await SharePlus.instance.share(ShareParams(
          files: [XFile(video.file.path)], subject: 'SanSeth Play recording'));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sharing not supported on this device.')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(RecordedVideo video) async {
    if (_busy) {
      return;
    }
    final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete recording?'),
                content: Text(video.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ]));
    if (allowed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final deleted = await widget.library.delete(video);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording could not be deleted.')));
    }
    _reload();
  }

  Future<void> _recoverInterrupted() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    var recovered = 0;
    try {
      final interrupted = await widget.library.interrupted();
      for (final part in interrupted) {
        if (await widget.library.recover(part) != null) {
          recovered++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Recovered $recovered interrupted recording(s).')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 580),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Recordings Library',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold))),
                    IconButton(
                        tooltip: 'Recover interrupted recordings',
                        onPressed: _busy ? null : _recoverInterrupted,
                        icon: const Icon(Icons.healing)),
                    IconButton(
                        tooltip: 'Refresh',
                        onPressed: _busy ? null : _reload,
                        icon: const Icon(Icons.refresh)),
                    IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const Divider(),
                  Expanded(
                      child: FutureBuilder<List<RecordedVideo>>(
                          future: _items,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                  child: snapshot.hasError
                                      ? const Text(
                                          'Recordings could not be loaded.')
                                      : const CircularProgressIndicator());
                            }
                            final items = snapshot.data!;
                            if (items.isEmpty) {
                              return const Center(
                                  child: Text('No recordings saved yet.'));
                            }
                            return ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final video = items[index];
                                  return ListTile(
                                    leading: const Icon(Icons.movie_outlined),
                                    title: Text(video.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                        '${(video.bytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
                                    onTap: widget.onPlay == null
                                        ? null
                                        : () {
                                            widget.onPlay!(StreamChannel(
                                                name: video.name,
                                                url: video.file.uri,
                                                group: 'My recordings',
                                                isVod: true));
                                            Navigator.of(context).pop();
                                          },
                                    trailing: PopupMenuButton<String>(
                                      tooltip: 'Recording actions',
                                      enabled: !_busy,
                                      onSelected: (action) {
                                        if (action == 'share') {
                                          _share(video);
                                        }
                                        if (action == 'delete') {
                                          _delete(video);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                            value: 'share',
                                            child: Text('Share / Export')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete')),
                                      ],
                                    ),
                                  );
                                });
                          })),
                ]))),
      );
}
