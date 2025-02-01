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

class CheckersGamePage extends StatefulWidget {
  const CheckersGamePage({super.key});

  @override
  State<CheckersGamePage> createState() => _CheckersGamePageState();
}

class _CheckersGamePageState extends State<CheckersGamePage> {
  // Representação do tabuleiro:
  // 0 = casa vazia, 1 = peça vermelha, 2 = peça preta.
  List<List<int>> board = List.generate(8, (index) => List.filled(8, 0));

  // Jogador atual: 1 (vermelho) ou 2 (preto)
  int currentPlayer = 1;

  // Coordenadas da peça selecionada (se houver)
  int? selectedRow;
  int? selectedCol;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
  }

  /// Inicializa o tabuleiro com a configuração padrão das damas.
  void _initializeBoard() {
    // Posiciona as peças apenas nas casas escuras ((linha + coluna) ímpar)
    // Coloca as peças pretas nas 3 primeiras linhas
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = 2; // peças pretas
        }
      }
    }
    // Coloca as peças vermelhas nas 3 últimas linhas
    for (int row = 5; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = 1; // peças vermelhas
        }
      }
    }
  }

  /// Função chamada ao tocar em uma casa do tabuleiro.
  void _onSquareTap(int row, int col) {
    // Se já há uma peça selecionada, tenta realizar o movimento.
    if (selectedRow != null && selectedCol != null) {
      if (_tryMove(selectedRow!, selectedCol!, row, col)) {
        setState(() {
          selectedRow = null;
          selectedCol = null;
          currentPlayer = (currentPlayer == 1) ? 2 : 1;
        });
        return;
      }
    }
    // Se não há peça selecionada ou o movimento não foi válido, tenta selecionar a peça.
    if (board[row][col] == currentPlayer) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
      });
    }
  }

  /// Verifica se o movimento de (fromRow, fromCol) para (toRow, toCol) é válido.
  /// Se for, realiza a movimentação (simples ou captura) e retorna true.
  bool _tryMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (board[toRow][toCol] != 0) return false;

    int rowDiff = toRow - fromRow;
    int colDiff = toCol - fromCol;

    // Direção do movimento: peças vermelhas se movem para cima e pretas para baixo
    int direction = (currentPlayer == 1) ? -1 : 1;

    // Movimento simples: uma casa diagonal na direção permitida
    if (rowDiff == direction && (colDiff == 1 || colDiff == -1)) {
      setState(() {
        board[toRow][toCol] = board[fromRow][fromCol];
        board[fromRow][fromCol] = 0;
      });
      return true;
    }
    // Movimento de captura: duas casas diagonais
    if (rowDiff == 2 * direction && (colDiff == 2 || colDiff == -2)) {
      int midRow = fromRow + direction;
      int midCol = fromCol + (colDiff ~/ 2);
      if (board[midRow][midCol] != 0 &&
          board[midRow][midCol] != currentPlayer) {
        setState(() {
          board[toRow][toCol] = board[fromRow][fromCol];
          board[fromRow][fromCol] = 0;
          board[midRow][midCol] = 0; // remove a peça capturada
        });
        return true;
      }
    }
    return false;
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

        if (selectedRow == row && selectedCol == col) {
          squareColor = Colors.yellow;
        }

        Widget pieceWidget = Container();
        if (board[row][col] != 0) {
          Color pieceColor = (board[row][col] == 1) ? Colors.red : Colors.black;
          pieceWidget = Center(
            child: Container(
              width: squareSize * 0.8,
              height: squareSize * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pieceColor,
              ),
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
        child: _buildBoard(),
      ),
    );
  }
}
