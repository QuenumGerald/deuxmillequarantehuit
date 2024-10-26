// game_screen.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class Tile {
  final int id;
  int value;
  int x;
  int y;
  bool merged;
  bool isNew;
  AnimationController? appearAnimationController;
  AnimationController? mergeAnimationController;
  Animation<double>? scaleAnimation;
  Animation<double>? oscillateAnimation;
  Animation<Color?>? colorAnimation;

  Tile({
    required this.id,
    required this.value,
    required this.x,
    required this.y,
    this.merged = false,
    this.isNew = false,
    this.appearAnimationController,
    this.mergeAnimationController,
    this.scaleAnimation,
    this.oscillateAnimation,
    this.colorAnimation,
  });
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int gridSize = 4;
  bool vibrationEnabled = true;
  late List<Tile> tiles;
  int score = 0;
  bool gameOver = false;
  bool won = false;
  int _tileIdCounter = 0;
  final Random random = Random();
  final AudioPlayer audioPlayer = AudioPlayer();
  late List<Source> popSounds;
  bool isMoving = false;
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  int _gameCount = 0;

  // Constantes pour la grille
  static const double cellSize = 75.0;       // Taille d'une cellule
  static const double cellSpacing = 85.0;    // Espacement entre les cellules
  static const double gridPadding = 7.0;     // Padding de la grille
  static const double animationOffset = 10.0; // Offset pour les animations

  @override
  void initState() {
    super.initState();
    MobileAds.instance.initialize();
    _loadBannerAd();
    _loadInterstitialAd();
    _initializeGame();
    popSounds = [
      AssetSource('merge.mp3'),
      AssetSource('merge1.mp3'),
      AssetSource('merge2.mp3'),
    ];
    audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // ID de test Android
          : 'ca-app-pub-3940256099942544/2934735716', // ID de test iOS
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Échec du chargement de la bannière : $error');
          ad.dispose();
          _bannerAd = null;
          // Réessayer de charger la pub après un échec
          Future.delayed(const Duration(minutes: 1), _loadBannerAd);
        },
      ),
    );
    _bannerAd?.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // ID de test Android
          : 'ca-app-pub-3940256099942544/4411468910', // ID de test iOS
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          // Configurer le callback de fermeture
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _isInterstitialAdReady = false;
              ad.dispose();
              _loadInterstitialAd(); // Recharger pour la prochaine fois
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isInterstitialAdReady = false;
              ad.dispose();
              _loadInterstitialAd(); // Réessayer de charger
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Échec du chargement de l\'interstitielle : $error');
          _isInterstitialAdReady = false;
          // Réessayer de charger après un délai
          Future.delayed(const Duration(minutes: 1), _loadInterstitialAd);
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd?.show();
    }
  }

  void _initializeGame() {
    tiles = [];
    _addRandomTile();
    _addRandomTile();
  }

  void _resetGame() {
    _gameCount++;
    if (_gameCount % 2 == 0) { // Afficher une pub toutes les 2 parties
      _showInterstitialAd();
    }

    setState(() {
      for (var tile in tiles) {
        tile.appearAnimationController?.dispose();
        tile.mergeAnimationController?.dispose();
      }
      tiles.clear();
      score = 0;
      gameOver = false;
      won = false;
      isMoving = false;
      _tileIdCounter = 0;
      _addRandomTile();
      _addRandomTile();
    });
  }

  Color _getTileColor(int value) {
    switch (value) {
      case 2:
        return const Color(0xffEEE4DA);
      case 4:
        return const Color(0xffEDE0C8);
      case 8:
        return const Color(0xffF2B179);
      case 16:
        return const Color(0xffF59563);
      case 32:
        return const Color(0xffF67C5F);
      case 64:
        return const Color(0xffF65E3B);
      case 128:
        return const Color(0xffEDCF72);
      case 256:
        return const Color(0xffEDCC61);
      case 512:
        return const Color(0xffEDC850);
      case 1024:
        return const Color(0xffEDC53F);
      case 2048:
        return const Color(0xffEDC22E);
      default:
        return const Color(0xffCDC1B4);
    }
  }

  Color _getTileTextColor(int value) {
    return value <= 4 ? const Color(0xff776E65) : Colors.white;
  }

  void _setupMergeAnimation(Tile tile) {
    final mergeAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Animation de mise à l'échelle
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: mergeAnimController,
        curve: Curves.easeInOut,
      ),
    );

    // Animation d'oscillation
    final oscillate = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.05),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: -0.05),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: mergeAnimController,
        curve: Curves.easeInOut,
      ),
    );

    // Animation de flash de couleur
    final baseColor = _getTileColor(tile.value);
    final highlightColor = HSLColor.fromColor(baseColor)
        .withLightness(min(1.0, HSLColor.fromColor(baseColor).lightness + 0.2))
        .withSaturation(min(1.0, HSLColor.fromColor(baseColor).saturation + 0.2))
        .toColor();

    final colorFlash = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: baseColor,
          end: highlightColor,
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: highlightColor,
          end: baseColor,
        ),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: mergeAnimController,
        curve: Curves.easeInOut,
      ),
    );

    tile.mergeAnimationController = mergeAnimController;
    tile.scaleAnimation = scale;
    tile.oscillateAnimation = oscillate;
    tile.colorAnimation = colorFlash;

    mergeAnimController.forward().then((_) {
      mergeAnimController.dispose();
      if (mounted) {
        setState(() {
          tile.mergeAnimationController = null;
          tile.scaleAnimation = null;
          tile.oscillateAnimation = null;
          tile.colorAnimation = null;
        });
      }
    });
  }

  Future<void> _playMergeSound() async {
    // Sélection du son basée sur une valeur aléatoire
    int index = random.nextInt(popSounds.length); // 0, 1, ou 2
    try {
      await audioPlayer.play(popSounds[index]);
    } catch (e) {
      print("Erreur de lecture du son: $e");
    }
  }

  Future<void> _playGameOverSound() async {
    await audioPlayer.play(AssetSource('game_over.mp3'));
  }

  void _addRandomTile() {
    List<Point<int>> emptyCells = [];
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (_getTileAt(x, y) == null) {
          emptyCells.add(Point(x, y));
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      final Point<int> cell = emptyCells[random.nextInt(emptyCells.length)];
      final AnimationController controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );

      _tileIdCounter++;
      final newTile = Tile(
        id: _tileIdCounter,
        value: random.nextDouble() < 0.9 ? 2 : 4,
        x: cell.x,
        y: cell.y,
        isNew: true,
        appearAnimationController: controller,
      );

      tiles.add(newTile);

      controller.forward().then((_) {
        controller.dispose();
        setState(() {
          newTile.isNew = false;
          newTile.appearAnimationController = null;
        });
      });
    }
  }

  Tile? _getTileAt(int x, int y) {
    for (var tile in tiles) {
      if (tile.x == x && tile.y == y) {
        return tile;
      }
    }
    return null;
  }

  void _onPanEnd(DragEndDetails details) {
    if (gameOver || isMoving) return;

    final dx = details.velocity.pixelsPerSecond.dx;
    final dy = details.velocity.pixelsPerSecond.dy;

    if (dx.abs() > dy.abs()) {
      if (dx > 0) {
        _move(Direction.right);
      } else {
        _move(Direction.left);
      }
    } else {
      if (dy > 0) {
        _move(Direction.down);
      } else {
        _move(Direction.up);
      }
    }
  }

  void _move(Direction direction) async {
    if (isMoving) return;

    setState(() {
      isMoving = true;
    });

    bool moved = false;
    tiles.forEach((tile) => tile.merged = false);

    List<Tile> sortedTiles = List.from(tiles);
    switch (direction) {
      case Direction.left:
        sortedTiles.sort((a, b) => a.y.compareTo(b.y));
        break;
      case Direction.right:
        sortedTiles.sort((a, b) => b.y.compareTo(a.y));
        break;
      case Direction.up:
        sortedTiles.sort((a, b) => a.x.compareTo(b.x));
        break;
      case Direction.down:
        sortedTiles.sort((a, b) => b.x.compareTo(a.x));
        break;
    }

    for (var tile in sortedTiles) {
      int targetX = tile.x;
      int targetY = tile.y;

      while (true) {
        int nextX = targetX;
        int nextY = targetY;

        switch (direction) {
          case Direction.left:
            nextY -= 1;
            break;
          case Direction.right:
            nextY += 1;
            break;
          case Direction.up:
            nextX -= 1;
            break;
          case Direction.down:
            nextX += 1;
            break;
        }

        if (nextX < 0 || nextX >= gridSize || nextY < 0 || nextY >= gridSize) {
          break;
        }

        Tile? nextTile = _getTileAt(nextX, nextY);
        if (nextTile == null) {
          targetX = nextX;
          targetY = nextY;
        } else if (nextTile.value == tile.value && !nextTile.merged && !tile.merged) {
          tiles.remove(nextTile);
          tile.value *= 2;
          tile.merged = true;
          targetX = nextX;
          targetY = nextY;
          score += tile.value;
          _setupMergeAnimation(tile);
          _playMergeSound();
          if (vibrationEnabled) {  // Vérifier si la vibration est activée
            Vibration.vibrate(duration: 30);
          }
          break;
        } else {
          break;
        }
      }

      if (tile.x != targetX || tile.y != targetY) {
        tile.x = targetX;
        tile.y = targetY;
        moved = true;
      }
    }

    if (moved) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
      _addRandomTile();
      _checkGameState();
    }

    setState(() {
      isMoving = false;
    });
  }

  void _checkGameState() {
    bool hasWon = false;
    bool canMove = false;

    List<List<int>> grid = List.generate(
      gridSize,
          (i) => List.generate(gridSize, (j) => 0),
    );

    for (var tile in tiles) {
      grid[tile.x][tile.y] = tile.value;
      if (tile.value == 2048) {
        hasWon = true;
      }
    }

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (grid[x][y] == 0) {
          canMove = true;
          break;
        }
        if (x < gridSize - 1 && grid[x][y] == grid[x + 1][y]) {
          canMove = true;
          break;
        }
        if (y < gridSize - 1 && grid[x][y] == grid[x][y + 1]) {
          canMove = true;
          break;
        }
      }
      if (canMove) break;
    }

    if (hasWon && !won) {
      setState(() {
        won = true;
      });
    }

    if (!canMove && !gameOver) {
      setState(() {
        gameOver = true;
      });
      _playGameOverSound();
    }
  }

  Widget _buildTile(Tile tile) {
    Widget tileWidget = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: tile.colorAnimation?.value ?? _getTileColor(tile.value),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          '${tile.value}',
          style: TextStyle(
            fontSize: tile.value > 512 ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: _getTileTextColor(tile.value),
          ),
        ),
      ),
    );

    if (tile.mergeAnimationController != null) {
      tileWidget = AnimatedBuilder(
        animation: tile.mergeAnimationController!,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..scale(tile.scaleAnimation!.value)
              ..translate(
                cellSpacing * tile.oscillateAnimation!.value,
                0.0,
              ),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: tileWidget,
      );
    }

    return Positioned(
      key: ValueKey(tile.id),
      left: tile.y * cellSpacing + gridPadding - animationOffset,
      top: tile.x * cellSpacing + gridPadding - animationOffset,
      child: Container(
        width: cellSize + 2 * animationOffset,
        height: cellSize + 2 * animationOffset,
        alignment: Alignment.center,
        child: tile.isNew && tile.appearAnimationController != null
            ? ScaleTransition(
          scale: CurvedAnimation(
            parent: tile.appearAnimationController!,
            curve: Curves.easeInOut,
          ),
          child: tileWidget,
        )
            : tileWidget,
      ),
    );
  }

  Widget _buildBannerAd() {
    if (_bannerAd == null) {
      return const SizedBox(height: 0);
    } else {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAF8EF),
      body: Stack(
        children: [
          SafeArea(
            // Contenu principal
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onPanEnd: _onPanEnd,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '2048',
                                    style: TextStyle(
                                      fontSize: 66,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff776E65),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        vibrationEnabled = !vibrationEnabled;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.vibration,
                                      color: vibrationEnabled
                                          ? const Color(0xff776E65)
                                          : const Color(0xffbbada0),
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Score: $score',
                                style: const TextStyle(
                                  fontSize: 44,
                                  color: Color(0xff776E65),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: 360,
                                height: 360,
                                padding: const EdgeInsets.all(gridPadding),
                                decoration: BoxDecoration(
                                  color: const Color(0xffBBADA0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Grille de fond
                                    for (int x = 0; x < gridSize; x++)
                                      for (int y = 0; y < gridSize; y++)
                                        Positioned(
                                          left: y * cellSpacing + gridPadding,
                                          top: x * cellSpacing + gridPadding,
                                          child: Container(
                                            width: cellSize,
                                            height: cellSize,
                                            decoration: BoxDecoration(
                                              color: const Color(0xffCDC1B4),
                                              borderRadius:
                                              BorderRadius.circular(3),
                                            ),
                                          ),
                                        ),
                                    // Tuiles
                                    ...tiles.map(_buildTile).toList(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (gameOver)
                                const Text(
                                  'Game Over!',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff776E65),
                                  ),
                                ),
                              if (won && !gameOver)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xEEEEE4DA),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'You Win!',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff776E65),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () => setState(() => won = false),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xff8f7a66),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: const Text(
                                          'Continue Playing',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _resetGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff8f7a66),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text(
                                  'Reset Game',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Publicité Bannière en bas
                _buildBannerAd(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    for (var tile in tiles) {
      tile.appearAnimationController?.dispose();
      tile.mergeAnimationController?.dispose();
    }
    audioPlayer.dispose();
    super.dispose();
  }
}

enum Direction { left, right, up, down }
