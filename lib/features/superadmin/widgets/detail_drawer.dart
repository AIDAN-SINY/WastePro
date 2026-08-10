import 'package:flutter/material.dart';

import '../theme.dart';

/// Right-side slide-in drawer used for read-only detail views (e.g. an
/// agency's full information from the super admin console).
///
/// Mirrors [showCrudDrawer]'s design (head + scrollable body + foot) but
/// without a save flow: the [footer] hosts actions like Edit / Delete.
Future<void> showDetailDrawer(
  BuildContext context, {
  required String title,
  required Widget body,
  Widget? footer,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, _, _) => _DetailDrawer(
      title: title,
      body: body,
      footer: footer,
    ),
    transitionBuilder: (context, anim, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

class _DetailDrawer extends StatelessWidget {
  const _DetailDrawer({
    required this.title,
    required this.body,
    this.footer,
  });

  final String title;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final drawerWidth = (width * 0.92).clamp(0.0, 460.0);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: SuperAdminTheme.surface,
        child: SizedBox(
          width: drawerWidth,
          height: double.infinity,
          child: Column(
            children: [
              // Head
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: SuperAdminTheme.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: SuperAdminTheme.sora(
                          16,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _CloseButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: body,
                ),
              ),
              // Foot (actions)
              if (footer != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: SuperAdminTheme.border),
                    ),
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small square ghost button (close).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: SuperAdminTheme.border),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 15,
          color: SuperAdminTheme.muted,
        ),
      ),
    );
  }
}

// --- Building blocks for detail bodies ---

/// Labeled key/value row used inside detail drawers.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: SuperAdminTheme.inter(
              10,
              weight: FontWeight.w600,
              color: SuperAdminTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: SuperAdminTheme.inter(13, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
