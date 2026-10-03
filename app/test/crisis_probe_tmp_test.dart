import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/db/database.dart';

void main() {
  test('sqlite loads', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.upsertConversation('x');
    expect(await db.countMessages('x'), 0);
    await db.close();
  });
}
