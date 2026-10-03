import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Full-screen scaffold that paints the Jugnu ground gradient behind the
/// [Scaffold] body. All Jugnu screens wrap their content in this widget.
///
/// The [Scaffold] itself has a transparent background so the gradient shows
/// through. Safe areas are respected on all edges.
///
/// ```dart
/// JugnuScaffold(
///   appBar: JugnuAppBar(title: Text('Today')),
///   body: ListView(...),
/// )
/// ```
class JugnuScaffold extends StatelessWidget {
  const JugnuScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: colors.ground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      ),
    );
  }
}
