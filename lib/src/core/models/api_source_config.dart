class ApiSourceConfig {
  final String? filePath;
  final String? baseUrl;
  final String? token;
  final String outputDir;
  final String? apiKey;
  final String? projectId;
  final String? collectionId;

  const ApiSourceConfig({
    this.filePath,
    this.baseUrl,
    this.token,
    this.outputDir = 'lib/actions',
    this.apiKey,
    this.projectId,
    this.collectionId,
  });
}
