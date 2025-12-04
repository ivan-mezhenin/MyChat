// lib/models/message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
  });

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      chatId: data['chatId'],
      senderId: data['senderId'],
      text: data['text'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: MessageType.values[data['type'] ?? 0],
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      chatId: json['chat_id'] ?? json['chatId'] ?? '',
      senderId: json['sender_id'] ?? json['senderId'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      type: MessageType.values[json['type'] ?? 0],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.index,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
    };
  }
}

enum MessageType { text, image, file }