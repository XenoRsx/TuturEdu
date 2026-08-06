// lib/utils/file_validator.dart
//
// 3-layer validation for chat attachments (see BLUEPRINT.md section 8):
//   1. File size - reject outright if over 10MB
//   2. Extension - reject outright if not in the allowed list
//   3. Magic number / file signature - checks the file's actual first bytes,
//      so a renamed .exe (or any mismatched file) can't slip through just
//      because its extension looks right.
//
// This runs entirely client-side, which is good UX (instant rejection, no
// wasted upload bandwidth) but is not an absolute security guarantee - a
// sufficiently motivated user could modify the client. A Cloud Function
// that re-validates the magic number server-side on Storage upload
// (onFinalize trigger) and deletes anything invalid is the recommended
// future hardening step (not implemented yet - no Cloud Functions in this
// project currently).

import 'dart:typed_data';

enum AttachmentType { image, document }

class FileValidationResult {
  final bool isValid;
  final String? errorMessage;
  final AttachmentType? attachmentType;

  const FileValidationResult.valid(AttachmentType type)
    : isValid = true,
      errorMessage = null,
      attachmentType = type;

  const FileValidationResult.invalid(String message)
    : isValid = false,
      errorMessage = message,
      attachmentType = null;
}

class FileValidator {
  static const int maxSizeBytes = 10 * 1024 * 1024; // 10MB

  static const Set<String> imageExtensions = {'jpg', 'jpeg', 'png'};
  static const Set<String> documentExtensions = {
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
  };

  static FileValidationResult validate(String fileName, Uint8List bytes) {
    // Layer 1: size
    if (bytes.isEmpty) {
      return const FileValidationResult.invalid('File appears to be empty.');
    }
    if (bytes.lengthInBytes > maxSizeBytes) {
      return const FileValidationResult.invalid(
        'File is too large. Maximum size is 10MB.',
      );
    }

    // Layer 2: extension
    final extension = _extensionOf(fileName);
    final isImageExt = imageExtensions.contains(extension);
    final isDocumentExt = documentExtensions.contains(extension);

    if (!isImageExt && !isDocumentExt) {
      return FileValidationResult.invalid(
        extension.isEmpty
            ? 'This file has no extension. Allowed types: PDF, Word, '
                  'PowerPoint, Excel, JPG, PNG.'
            : '".$extension" files are not allowed. Allowed types: PDF, '
                  'Word, PowerPoint, Excel, JPG, PNG.',
      );
    }

    // Layer 3: magic number (actual file signature, not just the name)
    if (!_matchesMagicNumber(extension, bytes)) {
      return const FileValidationResult.invalid(
        "This file's content doesn't match its extension - it may be "
        'corrupted, or renamed from a different file type. Upload rejected.',
      );
    }

    return FileValidationResult.valid(
      isImageExt ? AttachmentType.image : AttachmentType.document,
    );
  }

  static String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// Checks the file's real signature against what its extension claims.
  ///
  /// Note: .docx/.pptx/.xlsx all share the same ZIP-based signature (`PK..`),
  /// and the legacy .doc/.ppt/.xls formats all share the same OLE Compound
  /// File signature - telling them apart precisely would need parsing the
  /// file's internal structure. For the current MVP scope, matching
  /// signature + extension is considered sufficient (see BLUEPRINT.md 8.4).
  static bool _matchesMagicNumber(String extension, Uint8List bytes) {
    switch (extension) {
      case 'pdf':
        return _startsWith(bytes, [0x25, 0x50, 0x44, 0x46]); // %PDF
      case 'png':
        return _startsWith(bytes, [0x89, 0x50, 0x4E, 0x47]);
      case 'jpg':
      case 'jpeg':
        return _startsWith(bytes, [0xFF, 0xD8, 0xFF]);
      case 'docx':
      case 'pptx':
      case 'xlsx':
        return _startsWith(bytes, [0x50, 0x4B, 0x03, 0x04]); // PK.. (ZIP)
      case 'doc':
      case 'ppt':
      case 'xls':
        return _startsWith(
          bytes,
          [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1], // OLE Compound
        );
      default:
        return false;
    }
  }
}
