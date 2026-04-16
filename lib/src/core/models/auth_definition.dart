enum AuthType { none, bearer, basic, apiKey }

class AuthDefinition {
  final AuthType type;
  final String? token;
  final String? headerName;

  const AuthDefinition({
    required this.type,
    this.token,
    this.headerName,
  });

  bool get requiresAuth => type != AuthType.none;

  static const noAuth = AuthDefinition(type: AuthType.none);
}
