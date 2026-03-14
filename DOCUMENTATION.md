# Техническая документация MyChat

## 1. Общие сведения

### Введение
Данный документ описывает техническую архитектуру клиент-серверного приложения для обмена сообщениями MyChat. Проект состоит из серверной части на Go и клиентской части на Flutter. В нем реализованы регистрация, аутентификация, управление контактами, создание личных и групповых чатов, а также обмен сообщениями в реальном времени через WebSocket.

### Технологии и стек
**Backend (Go):**
- `Echo` — веб-фреймворк для обработки HTTP-запросов
- `Firebase Admin SDK` — интеграция с Firebase Authentication и Firestore
- `Gorilla WebSocket` — управление WebSocket-соединениями
- `Firestore Database` — база данных

**Frontend (Flutter):**
- `Flutter SDK` — кросс-платформенная разработка UI
- `http` — выполнение HTTP-запросов к API
- `web_socket_channel` — работа с WebSocket
- `shared_preferences` — хранение токена на устройстве

## 2. Архитектура приложения

Приложение построено по **классической клиент-серверной модели**  
с чётким разделением ответственности.

```text
                 ┌───────────────────────┐
                 │        Клиент         │
                 │      (Flutter)        │
                 └────────────┬──────────┘
          HTTP / WebSocket    │
      ┌───────────────────────┘
      ▼
┌─────────────────────────────┐
│         Сервер (Go)         │
│   бизнес-логика, валидация  │
└────────────────┬────────────┘
                 |
              Firebase
      ┌──────────┴──────────┐
      ▼                     ▼
┌────────────────┐    ┌──────────────┐
│  Auth          │    │  Firestore   │
│(аутентификация)│    │  (данные)    │
└────────────────┘    └──────────────┘
```

### Серверная часть (Go + Google Firebase)

#### Структура проекта
```text
MyChatServer/
├── cmd/
│   └── main.go                # Точка входа, запуск сервера
└── internal/
    ├── database/              # Клиент Firebase (Firestore + Auth)
    ├── registration/          # Регистрация новых пользователей
    ├── authentication/        # Аутентификация, токены
    ├── contact/               # Контакты
    ├── chat/                  # Чаты, сообщения
    └── websocket/             # Управление ws-соединениями
```

### Основные компоненты сервера

#### Слой данных (`database`)
```go
type Client struct {
    Auth      *auth.Client       // Firebase Authentication клиент
    Firestore *firestore.Client  // Firestore клиент
    APIKey    string             // API ключ Firebase
}
```
#### Ответственность:

* Инкапсулирует клиенты Firebase Authentication и Firestore
* Предоставляет унифицированный интерфейс для работы с Firebase
* Реализует методы: `CreateUserInAuth`, `SaveUserInFirestore`, `GetUserByEmail`, `ValidateIdToken`
  
#### Регистрация (`registration`)
```go
type Service struct {
    db *database.Client
}

type RegisterRequest struct {
    Username string `json:"username"`
    Email    string `json:"email"`
    Password string `json:"password"`
}
```
#### Процесс регистрации:

1. Получение запроса `POST /api/auth/register`
2. Валидация полей
3. Создание пользователя в Firebase Authentication
4. Сохранение профиля пользователя в Firestore
5. Возврат успешного ответа

#### Аутентификация (`authentication`)
```go
type Service struct {
    db *database.Client
}

type LoginResponse struct {
    Token string         `json:"token"`
    User  UserResponse   `json:"user"`
    Chats []ChatResponse `json:"chats"`
}
```
#### Процесс аутентификации:

1. Получение запроса `POST /api/auth/login` с email/password
2. Вызов Firebase REST API для аутентификации
3. Верификация полученного ID Token
4. Получение данных пользователя и списка чатов из Firestore
5. Возврат токена и данных клиенту

#### Управление контактами (`contact`)
```go
type ContactService struct {
    db *database.Client
}

type Contact struct {
    ID           string    `json:"id"`      
    OwnerUID     string    `json:"owner_uid"`
    ContactUID   string    `json:"contact_uid"`
    ContactEmail string    `json:"contact_email"`
    ContactName  string    `json:"contact_name"`
    CreatedAt    time.Time `json:"created_at"`
    Notes        string    `json:"notes,omitempty"`
}
```
#### Основные методы:

* `AddContact` — добавление контакта по email
* `GetContacts` — получение списка контактов
* `SearchUsers` — поиск пользователей по имени/email
* `DeleteContact` — удаление контакта

#### Управление чатом (`chat`)
```go
type Service struct {
    db       *database.Client
    wsServer *websocket.Server
}

type ChatResponse struct {
    ID           string    `json:"id"`
    Name         string    `json:"name"`
    Type         string    `json:"type"`       // "private" или "group"
    CreatedBy    string    `json:"created_by"`
    CreatedAt    time.Time `json:"created_at"`
    Participants []string  `json:"participants"`
}
```
#### Основные методы:

* `GetMessages` — получение истории сообщений
* `CreateChatFromContacts` — создание группового чата
* `CreatePrivateChat` — создание личного чата

#### WebSocket сервер (`websocket`)
```go
type Server struct {
    mu            *sync.RWMutex
    clients       map[string]*Client   
    chatListeners map[string]context.CancelFunc
    db            *database.Client
}

type Client struct {
    Connection *websocket.Conn
    UserID     string
    LastSeen   time.Time
}

type WSEvent struct {
    Type   string      `json:"type"`             // send_message, new_message и т.д.
    Data   interface{} `json:"data"`
    ChatID string      `json:"chat_id,omitempty"`
    UserID string      `json:"user_id,omitempty"`
}
```

#### Модели данных (`Firestore`)

`users collection:`
```
json
{
  "uid": "string",
  "name": "string",
  "email": "string",
  "created_at": "timestamp",
  "is_banned": "boolean"
}
```
`contacts collection`:
```
json
{
  "id": "string", // ownerUID_contactUID
  "OwnerUID": "string",
  "ContactUID": "string",
  "ContactEmail": "string",
  "ContactName": "string",
  "CreatedAt": "timestamp",
  "Notes": "string (optional)"
}
```
`chats collection:`
```
json
{
  "chat_id": "string",
  "name": "string",
  "type": "string", // "private" или "group"
  "participants": ["userID1", "userID2"],
  "created_by": "string",
  "created_at": "timestamp",
  "updated_at": "timestamp",
  "last_message": {
    "text": "string",
    "timestamp": "timestamp",
    "sender_id": "string"
  }
}
```
`chats/{chatId}/messages subcollection`:
```
json
{
  "sender_id": "string",
  "text": "string",
  "timestamp": "timestamp",
  "read_by": ["userID1", "userID2"]
}

```

### Клиентская часть (Flutter)

#### Структура проекта
```text
my_chat/
├── lib/
│   ├── main.dart                                  # Точка входа
│   ├── models/                                    # Модели данных
│   │   ├── contact.dart
│   │   ├── chat.dart
│   │   └── message.dart
│   ├── screens/                                   # Экраны приложения
│   │   ├── authentication_screen.dart
│   │   ├── chats_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── contacts_screen.dart
│   │   └── create_group_chat_screen.dart
│   ├── services/                                  # Сервисы для работы с API
│   │   ├── auth_service.dart
│   │   ├── chat_service.dart
│   │   ├── chat_creator_service.dart
│   │   ├── contact_service.dart
│   │   └── websocket_service.dart
│   └── websocket_manager.dart                     # Управления WebSocket
```
### Основные компоненты

#### Управление состоянием приложения (`AuthWrapper`)
```dart
class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}
```
#### Ответственность:

* Проверка наличия сохраненного токена при запуске
* Верификация токена на сервере
* Навигация на экран аутентификации или список чатов
* Инициализация WebSocket соединения
* Модели данных

#### `Contact:`
```dart
class Contact {
  final String id;
  final String ownerUid;
  final String contactUid;
  final String contactEmail;
  final String contactName;
  final DateTime createdAt;
  final String? notes;
  
  String get displayName => contactName.isNotEmpty ? contactName : contactEmail;
  String get initial => (contactName.isNotEmpty ? contactName[0] : contactEmail[0]).toUpperCase();
}
```
#### `Chat:`

```dart
class Chat {
  final String id;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<String> participantIds;
}
```

#### `Message:`

```dart
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isSending;
  final String? tempId;
}
```

### Сервисы для API

#### Базовый класс ответа:

```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  factory ApiResponse.success(T data, [int? statusCode]) => ApiResponse(
        success: true,
        data: data,
        statusCode: statusCode,
      );

  factory ApiResponse.error(String error, [int? statusCode]) => ApiResponse(
        success: false,
        error: error,
        statusCode: statusCode,
      );
}
```
#### `AuthService:`

```dart
class AuthService {
  Future<ApiResponse<LoginResponse>> login(String email, String password)
  Future<ApiResponse<String>> register({required String username, required String email, required String password})
  Future<ApiResponse<LoginResponse>> verifyToken(String token)
}
```
#### `ChatService:`

```dart
class ChatService {
  Future<ApiResponse<List<Chat>>> getInitialData()
  Future<ApiResponse<List<Message>>> getMessages(String chatId)
}
```
#### `ContactService:`

```dart
class ContactService {
  Future<ApiResponse<List<Contact>>> getContacts()
  Future<ApiResponse<Contact>> addContact(String email, {String? notes})
  Future<ApiResponse<void>> deleteContact(String contactId)
  Future<ApiResponse<List<UserSearchResult>>> searchUsers(String query)
}
```
### WebSocket управление

#### `WebSocketManager:`

``` dart
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  
  WebSocketService? _webSocketService;
  
  Future<WebSocketService> getService() async {
    if (_webSocketService?.isConnected ?? false) {
      return _webSocketService!;
    }
    return await _connect();
  }
}
```

#### `WebSocketService:`

```dart
class WebSocketService {
  WebSocketMessageCallback? onNewMessage;   
  WebSocketMessageCallback? onUserTyping; 
  WebSocketMessageCallback? onMessageSent;  
  WebSocketMessageCallback? onMessageRead;  
  WebSocketMessageCallback? onNewChat;  
  WebSocketConnectionCallback? onConnectionChanged; 
  
  void sendMessage({required String chatId, required String text})
  void sendTypingStatus({required String chatId, required bool isTyping})
  void markMessageAsRead({required String chatId, required String messageId})
  
  bool get isConnected
}
```
## 3. Ключевые UX-механизмы

### Обмен сообщениями в реальном времени

#### Процесс отправки сообщения:

1. Пользователь вводит текст и нажимает "Отправить"
2. Сообщение добавляется в список с флагом `isSending: true`
3. WebSocket отправляет событие `send_message` на сервер
4. Сервер сохраняет сообщение в Firestore
5. Firestore listener на сервере обнаруживает новое сообщение
6. Сервер рассылает событие `new_message` всем участникам чата
7. Клиент получает событие, находит временное сообщение по `tempId` и обновляет его статус
```dart
// Отправка сообщения
void _sendMessage() {
  final tempMessage = Message(
    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
    chatId: widget.chatId,
    senderId: widget.userUID,
    text: text,
    timestamp: DateTime.now(),
    isSending: true,
    tempId: tempId,
  );
  
  setState(() => _messages.add(tempMessage));
  _webSocketService!.sendMessage(chatId: widget.chatId, text: text);
}

// Получение подтверждения
_webSocketService!.onMessageSent = (data) {
  setState(() {
    final index = _messages.indexWhere((m) => m.tempId == tempId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        id: data['message_id'],
        isSending: false,
        tempId: null,
      );
    }
  });
};
```

### Создание чатов на основе контактов

#### Процесс:

1. Пользователь выбирает контакты в `CreateGroupChatScreen`
2. Отправка запроса `POST /api/chats/create-from-contacts`
3. Сервер создает чат и уведомляет всех участников через WebSocket
4. `ChatsScreen` получает событие `chat_created` и добавляет чат в список
```dart
_webSocketService!.onNewChat = (chatData) {
  final newChat = Chat(
    id: chatData['chat_id'],
    name: chatData['name'],
    participantIds: List<String>.from(chatData['participants']),
  );
  
  setState(() {
    _chats.insert(0, newChat);
  });
};
```
