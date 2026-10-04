import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';

class ChatScreen extends StatefulWidget {
  final String tripId;
  final String driverId;
  final String driverName;

  const ChatScreen({
    super.key,
    required this.tripId,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.tripId.isEmpty) return;

    // Limpiamos la caja de texto de inmediato para mejor fluidez
    _messageController.clear();

    try {
      // Guardamos el mensaje en Firestore
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MijanoTheme.sol,
        title: Text(
          'Chat con ${widget.driverName}',
          style: const TextStyle(color: MijanoTheme.ink, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: Column(
        children: [
          // 1. LISTA DE MENSAJES EN TIEMPO REAL
          Expanded(
            child: widget.tripId.isEmpty
                ? const Center(child: Text('Error: ID de viaje no válido'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('trips')
                        .doc(widget.tripId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error al cargar mensajes:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay mensajes aún. ¡Escribe el primero!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Muestra los mensajes nuevos abajo
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final senderId = data['senderId'] ?? '';
                          final messageText = data['text'] ?? '';
                          final isMe = senderId == currentUserId;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? MijanoTheme.sol : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                                  bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                messageText,
                                style: TextStyle(
                                  color: isMe ? MijanoTheme.ink : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // 2. CAJA DE TEXTO PARA ESCRIBIR
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: MijanoTheme.sol,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: MijanoTheme.ink),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}