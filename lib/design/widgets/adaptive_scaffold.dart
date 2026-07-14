import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// One chrome, two platforms. Top-level (tab) screens get a collapsing iOS
/// large-title nav bar (`CupertinoSliverNavigationBar`) on iOS and a Material
/// `AppBar` on Android. The title keeps Koinonia's serif on both — native manners,
/// brand intact. Content is supplied as [slivers]; use [AdaptiveScaffold.list]
/// for a simple padded list of children.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;

  /// Convenience: a single padded, scrollable list of [children].
  static Widget list({
    Key? key,
    required String title,
    required List<Widget> children,
    EdgeInsets padding = const EdgeInsets.all(AppSpacing.xxl),
    Widget? trailing,
  }) {
    return AdaptiveScaffold(
      key: key,
      title: title,
      trailing: trailing,
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return Scaffold(
        backgroundColor: c.bg,
        body: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(
                title,
                style: AppType.title.copyWith(
                    color: c.ink, fontSize: 30, fontWeight: FontWeight.w600),
              ),
              backgroundColor: c.bg.withValues(alpha: 0.72),
              border: const Border(),
              trailing: trailing,
            ),
            ...slivers,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: AppSpacing.xxl,
        centerTitle: false,
        title: Text(title, style: AppType.title.copyWith(color: c.ink)),
        actions: trailing == null
            ? null
            : [trailing!, const SizedBox(width: AppSpacing.sm)],
      ),
      body: CustomScrollView(slivers: slivers),
    );
  }
}
