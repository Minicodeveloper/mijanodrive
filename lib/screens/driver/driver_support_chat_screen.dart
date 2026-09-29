import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart'; 

class SupportChatScreen extends StatefulWidget {
  final String driverUid;
  final String driverName; 

  const SupportChatScreen({
    super.key, 
    required this.driverUid,
    required this.driverName,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirestoreService _fs = FirestoreService.instance;

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final text = _controller.text.trim();
    _controller.clear();
    
    // Método correcto para enviar mensajes desde la app del conductor
    await _fs.sendDriverSupportMessage(
      driverUid: widget.driverUid,
      driverName: widget.driverName,
      text: text,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Soporte con la Central',
          style: TextStyle(fontWeight: FontWeight.w900, color: MijanoTheme.ink),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fs.supportMessagesForDriver(widget.driverUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        '¿Tienes algún inconveniente con tus viajes o pagos? Escríbenos y la administración te responderá pronto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true, 
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = messages.length - 1 - index;
                    final data = messages[reversedIndex];
                    
                    final senderId = data['senderId'] ?? data['userId'] ?? '';
                    final isAdmin = data['isAdmin'] ?? false;

                    // El mensaje es tuyo si proviene de tu ID o rol conductor y NO es del admin
                    final bool isMyMessage = (senderId == currentUserId || data['senderRole'] == 'driver') && !isAdmin;

                    return Align(
                      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMyMessage ? MijanoTheme.sol.withOpacity(0.4) : MijanoTheme.cream,
                          border: Border.all(
                            color: MijanoTheme.ink,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMyMessage ? 'Tú' : 'Soporte (Central)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMyMessage ? Colors.black54 : MijanoTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['text'] ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                color: MijanoTheme.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu consulta a soporte...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: MijanoTheme.ink),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}