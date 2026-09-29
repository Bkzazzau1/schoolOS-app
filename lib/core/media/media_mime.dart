/// A best-effort mime type from a picked file's own extension. The server never trusts this either way (it
/// sniffs the real bytes and checks them against the category's own accepted mime types - see the backend's
/// apps/media/validation.py); this only decides what the app itself declares when it asks to start an upload.
/// One flat table for every extension SchoolOS uploads anywhere, rather than one per screen's own "kind of
/// picker" - a category (never this table) is what actually decides which of these a given upload may use.
const Map<String, String> _mimeTypesByExtension = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
};

String? mimeTypeForExtension(String? extension) => _mimeTypesByExtension[(extension ?? '').toLowerCase()];
