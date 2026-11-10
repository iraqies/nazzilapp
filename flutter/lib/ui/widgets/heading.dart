import 'package:flutter/material.dart';

/// The big line at the top of a screen. It is already large, so it follows
/// the system font size only part of the way and long words stay whole.
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.displaySmall),
      ),
    );
  }
}
