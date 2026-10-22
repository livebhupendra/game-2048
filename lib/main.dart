import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Game2048App());
}

class Game2048App extends StatelessWidget {
  const Game2048App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2048',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFAF8EF)),
      home: const GameScreen(),
    );
  }
}

enum Dir { left, right, up, down }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int n = 4;
  final Random _rng = Random();
  final FocusNode _focus = FocusNode();

  List<List<int>> grid = _empty();
  List<List<int>>? _prevGrid;
  int _prevScore = 0;
  int score = 0;
  int best = 0;
  bool over = false;
  bool won = false;
  bool keepPlaying = false;

  static List<List<int>> _empty() => List.generate(n, (_) => List.filled(n, 0));

  @override
  void initState() {
    super.initState();
    _loadBest();
    _newGame();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => best = p.getInt('best') ?? 0);
  }

  Future<void> _saveBest() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('best', best);
  }

  void _newGame() {
    setState(() {
      grid = _empty();
      score = 0;
      over = false;
      won = false;
      keepPlaying = false;
      _prevGrid = null;
      _spawn();
      _spawn();
    });
  }

  void _spawn() {
    final empties = <Point<int>>[];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (grid[r][c] == 0) empties.add(Point(r, c));
      }
    }
    if (empties.isEmpty) return;
    final p = empties[_rng.nextInt(empties.length)];
    grid[p.x][p.y] = _rng.nextDouble() < 0.9 ? 2 : 4;
  }

  List<List<Point<int>>> _lines(Dir d) {
    final idx = List.generate(n, (i) => i);
    switch (d) {
      case Dir.left:
        return idx.map((r) => idx.map((c) => Point(r, c)).toList()).toList();
      case Dir.right:
        return idx.map((r) => idx.reversed.map((c) => Point(r, c)).toList()).toList();
      case Dir.up:
        return idx.map((c) => idx.map((r) => Point(r, c)).toList()).toList();
      case Dir.down:
        return idx.map((c) => idx.reversed.map((r) => Point(r, c)).toList()).toList();
    }
  }

  void _move(Dir d) {
    if (over) return;
    final before = grid.map((r) => List<int>.from(r)).toList();
    final scoreBefore = score;
    var changed = false;
    var gained = 0;

    for (final line in _lines(d)) {
      final vals = line.map((p) => grid[p.x][p.y]).where((v) => v != 0).toList();
      final merged = <int>[];
      var i = 0;
      while (i < vals.length) {
        if (i + 1 < vals.length && vals[i] == vals[i + 1]) {
          final v = vals[i] * 2;
          merged.add(v);
          gained += v;
          i += 2;
        } else {
          merged.add(vals[i]);
          i++;
        }
      }
      while (merged.length < n) {
        merged.add(0);
      }
      for (var k = 0; k < n; k++) {
        final p = line[k];
        if (grid[p.x][p.y] != merged[k]) changed = true;
        grid[p.x][p.y] = merged[k];
      }
    }

    if (!changed) return;

    setState(() {
      _prevGrid = before;
      _prevScore = scoreBefore;
      score += gained;
      if (score > best) {
        best = score;
        _saveBest();
      }
      _spawn();
      if (!won && !keepPlaying && grid.any((r) => r.contains(2048))) won = true;
      if (!_canMove()) over = true;
    });
  }

  bool _canMove() {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (grid[r][c] == 0) return true;
        if (c + 1 < n && grid[r][c] == grid[r][c + 1]) return true;
        if (r + 1 < n && grid[r][c] == grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  void _undo() {
    if (_prevGrid == null) return;
    setState(() {
      grid = _prevGrid!;
      score = _prevScore;
      _prevGrid = null;
      over = false;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 150) return;
    if (v.dx.abs() > v.dy.abs()) {
      _move(v.dx > 0 ? Dir.right : Dir.left);
    } else {
      _move(v.dy > 0 ? Dir.down : Dir.up);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _move(Dir.left);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _move(Dir.right);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(Dir.up);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _move(Dir.down);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tiles ko swipe karke jodo aur 2048 tak pahucho!',
                            style: TextStyle(color: Color(0xFF776E65), fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _btn('Undo', _undo),
                        const SizedBox(width: 8),
                        _btn('New', _newGame),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onPanEnd: _onPanEnd,
                      child: AspectRatio(aspectRatio: 1, child: _board()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('2048',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF776E65))),
        Row(children: [_scoreBox('SCORE', score), const SizedBox(width: 8), _scoreBox('BEST', best)]),
      ],
    );
  }

  Widget _scoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFBBADA0), borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFEEE4DA), fontSize: 11, fontWeight: FontWeight.bold)),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _btn(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8F7A66),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(text),
    );
  }

  Widget _board() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFBBADA0), borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          Column(
            children: List.generate(
              n,
              (r) => Expanded(
                child: Row(
                  children: List.generate(n, (c) => Expanded(child: _tile(grid[r][c]))),
                ),
              ),
            ),
          ),
          if (over) _overlay('Game Over!', 'Try Again', _newGame),
          if (won && !over) _overlay('Aap jeet gaye!', 'Khelte Raho', () => setState(() {
                won = false;
                keepPlaying = true;
              })),
        ],
      ),
    );
  }

  Widget _overlay(String title, String btnText, VoidCallback onTap) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCCEEE4DA),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF776E65))),
            const SizedBox(height: 16),
            _btn(btnText, onTap),
          ],
        ),
      ),
    );
  }

  Widget _tile(int v) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _tileColor(v), borderRadius: BorderRadius.circular(6)),
      child: v == 0
          ? null
          : FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$v',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: v <= 4 ? const Color(0xFF776E65) : Colors.white,
                  ),
                ),
              ),
            ),
    );
  }

  Color _tileColor(int v) {
    switch (v) {
      case 0:
        return const Color(0xFFCDC1B4);
      case 2:
        return const Color(0xFFEEE4DA);
      case 4:
        return const Color(0xFFEDE0C8);
      case 8:
        return const Color(0xFFF2B179);
      case 16:
        return const Color(0xFFF59563);
      case 32:
        return const Color(0xFFF67C5F);
      case 64:
        return const Color(0xFFF65E3B);
      case 128:
        return const Color(0xFFEDCF72);
      case 256:
        return const Color(0xFFEDCC61);
      case 512:
        return const Color(0xFFEDC850);
      case 1024:
        return const Color(0xFFEDC53F);
      case 2048:
        return const Color(0xFFEDC22E);
      default:
        return const Color(0xFF3C3A32);
    }
  }
}
