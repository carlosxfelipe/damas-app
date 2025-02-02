import 'package:flutter/material.dart';

void main() {
  runApp(const CheckersApp());
}

class CheckersApp extends StatelessWidget {
  const CheckersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jogo de Damas',
      debugShowCheckedModeBanner: false,
      // Tema claro (padrão)
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      // Tema escuro, utilizado quando o sistema estiver em dark mode.
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: ThemeData.dark().textTheme,
      ),
      // Faz com que o tema seja definido conforme a preferência do sistema.
      themeMode: ThemeMode.system,
      home: const CheckersGamePage(),
    );
  }
}

/// Representa um movimento de uma casa para outra.
class Move {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;

  Move({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
  });

  /// Considera como movimento de captura se a distância for maior que 1.
  bool get isCapture => (toRow - fromRow).abs() > 1;
}

/// Retorna se a peça pertence ao jogador.
/// Para o jogador 1 (vermelho), as peças válidas são: 1 (pedra) e 3 (dama);
/// para o jogador 2 (preto), as peças válidas são: 2 (pedra) e 4 (dama).
bool belongsTo(int piece, int player) {
  if (player == 1) return piece == 1 || piece == 3;
  if (player == 2) return piece == 2 || piece == 4;
  return false;
}

/// Retorna se a peça é uma dama.
bool isKing(int piece) {
  return piece == 3 || piece == 4;
}

class CheckersGamePage extends StatefulWidget {
  const CheckersGamePage({super.key});

  @override
  State<CheckersGamePage> createState() => _CheckersGamePageState();
}

class _CheckersGamePageState extends State<CheckersGamePage> {
  /// boardSize pode ser 8 (64 casas) ou 10 (100 casas)
  int boardSize = 8;
  late List<List<int>> board;

  /// Jogador atual: 1 (vermelho – humano) ou 2 (preto – IA)
  int currentPlayer = 1;

  /// Coordenadas da peça selecionada (se houver)
  int? selectedRow;
  int? selectedCol;

  /// Controle do tempo de jogo
  late DateTime _startTime;

  /// Flag para indicar que o jogo acabou
  bool _gameOver = false;

  /// Conta os lances consecutivos de damas (sem captura nem deslocamento de pedra)
  int _consecutiveKingMovesWithoutCapture = 0;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
    _startTime = DateTime.now();
  }

  /// Inicializa o tabuleiro de acordo com o tamanho escolhido:
  /// • 8×8: 3 linhas de peças para cada jogador (pedras)
  /// • 10×10: 4 linhas de peças para cada jogador (pedras)
  void _initializeBoard() {
    board = List.generate(boardSize, (index) => List.filled(boardSize, 0));
    int numRows = boardSize == 8 ? 3 : 4;

    // Peças pretas (jogador 2) nas primeiras linhas (nas casas escuras)
    for (int row = 0; row < numRows; row++) {
      for (int col = 0; col < boardSize; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = 2; // pedra preta
        }
      }
    }
    // Peças vermelhas (jogador 1) nas últimas linhas (nas casas escuras)
    for (int row = boardSize - numRows; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = 1; // pedra vermelha
        }
      }
    }
  }

  /// Verifica se, após o movimento, a peça atingiu a última linha e a promove à dama.
  void _checkPromotion(int row, int col) {
    int piece = board[row][col];
    if (piece == 1 && row == 0) {
      board[row][col] = 3; // promove pedra vermelha a dama
    }
    if (piece == 2 && row == boardSize - 1) {
      board[row][col] = 4; // promove pedra preta a dama
    }
  }

  /// Se ocorrerem muitos lances consecutivos de dama sem captura nem deslocamento de pedra,
  /// declara empate.
  void _checkDrawCondition() {
    int threshold = boardSize == 8
        ? 40
        : 50; // 20 lances de cada jogador = 40 (ou 25 para 100 casas)
    if (_consecutiveKingMovesWithoutCapture >= threshold) {
      _gameOver = true;
      Duration duration = DateTime.now().difference(_startTime);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Fim de Jogo"),
            content: Text(
                "Empate por excesso de lances de dama sem captura.\nTempo da partida: ${duration.inMinutes} minuto(s) e ${duration.inSeconds % 60} segundo(s)"),
            actions: [
              TextButton(
                onPressed: () {
                  _resetGame();
                  Navigator.of(context).pop();
                },
                child: const Text("Ok"),
              ),
            ],
          );
        },
      );
    }
  }

  /// Tenta mover a peça de (fromRow, fromCol) para (toRow, toCol), respeitando:
  /// – Se houver captura disponível, somente movimentos de captura são permitidos.
  /// – Para pedras: o movimento simples é somente para frente; a captura pode ser em qualquer direção.
  /// – Para damas: o movimento simples e de captura se dá ao longo da diagonal inteira,
  ///   mas para capturar, deve-se “pular” exatamente uma peça adversária.
  bool _tryMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (board[toRow][toCol] != 0) return false;
    int piece = board[fromRow][fromCol];
    bool king = isKing(piece);
    List<Move> validMoves = _getValidMovesForPlayer(currentPlayer);
    bool captureExists = validMoves.any((move) => move.isCapture);

    int rowDiff = toRow - fromRow;
    int colDiff = toCol - fromCol;

    if (king) {
      // Movimentos de dama: verifica se o movimento é diagonal
      if (!_isDiagonal(fromRow, fromCol, toRow, toCol)) return false;
      int steps = rowDiff.abs();
      int stepRow = rowDiff ~/ steps;
      int stepCol = colDiff ~/ steps;
      int enemyCount = 0;
      int enemyRow = -1, enemyCol = -1;
      // Percorre todos os quadrados entre a origem e o destino
      for (int d = 1; d <= steps; d++) {
        int r = fromRow + d * stepRow;
        int c = fromCol + d * stepCol;
        if (board[r][c] != 0) {
          if (belongsTo(board[r][c], currentPlayer)) return false;
          enemyCount++;
          enemyRow = r;
          enemyCol = c;
          if (enemyCount > 1) return false;
        }
      }
      // Se houver possibilidade de captura em outro lance, não permite simples (sem captura)
      if (captureExists && enemyCount == 0) return false;
      if (enemyCount == 0) {
        // Movimento simples da dama
        setState(() {
          board[toRow][toCol] = piece;
          board[fromRow][fromCol] = 0;
          _consecutiveKingMovesWithoutCapture++;
        });
      } else if (enemyCount == 1) {
        // Movimento de captura: remove a peça adversária
        setState(() {
          board[toRow][toCol] = piece;
          board[fromRow][fromCol] = 0;
          board[enemyRow][enemyCol] = 0;
          _consecutiveKingMovesWithoutCapture = 0;
        });
      }
      _checkDrawCondition();
      return true;
    } else {
      // Para pedra normal:
      // Movimento simples: somente para frente.
      int forward = currentPlayer == 1 ? -1 : 1;
      if (!captureExists && rowDiff == forward && colDiff.abs() == 1) {
        setState(() {
          board[toRow][toCol] = piece;
          board[fromRow][fromCol] = 0;
          _checkPromotion(toRow, toCol);
          _consecutiveKingMovesWithoutCapture = 0;
        });
        return true;
      }
      // Movimento de captura: permite salto em qualquer direção (2 casas)
      if (rowDiff.abs() == 2 && colDiff.abs() == 2) {
        int midRow = fromRow + rowDiff ~/ 2;
        int midCol = fromCol + colDiff ~/ 2;
        if (board[midRow][midCol] != 0 &&
            !belongsTo(board[midRow][midCol], currentPlayer)) {
          setState(() {
            board[toRow][toCol] = piece;
            board[fromRow][fromCol] = 0;
            board[midRow][midCol] = 0;
            _checkPromotion(toRow, toCol);
            _consecutiveKingMovesWithoutCapture = 0;
          });
          return true;
        }
      }
      return false;
    }
  }

  /// Retorna true se (toRow,toCol) está numa diagonal de (fromRow,fromCol)
  bool _isDiagonal(int fromRow, int fromCol, int toRow, int toCol) {
    return (toRow - fromRow).abs() == (toCol - fromCol).abs() &&
        (toRow - fromRow) != 0;
  }

  /// Retorna uma lista de movimentos válidos para o jogador especificado,
  /// levando em conta as regras diferenciadas para pedras e damas.
  List<Move> _getValidMovesForPlayer(int player) {
    List<Move> moves = [];
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        int piece = board[row][col];
        if (!belongsTo(piece, player)) continue;
        if (isKing(piece)) {
          // Movimentos da dama: em todas as diagonais.
          for (int dRow in [-1, 1]) {
            for (int dCol in [-1, 1]) {
              int r = row + dRow;
              int c = col + dCol;
              bool enemyFound = false;
              while (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
                if (board[r][c] == 0) {
                  // Se ainda não encontrou inimigo, ou se já encontrou, este é destino de captura
                  moves.add(
                      Move(fromRow: row, fromCol: col, toRow: r, toCol: c));
                } else {
                  if (belongsTo(board[r][c], player)) break;
                  if (!enemyFound) {
                    enemyFound = true;
                  } else {
                    break;
                  }
                }
                r += dRow;
                c += dCol;
              }
            }
          }
        } else {
          // Para pedra normal:
          int forward = player == 1 ? -1 : 1;
          // Movimento simples (somente para frente)
          int newRow = row + forward;
          for (int dCol in [-1, 1]) {
            int newCol = col + dCol;
            if (newRow >= 0 &&
                newRow < boardSize &&
                newCol >= 0 &&
                newCol < boardSize &&
                board[newRow][newCol] == 0) {
              moves.add(Move(
                  fromRow: row, fromCol: col, toRow: newRow, toCol: newCol));
            }
          }
          // Movimento de captura: em qualquer direção (salto de 2 casas)
          for (int dRow in [-2, 2]) {
            for (int dCol in [-2, 2]) {
              int targetRow = row + dRow;
              int targetCol = col + dCol;
              if (targetRow >= 0 &&
                  targetRow < boardSize &&
                  targetCol >= 0 &&
                  targetCol < boardSize &&
                  board[targetRow][targetCol] == 0) {
                int midRow = row + dRow ~/ 2;
                int midCol = col + dCol ~/ 2;
                if (board[midRow][midCol] != 0 &&
                    !belongsTo(board[midRow][midCol], player)) {
                  moves.add(Move(
                      fromRow: row,
                      fromCol: col,
                      toRow: targetRow,
                      toCol: targetCol));
                }
              }
            }
          }
        }
      }
    }
    return moves;
  }

  /// Verifica se a peça, a partir da posição (row, col), tem alguma captura adicional disponível.
  bool _hasAdditionalCapture(int row, int col) {
    int piece = board[row][col];
    if (isKing(piece)) {
      // Para dama: varre todas as diagonais.
      for (int dRow in [-1, 1]) {
        for (int dCol in [-1, 1]) {
          int r = row + dRow;
          int c = col + dCol;
          bool enemyFound = false;
          while (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
            if (board[r][c] == 0) {
              if (enemyFound) return true;
            } else {
              if (belongsTo(board[r][c], currentPlayer)) break;
              if (!enemyFound) {
                enemyFound = true;
              } else {
                break;
              }
            }
            r += dRow;
            c += dCol;
          }
        }
      }
      return false;
    } else {
      // Para pedra: verifica saltos de 2 casas em qualquer diagonal.
      for (int dRow in [-2, 2]) {
        for (int dCol in [-2, 2]) {
          int targetRow = row + dRow;
          int targetCol = col + dCol;
          if (targetRow >= 0 &&
              targetRow < boardSize &&
              targetCol >= 0 &&
              targetCol < boardSize &&
              board[targetRow][targetCol] == 0) {
            int midRow = row + dRow ~/ 2;
            int midCol = col + dCol ~/ 2;
            if (midRow >= 0 &&
                midRow < boardSize &&
                midCol >= 0 &&
                midCol < boardSize) {
              if (board[midRow][midCol] != 0 &&
                  !belongsTo(board[midRow][midCol], currentPlayer)) {
                return true;
              }
            }
          }
        }
      }
      return false;
    }
  }

  /// Verifica se o jogo acabou (ou se não há movimentos disponíveis)
  /// e, se sim, exibe uma janela com o vencedor.
  void _checkGameOver() {
    if (_gameOver) return;
    List<Move> moves = _getValidMovesForPlayer(currentPlayer);
    if (moves.isEmpty) {
      _gameOver = true;
      int winner = currentPlayer == 1 ? 2 : 1;
      Duration duration = DateTime.now().difference(_startTime);
      _showGameOverDialog(
          "Vencedor: Jogador $winner\nTempo da partida: ${duration.inMinutes} minuto(s) e ${duration.inSeconds % 60} segundo(s)");
    }
  }

  void _resetGame() {
    setState(() {
      _consecutiveKingMovesWithoutCapture = 0;
      board = List.generate(boardSize, (index) => List.filled(boardSize, 0));
      _initializeBoard();
      currentPlayer = 1;
      selectedRow = null;
      selectedCol = null;
      _startTime = DateTime.now();
      _gameOver = false;
    });
  }

  /// Exibe uma janela informando o fim do jogo.
  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Fim de Jogo"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                _resetGame();
                Navigator.of(context).pop();
              },
              child: const Text("Ok"),
            ),
          ],
        );
      },
    );
  }

  /// Controle de toque do jogador humano.
  /// Se já há uma peça selecionada e o movimento for válido, tenta movê-la.
  /// Se o movimento for de captura e houver possibilidade de encadeamento, a peça permanece selecionada.
  void _onSquareTap(int row, int col) {
    if (_gameOver) return;

    if (selectedRow != null && selectedCol != null) {
      int oldRow = selectedRow!;
      int oldCol = selectedCol!;
      bool wasCapture = (row - oldRow).abs() > 1;
      if (_tryMove(oldRow, oldCol, row, col)) {
        if (wasCapture && _hasAdditionalCapture(row, col)) {
          setState(() {
            selectedRow = row;
            selectedCol = col;
            // O turno permanece com o mesmo jogador.
          });
        } else {
          setState(() {
            selectedRow = null;
            selectedCol = null;
            currentPlayer = currentPlayer == 1 ? 2 : 1;
          });
          _checkGameOver();
          if (currentPlayer == 2 && !_gameOver) {
            Future.delayed(const Duration(milliseconds: 500), _makeAIMove);
          }
        }
        return;
      }
    }
    // Seleciona a peça se ela pertencer ao jogador atual.
    if (belongsTo(board[row][col], currentPlayer)) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
      });
    }
  }

  /// Realiza a jogada da IA (adversário).
  /// A IA escolhe, de forma aleatória, dentre os movimentos válidos (priorizando capturas)
  /// e, se o movimento permitir encadeamento de capturas, continua jogando.
  void _makeAIMove() async {
    if (_gameOver) return;

    await Future.delayed(const Duration(milliseconds: 500));
    List<Move> validMoves = _getValidMovesForPlayer(currentPlayer);
    if (validMoves.isEmpty) {
      _checkGameOver();
      return;
    }
    List<Move> captureMoves =
        validMoves.where((move) => move.isCapture).toList();
    if (captureMoves.isNotEmpty) {
      validMoves = captureMoves;
    }
    validMoves.shuffle();
    Move move = validMoves.first;
    setState(() {
      // Se for captura, remove a peça adversária.
      if (move.isCapture) {
        if (!isKing(board[move.fromRow][move.fromCol])) {
          int midRow = (move.fromRow + move.toRow) ~/ 2;
          int midCol = (move.fromCol + move.toCol) ~/ 2;
          board[midRow][midCol] = 0;
        } else {
          int steps = (move.toRow - move.fromRow).abs();
          int stepRow = (move.toRow - move.fromRow) ~/ steps;
          int stepCol = (move.toCol - move.fromCol) ~/ steps;
          for (int d = 1; d <= steps; d++) {
            int r = move.fromRow + d * stepRow;
            int c = move.fromCol + d * stepCol;
            if (board[r][c] != 0 && !belongsTo(board[r][c], currentPlayer)) {
              board[r][c] = 0;
              break;
            }
          }
        }
      }
      int piece = board[move.fromRow][move.fromCol];
      board[move.toRow][move.toCol] = piece;
      board[move.fromRow][move.fromCol] = 0;
      _checkPromotion(move.toRow, move.toCol);
    });
    if (move.isCapture && _hasAdditionalCapture(move.toRow, move.toCol)) {
      Future.delayed(const Duration(milliseconds: 500), _makeAIMove);
      return;
    }
    setState(() {
      currentPlayer = 1;
    });
    _checkGameOver();
  }

  /// Constrói a interface gráfica do tabuleiro.
  Widget _buildBoard() {
    double boardWidth = MediaQuery.of(context).size.width;
    double squareSize = boardWidth / boardSize;
    List<Widget> rowsWidgets = [];

    for (int row = 0; row < boardSize; row++) {
      List<Widget> rowSquares = [];
      for (int col = 0; col < boardSize; col++) {
        bool isDark = (row + col) % 2 == 1;
        Color squareColor = isDark ? Colors.brown : Colors.grey[300]!;
        if (selectedRow == row && selectedCol == col) {
          squareColor = Colors.yellow;
        }
        Widget pieceWidget = Container();
        int piece = board[row][col];
        if (piece != 0) {
          Color pieceColor =
              (piece == 1 || piece == 3) ? Colors.red : Colors.black;
          bool king = isKing(piece);
          pieceWidget = Center(
            child: Container(
              width: squareSize * 0.8,
              height: squareSize * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pieceColor,
                border:
                    king ? Border.all(color: Colors.yellow, width: 3) : null,
              ),
              child: king
                  ? Center(
                      child: Text(
                        "K",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: squareSize * 0.4,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }
        rowSquares.add(GestureDetector(
          onTap: () => _onSquareTap(row, col),
          child: Container(
            width: squareSize,
            height: squareSize,
            color: squareColor,
            child: pieceWidget,
          ),
        ));
      }
      rowsWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: rowSquares,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rowsWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jogo de Damas"),
        actions: [
          // Botão para escolher tabuleiro de 64 ou 100 casas.
          IconButton(
            icon: Text(boardSize == 8 ? "64 casas" : "100 casas"),
            onPressed: () {
              setState(() {
                boardSize = boardSize == 8 ? 10 : 8;
                _resetGame();
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBoard(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _resetGame,
              child: const Text("Resetar Jogo"),
            ),
          ],
        ),
      ),
    );
  }
}
