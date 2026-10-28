
import 'package:flutter/material.dart';
import '../theme.dart';

class FrequentPlacesSheet extends StatefulWidget {
  final Function(String) onPlaceSelected;

  const FrequentPlacesSheet({
    super.key,
    required this.onPlaceSelected,
  });

  @override
  State<FrequentPlacesSheet> createState() =>
      _FrequentPlacesSheetState();
}

class _FrequentPlacesSheetState extends State<FrequentPlacesSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _collapsedSize = 0.08;
  static const double _expandedSize = 0.4;

  bool _isExpanded = false;

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;

    setState(() {
      _isExpanded = !_isExpanded;
    });

    _sheetController.animateTo(
      _isExpanded ? _expandedSize : _collapsedSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    if (keyboardHeight > 0) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _collapsedSize,
      minChildSize: _collapsedSize,
      maxChildSize: _expandedSize,
      snap: true,
      snapSizes: const [_collapsedSize, _expandedSize],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
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
                child: InkWell(
                  onTap: _toggleSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Lugares frecuentes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: MijanoTheme.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: MijanoTheme.solDeep,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildQuickButton('Casa', Icons.home),
                    _buildQuickButton('Trabajo', Icons.work),
                    _buildQuickButton(
                      'Supermercado',
                      Icons.shopping_cart,
                    ),
                    _buildQuickButton(
                      'Hospital',
                      Icons.local_hospital,
                    ),
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
      onTap: () => widget.onPlaceSelected(label),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
