import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat/models/contact.dart';
import 'package:my_chat/services/chat_service.dart';

void main() {
  group('Модели', () {
    test('Contact.fromJson работает правильно', () {
      final json = {
        'id': '123',
        'owner_uid': 'user1',
        'contact_uid': 'user2',
        'contact_email': 'test@example.com',
        'contact_name': 'Иван',
        'created_at': '2026-03-07T12:00:00.000Z',
      };

      final contact = Contact.fromJson(json);

      expect(contact.id, '123');
      expect(contact.displayName, 'Иван');
      expect(contact.initial, 'И');
    });

    test('Chat.fromJson работает правильно', () {
      final json = {
        'id': 'chat1',
        'name': 'Тестовый чат',
        'last_message': 'Привет!',
        'last_message_time': '2026-03-07T12:00:00.000Z',
      };

      final chat = Chat.fromJson(json);

      expect(chat.id, 'chat1');
      expect(chat.name, 'Тестовый чат');
      expect(chat.lastMessage, 'Привет!');
    });

    test('Message.fromJson работает правильно', () {
      final json = {
        'id': 'msg1',
        'chat_id': 'chat1',
        'sender_id': 'user1',
        'text': 'Привет мир',
        'timestamp': '2026-03-07T12:00:00.000Z',
      };

      final message = Message.fromJson(json);

      expect(message.text, 'Привет мир');
      expect(message.senderId, 'user1');
    });
  });

  group('Модель Contact', () {
    test('1. Contact.fromJson — все поля корректно парсятся', () {
      final json = {
        'id': 'contact_001',
        'owner_uid': 'user_abc',
        'contact_uid': 'user_xyz',
        'contact_email': 'friend@example.com',
        'contact_name': 'Алексей',
        'created_at': '2026-03-08T14:30:00.000Z',
        'notes': 'Друг с работы',
      };

      final contact = Contact.fromJson(json);

      expect(contact.id, 'contact_001');
      expect(contact.ownerUid, 'user_abc');
      expect(contact.contactUid, 'user_xyz');
      expect(contact.contactEmail, 'friend@example.com');
      expect(contact.contactName, 'Алексей');
      expect(contact.notes, 'Друг с работы');
      expect(contact.displayName, 'Алексей');
      expect(contact.initial, 'А');
    });

    test('2. Contact.fromJson — без имени показывает email', () {
      final json = {
        'id': 'c2',
        'owner_uid': 'u1',
        'contact_uid': 'u2',
        'contact_email': 'no_name@example.com',
        'contact_name': '',
        'created_at': '2026-03-08T14:30:00.000Z',
      };

      final contact = Contact.fromJson(json);
      expect(contact.displayName, 'no_name@example.com');
      expect(contact.initial, 'N');
    });

    test('3. Contact.fromJson — без notes (null)', () {
      final json = {
        'id': 'c3',
        'owner_uid': 'u1',
        'contact_uid': 'u2',
        'contact_email': 'test@mail.ru',
        'contact_name': 'Тест',
        'created_at': '2026-03-08T14:30:00.000Z',
      };

      final contact = Contact.fromJson(json);
      expect(contact.notes, isNull);
    });

    test('4. Contact.toJson — все поля сериализуются', () {
      final contact = Contact(
        id: 'c4',
        ownerUid: 'owner1',
        contactUid: 'contact1',
        contactEmail: 'email@test.com',
        contactName: 'Имя',
        createdAt: DateTime(2026, 3, 8, 15, 0),
        notes: 'Заметка',
      );

      final json = contact.toJson();

      expect(json['id'], 'c4');
      expect(json['owner_uid'], 'owner1');
      expect(json['contact_email'], 'email@test.com');
      expect(json['contact_name'], 'Имя');
      expect(json['notes'], 'Заметка');
      expect(json['created_at'], startsWith('2026-03-08T15:00:00'));
    });

    test('5. Contact.toJson — без notes не добавляет ключ', () {
      final contact = Contact(
        id: 'c5',
        ownerUid: 'u1',
        contactUid: 'u2',
        contactEmail: 'test@mail.ru',
        contactName: 'Тест',
        createdAt: DateTime.now(),
      );

      final json = contact.toJson();
      expect(json.containsKey('notes'), false);
    });

    test('6. Contact.initial — берёт первую букву имени', () {
      final contact = Contact(
        id: 'c6',
        ownerUid: 'u1',
        contactUid: 'u2',
        contactEmail: 'a@mail.ru',
        contactName: 'Ольга',
        createdAt: DateTime.now(),
      );
      expect(contact.initial, 'О');
    });

    test('7. Contact.initial — если имя пустое, берёт email', () {
      final contact = Contact(
        id: 'c7',
        ownerUid: 'u1',
        contactUid: 'u2',
        contactEmail: 'z@mail.ru',
        contactName: '',
        createdAt: DateTime.now(),
      );
      expect(contact.initial, 'Z');
    });
  });

  group('Модель Chat', () {
    test('9. Chat.fromJson — базовые поля', () {
      final json = {
        'id': 'chat_001',
        'name': 'Группа друзей',
        'type': 'group',
        'last_message': 'Пойдём завтра?',
        'last_message_time': '2026-03-08T16:45:00.000Z',
      };

      final chat = Chat.fromJson(json);

      expect(chat.id, 'chat_001');
      expect(chat.name, 'Группа друзей');
      expect(chat.lastMessage, 'Пойдём завтра?');
    });

    test('10. Chat.fromJson — без последнего сообщения', () {
      final json = {
        'id': 'chat_002',
        'name': 'Личный чат',
        'type': 'private',
      };

      final chat = Chat.fromJson(json);
      expect(chat.lastMessage, isNull);
    });

  group('Модель Message', () {
    test('12. Message.fromJson — все поля', () {
      final json = {
        'id': 'msg_001',
        'chat_id': 'chat_001',
        'sender_id': 'user_abc',
        'text': 'Привет всем!',
        'timestamp': '2026-03-08T17:20:00.000Z',
      };

      final message = Message.fromJson(json);

      expect(message.id, 'msg_001');
      expect(message.text, 'Привет всем!');
      expect(message.senderId, 'user_abc');
    });
  });

  group('Edge-кейсы и ошибки', () {
    test('18. Message.fromJson — timestamp как строка с миллисекундами', () {
      final json = {
        'id': 'm4',
        'chat_id': 'c1',
        'sender_id': 'u1',
        'text': 'Тест',
        'timestamp': '2026-03-08T19:30:45.123Z',
      };

      final message = Message.fromJson(json);
      expect(message.timestamp.millisecond, 123);
    });

    test('19. Contact.displayName — приоритет имени над email', () {
      final contact = Contact(
        id: 'c9',
        ownerUid: 'u1',
        contactUid: 'u2',
        contactEmail: 'email@domain.com',
        contactName: 'Саша',
        createdAt: DateTime.now(),
      );
      expect(contact.displayName, 'Саша');
    });

    test('20. Contact.initial — uppercase первая буква', () {
      final contact = Contact(
        id: 'c10',
        ownerUid: 'u1',
        contactUid: 'u2',
        contactEmail: 'lower@mail.ru',
        contactName: 'нижний регистр',
        createdAt: DateTime.now(),
      );
      expect(contact.initial, 'Н');
    });

    test('22. Contact.toJson — дата в ISO 8601', () {
      final date = DateTime.utc(2026, 3, 8, 20, 45, 30);
      final contact = Contact(
        id: 'c11',
        ownerUid: 'u',
        contactUid: 'u2',
        contactEmail: 'e@mail.ru',
        contactName: 'Имя',
        createdAt: date,
      );

      final json = contact.toJson();
      expect(json['created_at'], '2026-03-08T20:45:30.000Z');
    });

  });
  });
}