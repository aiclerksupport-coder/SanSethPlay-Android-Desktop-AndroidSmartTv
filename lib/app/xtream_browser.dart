import 'package:flutter/material.dart';
import '../core/xtream_client.dart';
import '../core/xtream_store.dart';

/// Explicitly user-configured service. No third-party channels or credentials
/// are bundled. Browsing never triggers playback until an item is selected.
class XtreamBrowser extends StatefulWidget {
  const XtreamBrowser({super.key});
  @override
  State<XtreamBrowser> createState() => _XtreamBrowserState();
}

class _XtreamBrowserState extends State<XtreamBrowser> {
  final _service = XtreamClient();
  final _store = XtreamStore();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  XtreamAccount? _account;
  XtreamMediaType _type = XtreamMediaType.live;
  List<XtreamItem> _items = [];
  List<XtreamEpisode> _episodes = [];
  Map<String, String> _categories = {};
  String _categoryId = '';
  String _search = '';
  XtreamItem? _selectedSeries;
  bool _busy = false;
  String? _message;
  int _generation = 0;
  int _sessionGeneration = 0;
  int _episodeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = _sessionGeneration;
    try {
      final saved = await _store.load();
      if (!mounted || saved == null || session != _sessionGeneration) {
        return;
      }
      _server.text = saved.server.toString();
      _username.text = saved.username;
      _password.text = saved.password;
      setState(() => _account = saved);
      await _load();
    } catch (_) {
      if (mounted && session == _sessionGeneration) {
        setState(() =>
            _message = 'Saved login read nahi hua. Details dobara daalein.');
      }
    }
  }

  Future<void> _login() async {
    if (_busy) {
      return;
    }
    final session = ++_sessionGeneration;
    XtreamAccount account;
    try {
      account = XtreamAccount(
          server: Uri.parse(_server.text.trim()),
          username: _username.text.trim(),
          password: _password.text);
    } catch (_) {
      setState(() => _message = 'Server URL aur account details check karein.');
      return;
    }
    setState(() {
      _busy = true;
      _message = 'Connecting securely...';
    });
    try {
      await _service.authenticate(account);
      if (!mounted || session != _sessionGeneration) {
        return;
      }
      await _store.save(account);
      if (!mounted || session != _sessionGeneration) {
        return;
      }
      setState(() {
        _account = account;
        _message = null;
      });
    } catch (_) {
      if (mounted && session == _sessionGeneration) {
        setState(() => _message =
            'Provider login fail hua. Active account aur network check karein.');
      }
    } finally {
      if (mounted && session == _sessionGeneration) {
        setState(() => _busy = false);
      }
    }
    if (mounted && session == _sessionGeneration && _account == account) {
      await _load();
    }
  }

  Future<void> _load() async {
    final account = _account;
    if (account == null) {
      return;
    }
    final generation = ++_generation;
    final session = _sessionGeneration;
    ++_episodeGeneration;
    setState(() {
      _busy = true;
      _selectedSeries = null;
      _episodes = [];
      _message = null;
    });
    try {
      final categoryList = await _service.categories(account, _type);
      final entries = await _service.catalog(account, _type);
      if (!mounted ||
          generation != _generation ||
          session != _sessionGeneration) {
        return;
      }
      setState(() {
        _items = entries;
        _categories = categoryList;
        _categoryId = '';
      });
    } catch (_) {
      if (mounted &&
          generation == _generation &&
          session == _sessionGeneration) {
        setState(
            () => _message = 'Provider catalog load nahi hua. Retry karein.');
      }
    } finally {
      if (mounted &&
          generation == _generation &&
          session == _sessionGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pick(XtreamItem item) async {
    final account = _account;
    if (account == null || _busy) {
      return;
    }
    if (item.type != XtreamMediaType.series) {
      Navigator.of(context).pop(_service.channel(account, item));
      return;
    }
    final episodeRequest = ++_episodeGeneration;
    final session = _sessionGeneration;
    setState(() {
      _busy = true;
      _message = null;
      _selectedSeries = item;
      _episodes = [];
    });
    try {
      final found = await _service.episodes(account, item.id);
      if (mounted &&
          session == _sessionGeneration &&
          episodeRequest == _episodeGeneration) {
        setState(() => _episodes = found);
      }
    } catch (_) {
      if (mounted &&
          session == _sessionGeneration &&
          episodeRequest == _episodeGeneration) {
        setState(() => _message = 'Episodes unavailable. Dobara try karein.');
      }
    } finally {
      if (mounted &&
          session == _sessionGeneration &&
          episodeRequest == _episodeGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_busy) {
      return;
    }
    // Invalidate all pending login, catalog, and episode operations first.
    ++_sessionGeneration;
    ++_generation;
    ++_episodeGeneration;
    try {
      await _store.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _account = null;
        _items = [];
        _episodes = [];
        _selectedSeries = null;
        _server.clear();
        _username.clear();
        _password.clear();
        _message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Saved login remove nahi hua.');
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    ++_sessionGeneration;
    ++_episodeGeneration;
    _service.dispose();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _items
        .where((item) =>
            (_categoryId.isEmpty || item.categoryId == _categoryId) &&
            item.name.toLowerCase().contains(_search))
        .toList(growable: false);
    return Dialog.fullscreen(
      child: Scaffold(
          appBar: AppBar(
              title: const Text('Provider • Live / Movies / Series',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              leading: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
              actions: [
                if (_account != null)
                  IconButton(
                      tooltip: 'Remove saved provider login',
                      onPressed: _busy ? null : _logout,
                      icon: const Icon(Icons.logout))
              ]),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        if (_account == null)
                          Expanded(
                              child: ListView(children: [
                            const Text(
                                'Sirf authorized provider account daalein. Credentials device secure storage mein save honge.'),
                            const SizedBox(height: 16),
                            TextField(
                                controller: _server,
                                maxLines: 1,
                                decoration: const InputDecoration(
                                    labelText: 'Provider server URL',
                                    hintText: 'https://provider.example')),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _username,
                                maxLines: 1,
                                decoration: const InputDecoration(
                                    labelText: 'Username')),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _password,
                                obscureText: true,
                                maxLines: 1,
                                decoration: const InputDecoration(
                                    labelText: 'Password')),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed: _busy ? null : _login,
                                child: const Text('Connect & Save')),
                          ]))
                        else ...[
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final type in XtreamMediaType.values)
                              ChoiceChip(
                                  label: Text(switch (type) {
                                    XtreamMediaType.live => 'Live TV',
                                    XtreamMediaType.movie => 'Movies',
                                    XtreamMediaType.series => 'Series',
                                  }),
                                  selected: _type == type,
                                  onSelected: _busy
                                      ? null
                                      : (_) {
                                          setState(() => _type = type);
                                          _load();
                                        }),
                            IconButton(
                                tooltip: 'Refresh catalog',
                                onPressed: _busy ? null : _load,
                                icon: const Icon(Icons.refresh)),
                          ]),
                          const SizedBox(height: 8),
                          TextField(
                              onChanged: (value) =>
                                  setState(() => _search = value.toLowerCase()),
                              decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Search titles')),
                          const SizedBox(height: 8),
                          if (_selectedSeries == null && _categories.isNotEmpty)
                            DropdownButton<String>(
                                isExpanded: true,
                                value: _categoryId,
                                items: [
                                  const DropdownMenuItem(
                                      value: '', child: Text('All categories')),
                                  ..._categories.entries.map((e) =>
                                      DropdownMenuItem(
                                          value: e.key,
                                          child: Text(e.value,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis)))
                                ],
                                onChanged: (value) =>
                                    setState(() => _categoryId = value ?? '')),
                          if (_selectedSeries != null)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                    onPressed: () => setState(() {
                                          ++_episodeGeneration;
                                          _selectedSeries = null;
                                        }),
                                    icon: const Icon(Icons.arrow_back),
                                    label: Text(_selectedSeries!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis))),
                          Expanded(
                              child: _selectedSeries == null
                                  ? ListView.builder(
                                      itemCount: visibleItems.length,
                                      itemBuilder: (context, index) {
                                        final visible = visibleItems[index];
                                        return ListTile(
                                            title: Text(visible.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            subtitle: Text(
                                                _categories[
                                                        visible.categoryId] ??
                                                    visible.type.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            trailing:
                                                const Icon(Icons.play_arrow),
                                            onTap: _busy
                                                ? null
                                                : () => _pick(visible));
                                      })
                                  : ListView.builder(
                                      itemCount: _episodes.length,
                                      itemBuilder: (context, index) {
                                        final episode = _episodes[index];
                                        return ListTile(
                                            title: Text(episode.title,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            subtitle: Text(
                                                'Season ${episode.season}'),
                                            trailing:
                                                const Icon(Icons.play_arrow),
                                            onTap: () => Navigator.pop(
                                                context,
                                                _service.channel(
                                                    _account!, _selectedSeries!,
                                                    title:
                                                        '${_selectedSeries!.name} • ${episode.title}',
                                                    episodeId: episode.id,
                                                    episodeExtension:
                                                        episode.extension)));
                                      })),
                        ],
                        if (_busy) const LinearProgressIndicator(),
                        if (_message != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(_message!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                      ]))))),
    );
  }
}
