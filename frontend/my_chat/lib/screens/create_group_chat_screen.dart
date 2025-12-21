import 'package:flutter/material.dart';
import 'package:my_chat/models/contact.dart';
import 'package:my_chat/services/contact_service.dart';
import 'package:my_chat/services/chat_creator_service.dart';
import 'package:my_chat/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateGroupChatScreen extends StatefulWidget {
  final String userUID;

  const CreateGroupChatScreen({
    super.key, 
    required this.userUID, 
  });

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  ContactService? _contactService;
  ChatCreationService? _chatCreationService;
  List<Contact> _contacts = [];
  final List<Contact> _selectedContacts = [];
  final TextEditingController _chatNameController = TextEditingController();
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _contactService = ContactService(prefs: prefs);
      _chatCreationService = ChatCreationService(prefs: prefs);

      await _loadContacts();
    } catch (e) {
      _printDebug('Error initializing services: $e');
      _showSnackBar('Ошибка инициализации');
    }
  }

  Future<void> _loadContacts() async {
    if (_contactService == null) {
      _printDebug('Contact service not initialized');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _contactService!.getContacts();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success) {
            _contacts = response.data!;
            _printDebug('Loaded ${_contacts.length} contacts');
          } else {
            _showSnackBar('Не удалось загрузить контакты');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Ошибка загрузки контактов');
      }
    }
  }

  void _toggleContactSelection(Contact contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  Future<void> _createGroupChat() async {
    if (_isCreating) return;

    if (_chatCreationService == null || _contactService == null) {
      _showSnackBar('Сервисы не инициализированы');
      return;
    }

    if (_chatNameController.text.isEmpty) {
      _showSnackBar('Введите название чата');
      return;
    }

    if (_selectedContacts.isEmpty) {
      _showSnackBar('Выберите хотя бы один контакт');
      return;
    }

    setState(() => _isCreating = true);
    
    _showLoadingDialog('Создание группового чата...');
    
    try {
      final response = await _chatCreationService!.createChatFromContacts(
        chatName: _chatNameController.text,
        contactIds: _selectedContacts.map((c) => c.id).toList(),
        chatType: 'group',
      );
      
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isCreating = false);
      
      if (response.success) {
        final chat = response.data!;
        _printDebug('Chat created successfully: ${chat.id}');
        _openChatScreen(chat.id, chat.name);
      } else {
        _showSnackBar('Ошибка: ${response.error}');
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isCreating = false);
      _printDebug('Error creating chat: $e\n$stackTrace');
      _showSnackBar('Ошибка при создании чата');
    }
  }

  void _openChatScreen(String chatId, String chatName) {
    Navigator.pop(context);
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: chatName,
              userUID: widget.userUID,
            ),
          ),
        );
      }
    });
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

  void _printDebug(String message) {
    debugPrint('[CreateGroupChat] $message');
  }

  Widget _buildSelectedContacts() {
    if (_selectedContacts.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Выбранные контакты:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _selectedContacts.length,
            itemBuilder: (context, index) {
              final contact = _selectedContacts[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(contact.initial),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _toggleContactSelection(contact),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        contact.displayName,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildContactList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Нет доступных контактов',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте контакты сначала',
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
        final isSelected = _selectedContacts.contains(contact);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected ? Colors.blue : Colors.grey,
            child: Text(
              contact.initial,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            contact.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            contact.contactEmail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleContactSelection(contact),
          ),
          onTap: () => _toggleContactSelection(contact),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать групповой чат'),
        actions: [
          if (!_isCreating)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _createGroupChat,
              tooltip: 'Создать чат',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _chatNameController,
              decoration: const InputDecoration(
                labelText: 'Название чата',
                hintText: 'Введите название чата',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat),
              ),
              maxLength: 50,
            ),
          ),
          _buildSelectedContacts(),
          Expanded(
            child: _buildContactList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatNameController.dispose();
    super.dispose();
  }
}