import 'package:flutter/material.dart';
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

    
    await _fs.sendAdminOrDriverSupportMessage(
      driverUid: widget.driverUid,
      driverName: widget.driverName,
      text: text,
      isAdmin: false, 
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Listado de mensajes en tiempo real desde support_chats
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
                    final isAdmin = data['isAdmin'] ?? false;
                    final text = data['text'] ?? '';

                    return Align(
                      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isAdmin ? MijanoTheme.cream : MijanoTheme.sol.withOpacity(0.4),
                          border: Border.all(
                            color: isAdmin ? MijanoTheme.ink.withOpacity(0.2) : MijanoTheme.ink,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin ? 'Soporte (Central)' : 'Tú',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAdmin ? MijanoTheme.ink : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              text,
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