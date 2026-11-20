import 'package:erp_mobile/core/network/page_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String name(Map<String, dynamic> json) => json['name'] as String;

  test('reads the backend PageResponse', () {
    final page = PageModel.fromData({
      'items': [
        {'name': 'a'},
        {'name': 'b'},
      ],
      'page': 1,
      'pageSize': 2,
      'totalItems': 5,
      'totalPages': 3,
    }, name);

    expect(page.items, ['a', 'b']);
    expect(page.hasMore, isTrue); // 1 < 3
  });

  test('last page → hasMore false; missing items → empty', () {
    final page = PageModel.fromData({'page': 3, 'totalPages': 3}, name);
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });
}
