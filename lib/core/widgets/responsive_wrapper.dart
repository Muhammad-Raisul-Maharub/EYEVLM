import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // This centers content for Web and adds scrolling for small Mobiles
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600), // Keeps Web UI neat
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
