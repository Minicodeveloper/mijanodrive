import 'package:flutter/material.dart';
import '../theme.dart';

class FrequentPlacesSheet extends StatelessWidget {
  final Function(String) onPlaceSelected;

  const FrequentPlacesSheet({super.key, required this.onPlaceSelected});

  @override
  Widget build(BuildContext context) {
    // Si el teclado está abierto, ocultamos el sheet para no estorbar
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardHeight > 0) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.08,
      minChildSize: 0.08,
      maxChildSize: 0.4,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lugares frecuentes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MijanoTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildQuickButton('Casa', Icons.home),
                    _buildQuickButton('Trabajo', Icons.work),
                    _buildQuickButton('Supermercado', Icons.shopping_cart),
                    _buildQuickButton('Hospital', Icons.local_hospital),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickButton(String label, IconData icon) {
    return InkWell(
      onTap: () => onPlaceSelected(label),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: MijanoTheme.solDeep),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}