import 'package:flutter/material.dart';
import 'dart:math';

import '../../../core/models/prize_item.dart';

class FortuneWheel extends StatefulWidget {
  final List<PrizeItem> items;
  final Function(PrizeItem)? onSpinEnd;

  const FortuneWheel({super.key, required this.items, this.onSpinEnd});

  @override
  FortuneWheelState createState() => FortuneWheelState();
}

class FortuneWheelState extends State<FortuneWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Random _random = Random();
  double _currentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animation = Tween<double>(begin: 0, end: 0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
  }

  // MÉTODO CON LA FÓRMULA SIMPLIFICADA Y FINAL
  Future<void> spinTo(int prizeIndex) {
    if (_controller.isAnimating) return Future.value();

    final double anglePerItem = 2 * pi / widget.items.length;
    // 1. Calculamos el ángulo final donde debe detenerse la ruleta.
    //    El puntero está arriba (en -pi/2), y el centro del primer premio (índice 0) también.
    //    Por lo tanto, para llegar al premio 'prizeIndex', necesitamos rotar esa cantidad de "porciones".
    final double targetAngle = - (prizeIndex * anglePerItem);

    // 2. Añadimos un número fijo de rotaciones completas para el efecto visual.
    final double fullSpins = 5 * (2 * pi);

    // 3. El ángulo final de la animación es la posición actual, menos los giros completos,
    //    menos el ángulo necesario para llegar al objetivo.
    final double endAngle = _currentAngle - fullSpins - ( (_currentAngle % (2 * pi)) - targetAngle );

    _animation = Tween<double>(begin: _currentAngle, end: endAngle)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _currentAngle = endAngle;

    return _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animation.value,
              child: child,
            );
          },
          child: CustomPaint(
            size: const Size.square(300),
            painter: RoulettePainter(items: widget.items),
          ),
        ),
        const RoulettePointer(),
      ],
    );
  }
}

// --- EL RESTO DEL ARCHIVO (RoulettePointer, _PointerPainter, RoulettePainter) ---
// --- NO NECESITA CAMBIOS Y SE MANTIENE IGUAL ---

class RoulettePointer extends StatelessWidget {
  const RoulettePointer({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 30),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade800
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoulettePainter extends CustomPainter {
  final List<PrizeItem> items;
  final Paint _paint = Paint();

  RoulettePainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final angle = 2 * pi / items.length;

    for (int i = 0; i < items.length; i++) {
      _paint.color = items[i].color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 - angle / 2 + i * angle,
        angle,
        true,
        _paint,
      );
    }

    _paint.color = Colors.white.withOpacity(0.5);
    _paint.strokeWidth = 2.0;
    for (int i = 0; i < items.length; i++) {
      final lineAngle = -pi / 2 - angle / 2 + i * angle;
      final startPoint = center;
      final endPoint = Offset(
        center.dx + radius * cos(lineAngle),
        center.dy + radius * sin(lineAngle),
      );
      canvas.drawLine(startPoint, endPoint, _paint);
    }

    for (int i = 0; i < items.length; i++) {
      final middleAngle = -pi / 2 - angle / 2 + i * angle + angle / 2;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(middleAngle);

      final textPainter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.text = TextSpan(
        text: items[i].label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
      );
      textPainter.layout(minWidth: 0, maxWidth: radius * 0.8);

      final textOffset = Offset(
          radius * 0.55 - textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, textOffset);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}