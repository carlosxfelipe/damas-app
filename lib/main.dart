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

  /// Se a diferença de linhas for 2, trata-se de um movimento de captura.
  bool get isCapture => (toRow - fromRow).abs() == 2;
}

/// Retorna se a peça pertence ao jogador.
/// Para o jogador 1 (vermelho), as peças válidas são 1 (normal) e 3 (dama);
/// para o jogador 2 (preto), as peças válidas são 2 (normal) e 4 (dama).
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
  // Representação do tabuleiro:
  // 0 = casa vazia,
  // 1 = peça vermelha normal,
  // 2 = peça preta normal,
  // 3 = dama vermelha,
  // 4 = dama preta.
  List<List<int>> board = List.generate(8, (index) => List.filled(8, 0));

  // Jogador atual: 1 (vermelho – humano) ou 2 (preto – IA)
  int currentPlayer = 1;

  // Coordenadas da peça selecionada (se houver)
  int? selectedRow;
  int? selectedCol;

  // Controle do tempo de jogo
  late DateTime _startTime;

  // Flag para indicar que o jogo acabou
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
    _startTime = DateTime.now();
  }

  /// Inicializa o tabuleiro com a configuração padrão das damas.
  void _initializeBoard() {
    // Peças pretas nas 3 primeiras linhas (nas casas escuras)
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = 2; // peça preta normal
        }
      }
    }
    // Peças vermelhas nas 3 últimas linhas (nas casas escuras)
    for (int row = 5; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = 1; // peça vermelha normal
        }
      }
    }
  }

  /// Verifica se, após o movimento, a peça atingiu a última linha adversária e a promove a dama.
  void _checkPromotion(int row, int col) {
    int piece = board[row][col];
    if (piece == 1 && row == 0) {
      board[row][col] = 3; // promove peça vermelha normal a dama vermelha.
    }
    if (piece == 2 && row == 7) {
      board[row][col] = 4; // promove peça preta normal a dama preta.
    }
  }

  /// Verifica se a peça, a partir da posição (row, col), tem alguma captura adicional disponível.
  bool _hasAdditionalCapture(int row, int col) {
    int piece = board[row][col];
    if (!isKing(piece)) {
      int direction = (currentPlayer == 1) ? -1 : 1;
      for (int delta in [-2, 2]) {
        int newRow = row + 2 * direction;
        int newCol = col + delta;
        if (newRow >= 0 &&
            newRow < 8 &&
            newCol >= 0 &&
            newCol < 8 &&
            board[newRow][newCol] == 0) {
          int midRow = row + direction;
          int midCol = col + (delta ~/ 2);
          if (midRow >= 0 &&
              midRow < 8 &&
              midCol >= 0 &&
              midCol < 8 &&
              board[midRow][midCol] != 0 &&
              !belongsTo(board[midRow][midCol], currentPlayer)) {
            return true;
          }
        }
      }
      return false;
    } else {
      // Para dama: verifica em todas as diagonais.
      for (int dRow in [-1, 1]) {
        for (int dCol in [-1, 1]) {
          int newRow = row + 2 * dRow;
          int newCol = col + 2 * dCol;
          if (newRow >= 0 &&
              newRow < 8 &&
              newCol >= 0 &&
              newCol < 8 &&
              board[newRow][newCol] == 0) {
            int midRow = row + dRow;
            int midCol = col + dCol;
            if (midRow >= 0 &&
                midRow < 8 &&
                midCol >= 0 &&
                midCol < 8 &&
                board[midRow][midCol] != 0 &&
                !belongsTo(board[midRow][midCol], currentPlayer)) {
              return true;
            }
          }
        }
      }
      return false;
    }
  }

  /// Tenta mover a peça de (fromRow, fromCol) para (toRow, toCol).
  /// Se o movimento for válido (simples ou de captura) e obedecer à regra de captura obrigatória,
  /// atualiza o tabuleiro e retorna true.
  bool _tryMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (board[toRow][toCol] != 0) return false;

    int piece = board[fromRow][fromCol];
    bool king = isKing(piece);
    List<Move> validMoves = _getValidMovesForPlayer(currentPlayer);
    bool captureExists = validMoves.any((move) => move.isCapture);

    int rowDiff = toRow - fromRow;
    int colDiff = toCol - fromCol;

    if (captureExists) {
      // Se houver captura disponível, somente movimentos de captura são permitidos.
      if (!king) {
        int direction = (currentPlayer == 1) ? -1 : 1;
        if (rowDiff == 2 * direction && (colDiff == 2 || colDiff == -2)) {
          int midRow = fromRow + direction;
          int midCol = fromCol + (colDiff ~/ 2);
          if (board[midRow][midCol] != 0 &&
              !belongsTo(board[midRow][midCol], currentPlayer)) {
            setState(() {
              board[toRow][toCol] = piece;
              board[fromRow][fromCol] = 0;
              board[midRow][midCol] = 0;
              _checkPromotion(toRow, toCol);
            });
            return true;
          }
        }
        return false;
      } else {
        // Para dama: captura se mover duas casas em ambas as direções.
        if (rowDiff.abs() == 2 && colDiff.abs() == 2) {
          int midRow = (fromRow + toRow) ~/ 2;
          int midCol = (fromCol + toCol) ~/ 2;
          if (board[midRow][midCol] != 0 &&
              !belongsTo(board[midRow][midCol], currentPlayer)) {
            setState(() {
              board[toRow][toCol] = piece;
              board[fromRow][fromCol] = 0;
              board[midRow][midCol] = 0;
            });
            return true;
          }
        }
        return false;
      }
    } else {
      // Se não há captura disponível, permite movimento simples (ou captura se for válido).
      if (!king) {
        int direction = (currentPlayer == 1) ? -1 : 1;
        // Movimento simples
        if (rowDiff == direction && (colDiff == 1 || colDiff == -1)) {
          setState(() {
            board[toRow][toCol] = piece;
            board[fromRow][fromCol] = 0;
            _checkPromotion(toRow, toCol);
          });
          return true;
        }
        // Movimento de captura
        if (rowDiff == 2 * direction && (colDiff == 2 || colDiff == -2)) {
          int midRow = fromRow + direction;
          int midCol = colDiff ~/ 2 + fromCol;
          if (board[midRow][midCol] != 0 &&
              !belongsTo(board[midRow][midCol], currentPlayer)) {
            setState(() {
              board[toRow][toCol] = piece;
              board[fromRow][fromCol] = 0;
              board[midRow][midCol] = 0;
              _checkPromotion(toRow, toCol);
            });
            return true;
          }
        }
        return false;
      } else {
        // Para dama: movimento simples em qualquer diagonal.
        if (rowDiff.abs() == 1 && colDiff.abs() == 1) {
          setState(() {
            board[toRow][toCol] = piece;
            board[fromRow][fromCol] = 0;
          });
          return true;
        }
        // Captura: duas casas em qualquer diagonal.
        if (rowDiff.abs() == 2 && colDiff.abs() == 2) {
          int midRow = (fromRow + toRow) ~/ 2;
          int midCol = (fromCol + toCol) ~/ 2;
          if (board[midRow][midCol] != 0 &&
              !belongsTo(board[midRow][midCol], currentPlayer)) {
            setState(() {
              board[toRow][toCol] = piece;
              board[fromRow][fromCol] = 0;
              board[midRow][midCol] = 0;
            });
            return true;
          }
        }
        return false;
      }
    }
  }

  /// Retorna uma lista de movimentos válidos para o jogador especificado.
  List<Move> _getValidMovesForPlayer(int player) {
    List<Move> moves = [];
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        int piece = board[row][col];
        if (!belongsTo(piece, player)) continue;

        if (!isKing(piece)) {
          int direction = (player == 1) ? -1 : 1;
          // Movimento simples
          int newRow = row + direction;
          for (int delta in [-1, 1]) {
            int newCol = col + delta;
            if (newRow >= 0 &&
                newRow < 8 &&
                newCol >= 0 &&
                newCol < 8 &&
                board[newRow][newCol] == 0) {
              moves.add(Move(
                  fromRow: row, fromCol: col, toRow: newRow, toCol: newCol));
            }
          }
          // Movimento de captura
          int captureRow = row + 2 * direction;
          for (int delta in [-2, 2]) {
            int captureCol = col + delta;
            if (captureRow >= 0 &&
                captureRow < 8 &&
                captureCol >= 0 &&
                captureCol < 8 &&
                board[captureRow][captureCol] == 0) {
              int midRow = row + direction;
              int midCol = col + (delta ~/ 2);
              if (midRow >= 0 &&
                  midRow < 8 &&
                  midCol >= 0 &&
                  midCol < 8 &&
                  board[midRow][midCol] != 0 &&
                  !belongsTo(board[midRow][midCol], player)) {
                moves.add(Move(
                    fromRow: row,
                    fromCol: col,
                    toRow: captureRow,
                    toCol: captureCol));
              }
            }
          }
        } else {
          // Para dama: movimenta-se em qualquer diagonal.
          for (int dRow in [-1, 1]) {
            for (int dCol in [-1, 1]) {
              int newRow = row + dRow;
              int newCol = col + dCol;
              if (newRow >= 0 &&
                  newRow < 8 &&
                  newCol >= 0 &&
                  newCol < 8 &&
                  board[newRow][newCol] == 0) {
                moves.add(Move(
                    fromRow: row, fromCol: col, toRow: newRow, toCol: newCol));
              }
              int capRow = row + 2 * dRow;
              int capCol = col + 2 * dCol;
              if (capRow >= 0 &&
                  capRow < 8 &&
                  capCol >= 0 &&
                  capCol < 8 &&
                  board[capRow][capCol] == 0) {
                int midRow = row + dRow;
                int midCol = col + dCol;
                if (midRow >= 0 &&
                    midRow < 8 &&
                    midCol >= 0 &&
                    midCol < 8 &&
                    board[midRow][midCol] != 0 &&
                    !belongsTo(board[midRow][midCol], player)) {
                  moves.add(Move(
                      fromRow: row,
                      fromCol: col,
                      toRow: capRow,
                      toCol: capCol));
                }
              }
            }
          }
        }
      }
    }
    return moves;
  }

  /// Verifica se o jogo acabou e, se sim, exibe a janela com o vencedor e o tempo decorrido.
  void _checkGameOver() {
    if (_gameOver) return;
    List<Move> moves = _getValidMovesForPlayer(currentPlayer);
    if (moves.isEmpty) {
      _gameOver = true;
      // Se o jogador atual não possui movimentos, o vencedor é o outro jogador.
      int winner = (currentPlayer == 1) ? 2 : 1;
      Duration duration = DateTime.now().difference(_startTime);
      _showGameOverDialog(winner, duration);
    }
  }

  void _resetGame() {
    setState(() {
      board = List.generate(8, (index) => List.filled(8, 0));
      _initializeBoard();
      currentPlayer = 1;
      selectedRow = null;
      selectedCol = null;
      _startTime = DateTime.now();
      _gameOver = false;
    });
  }

  /// Exibe uma janela informando o vencedor e o tempo da partida.
  void _showGameOverDialog(int winner, Duration duration) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Fim de Jogo"),
          content: Text(
              "Vencedor: Jogador $winner\nTempo da partida: ${duration.inMinutes} minuto(s) e ${duration.inSeconds % 60} segundo(s)"),
          actions: [
            TextButton(
              onPressed: () {
                _resetGame(); // Reinicia o jogo
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
  /// Se o movimento for de captura e houver captura adicional, a peça permanece selecionada para continuar.
  void _onSquareTap(int row, int col) {
    if (_gameOver) return;

    if (selectedRow != null && selectedCol != null) {
      int oldRow = selectedRow!;
      int oldCol = selectedCol!;
      // Se a diferença de linhas for 2, o movimento é de captura.
      bool wasCapture = ((row - oldRow).abs() == 2);
      if (_tryMove(oldRow, oldCol, row, col)) {
        if (wasCapture && _hasAdditionalCapture(row, col)) {
          // Permanece com a mesma peça para continuar capturando.
          setState(() {
            selectedRow = row;
            selectedCol = col;
            // O turno permanece com o mesmo jogador.
          });
        } else {
          setState(() {
            selectedRow = null;
            selectedCol = null;
            currentPlayer = (currentPlayer == 1) ? 2 : 1;
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
  /// e, se o movimento for de captura com possibilidade de encadeamento, continua jogando.
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
      if (move.isCapture) {
        int midRow = (move.fromRow + move.toRow) ~/ 2;
        int midCol = (move.fromCol + move.toCol) ~/ 2;
        board[midRow][midCol] = 0;
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
    double boardSize = MediaQuery.of(context).size.width;
    double squareSize = boardSize / 8;
    List<Widget> rowsWidgets = [];

    for (int row = 0; row < 8; row++) {
      List<Widget> rowSquares = [];
      for (int col = 0; col < 8; col++) {
        bool isDarkSquare = (row + col) % 2 == 1;
        Color squareColor = isDarkSquare ? Colors.brown : Colors.grey[300]!;

        // Destaca a casa da peça selecionada.
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
                // Se a peça for dama, adiciona uma borda para destacá-la.
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
