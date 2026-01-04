import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget mobileBody;
  final Widget? webBody;
  final double breakPoint;

  const ResponsiveWrapper({
    super.key, 
    required this.mobileBody, 
    this.webBody,
    this.breakPoint = 800.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > breakPoint) {
          return webBody ?? _defaultWebLayout();
        } else {
          return mobileBody;
        }
      },
    );
  }

  Widget _defaultWebLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: mobileBody,
      ),
    );
  }
}
