import 'package:flutter/material.dart';

class SelectComponent extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final int initial;
  final Function(Map<String, dynamic>)? onChanged;
  final String? label;

  const SelectComponent({
    super.key,
    required this.data,
    this.initial = 0,
    this.onChanged,
    this.label,
  });

  @override
  State<SelectComponent> createState() => _SelectComponentState();
}

class _SelectComponentState extends State<SelectComponent> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initial.clamp(0, widget.data.length - 1);
  }

  // Get all items
  List<Map<String, dynamic>> getItems() {
    return widget.data;
  }

  // Get currently selected item
  Map<String, dynamic> getSelectedItem() {
    if (_selectedIndex >= 0 && _selectedIndex < widget.data.length) {
      return widget.data[_selectedIndex];
    }
    return widget.data.isNotEmpty ? widget.data[0] : {};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          if (widget.label != null) ...[
            const Icon(Icons.language, color: Colors.grey, size: 16), // Default icon
            const SizedBox(width: 8),
          ],
          Expanded(
            child: DropdownButton<int>(
              value: _selectedIndex,
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: Container(),
              isExpanded: true,
              items: widget.data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                
                return DropdownMenuItem<int>(
                  value: index,
                  child: Row(
                    children: [
                      if (item['icon'] != null) ...[
                        Icon(item['icon'], size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          item['displayName'] ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (int? newIndex) {
                if (newIndex != null && newIndex != _selectedIndex) {
                  setState(() {
                    _selectedIndex = newIndex;
                  });
                  
                  // Call the callback with selected item
                  if (widget.onChanged != null) {
                    widget.onChanged!(getSelectedItem());
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}