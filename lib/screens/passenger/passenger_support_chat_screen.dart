import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

/// Pantalla de soporte y atención al cliente en tiempo real para Pasajeros.
/// Mantiene la identidad visual de MijanoDrive y corrige el overflow y estilo de input.
class PassengerSupportChatScreen extends StatefulWidget {
  final String passengerUid;
  final String passengerName;

  const PassengerSupportChatScreen({
    super.key,
    required this.passengerUid,
    required this.passengerName,
  });

  @override
  State<PassengerSupportChatScreen> createState() => _PassengerSupportChatScreenState();
}

class _PassengerSupportChatScreenState extends State<PassengerSupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _fs = FirestoreService.instance;

  int _lastMessageCount = 0;
  bool _isHeaderMinimized = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom([bool animated = true]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _scrollToBottom(true);

    try {
      await _fs.sendPassengerSupportMessage(
        passengerUid: widget.passengerUid,
        passengerName: widget.passengerName,
        text: text,
      );
      _scrollToBottom(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MijanoTheme.signal,
            content: Text('Error al enviar el mensaje: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Soporte con la Central',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: MijanoTheme.ink,
            fontSize: 20,
          ),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: Column(
        children: [
          // Listado de mensajes en tiempo real desde Firestore
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fs.supportMessagesForUser(widget.passengerUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: MijanoTheme.ink),
                  );
                }

                final messages = snapshot.data ?? [];

                // Auto-scroll al recibir o enviar nuevos mensajes
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom(true);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    // Encabezado deslizable: Centro de Ayuda al Pasajero
                    if (index == 0) {
                      return _buildHelpHeader(hasMessages: messages.isNotEmpty);
                    }

                    final msg = messages[index - 1];
                    final isAdmin = (msg['isAdmin'] == true) ||
                        (msg['senderRole'] == 'admin') ||
                        (msg['senderId'] == 'admin');
                    final text = msg['text'] ?? '';

                    return _buildMessageBubble(
                      text: text,
                      isAdmin: isAdmin,
                    );
                  },
                );
              },
            ),
          ),

          // Barra inferior fija mejorada (Estilo WhatsApp moderno con colores Mijano)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: MijanoTheme.cream,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: MijanoTheme.ink.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _sendMessage(),
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: MijanoTheme.ink,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Escribe tu consulta a soporte...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            //color: Colors.black45,
                            fontWeight: FontWeight.normal,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: MijanoTheme.sol,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: MijanoTheme.ink, size: 22),
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

  /// Encabezado deslizable con la información del Centro de Ayuda (Corregido el overflow)
  Widget _buildHelpHeader({required bool hasMessages}) {
    if (hasMessages && _isHeaderMinimized) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: InkWell(
            onTap: () => setState(() => _isHeaderMinimized = false),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MijanoTheme.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MijanoTheme.ink.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent, size: 16, color: MijanoTheme.ink),
                  SizedBox(width: 6),
                  Text(
                    'Centro de Ayuda al Pasajero (Mostrar info)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: MijanoTheme.ink,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: MijanoTheme.ink),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MijanoTheme.cream,
        border: Border.all(color: MijanoTheme.ink, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.support_agent, size: 22, color: MijanoTheme.ink),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Centro de Ayuda al Pasajero',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: MijanoTheme.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMessages)
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, size: 20, color: MijanoTheme.ink),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _isHeaderMinimized = true),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '¿Tienes algún inconveniente con tus viajes, cobros o seguridad? Escríbenos y el equipo de soporte administrativo te responderá a la brevedad.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Burbuja de conversación fiel al diseño original
  Widget _buildMessageBubble({
    required String text,
    required bool isAdmin,
  }) {
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isAdmin ? MijanoTheme.cream : const Color(0xFFFFF0A6),
          border: Border.all(
            color: isAdmin
                ? MijanoTheme.ink.withValues(alpha: 0.25)
                : Colors.black,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAdmin ? 'Soporte (Central)' : 'Tú',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAdmin ? MijanoTheme.ink : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: MijanoTheme.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}