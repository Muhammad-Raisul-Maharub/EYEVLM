import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final historyRefreshProvider = NotifierProvider<HistoryRefreshNotifier, int>(HistoryRefreshNotifier.new);
