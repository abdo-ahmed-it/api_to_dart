import 'package:api_to_dart/api_to_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ApiEndpoint output overrides', () {
    final base = ApiEndpoint(
      name: 'List Users',
      path: '/users',
      method: HttpMethod.GET,
    );

    test('derives defaults when no overrides', () {
      expect(base.actionClassName, 'GetListUsersAction');
      expect(base.responseClassName, 'GetListUsersResponse');
      expect(base.fileName, 'get_list_users_action.dart');
      expect(base.key, 'GET /users');
    });

    test('honors class + file name overrides', () {
      final ep = ApiEndpoint(
        name: 'List Users',
        path: '/users',
        method: HttpMethod.GET,
        actionClassOverride: 'UsersAction',
        responseClassOverride: 'UsersResponse',
        fileNameOverride: 'users.dart',
      );
      expect(ep.actionClassName, 'UsersAction');
      expect(ep.responseClassName, 'UsersResponse');
      expect(ep.fileName, 'users.dart');
      // key is independent of names
      expect(ep.key, 'GET /users');
    });

    test('blank overrides fall back to derived defaults', () {
      final ep = ApiEndpoint(
        name: 'List Users',
        path: '/users',
        method: HttpMethod.GET,
        actionClassOverride: '',
        fileNameOverride: '',
      );
      expect(ep.actionClassName, 'GetListUsersAction');
      expect(ep.fileName, 'get_list_users_action.dart');
    });

    test('key distinguishes same path with different methods', () {
      final post =
          ApiEndpoint(name: 'Create', path: '/users', method: HttpMethod.POST);
      expect(base.key, isNot(post.key));
    });
  });
}
