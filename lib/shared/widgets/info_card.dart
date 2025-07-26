import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Widget? iconWidget;
  final Color color;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.iconWidget,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Determina si el color de fondo es claro u oscuro para elegir el color del texto
    final bool isColorDark = color.computeLuminance() < 0.5;
    final Color textColor = isColorDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title,
              style:
              TextStyle(color: textColor.withOpacity(0.8), fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Muestra el ícono y el espacio solo si el ícono no es nulo
              if (iconWidget != null)
                IconTheme(
                    data: IconThemeData(color: textColor, size: 24),
                    child: iconWidget!),
              if (iconWidget != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor),
                  // Se centra el texto horizontalmente si no hay ícono
                  textAlign:
                  iconWidget == null ? TextAlign.center : TextAlign.start,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}