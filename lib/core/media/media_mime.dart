/// A best-effort mime type from a picked file's own extension, for the categories the app uploads today. The
/// server never trusts this either way (it sniffs the real bytes - see the backend's apps/media/validation.py);
/// this only decides what the app itself declares when it asks to start an upload.
String? mimeTypeForExtension(String? extension, {required String mediaType}) {
  final ext = (extension ?? '').toLowerCase();
  if (mediaType == 'image') {
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => null,
    };
  }
  if (mediaType == 'video') {
    return switch (ext) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => null,
    };
  }
  if (mediaType == 'document') {
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      _ => null,
    };
  }
  return null;
}
