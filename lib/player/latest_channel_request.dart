/// Deterministic latest-request-wins mailbox used to document and test the
/// desired player channel-switch semantics independently of native codecs.
class LatestChannelRequest {
  String? _pending;
  void request(String url) {
    _pending = url;
  }

  String? take() {
    final result = _pending;
    _pending = null;
    return result;
  }

  bool get hasPending => _pending != null;
  void clear() {
    _pending = null;
  }
}
