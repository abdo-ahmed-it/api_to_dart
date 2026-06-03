import 'package:api_to_dart/api_to_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PostmanSource', () {
    test('parses example Postman collection', () async {
      final source = PostmanSource();
      final tree = await source.parse(
        const ApiSourceConfig(
          filePath: 'example/lib/api/postman_collection.json',
        ),
      );

      expect(tree.sourceName, equals('Derman'));
      expect(tree.totalEndpoints, equals(13));
      expect(tree.folders.length, greaterThan(0));

      // Check a folder
      final appFolder = tree.folders.firstWhere((f) => f.name == 'App');
      expect(appFolder.endpoints.length, equals(4));

      // Check an endpoint
      final home = appFolder.endpoints.firstWhere((e) => e.name == 'Home');
      expect(home.method, equals(HttpMethod.GET));
      expect(home.path, equals('/home'));
    });

    test('parses auth types correctly', () async {
      final source = PostmanSource();
      final tree = await source.parse(
        const ApiSourceConfig(
          filePath: 'example/lib/api/postman_collection.json',
        ),
      );

      final allEndpoints = tree.allEndpoints;

      // Home should have noauth
      final home = allEndpoints.firstWhere((e) => e.name == 'Home');
      expect(home.auth.type, equals(AuthType.none));

      // Profile Data should have bearer
      final profile =
          allEndpoints.firstWhere((e) => e.name == 'Profile Data');
      expect(profile.auth.type, equals(AuthType.bearer));
    });

    test('parses body correctly', () async {
      final source = PostmanSource();
      final tree = await source.parse(
        const ApiSourceConfig(
          filePath: 'example/lib/api/postman_collection.json',
        ),
      );

      final login =
          tree.allEndpoints.firstWhere((e) => e.name == 'Login');
      expect(login.body, isNotNull);
      expect(login.body!.contentType, equals(BodyContentType.formData));
      expect(login.body!.formFields, containsPair('phone', '123456789'));
    });
  });

  group('ActionGenerator', () {
    test('generates action class', () {
      final generator = ActionGenerator();
      final endpoint = ApiEndpoint(
        name: 'Login',
        path: '/auth/login',
        method: HttpMethod.POST,
        auth: const AuthDefinition(type: AuthType.bearer, token: 'test'),
        body: const BodyDefinition(
          contentType: BodyContentType.formData,
          formFields: {'email': 'test@test.com', 'password': '123'},
        ),
      );

      final code = generator.generate(endpoint);

      // Method is prefixed so same-path endpoints don't collide on names.
      expect(code, contains('class PostLoginAction'));
      expect(code, contains('RequestMethod.POST'));
      expect(code, contains("path => '/auth/login'"));
      expect(code, contains('authRequired => true'));
      expect(code, contains('PostLoginResponse'));
    });

    test('generates action-only class', () {
      final generator = ActionGenerator();
      final endpoint = ApiEndpoint(
        name: 'GetUsers',
        path: '/users',
        method: HttpMethod.GET,
      );

      final code = generator.generateActionOnly(endpoint);

      // Name already starts with the method → no "GetGetUsers" duplication.
      expect(code, contains('class GetUsersAction'));
      expect(code, contains('ApiRequestAction<dynamic>'));
      expect(code, contains('RequestMethod.GET'));
    });

    test('same path different methods produce distinct file and class names',
        () {
      const get = ApiEndpoint(name: 'Users', path: '/users', method: HttpMethod.GET);
      const post =
          ApiEndpoint(name: 'Users', path: '/users', method: HttpMethod.POST);

      expect(get.fileName, equals('get_users_action.dart'));
      expect(post.fileName, equals('post_users_action.dart'));
      expect(get.fileName, isNot(equals(post.fileName)));
      expect(get.actionClassName, equals('GetUsersAction'));
      expect(post.actionClassName, equals('PostUsersAction'));
      expect(get.responseClassName, equals('GetUsersResponse'));
    });
  });

  group('BodyProcessor', () {
    test('processes null body', () {
      final body = processBody(null);
      expect(body.isEmpty, isTrue);
    });

    test('processes BodyDefinition passthrough', () {
      const original = BodyDefinition(
        contentType: BodyContentType.rawJson,
        rawBody: '{"test": true}',
      );
      final result = processBody(original);
      expect(identical(result, original), isTrue);
    });

    test('processes formdata map', () {
      final body = processBody({
        'mode': 'formdata',
        'data': {'name': 'John', 'age': '30'},
      });
      expect(body.contentType, equals(BodyContentType.formData));
      expect(body.formFields, containsPair('name', 'John'));
    });

    test('processes raw body', () {
      final body = processBody({
        'mode': 'raw',
        'data': '{"key": "value"}',
      });
      expect(body.contentType, equals(BodyContentType.rawJson));
      expect(body.rawBody, equals('{"key": "value"}'));
    });
  });

  group('ResponseGenerator', () {
    test('generates Dart model from JSON', () {
      final generator = ResponseGenerator();
      const json = '{"id": 1, "name": "Test", "active": true}';

      final code = generator.generate(json, 'UserResponse');

      expect(code, contains('class UserResponse'));
      expect(code, contains('fromJson'));
      expect(code, contains('toJson'));
      expect(code, contains('int?'));
      expect(code, contains('String?'));
      expect(code, contains('bool?'));
    });
  });

  group('EndpointTree', () {
    test('counts total endpoints correctly', () {
      final tree = EndpointTree(
        sourceName: 'Test',
        folders: [
          const ApiFolder(
            name: 'Auth',
            endpoints: [
              ApiEndpoint(name: 'Login', path: '/login', method: HttpMethod.POST),
              ApiEndpoint(
                  name: 'Register', path: '/register', method: HttpMethod.POST),
            ],
          ),
        ],
        rootEndpoints: const [
          ApiEndpoint(name: 'Health', path: '/health', method: HttpMethod.GET),
        ],
      );

      expect(tree.totalEndpoints, equals(3));
      expect(tree.allEndpoints.length, equals(3));
    });
  });

  group('LocalFileSource', () {
    test('parses YAML config', () async {
      final source = LocalFileSource();
      final tree = await source.parse(
        const ApiSourceConfig(
          filePath: 'example/lib/single_action.yaml',
        ),
      );

      expect(tree.totalEndpoints, equals(1));
      final endpoint = tree.rootEndpoints.first;
      expect(endpoint.name, equals('Register'));
      expect(endpoint.path, equals('/auth/register'));
      expect(endpoint.method, equals(HttpMethod.POST));
      expect(endpoint.body?.contentType, equals(BodyContentType.urlEncoded));
    });
  });
}
