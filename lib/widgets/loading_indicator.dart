import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String text;
  const LoadingIndicator({super.key, this.text = "Cargando..."});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.indigo),
          const SizedBox(height: 15),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
