// 包内共用的集合相等与哈希工具。领域层不引入 `collection` 包，所以在这里手写。

/// 两个集合元素相同（不计顺序）。
bool setEquals<T>(Set<T> a, Set<T> b) =>
    identical(a, b) || (a.length == b.length && a.containsAll(b));

/// 与 [setEquals] 一致的哈希：不受元素顺序影响。
int setHash<T>(Set<T> s) => Object.hashAllUnordered(s);

/// 两个映射的键值对完全相同（不计顺序）。
bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

/// 与 [mapEquals] 一致的哈希：不受键顺序影响。
int mapHash<K, V>(Map<K, V> m) =>
    Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));

/// 两个列表逐项相同。
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// `copyWith` 中区分"未传入"与"显式传入 null"的占位值。
const Object unset = _Unset();

final class _Unset {
  const _Unset();
}
