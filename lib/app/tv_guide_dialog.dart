import 'package:flutter/material.dart';
import '../core/channel.dart';
import '../core/epg_repository.dart';
import '../core/epg_schedule.dart';
import '../core/catchup.dart';

const _gold = Color(0xFFF5C75C);

/// Shared horizontal EPG timeline, with lazy channel rows and bounded labels.
/// Scroll once horizontally; all channel rows keep the same time alignment.
class TvGuideDialog extends StatefulWidget {
  const TvGuideDialog(
      {super.key,
      required this.channels,
      required this.programs,
      required this.onPlay});
  final List<StreamChannel> channels;
  final Map<String, List<EpgProgram>> programs;
  final ValueChanged<StreamChannel> onPlay;
  @override
  State<TvGuideDialog> createState() => _TvGuideDialogState();
}

class _TvGuideDialogState extends State<TvGuideDialog> {
  final _search = TextEditingController();
  String _query = '';
  DateTime _windowStart = halfHourFloor(DateTime.now().toUtc());
  static const double _labelWidth = 168;
  static const double _slotWidth = 134;
  static const int _slots = 12;
  static const double _timelineWidth = _slotWidth * _slots;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _timelineRow(StreamChannel channel, GuideWindow window) {
    final events = widget.programs[channel.tvgId] ?? const <EpgProgram>[];
    return SizedBox(
      width: _timelineWidth,
      height: 72,
      child: Stack(children: [
        Row(
            children: List.generate(
                _slots,
                (_) => Container(
                      width: _slotWidth,
                      decoration: const BoxDecoration(
                          border: Border(
                              right: BorderSide(
                                  color: Color(0xFF333B46), width: 0.5))),
                    ))),
        for (final event in events)
          if (window.leftFraction(event) case final double left)
            if (window.widthFraction(event) > 0)
              Positioned(
                left: left * _timelineWidth + 2,
                width: (window.widthFraction(event) * _timelineWidth - 4)
                    .clamp(1.0, _timelineWidth)
                    .toDouble(),
                top: 5,
                bottom: 5,
                child: Tooltip(
                  message:
                      '${_time(event.start)}–${_time(event.stop)} ${event.title}',
                  child: InkWell(
                      onTap: () {
                        final replay = CatchupUrl.archivedProgramme(
                            channel, event.title, event.start, event.stop);
                        if (replay == null &&
                            event.stop.isBefore(DateTime.now())) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Archive is not available for this programme.')));
                          return;
                        }
                        Navigator.pop(context);
                        widget.onPlay(replay ?? channel);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: const Color(0xFF28313F),
                            border: Border.all(color: const Color(0xFF485465)),
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(event.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '${_time(event.start)}–${_time(event.stop)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white70)),
                                ])),
                      )),
                ),
              ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final window = GuideWindow(_windowStart);
    final channels = widget.channels
        .where((c) =>
            c.tvgId != null &&
            widget.programs.containsKey(c.tvgId) &&
            c.name.toLowerCase().contains(_query))
        .toList(growable: false);
    final dialogWidth = (size.width - 24).clamp(240.0, 1200.0);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
          width: dialogWidth,
          height: (size.height * .88).clamp(240.0, 830.0),
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_month_outlined, color: _gold),
                      const SizedBox(width: 6),
                      const Expanded(
                          child: Text('TV GUIDE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18))),
                      IconButton(
                          tooltip: 'Close guide',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ]),
                    TextField(
                        controller: _search,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        decoration: const InputDecoration(
                            isDense: true,
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search channels')),
                    const SizedBox(height: 5),
                    Row(children: [
                      IconButton(
                          tooltip: 'Previous 6 hours',
                          onPressed: () => setState(() => _windowStart =
                              _windowStart.subtract(const Duration(hours: 6))),
                          icon: const Icon(Icons.chevron_left)),
                      Expanded(
                          child: Text(
                              '${_time(window.start)} – ${_time(window.end)}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      TextButton(
                          onPressed: () => setState(() => _windowStart =
                              halfHourFloor(DateTime.now().toUtc())),
                          child: const Text('Now')),
                      IconButton(
                          tooltip: 'Next 6 hours',
                          onPressed: () => setState(() => _windowStart =
                              _windowStart.add(const Duration(hours: 6))),
                          icon: const Icon(Icons.chevron_right)),
                    ]),
                    const SizedBox(height: 5),
                    Expanded(
                        child: channels.isEmpty
                            ? const Center(
                                child: Text(
                                    'EPG matching channels nahi mile. M3U tvg-id check karein.',
                                    textAlign: TextAlign.center))
                            : LayoutBuilder(builder: (context, constraints) {
                                // Single horizontal viewport means header and every row share
                                // exactly the same timeline position, including on TV.
                                final labelWidth = constraints.maxWidth < 450
                                    ? 118.0
                                    : _labelWidth;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                      width: labelWidth + _timelineWidth,
                                      child: Column(children: [
                                        SizedBox(
                                            height: 36,
                                            child: Row(children: [
                                              SizedBox(
                                                  width: labelWidth,
                                                  child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      child: Text('CHANNEL',
                                                          style: TextStyle(
                                                              color: _gold,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700)))),
                                              ...List.generate(
                                                  _slots,
                                                  (i) => SizedBox(
                                                      width: _slotWidth,
                                                      child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          child: Text(
                                                              _time(_windowStart
                                                                  .add(Duration(
                                                                      minutes: 30 *
                                                                          i))),
                                                              style: const TextStyle(
                                                                  color:
                                                                      _gold))))),
                                            ])),
                                        Expanded(
                                            child: ListView.builder(
                                                itemCount: channels.length,
                                                itemExtent: 76,
                                                itemBuilder: (context, i) {
                                                  final channel = channels[i];
                                                  return Row(children: [
                                                    SizedBox(
                                                        width: labelWidth,
                                                        child: TextButton.icon(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                            widget.onPlay(
                                                                channel);
                                                          },
                                                          icon: const Icon(
                                                              Icons.play_arrow,
                                                              size: 18,
                                                              color: _gold),
                                                          label: Text(
                                                              channel.name,
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          12)),
                                                        )),
                                                    _timelineRow(
                                                        channel, window),
                                                  ]);
                                                })),
                                      ])),
                                );
                              })),
                  ]))),
    );
  }
}
