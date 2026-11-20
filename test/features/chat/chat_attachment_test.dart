import 'package:erp_mobile/features/chat/model/chat_attachment.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content types the server accepts; others → null', () {
    expect(AttachmentRules.contentTypeFor('a/IMG_1.JPG'), 'image/jpeg');
    expect(AttachmentRules.contentTypeFor('voice-1.m4a'), 'audio/mp4');
    expect(AttachmentRules.contentTypeFor('report.pdf'), 'application/pdf');
    expect(AttachmentRules.contentTypeFor('report.docx'), isNull); // not yet
  });

  test('problem: wrong type, too big, or OK', () {
    expect(
      AttachmentRules.problem(fileName: 'a.docx', sizeBytes: 10),
      isNotNull,
    );
    expect(
      AttachmentRules.problem(fileName: 'a.pdf', sizeBytes: 26 * 1024 * 1024),
      contains('25.0 MB'),
    );
    expect(AttachmentRules.problem(fileName: 'a.pdf', sizeBytes: 1024), isNull);
  });

  test('sizeLabel + typeFor', () {
    expect(AttachmentRules.sizeLabel(1258291), '1.2 MB');
    expect(AttachmentRules.sizeLabel(2000), '2 KB');
    expect(AttachmentRules.typeFor('image/png'), MessageType.image);
    expect(AttachmentRules.typeFor('audio/mp4'), MessageType.voice);
    expect(AttachmentRules.typeFor('application/pdf'), MessageType.file);
  });
}
