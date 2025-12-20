import 'package:flutter/material.dart';
import 'package:my_chat/models/contact.dart';
import 'package:my_chat/services/contact_service.dart';
import 'package:my_chat/services/chat_creator_service.dart';
import 'package:my_chat/screens/chat_screen.dart';
import 'package:my_chat/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsScreen extends StatefulWidget {
  final String userUID;
  final WebSocketService webSocketService;

  const ContactsScreen({
    super.key, 
    required this.userUID, 
    required this.webSocketService,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  ContactService? _contactService;
  ChatCreationService? _chatCreationService;
  List<Contact> _contacts = [];
  bool _isLoading = true;
  bool _isInitializing = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    debugPrint('ContactsScreen initState');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
      _isLoading = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      _contactService = ContactService(prefs: prefs);
      _chatCreationService = ChatCreationService(prefs: prefs);
      
      debugPrint('Services initialized successfully');
      
      await _loadContacts();
      
    } catch (e, stackTrace) {
      debugPrint('Error initializing ContactsScreen: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _error = 'Ошибка инициализации: ${e.toString()}';
          _isLoading = false;
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _loadContacts() async {
    if (!mounted || _contactService == null) {
      debugPrint('Cannot load contacts: service not initialized');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      debugPrint('Loading contacts...');
      final response = await _contactService!.getContacts();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitializing = false;
          
          if (response.success) {
            _contacts = response.data ?? [];
            debugPrint('Loaded ${_contacts.length} contacts');
          } else {
            _error = response.error ?? 'Не удалось загрузить контакты';
            debugPrint('Error loading contacts: $_error');
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Exception in _loadContacts: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitializing = false;
          _error = 'Ошибка загрузки: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _addContact() async {
    if (_contactService == null) {
      _showSnackBar('Сервис контактов не инициализирован');
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddContactDialog(),
    );

    if (result != null) {
      final email = result['email'];
      final notes = result['notes'];
      
      if (email != null && email.isNotEmpty) {
        _showLoadingDialog('Добавление контакта...');
        
        try {
          final response = await _contactService!.addContact(email, notes: notes);
          
            if (!mounted) return;
          Navigator.pop(context);
          
          if (response.success) {
            await _loadContacts();
            _showSnackBar('Контакт успешно добавлен');
          } else {
            _showSnackBar('Ошибка: ${response.error}');
          }
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context);
          _showSnackBar('Ошибка при добавлении: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _startPrivateChat(Contact contact) async {
    if (_chatCreationService == null) {
      _showSnackBar('Сервис создания чатов не инициализирован');
      return;
    }

    _showLoadingDialog('Создание чата...');
    
    try {
      final response = await _chatCreationService!.createPrivateChat(contact.id);
      if (!mounted) return;
      Navigator.pop(context);
      
      if (response.success) {
        final chat = response.data!;
        _openChatScreen(chat.id, chat.name);
      } else {
        _showSnackBar('Ошибка: ${response.error}');
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Ошибка при создании чата: ${e.toString()}');
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    if (_contactService == null) {
      _showSnackBar('Сервис контактов не инициализирован');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить контакт'),
        content: Text('Удалить ${contact.contactName} (${contact.contactEmail}) из контактов?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final response = await _contactService!.deleteContact(contact.id);
        
        if (response.success) {
          setState(() {
            _contacts.removeWhere((c) => c.id == contact.id);
          });
          _showSnackBar('Контакт удален');
        } else {
          _showSnackBar('Ошибка: ${response.error}');
        }
      } catch (e) {
        _showSnackBar('Ошибка при удалении: ${e.toString()}');
      }
    }
  }

  void _openChatScreen(String chatId, String chatName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          chatName: chatName,
          userUID: widget.userUID,
          webSocketService: widget.webSocketService, 
        ),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildContactList() {
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Контактов пока нет',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите + чтобы добавить контакт',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ContactListItem(
          contact: contact,
          onTap: () => _startPrivateChat(contact),
          onDelete: () => _deleteContact(contact),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Инициализация...'),
          ],
        ),
      );
    }
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ошибка: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContacts,
              child: const Text('Повторить'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _initializeApp,
              child: const Text('Перезапустить'),
            ),
          ],
        ),
      );
    }
    
    return _buildContactList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addContact,
            tooltip: 'Добавить контакт',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  @override
  void dispose() {
    debugPrint('ContactsScreen dispose');
    
    _contactService?.dispose();
    _chatCreationService?.dispose();
    
    super.dispose();
  }
}

class ContactListItem extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ContactListItem({
    super.key,
    required this.contact,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          contact.initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        contact.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(contact.contactEmail),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') onDelete();
          if (value == 'chat') onTap();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'chat',
            child: Row(
              children: [
                Icon(Icons.chat, size: 20),
                SizedBox(width: 8),
                Text('Start Chat'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class AddContactDialog extends StatefulWidget {
    const AddContactDialog({super.key});
  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Contact'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'user@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., Colleague from work',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              Navigator.pop(context, {
                'email': _emailController.text.trim(),
                'notes': _notesController.text.trim(),
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}