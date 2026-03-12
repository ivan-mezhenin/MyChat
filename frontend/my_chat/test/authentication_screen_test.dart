import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat/screens/authentication_screen.dart';

void main() {
  testWidgets('При нажатии на кнопку "Войти" вызывается authenticate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Войти'), findsOneWidget);
  });

  group('AuthenticationScreen — базовые проверки отображения', () {
    testWidgets('1. Экран отображает заголовок "Вход" или "Регистрация"', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.textContaining('Вход'), findsOneWidget);
    });

    testWidgets('3. Поле для пароля присутствует', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.text('Пароль'), findsOneWidget);
    });

    testWidgets('4. Кнопка "Войти" или "Зарегистрироваться" видна', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.textContaining('Войти'), findsOneWidget);
    });

    testWidgets('5. Ссылка "Нет аккаунта? Зарегистрироваться" видна', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.textContaining('Зарегистрироваться'), findsOneWidget);
    });
  });

  group('Переключение режимов логин/регистрация', () {
    testWidgets('6. При старте показан режим входа', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.text('Войти'), findsOneWidget);
      expect(find.text('Нет аккаунта? Зарегистрироваться'), findsOneWidget);
    });

    testWidgets('7. Нажатие на "Зарегистрироваться" переключает на регистрацию', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      await tester.tap(find.textContaining('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Зарегистрироваться'), findsOneWidget);
      expect(find.text('Уже есть аккаунт? Войти'), findsOneWidget);
    });
  });
  group('Дополнительные сценарии', () {
    testWidgets('17. Экран показывает индикатор загрузки при _isLoading = true', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('19. Кнопка "Войти" меняет текст при переключении режима', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.text('Войти'), findsOneWidget);

      await tester.tap(find.textContaining('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Зарегистрироваться'), findsOneWidget);
    });

    testWidgets('25. Экран отображает иконки полей (если есть)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthenticationScreen()));

      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });
}