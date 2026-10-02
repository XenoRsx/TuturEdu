import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturedu/utils/file_validator.dart';

Uint8List bytesStartingWith(List<int> signature, {int length = 64}) {
  final bytes = Uint8List(length);
  bytes.setRange(0, signature.length, signature);
  return bytes;
}

void main() {
  const png = [0x89, 0x50, 0x4E, 0x47];
  const jpg = [0xFF, 0xD8, 0xFF];
  const pdf = [0x25, 0x50, 0x44, 0x46];
  const zip = [0x50, 0x4B, 0x03, 0x04];

  group('FileValidator.validate - accepted files', () {
    test('a real PNG is accepted as an image', () {
      final result = FileValidator.validate(
        'photo.png',
        bytesStartingWith(png),
      );
      expect(result.isValid, isTrue);
      expect(result.attachmentType, AttachmentType.image);
    });

    test('a real JPEG is accepted as an image (.jpg and .jpeg)', () {
      expect(
        FileValidator.validate('a.jpg', bytesStartingWith(jpg)).isValid,
        isTrue,
      );
      expect(
        FileValidator.validate('a.jpeg', bytesStartingWith(jpg)).isValid,
        isTrue,
      );
    });

    test('a real PDF is accepted as a document', () {
      final result = FileValidator.validate(
        'notes.pdf',
        bytesStartingWith(pdf),
      );
      expect(result.isValid, isTrue);
      expect(result.attachmentType, AttachmentType.document);
    });

    test('a .docx (ZIP signature) is accepted as a document', () {
      final result = FileValidator.validate(
        'essay.docx',
        bytesStartingWith(zip),
      );
      expect(result.isValid, isTrue);
      expect(result.attachmentType, AttachmentType.document);
    });

    test('extension check is case-insensitive', () {
      expect(
        FileValidator.validate('PHOTO.PNG', bytesStartingWith(png)).isValid,
        isTrue,
      );
    });
  });

  group('FileValidator.validate - rejected files', () {
    test('an empty file is rejected', () {
      expect(FileValidator.validate('a.png', Uint8List(0)).isValid, isFalse);
    });

    test('a file over 10MB is rejected', () {
      final tooBig = bytesStartingWith(
        png,
        length: FileValidator.maxSizeBytes + 1,
      );
      expect(FileValidator.validate('big.png', tooBig).isValid, isFalse);
    });

    test('a disallowed extension is rejected', () {
      expect(
        FileValidator.validate('virus.exe', bytesStartingWith(png)).isValid,
        isFalse,
      );
    });

    test('a file with no extension is rejected', () {
      expect(
        FileValidator.validate('README', bytesStartingWith(pdf)).isValid,
        isFalse,
      );
    });

    test('content that does not match the extension is rejected', () {
      // e.g. an executable or a PDF renamed to look like a photo
      final result = FileValidator.validate(
        'photo.png',
        bytesStartingWith(pdf),
      );
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains("doesn't match"));
    });
  });
}
