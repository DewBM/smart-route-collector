import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_manager.dart';
import '../theme/app_tokens.dart';

/// Slim status strip above the navigation bar. Only visible when there is
/// something worth saying: offline, changes waiting, syncing, or just synced.
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncManager>();
    final s = context.status;
    final n = sync.pendingCount;
    final changes = n == 1 ? '1 change' : '$n changes';

    ({
      IconData icon,
      String text,
      Color bg,
      Color fg,
      bool spin,
      bool tappable,
    })?
    view;

    if (sync.isSyncing) {
      view = (
        icon: Icons.sync_rounded,
        text: 'Syncing $changes…',
        bg: s.nextContainer,
        fg: s.next,
        spin: true,
        tappable: false,
      );
    } else if (!sync.isOnline) {
      view = (
        icon: Icons.cloud_off_rounded,
        text: n > 0
            ? "Offline · $changes saved, will sync when you're back online"
            : "You're offline · your work is saved on this device",
        bg: s.warningContainer,
        fg: s.warning,
        spin: false,
        tappable: false,
      );
    } else if (n > 0) {
      view = (
        icon: Icons.sync_problem_rounded,
        text: sync.lastAttemptFailed
            ? '$changes not synced · Tap to retry'
            : '$changes waiting to sync · Tap to sync now',
        bg: s.warningContainer,
        fg: s.warning,
        spin: false,
        tappable: true,
      );
    } else if (sync.justSynced) {
      view = (
        icon: Icons.cloud_done_rounded,
        text: 'All changes synced',
        bg: s.successContainer,
        fg: s.success,
        spin: false,
        tappable: false,
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: view == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              button: view.tappable,
              child: Material(
                color: view.bg,
                child: InkWell(
                  onTap: view.tappable ? () => sync.flush() : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: Gap.sm,
                      ),
                      child: Row(
                        children: [
                          view.spin
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: view.fg,
                                  ),
                                )
                              : Icon(view.icon, size: 18, color: view.fg),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text(
                              view.text,
                              style: context.text.labelMedium?.copyWith(
                                color: view.fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
