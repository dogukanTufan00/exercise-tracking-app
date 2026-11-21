import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/watch/watch_sync_service.dart';

/// Saat eşlemesi servisini sağlayıcıdan alır; sağlayıcı yoksa (testler) `null`.
WatchSyncService? readWatchSync(BuildContext context) {
  try {
    return context.read<WatchSyncService>();
  } on ProviderNotFoundException {
    return null;
  }
}
