class BarcodeValidator {
  BarcodeValidator._();

  /// Validates whether a barcode string is a legitimate product barcode (e.g. EAN, UPC, Code-128).
  ///
  /// Returns `null` if valid, or a user-friendly error string if invalid (e.g. if a QR code link or URL was scanned/entered).
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Barcode is required for barcoded products';
    }
    final code = value.trim();

    // Check for web links, URLs, protocols, or QR redirect links
    if (isUrlOrLink(code)) {
      return 'Invalid barcode: QR code links and URLs are not allowed as product barcodes.';
    }

    // Standard product barcodes are between 4 and 32 characters
    if (code.length < 4) {
      return 'Barcode is too short (minimum 4 characters).';
    }
    if (code.length > 32) {
      return 'Barcode is too long (maximum 32 characters).';
    }

    // Must be alphanumeric (plus optional hyphen or underscore)
    final validPattern = RegExp(r'^[a-zA-Z0-9\-_]+$');
    if (!validPattern.hasMatch(code)) {
      return 'Invalid barcode: only letters, numbers, and dashes are allowed (no spaces or symbols).';
    }

    return null;
  }

  /// Convenience boolean check.
  static bool isValid(String? value) => validate(value) == null;

  /// Returns true if [value] is a web link / QR link.
  static bool isUrlOrLink(String? value) {
    if (value == null) return false;
    final lower = value.trim().toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        lower.startsWith('upi://') ||
        lower.startsWith('tel:') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('ftp://') ||
        lower.contains('://') ||
        lower.contains('.com') ||
        lower.contains('.in') ||
        lower.contains('.org') ||
        lower.contains('.net') ||
        lower.contains('.io') ||
        lower.contains('.co') ||
        lower.contains('.app') ||
        lower.contains('.me') ||
        lower.contains('.link') ||
        lower.contains('/') ||
        lower.contains('?') ||
        lower.contains('&') ||
        lower.contains('=');
  }
}
