import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:my_chat/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([http.Client])
import 'auth_service_test.mocks.dart';

void main() {
  late AuthService authService;
  late MockClient mockClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockClient();
    authService = AuthService(client: mockClient);
  });

  test('Логин с неверным email возвращает ошибку', () async {
    final result = await authService.login('неправильный_email', '123456');

    expect(result.success, false);
    expect(result.error, 'Please enter a valid email');
  });
  group('AuthService — базовые проверки', () {
    test('1. AuthService создаётся без ошибок', () {
      expect(authService, isNotNull);
    });

    test('2. Метод dispose не падает', () {
      expect(() => authService.dispose(), returnsNormally);
    });

    test('6. login с пустым email → ошибка', () async {
      final result = await authService.login('', '123456');
      expect(result.success, false);
      expect(result.error, isNotEmpty);
    });

    test('7. login с пустым паролем → ошибка', () async {
      final result = await authService.login('test@mail.ru', '');
      expect(result.success, false);
    });

    test('8. login с очень коротким паролем → ошибка', () async {
      final result = await authService.login('test@mail.ru', '12');
      expect(result.success, false);
    });

    test('9. register с пустым username → ошибка', () async {
      final result = await authService.register(username: '', email: 'test@mail.ru', password: '123456');
      expect(result.success, false);
    });

    test('10. register с некорректным email → ошибка', () async {
      final result = await authService.register(username: 'user', email: 'invalid', password: '123456');
      expect(result.success, false);
    });

    test('11. register с коротким паролем → ошибка', () async {
      final result = await authService.register(username: 'user', email: 'test@mail.ru', password: '123');
      expect(result.success, false);
    });

    test('12. login с очень длинным email → ошибка валидации', () async {
      final longEmail = 'a' * 300 + '@mail.ru';
      final result = await authService.login(longEmail, '123456');
      expect(result.success, false);
    });

    test('13. register с пустым всем → ошибка', () async {
      final result = await authService.register(username: '',email:  '', password: '');
      expect(result.success, false);
    });
  });
}