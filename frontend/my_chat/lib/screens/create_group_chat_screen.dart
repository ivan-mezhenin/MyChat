import 'package:flutter/material.dart';
import 'package:my_chat/models/contact.dart';
import 'package:my_chat/services/contact_service.dart';
import 'package:my_chat/services/chat_creator_service.dart';
import 'package:my_chat/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_chat/services/websocket_service.dart';

class CreateGroupChatScreen extends StatefulWidget {
  final String userUID;
  final WebSocketService webSocketService;

  const CreateGroupChatScreen({super.key, required this.userUID, required this.webSocketService});

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

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _contactService = ContactService(prefs: prefs);
    _chatCreationService = ChatCreationService(prefs: prefs);

    await _loadContacts();
  }

  Future<void> _loadContacts() async {
      if (_contactService == null) return; 

    final response = await _contactService!.getContacts();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success) {
          _contacts = response.data!;
        }
      });
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

    if (_chatCreationService == null || _contactService == null) {
        _showSnackBar('Сервисы не инициализированы');
        return;
        }
    if (_chatNameController.text.isEmpty) {
      _showSnackBar('Please enter chat name');
      return;
    }

    if (_selectedContacts.isEmpty) {
      _showSnackBar('Please select at least one contact');
      return;
    }

    _showLoadingDialog('Creating group chat...');
    
    final response = await _chatCreationService!.createChatFromContacts(
      chatName: _chatNameController.text,
      contactIds: _selectedContacts.map((c) => c.id).toList(),
      chatType: 'group',
    );
    if (!mounted) return; 
    Navigator.pop(context);
    
    if (response.success) {
      final chat = response.data!;
      _openChatScreen(chat.id, chat.name);
    } else {
      _showSnackBar('Error: ${response.error}');
    }
  }

  void _openChatScreen(String chatId, String chatName) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          chatName: chatName,
          userUID: widget.userUID,
          webSocketService: widget.webSocketService,
        ),
      ),
      (route) => route.isFirst,
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
            'Selected contacts:',
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
    if (_contacts.isEmpty) {
      return const Center(
        child: Text(
          'No contacts available. Add contacts first.',
          style: TextStyle(color: Colors.grey),
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
          title: Text(contact.displayName),
          subtitle: Text(contact.contactEmail),
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
        title: const Text('Create Group Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _createGroupChat,
            tooltip: 'Create chat',
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
                labelText: 'Chat Name',
                hintText: 'Enter chat name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat),
              ),
            ),
          ),
          _buildSelectedContacts(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContactList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_contactService == null || _chatCreationService == null) {
      super.dispose();
      return;
    }
    _contactService!.dispose();
    _chatCreationService!.dispose();
    _chatNameController.dispose();
    super.dispose();
  }
}