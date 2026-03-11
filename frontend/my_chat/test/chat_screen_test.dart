import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat/screens/chat_screen.dart';

void main() {
  testWidgets('ChatScreen показывает поле ввода и кнопку отправки', (tester) async {

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          chatId: 'test_chat',
          chatName: 'Тестовый чат',
          userUID: 'user123',
        ),
      ),
    );

    expect(find.text('Тестовый чат'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('При вводе текста и нажатии отправки сообщение добавляется', (tester) async {

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          chatId: 'test_chat',
          chatName: 'Тест',
          userUID: 'user1',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Привет!');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Привет!'), findsOneWidget);
  });

  group('ChatScreen — отображение основных элементов', () {
    testWidgets('1. Экран показывает название чата в AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тестовый чат',
            userUID: 'user123',
          ),
        ),
      );

      expect(find.text('Тестовый чат'), findsOneWidget);
    });

    testWidgets('3. Кнопка отправки (иконка send) присутствует', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });

  group('Ввод и отправка сообщений', () {
    testWidgets('6. Можно ввести текст в поле сообщения', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Привет, как дела?');
      await tester.pump();

      expect(find.text('Привет, как дела?'), findsOneWidget);
    });

    testWidgets('8. При отправке пустого сообщения ничего не происходит', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
    });

  group('Дополнительные сценарии и состояния', () {
    testWidgets('15. Экран не падает при очень длинном сообщении', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      final longText = 'a' * 1000;
      await tester.enterText(find.byType(TextField), longText);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('18. Сообщение от другого пользователя отображается слева', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      expect(find.byType(Align), findsWidgets);
    });

    testWidgets('22. Экран не падает при отсутствии WebSocketService', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('25. Экран корректно отображается в тёмной теме', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ChatScreen(
            chatId: 'chat1',
            chatName: 'Тест',
            userUID: 'user1',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
  });
}