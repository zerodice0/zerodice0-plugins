# Flutter Performance Antipattern Catalog
# Flutter 성능 안티패턴 카탈로그

A comprehensive catalog of 10 common Flutter performance antipatterns, with detection strategies, code examples, and expected improvements.

> **Severity Levels**: Critical (앱 크래시/프리즈 유발) | Major (눈에 띄는 성능 저하) | Minor (최적화 기회)
>
> **Categories**: Rebuild Optimization (리빌드 최적화) | Rendering Performance (렌더링 성능) | Memory Management (메모리 관리) | Network Performance (네트워크 성능)

---

## AP-001: setState Inside build Method
<!-- build 메서드 내부에서 setState 호출 -->

- **Severity**: Critical
- **Category**: Rebuild Optimization

### Problem

Calling `setState()` inside the `build()` method causes infinite rebuild loops. The `build()` method is called whenever state changes, so calling `setState()` within it triggers another build, which triggers another `setState()`, ad infinitum. This crashes the app or causes severe jank (무한 리빌드 루프로 인한 앱 크래시 또는 심각한 버벅임).

### Detection

- **Strategy**: Grep for `setState` in `.dart` files, then Read surrounding context to verify it is inside a `build` method body.
- **Grep pattern**: `setState` in `*.dart` files
- **Verification**: Read the file and confirm the `setState` call is directly inside `Widget build(BuildContext context)` rather than inside a callback or event handler.

### Performance Impact

- Infinite rebuilds
- Complete UI freeze (UI 완전 정지)
- Potential app crash with stack overflow

### Before (Bad)

```dart
class CounterWidget extends StatefulWidget {
  const CounterWidget({super.key});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    // BAD: setState called directly inside build — triggers infinite loop
    // 잘못된 예: build 안에서 setState를 직접 호출하면 무한 루프 발생
    setState(() {
      _count++;
    });

    return Text('Count: $_count');
  }
}
```

### After (Good)

```dart
class CounterWidget extends StatefulWidget {
  const CounterWidget({super.key});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  int _count = 0;

  void _increment() {
    // GOOD: setState is called from an event handler, not from build
    // 올바른 예: 이벤트 핸들러에서 setState 호출
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _increment,
      child: Text('Count: $_count'),
    );
  }
}
```

### Expected Improvement

Eliminates infinite rebuilds entirely. The app goes from crashing/frozen to functioning normally.

---

## AP-002: Missing const Constructors
<!-- const 생성자 누락 -->

- **Severity**: Major
- **Category**: Rebuild Optimization

### Problem

Non-const widget constructors cause unnecessary rebuilds when the parent widget rebuilds. Flutter can skip rebuilding `const` widgets because it knows they haven't changed. Without `const`, Flutter must rebuild the widget every time the parent's `build()` runs, even if the arguments are identical (부모 위젯이 리빌드될 때 불필요한 자식 리빌드 발생).

### Detection

- **Strategy**: Grep for common widget constructors not preceded by `const`.
- **Grep pattern**: `(?<!const\s)(?:Text|Icon|SizedBox|Padding)\(` in `*.dart` files
- **Additional patterns**: `EdgeInsets.` not preceded by `const`
- **Note**: False positives are possible when arguments are non-const expressions. Manual verification recommended.

### Performance Impact

- 10-30% unnecessary rebuilds in typical apps
- Increased frame build times (프레임 빌드 시간 증가)
- More noticeable in deeply nested widget trees

### Before (Bad)

```dart
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: These widgets are recreated on every parent rebuild
        // 잘못된 예: 부모가 리빌드될 때마다 이 위젯들이 재생성됨
        SizedBox(height: 16),
        Icon(Icons.person, size: 48),
        Text('Profile'),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Welcome'),
        ),
      ],
    );
  }
}
```

### After (Good)

```dart
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // GOOD: const widgets are cached and never rebuilt unnecessarily
        // 올바른 예: const 위젯은 캐시되어 불필요한 리빌드를 하지 않음
        SizedBox(height: 16),
        Icon(Icons.person, size: 48),
        Text('Profile'),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Welcome'),
        ),
      ],
    );
  }
}
```

### Expected Improvement

Reduces widget tree rebuilds by 10-30%. The effect compounds in complex UIs with many static widgets.

---

## AP-003: I/O Operations Inside build
<!-- build 메서드 내부에서 I/O 작업 수행 -->

- **Severity**: Critical
- **Category**: Rendering Performance

### Problem

HTTP calls, file I/O, or database queries executed directly inside `build()` block the UI thread. The `build()` method must return a widget tree quickly (ideally under 16ms for 60fps). Any blocking I/O inside `build()` freezes the entire UI until the operation completes (UI 스레드를 차단하여 전체 화면이 멈춤).

### Detection

- **Strategy**: Grep for I/O calls near `build` methods.
- **Grep patterns**:
  - `http.get`, `http.post`, `HttpClient`
  - `File(`, `openDatabase`, `Dio(`
- **Verification**: Read the file to confirm these calls are inside a `build()` method body rather than in `initState`, a callback, or an async method.

### Performance Impact

- UI freezes for the entire duration of the I/O operation (I/O 작업 동안 UI 완전 정지)
- Jank or ANR (Application Not Responding) on slow networks
- Frames dropped during data loading

### Before (Bad)

```dart
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    // BAD: HTTP request inside build — blocks UI thread, called on every rebuild
    // 잘못된 예: build 안에서 HTTP 요청 — UI 스레드 차단, 매 리빌드마다 호출
    final response = http.get(Uri.parse('https://api.example.com/user'));

    return FutureBuilder(
      future: response, // This also re-fires on every rebuild!
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text('User: ${snapshot.data}');
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
```

### After (Good)

```dart
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final Future<http.Response> _userFuture;

  @override
  void initState() {
    super.initState();
    // GOOD: I/O is triggered once in initState, not in build
    // 올바른 예: I/O를 initState에서 한 번만 실행
    _userFuture = http.get(Uri.parse('https://api.example.com/user'));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _userFuture, // Stable reference — won't re-fire on rebuild
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text('User: ${snapshot.data}');
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
```

### Expected Improvement

Eliminates UI blocking from I/O. Build times drop from hundreds of milliseconds (or seconds) to sub-millisecond.

---

## AP-004: Inefficient ListView Usage
<!-- 비효율적인 ListView 사용 -->

- **Severity**: Major
- **Category**: Memory Management

### Problem

Using `ListView(children: [...])` with many items loads all children into memory and lays them out at once, regardless of whether they are visible on screen. For large lists (100+ items), this causes high memory usage, slow initial render, and potential out-of-memory crashes (모든 항목을 한 번에 메모리에 로드하여 메모리 과다 사용).

### Detection

- **Strategy**: Grep for `ListView(` without `.builder` or `.separated`.
- **Grep pattern**: `ListView\(` in `*.dart` files
- **Exclusion**: Filter out `ListView.builder`, `ListView.separated`, `ListView.custom`
- **Verification**: Read the file to check if the list has a large or dynamic number of children.

### Performance Impact

- O(n) memory usage regardless of visible items (보이지 않는 항목도 모두 메모리에 로드)
- Slow initial render for large lists
- Potential out-of-memory crash on low-end devices

### Before (Bad)

```dart
class MessageList extends StatelessWidget {
  final List<Message> messages; // Could be thousands of items

  const MessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    // BAD: All items are built and laid out at once
    // 잘못된 예: 모든 항목이 한 번에 빌드되고 레이아웃됨
    return ListView(
      children: messages.map((msg) {
        return ListTile(
          title: Text(msg.sender),
          subtitle: Text(msg.content),
          leading: CircleAvatar(
            backgroundImage: NetworkImage(msg.avatarUrl),
          ),
        );
      }).toList(),
    );
  }
}
```

### After (Good)

```dart
class MessageList extends StatelessWidget {
  final List<Message> messages;

  const MessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    // GOOD: Only visible items are built — O(visible) memory usage
    // 올바른 예: 화면에 보이는 항목만 빌드됨 — O(보이는 항목 수) 메모리 사용
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return ListTile(
          title: Text(msg.sender),
          subtitle: Text(msg.content),
          leading: CircleAvatar(
            backgroundImage: NetworkImage(msg.avatarUrl),
          ),
        );
      },
    );
  }
}
```

### Expected Improvement

Memory usage drops from O(n) to O(visible items). Initial render time drops significantly for large lists (e.g., 1000 items: from ~2s to ~50ms).

---

## AP-005: Missing Keys in Lists
<!-- 리스트에서 Key 누락 -->

- **Severity**: Minor
- **Category**: Rebuild Optimization

### Problem

Without explicit keys, Flutter uses index-based diffing for list items. When items are reordered, inserted, or removed, Flutter cannot tell which item is which and may rebuild all items unnecessarily. Worse, stateful widgets can lose or swap their state (Key가 없으면 리스트 항목의 상태가 뒤섞이거나 불필요한 리빌드 발생).

### Detection

- **Strategy**: Read `ListView.builder` itemBuilder body and check for `Key`, `ValueKey`, or `ObjectKey` usage.
- **Grep pattern**: `itemBuilder` in `*.dart` files
- **Verification**: Read the returned widget in the itemBuilder and check if it has a `key` parameter set.

### Performance Impact

- Slower list updates when items are reordered or removed
- Potential state bugs with StatefulWidget list items (상태 버그 가능성)
- More work for the element tree diffing algorithm

### Before (Bad)

```dart
ListView.builder(
  itemCount: todos.length,
  itemBuilder: (context, index) {
    final todo = todos[index];
    // BAD: No key — if list is reordered, state may be swapped
    // 잘못된 예: Key 없음 — 리스트가 재정렬되면 상태가 뒤섞일 수 있음
    return TodoTile(
      title: todo.title,
      isCompleted: todo.isCompleted,
      onToggle: () => toggleTodo(todo.id),
    );
  },
);
```

### After (Good)

```dart
ListView.builder(
  itemCount: todos.length,
  itemBuilder: (context, index) {
    final todo = todos[index];
    // GOOD: ValueKey ensures correct diffing and state preservation
    // 올바른 예: ValueKey로 정확한 비교와 상태 보존 보장
    return TodoTile(
      key: ValueKey(todo.id),
      title: todo.title,
      isCompleted: todo.isCompleted,
      onToggle: () => toggleTodo(todo.id),
    );
  },
);
```

### Expected Improvement

Faster list diffing and updates, especially for reorderable or filterable lists. Eliminates state-swap bugs in lists of StatefulWidgets.

---

## AP-006: Excessive Rebuilds from setState Scope
<!-- setState 범위로 인한 과도한 리빌드 -->

- **Severity**: Major
- **Category**: Rebuild Optimization

### Problem

Calling `setState()` in a large StatefulWidget rebuilds the entire widget's subtree, even if only a small part of the UI actually changed. For example, if a counter value changes but the entire screen rebuilds including app bars, lists, and images, most of that work is wasted (작은 변경인데도 전체 서브트리가 리빌드되는 문제).

### Detection

- **Strategy**: Read the file to analyze widget size (line count of `build` method) and `setState` usage patterns.
- **Heuristic**: A `build` method longer than 50 lines with `setState` calls is a candidate.
- **Verification**: Check if the data changed by `setState` is used by only a small portion of the widget tree.

### Performance Impact

- Rebuilds large subtrees unnecessarily (큰 서브트리가 불필요하게 리빌드)
- Increased frame build time
- More garbage collection pressure from discarded widget objects

### Before (Bad)

```dart
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _notificationCount = 0;

  void _onNewNotification() {
    // BAD: This rebuilds the ENTIRE dashboard just for a badge count
    // 잘못된 예: 배지 숫자 하나 때문에 전체 대시보드가 리빌드됨
    setState(() {
      _notificationCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Badge(
            label: Text('$_notificationCount'),
            child: const Icon(Icons.notifications),
          ),
        ],
      ),
      body: Column(
        children: [
          const HeavyChartWidget(),     // Rebuilds unnecessarily
          const UserActivityFeed(),     // Rebuilds unnecessarily
          const RecentTransactions(),   // Rebuilds unnecessarily
        ],
      ),
    );
  }
}
```

### After (Good)

```dart
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          // GOOD: Only the badge rebuilds when count changes
          // 올바른 예: 카운트 변경 시 배지만 리빌드됨
          NotificationBadge(),
        ],
      ),
      body: const Column(
        children: [
          HeavyChartWidget(),       // Not affected by badge changes
          UserActivityFeed(),       // Not affected by badge changes
          RecentTransactions(),     // Not affected by badge changes
        ],
      ),
    );
  }
}

class NotificationBadge extends StatefulWidget {
  const NotificationBadge({super.key});

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _count = 0;

  void _onNewNotification() {
    // GOOD: setState only rebuilds this small widget
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text('$_count'),
      child: const Icon(Icons.notifications),
    );
  }
}
```

### Expected Improvement

Reduces rebuild scope by 50-80%. Only the small extracted widget rebuilds instead of the entire screen.

---

## AP-007: No Image Caching for Network Images
<!-- 네트워크 이미지 캐싱 미적용 -->

- **Severity**: Minor
- **Category**: Network Performance

### Problem

`Image.network` downloads images every time the widget is built (unless the HTTP cache headers happen to work). It provides no disk caching, no placeholder support, and no error handling out of the box. In lists or screens that rebuild frequently, this leads to redundant downloads and flickering images (매번 이미지를 다시 다운로드하여 네트워크 낭비 및 깜빡임 발생).

### Detection

- **Strategy**: Grep for `Image.network` usage and check `pubspec.yaml` for `cached_network_image` dependency.
- **Grep pattern**: `Image\.network` in `*.dart` files
- **Verification**: Read `pubspec.yaml` and check if `cached_network_image` is listed under dependencies.
- **Threshold**: Any usage of `Image.network` without a caching package is flagged.

### Performance Impact

- Redundant network requests for the same image (동일 이미지에 대한 중복 네트워크 요청)
- Slower image loading on revisits
- Higher bandwidth consumption
- Image flickering during rebuilds

### Before (Bad)

```dart
class UserAvatar extends StatelessWidget {
  final String imageUrl;

  const UserAvatar({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // BAD: No caching, no placeholder, no error handling
    // 잘못된 예: 캐싱 없음, 플레이스홀더 없음, 에러 처리 없음
    return CircleAvatar(
      backgroundImage: NetworkImage(imageUrl),
      radius: 24,
    );
  }
}
```

### After (Good)

```dart
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final String imageUrl;

  const UserAvatar({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // GOOD: Disk-cached, with placeholder and error widget
    // 올바른 예: 디스크 캐시, 플레이스홀더, 에러 위젯 포함
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        backgroundImage: imageProvider,
        radius: 24,
      ),
      placeholder: (context, url) => const CircleAvatar(
        radius: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => const CircleAvatar(
        radius: 24,
        child: Icon(Icons.error),
      ),
    );
  }
}
```

**pubspec.yaml addition:**

```yaml
dependencies:
  cached_network_image: ^3.3.0
```

### Expected Improvement

Eliminates redundant image downloads after the first load. Images load instantly from disk cache on subsequent visits.

---

## AP-008: Missing RepaintBoundary for Custom Paint
<!-- CustomPaint에 RepaintBoundary 누락 -->

- **Severity**: Minor
- **Category**: Rendering Performance

### Problem

`CustomPaint` without a `RepaintBoundary` causes the paint phase to propagate to surrounding widgets. When the CustomPainter needs to repaint (e.g., during animation), everything in the same repaint boundary repaints too. This is especially costly for complex custom paintings alongside other UI elements (CustomPaint의 다시 그리기가 주변 위젯까지 전파되는 문제).

### Detection

- **Strategy**: Grep for `CustomPaint` and check if it is wrapped in or near a `RepaintBoundary`.
- **Grep pattern**: `CustomPaint` in `*.dart` files
- **Verification**: Read surrounding lines (20-30 lines up) to check for `RepaintBoundary` wrapping.

### Performance Impact

- Unnecessary repaints of surrounding widgets (주변 위젯의 불필요한 다시 그리기)
- Higher GPU workload during animations
- Jank in paint-heavy UIs (charts, canvases, games)

### Before (Bad)

```dart
class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Sales Report'),
        // BAD: When the chart repaints, the entire Column repaints too
        // 잘못된 예: 차트가 다시 그려지면 전체 Column도 다시 그려짐
        CustomPaint(
          painter: SalesChartPainter(),
          size: const Size(300, 200),
        ),
        const Text('Updated: 2024-01-15'),
      ],
    );
  }
}
```

### After (Good)

```dart
class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Sales Report'),
        // GOOD: RepaintBoundary isolates the chart's repaint area
        // 올바른 예: RepaintBoundary가 차트의 다시 그리기 영역을 격리함
        RepaintBoundary(
          child: CustomPaint(
            painter: SalesChartPainter(),
            size: const Size(300, 200),
          ),
        ),
        const Text('Updated: 2024-01-15'),
      ],
    );
  }
}
```

### Expected Improvement

Reduces repaint area significantly. Only the `CustomPaint` region is repainted instead of the entire parent subtree. Particularly impactful for animated charts and canvases.

---

## AP-009: Excessive GlobalKey Usage
<!-- 과도한 GlobalKey 사용 -->

- **Severity**: Minor
- **Category**: Memory Management

### Problem

`GlobalKey` is expensive because it registers the widget in a global registry, prevents the framework from recycling the widget's Element, and can cause memory leaks if not disposed properly. Overuse of `GlobalKey` (especially when `ValueKey`, `ObjectKey`, or no key would suffice) wastes memory and slows down the widget tree operations (GlobalKey는 비용이 높고 위젯 재활용을 방해하며 메모리 누수 유발 가능).

### Detection

- **Strategy**: Grep for `GlobalKey` and count occurrences across the project.
- **Grep pattern**: `GlobalKey` in `*.dart` files
- **Threshold**: 5+ `GlobalKey` instances in a single file or 20+ across the project warrant review.
- **Verification**: Read each usage to determine if `GlobalKey` is actually necessary (e.g., for `Form` validation, `Scaffold` drawers) or could be replaced.

### Performance Impact

- Increased memory usage per GlobalKey instance (GlobalKey 인스턴스당 메모리 사용 증가)
- Prevents widget element recycling
- Potential memory leaks in long-lived screens
- Slower widget tree operations (insert, remove, move)

### Before (Bad)

```dart
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  // BAD: GlobalKey used just to read widget size — overkill
  // 잘못된 예: 위젯 크기를 읽기 위해 GlobalKey 사용 — 과도함
  final _headerKey = GlobalKey();
  final _bodyKey = GlobalKey();
  final _footerKey = GlobalKey();
  final _buttonKey = GlobalKey();
  final _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(key: _headerKey, child: const Text('Header')),
        Container(key: _bodyKey, child: const Text('Body')),
        Container(key: _footerKey, child: const Text('Footer')),
        ElevatedButton(key: _buttonKey, onPressed: () {}, child: const Text('Submit')),
        Image.asset('assets/logo.png', key: _imageKey),
      ],
    );
  }
}
```

### After (Good)

```dart
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  // GOOD: Only use GlobalKey where truly necessary (e.g., Form validation)
  // 올바른 예: 정말 필요한 곳에만 GlobalKey 사용 (예: Form 유효성 검사)
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Use ValueKey or no key for simple identification
          const Text('Header'),
          const Text('Body'),
          const Text('Footer'),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Submit
              }
            },
            child: const Text('Submit'),
          ),
          Image.asset('assets/logo.png'),
        ],
      ),
    );
  }
}
```

### Expected Improvement

Better memory efficiency and widget recycling. Reduces the global registry size and avoids unnecessary Element retention.

---

## AP-010: Synchronous File I/O
<!-- 동기 파일 I/O -->

- **Severity**: Critical
- **Category**: Rendering Performance

### Problem

Synchronous file operations like `readAsStringSync()`, `writeAsBytesSync()`, and `existsSync()` block the UI thread (the main isolate) until the operation completes. On slow storage or large files, this can freeze the UI for hundreds of milliseconds or more. Flutter's single-threaded UI model means any blocking call directly impacts frame rendering (동기 파일 작업이 UI 스레드를 차단하여 화면 멈춤 현상 발생).

### Detection

- **Strategy**: Grep for synchronous I/O method patterns.
- **Grep patterns**:
  - `readAsStringSync`, `readAsBytesSync`, `readAsLinesSync`
  - `writeAsStringSync`, `writeAsBytesSync`
  - `existsSync`, `createSync`, `deleteSync`
  - General pattern: `Sync(` or `Sync<` in `*.dart` files
- **Exclusion**: Test files and build scripts may legitimately use sync I/O.

### Performance Impact

- UI freezes during file operations (파일 작업 중 UI 정지)
- Dropped frames, visible jank
- Worse on slower devices or larger files
- Can trigger ANR (Application Not Responding) on Android

### Before (Bad)

```dart
class SettingsManager {
  static const _filePath = 'settings.json';

  // BAD: Synchronous file operations block the UI thread
  // 잘못된 예: 동기 파일 작업이 UI 스레드를 차단함
  Map<String, dynamic> loadSettings() {
    final file = File(_filePath);
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    }
    return {};
  }

  void saveSettings(Map<String, dynamic> settings) {
    final file = File(_filePath);
    file.writeAsStringSync(jsonEncode(settings));
  }
}

// Usage in a widget:
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _manager = SettingsManager();
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    // BAD: Blocks UI thread during initialization
    _settings = _manager.loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Theme: ${_settings['theme']}');
  }
}
```

### After (Good)

```dart
class SettingsManager {
  static const _filePath = 'settings.json';

  // GOOD: Async file operations don't block the UI thread
  // 올바른 예: 비동기 파일 작업은 UI 스레드를 차단하지 않음
  Future<Map<String, dynamic>> loadSettings() async {
    final file = File(_filePath);
    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    }
    return {};
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final file = File(_filePath);
    await file.writeAsString(jsonEncode(settings));
  }
}

// Usage in a widget:
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _manager = SettingsManager();
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // GOOD: Async load doesn't block the UI thread
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _manager.loadSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    return Text('Theme: ${_settings['theme']}');
  }
}
```

### Expected Improvement

Eliminates UI blocking from file I/O. File operations run on the Dart event loop without blocking frame rendering. For heavy file operations, consider using `compute()` or `Isolate` for complete isolation from the UI thread.

---

## Quick Reference Table
## 빠른 참조 표

| ID | Antipattern | Severity | Category | Key Detection Pattern |
|----|------------|----------|----------|----------------------|
| AP-001 | setState inside build | Critical | Rebuild Optimization | `setState` inside `build()` |
| AP-002 | Missing const constructors | Major | Rebuild Optimization | `(?<!const\s)(?:Text\|Icon\|SizedBox\|Padding)\(` |
| AP-003 | I/O inside build | Critical | Rendering Performance | `http.get`, `File(` near `build` |
| AP-004 | Inefficient ListView | Major | Memory Management | `ListView(` without `.builder` |
| AP-005 | Missing keys in lists | Minor | Rebuild Optimization | `itemBuilder` without `key:` |
| AP-006 | Excessive setState scope | Major | Rebuild Optimization | Large `build` + `setState` |
| AP-007 | No image caching | Minor | Network Performance | `Image.network` without cache pkg |
| AP-008 | Missing RepaintBoundary | Minor | Rendering Performance | `CustomPaint` without `RepaintBoundary` |
| AP-009 | Excessive GlobalKey | Minor | Memory Management | `GlobalKey` count > 5 per file |
| AP-010 | Synchronous file I/O | Critical | Rendering Performance | `Sync(` in `*.dart` files |
