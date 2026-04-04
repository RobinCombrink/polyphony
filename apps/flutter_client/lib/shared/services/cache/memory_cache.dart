class MemoryCache<T> {
  MemoryCache({Duration ttl = const Duration(minutes: 5)}) : _ttl = ttl;

  final Duration _ttl;
  final _entries = <String, _CacheEntry<T>>{};

  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }

    return entry.value;
  }

  void set(String key, T value) {
    _entries[key] = _CacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(_ttl),
    );
  }

  void invalidate(String key) {
    _entries.remove(key);
  }

  void invalidateWhere(bool Function(String key) predicate) {
    _entries.removeWhere((key, _) => predicate(key));
  }

  void clear() {
    _entries.clear();
  }
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final T value;
  final DateTime expiresAt;
}
