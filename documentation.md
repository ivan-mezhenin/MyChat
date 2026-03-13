# Техническая документация проекта MyChat

**Версия:** 1.0  
**Дата:** март 2026  
**Автор:** Иван Меженин  

## 1. Общая архитектура

Приложение — десктопный мессенджер реального времени (macOS, Windows, Linux).  
Архитектура — клиент-серверная с WebSocket-соединением.

### Высокоуровневая схема

```mermaid
graph TD
    A["Flutter Client<br>(macOS / Windows / Linux)"] 
    -->|WebSocket (wss)| B["Go Backend<br>(Echo + gorilla/websocket)"]
    B -->|Firebase Admin SDK| C["Firebase Authentication"]
    B -->|Firestore SDK| D["Cloud Firestore<br>(чатов, сообщений, контактов)"]
    A -->|HTTP (REST)| B
2. Backend (Go)
Основные модули

cmd/server/main.go — точка входа
internal/handlers/ — обработчики HTTP (auth, contacts, chats)
internal/services/ — бизнес-логика (auth_service.go, chat_service.go, contact_service.go)
internal/websocket/ — WebSocket-сервер (подключения, рассылка сообщений, typing-индикаторы)
internal/firebase/ — инициализация Firebase Admin SDK + Firestore
internal/models/ — структуры данных (Chat, Message, Contact)

Ключевые технологии

Go 1.26
Echo (роутинг, middleware)
gorilla/websocket (реальное время)
Firebase Admin SDK (аутентификация и Firestore)

3. Frontend (Flutter)
Структура проекта
textlib/
├── main.dart
├── screens/
│   ├── authentication_screen.dart
│   ├── chats_screen.dart
│   ├── contacts_screen.dart
│   └── chat_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── chat_service.dart
│   ├── contact_service.dart
│   └── websocket_service.dart
├── models/
│   ├── contact.dart
│   ├── chat.dart
│   └── message.dart
└── config/
    └── websocket_config.dart
Ключевые компоненты

WebSocketService — подключение, reconnect, обработка событий (new_message, typing, message_read)
AuthService — логин/регистрация + хранение токена в SharedPreferences
ChatService / ContactService — REST-запросы к backend
UI — экраны с использованием Provider / setState

Технологии

Flutter (Dart)
SharedPreferences (хранение токена)
web_socket_channel (WebSocket-клиент)

4. Протокол WebSocket
Формат сообщений (JSON):
JSON{
  "type": "send_message | new_message | typing | message_read | auth",
  "data": { ... }
}
Основные типы:

send_message — отправка сообщения клиентом
new_message — рассылка всем участникам чата
typing — индикатор набора текста
message_read — отметка о прочтении

5. База данных (Firestore)
Коллекции:

users — профили пользователей
contacts — связи между пользователями
chats — чаты (приватные и групповые)
messages — сообщения внутри чата

6. Безопасность

Firebase Authentication (JWT-токены)
Проверка токена на каждом WebSocket-подключении
CORS на backend
SharedPreferences + secure storage на клиенте

7. Взаимосвязь компонентов
FirebaseGoServerFlutterClientUserFirebaseGoServerFlutterClientUser#mermaid-diagram-mermaid-i1x3bti{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;fill:#ccc;}@keyframes edge-animation-frame{from{stroke-dashoffset:0;}}@keyframes dash{to{stroke-dashoffset:0;}}#mermaid-diagram-mermaid-i1x3bti .edge-animation-slow{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 50s linear infinite;stroke-linecap:round;}#mermaid-diagram-mermaid-i1x3bti .edge-animation-fast{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 20s linear infinite;stroke-linecap:round;}#mermaid-diagram-mermaid-i1x3bti .error-icon{fill:#a44141;}#mermaid-diagram-mermaid-i1x3bti .error-text{fill:#ddd;stroke:#ddd;}#mermaid-diagram-mermaid-i1x3bti .edge-thickness-normal{stroke-width:1px;}#mermaid-diagram-mermaid-i1x3bti .edge-thickness-thick{stroke-width:3.5px;}#mermaid-diagram-mermaid-i1x3bti .edge-pattern-solid{stroke-dasharray:0;}#mermaid-diagram-mermaid-i1x3bti .edge-thickness-invisible{stroke-width:0;fill:none;}#mermaid-diagram-mermaid-i1x3bti .edge-pattern-dashed{stroke-dasharray:3;}#mermaid-diagram-mermaid-i1x3bti .edge-pattern-dotted{stroke-dasharray:2;}#mermaid-diagram-mermaid-i1x3bti .marker{fill:lightgrey;stroke:lightgrey;}#mermaid-diagram-mermaid-i1x3bti .marker.cross{stroke:lightgrey;}#mermaid-diagram-mermaid-i1x3bti svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;}#mermaid-diagram-mermaid-i1x3bti p{margin:0;}#mermaid-diagram-mermaid-i1x3bti .actor{stroke:#ccc;fill:#1f2020;}#mermaid-diagram-mermaid-i1x3bti text.actor>tspan{fill:lightgrey;stroke:none;}#mermaid-diagram-mermaid-i1x3bti .actor-line{stroke:#ccc;}#mermaid-diagram-mermaid-i1x3bti .messageLine0{stroke-width:1.5;stroke-dasharray:none;stroke:lightgrey;}#mermaid-diagram-mermaid-i1x3bti .messageLine1{stroke-width:1.5;stroke-dasharray:2,2;stroke:lightgrey;}#mermaid-diagram-mermaid-i1x3bti #arrowhead path{fill:lightgrey;stroke:lightgrey;}#mermaid-diagram-mermaid-i1x3bti .sequenceNumber{fill:black;}#mermaid-diagram-mermaid-i1x3bti #sequencenumber{fill:lightgrey;}#mermaid-diagram-mermaid-i1x3bti #crosshead path{fill:lightgrey;stroke:lightgrey;}#mermaid-diagram-mermaid-i1x3bti .messageText{fill:lightgrey;stroke:none;}#mermaid-diagram-mermaid-i1x3bti .labelBox{stroke:#ccc;fill:#1f2020;}#mermaid-diagram-mermaid-i1x3bti .labelText,#mermaid-diagram-mermaid-i1x3bti .labelText>tspan{fill:lightgrey;stroke:none;}#mermaid-diagram-mermaid-i1x3bti .loopText,#mermaid-diagram-mermaid-i1x3bti .loopText>tspan{fill:lightgrey;stroke:none;}#mermaid-diagram-mermaid-i1x3bti .loopLine{stroke-width:2px;stroke-dasharray:2,2;stroke:#ccc;fill:#ccc;}#mermaid-diagram-mermaid-i1x3bti .note{stroke:hsl(180, 0%, 18.3529411765%);fill:hsl(180, 1.5873015873%, 28.3529411765%);}#mermaid-diagram-mermaid-i1x3bti .noteText,#mermaid-diagram-mermaid-i1x3bti .noteText>tspan{fill:rgb(183.8476190475, 181.5523809523, 181.5523809523);stroke:none;}#mermaid-diagram-mermaid-i1x3bti .activation0{fill:hsl(180, 1.5873015873%, 28.3529411765%);stroke:#ccc;}#mermaid-diagram-mermaid-i1x3bti .activation1{fill:hsl(180, 1.5873015873%, 28.3529411765%);stroke:#ccc;}#mermaid-diagram-mermaid-i1x3bti .activation2{fill:hsl(180, 1.5873015873%, 28.3529411765%);stroke:#ccc;}#mermaid-diagram-mermaid-i1x3bti .actorPopupMenu{position:absolute;}#mermaid-diagram-mermaid-i1x3bti .actorPopupMenuPanel{position:absolute;fill:#1f2020;box-shadow:0px 8px 16px 0px rgba(0,0,0,0.2);filter:drop-shadow(3px 5px 2px rgb(0 0 0 / 0.4));}#mermaid-diagram-mermaid-i1x3bti .actor-man line{stroke:#ccc;fill:#1f2020;}#mermaid-diagram-mermaid-i1x3bti .actor-man circle,#mermaid-diagram-mermaid-i1x3bti line{stroke:#ccc;fill:#1f2020;stroke-width:2px;}#mermaid-diagram-mermaid-i1x3bti :root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}Открывает чатWebSocket connect + tokenValidate tokenConnection OKsend_messageSave to Firestorenew_message (broadcast)
8. Развёртывание

Backend: VPS / Docker (порт 8080)
Frontend: flutter build macos / flutter build windows / flutter build linux
Web-версия (опционально): flutter build web

9. Технологический стек





























СлойТехнологияBackendGo 1.26 + Echo + gorilla/websocketAuth + DBFirebase Authentication + FirestoreFrontendFlutter (Dart)Реальное времяWebSocketХранениеSharedPreferences
