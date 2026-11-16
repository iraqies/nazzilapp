import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/nazzil_controller.dart';
import 'home_screen.dart';
import 'library_screen.dart';

/// A wide window's page under the toolbar, in one scroll: the post on show, or
/// a word on what Nazzil does while nothing is saved, then the library.
class WidePage extends StatelessWidget {
  const WidePage({super.key, required this.controller});
  final NazzilController controller;

  /// The page stops growing here and stays in the middle of a wider window.
  static const maxWidth = 1440.0;

  @override
  Widget build(BuildContext context) {
    final media = controller.media;
    final error = controller.error;
    final library = controller.library.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(24.0, (constraints.maxWidth - maxWidth) / 2);
        return CustomScrollView(
          // A new post gets a new key, so the page opens at its top, where the post is.
          key: PageStorageKey('wide ${media?.webpageUrl ?? ''}'),
          slivers: [
            if (media == null && error.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 20, side, 0),
                sliver: SliverToBoxAdapter(child: ErrorLine(error)),
              ),
            if (media != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 24, side, 0),
                sliver: SliverToBoxAdapter(
                  child: FocusTraversalGroup(child: WidePost(controller: controller, media: media)),
                ),
              )
            else if (!library)
              SliverFillRemaining(hasScrollBody: false, child: WideIntro(controller: controller)),
            if (library)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, media == null && error.isEmpty ? 28 : 44, side, 32),
                sliver: SliverMainAxisGroup(slivers: LibraryScreen.wideSlivers(context, controller)),
              ),
          ],
        );
      },
    );
  }
}
