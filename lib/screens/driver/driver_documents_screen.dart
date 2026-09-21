import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  
  final Map<String, String> _documentNames = {
    'criminalRecord': 'Antecedentes Penales',
    'docBack': 'DNI (Reverso)',
    'docFront': 'DNI (Anverso)',
    'facePhoto': 'Foto de Rostro',
    'licensedDocument': 'Licencia de Conducir',
    'policeRecord': 'Antecedentes Policiales',
    'propertyCardPhoto': 'Tarjeta de Propiedad',
    'soatPhoto': 'SOAT / Seguro',
    'vehiclePhoto': 'Foto del Vehículo',
  };

  
  Future<void> _checkAndCreateDefaultDocuments(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final docSnapshot = await userRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>?;
        
        if (data == null || !data.containsKey('documents') || data['documents'] is! Map) {
          final defaultDocumentsMap = {
            'criminalRecord': {'url': '', 'status': 'pending'},
            'docBack': {'url': '', 'status': 'pending'},
            'docFront': {'url': '', 'status': 'pending'},
            'facePhoto': {'url': '', 'status': 'pending'},
            'licensedDocument': {'url': '', 'status': 'pending'},
            'policeRecord': {'url': '', 'status': 'pending'},
            'propertyCardPhoto': {'url': '', 'status': 'pending'},
            'soatPhoto': {'url': '', 'status': 'pending'},
            'vehiclePhoto': {'url': '', 'status': 'pending'},
          };

          await userRef.set({'documents': defaultDocumentsMap}, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error al inicializar documentos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = fb.FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mis Documentos Enviados', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Color(0xFFF9D408)),
      ),
      body: user == null
          ? const Center(
              child: Text('No hay una sesión activa.', style: TextStyle(color: Colors.white70)),
            )
          : FutureBuilder(
              future: _checkAndCreateDefaultDocuments(user.uid),
              builder: (context, initSnapshot) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFF9D408)));
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text('No se encontró información del usuario.', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    final userData = snapshot.data!.data() as Map<String, dynamic>?;
                    final Map<String, dynamic> documentsMap = userData?['documents'] ?? {};

                    if (documentsMap.isEmpty) {
                      return const Center(
                        child: Text('No hay documentos registrados.', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    final docKeys = documentsMap.keys.toList();

                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8, 
                      ),
                      itemCount: docKeys.length,
                      itemBuilder: (context, index) {
                        final key = docKeys[index];
                        final docName = _documentNames[key] ?? key;

                        
                        final docData = documentsMap[key];
                        String imageUrl = '';
                        String status = 'pending';

                        if (docData is Map) {
                          imageUrl = docData['url']?.toString().trim() ?? '';
                          status = docData['status']?.toString().trim() ?? 'pending';
                        } else if (docData is String) {
                          imageUrl = docData.trim();
                        }

                        
                        if (status == 'rejected') {
                          imageUrl = '';
                        }

                        final bool hasImage = imageUrl.isNotEmpty && imageUrl.startsWith('http');
                        final bool isRejected = (status == 'rejected');

                        return GestureDetector(
                          onTap: hasImage ? () => _showImageDialog(context, imageUrl, docName) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRejected 
                                    ? Colors.red 
                                    : (hasImage ? Colors.green : const Color(0xFFF9D408).withOpacity(0.5)),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. TÍTULO DEL DOCUMENTO
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    docName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                
                                
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: isRejected
                                        ? Padding(
                                            padding: const EdgeInsets.all(6.0),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.error_outline, color: Colors.red, size: 28),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Rechazado\nVuelva a subir',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          )
                                        : (hasImage
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return const Center(
                                                      child: CircularProgressIndicator(color: Color(0xFFF9D408), strokeWidth: 2),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) => const Center(
                                                    child: Icon(Icons.broken_image, color: Colors.red),
                                                  ),
                                                ),
                                              )
                                            : const Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.hourglass_top, color: Color(0xFFF9D408), size: 30),
                                                  SizedBox(height: 6),
                                                  Text(
                                                    'Sin subir',
                                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                                  ),
                                                ],
                                              )),
                                  ),
                                ),

                                
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isRejected 
                                            ? Icons.cancel 
                                            : (hasImage ? Icons.check_circle : Icons.info_outline),
                                        size: 14,
                                        color: isRejected 
                                            ? Colors.red 
                                            : (hasImage ? Colors.green : const Color(0xFFF9D408)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isRejected 
                                            ? 'Rechazado' 
                                            : (hasImage ? 'Registrado' : 'Pendiente'),
                                        style: TextStyle(
                                          color: isRejected 
                                              ? Colors.red 
                                              : (hasImage ? Colors.green : const Color(0xFFF9D408)),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  void _showImageDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Color(0xFFF9D408)));
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFFF9D408))),
          ),
        ],
      ),
    );
  }
}