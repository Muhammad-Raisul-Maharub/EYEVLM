import 'package:flutter/material.dart';
import 'package:eyevlm_app/core/widgets/animated_background.dart';
import 'package:eyevlm_app/core/widgets/responsive_wrapper.dart';

class BaseScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;

  const BaseScaffold({
    super.key, 
    required this.body, 
    this.title, 
    this.floatingActionButton,
    this.actions,
    this.leading,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Lets background show behind AppBar
      appBar: title != null 
          ? AppBar(
              title: Text(title!),
              backgroundColor: Colors.transparent, // Glass effect
              elevation: 0,
              centerTitle: true,
              actions: actions,
              leading: leading,
              automaticallyImplyLeading: showBackButton,
            ) 
          : null,
      floatingActionButton: floatingActionButton,
      // Here is the Magic: We wrap EVERY screen in the Background + Responsive logic
      body: AnimatedBackground(
        child: ResponsiveWrapper(
          child: body,
        ),
      ),
    );
  }
}
