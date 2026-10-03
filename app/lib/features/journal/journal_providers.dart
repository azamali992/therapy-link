import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';

final journalProvider = FutureProvider<List<JournalEntry>>((ref) => ref.watch(apiClientProvider).journal());
