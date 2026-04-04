import "package:flutter_test/flutter_test.dart";
import "package:polyphony_flutter_client/shared/services/cache/memory_cache.dart";

void main() {
  group("MemoryCache", () {
    test("get returns null for missing key", () {
      final cache = MemoryCache<String>();

      expect(cache.get("missing"), isNull);
    });

    test("get returns value for present non-expired key", () {
      final cache = MemoryCache<String>()..set("key", "value");

      expect(cache.get("key"), equals("value"));
    });

    test("get returns null for expired key", () async {
      final cache = MemoryCache<String>(
        ttl: const Duration(milliseconds: 50),
      )..set("key", "value");

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(cache.get("key"), isNull);
    });

    test("set overwrites existing key", () {
      final cache = MemoryCache<String>()
        ..set("key", "first")
        ..set("key", "second");

      expect(cache.get("key"), equals("second"));
    });

    test("invalidate removes specific key", () {
      final cache = MemoryCache<String>()
        ..set("a", "1")
        ..set("b", "2")
        ..invalidate("a");

      expect(cache.get("a"), isNull);
      expect(cache.get("b"), equals("2"));
    });

    test("invalidateWhere removes matching keys and leaves others", () {
      final cache = MemoryCache<String>()
        ..set("reactions:ch1:msg1", "data1")
        ..set("reactions:ch1:msg2", "data2")
        ..set("reactions:ch2:msg3", "data3")
        ..invalidateWhere((key) => key.startsWith("reactions:ch1:"));

      expect(cache.get("reactions:ch1:msg1"), isNull);
      expect(cache.get("reactions:ch1:msg2"), isNull);
      expect(cache.get("reactions:ch2:msg3"), equals("data3"));
    });

    test("clear removes all entries", () {
      final cache = MemoryCache<String>()
        ..set("a", "1")
        ..set("b", "2")
        ..clear();

      expect(cache.get("a"), isNull);
      expect(cache.get("b"), isNull);
    });

    test("constructor accepts custom TTL", () {
      final cache = MemoryCache<int>(
        ttl: const Duration(hours: 1),
      )..set("long-lived", 42);

      expect(cache.get("long-lived"), equals(42));
    });
  });
}
