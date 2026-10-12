import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';

class DocumentViewerDialog extends StatelessWidget {
  final String url;
  final String title;

  const DocumentViewerDialog({
    super.key,
    required this.url,
    required this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String url,
    required String title,
  }) {
    if (url.trim().isEmpty) return Future.value();
    return showDialog(
      context: context,
      builder: (context) => DocumentViewerDialog(url: url, title: title),
    );
  }

  bool get _isPdf => url.toLowerCase().contains('.pdf');

  Future<void> _openExternal() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: maxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: MijanoTheme.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Contenido (PDF o Imagen)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _isPdf
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text(
                                'Documento PDF',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MijanoTheme.ink,
                                  foregroundColor: MijanoTheme.sol,
                                ),
                                onPressed: _openExternal,
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Abrir en nueva pestaña'),
                              ),
                            ],
                          ),
                        )
                      : InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(color: MijanoTheme.sol),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'No se pudo cargar el archivo',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (!_isPdf) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openExternal,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Abrir en nueva pestaña', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
