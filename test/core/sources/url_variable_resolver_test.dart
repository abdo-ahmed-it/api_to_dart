import 'package:api_to_dart/api_to_dart.dart';
import 'package:test/test.dart';

void main() {
  group('UrlVariableResolver', () {
    const urlVars = {
      'system_user_url': 'https://host/api/v1/system-user',
      'client_url': 'https://host/api/v1/client',
    };

    test('strips a URL-variable prefix and sets the base override', () {
      final ep = ApiEndpoint(
        name: 'Login',
        path: '/system_user_url/login',
        method: HttpMethod.POST,
      );
      final resolved = const UrlVariableResolver(urlVars).resolveEndpoint(ep);

      expect(resolved.path, '/login');
      expect(resolved.baseUrlOverride, 'https://host/api/v1/system-user');
      // name is rebuilt from the clean path
      expect(resolved.name, 'Login');
    });

    test('leaves endpoints without a known prefix unchanged', () {
      final ep = ApiEndpoint(
        name: 'Health',
        path: '/health/check',
        method: HttpMethod.GET,
      );
      final resolved = const UrlVariableResolver(urlVars).resolveEndpoint(ep);

      expect(resolved.path, '/health/check');
      expect(resolved.baseUrlOverride, isNull);
      expect(identical(resolved, ep), isTrue);
    });

    test('rebuilds a multi-segment name from the clean path', () {
      final ep = ApiEndpoint(
        name: 'OldName',
        path: '/client_url/orders/recent',
        method: HttpMethod.GET,
      );
      final resolved = const UrlVariableResolver(urlVars).resolveEndpoint(ep);

      expect(resolved.path, '/orders/recent');
      expect(resolved.baseUrlOverride, 'https://host/api/v1/client');
      expect(resolved.name, 'OrdersRecent');
    });

    test('resolves a whole tree preserving folder structure', () {
      final tree = EndpointTree(
        sourceName: 'Apidog',
        folders: [
          ApiFolder(name: 'Auth', endpoints: [
            ApiEndpoint(
                name: 'Login',
                path: '/system_user_url/login',
                method: HttpMethod.POST),
          ]),
        ],
      );
      final resolved = const UrlVariableResolver(urlVars).resolveTree(tree);

      final ep = resolved.folders.single.endpoints.single;
      expect(ep.path, '/login');
      expect(ep.baseUrlOverride, 'https://host/api/v1/system-user');
    });

    test('is a no-op when there are no URL variables', () {
      final tree = EndpointTree(
        sourceName: 'X',
        rootEndpoints: [
          ApiEndpoint(name: 'A', path: '/a/b', method: HttpMethod.GET),
        ],
      );
      final resolved = const UrlVariableResolver({}).resolveTree(tree);
      expect(identical(resolved, tree), isTrue);
    });
  });
}
