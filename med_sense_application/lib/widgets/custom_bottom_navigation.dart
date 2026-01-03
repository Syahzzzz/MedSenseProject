import 'package:flutter/material.dart';
import 'package:med_sense_application/utils/translations.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Color backgroundColor;
  final Color selectedColor;
  final Color unselectedColor;

  const CustomBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.backgroundColor = const Color(0xFFFFF9C4), // Light yellow default
    this.selectedColor = Colors.black,
    this.unselectedColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_outlined, 'label': AppTranslations.get('home')},
      {'icon': Icons.location_on_outlined, 'label': AppTranslations.get('location')},
      {'icon': Icons.calendar_today_outlined, 'label': AppTranslations.get('booking')},
      {'icon': Icons.person_outline, 'label': AppTranslations.get('profile')},
    ];

    return Container(
      height: 80, // slightly taller to accommodate the circle
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // Fix: LayoutBuilder now wraps the Stack, ensuring AnimatedPositioned is a direct child of Stack
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate width of each item based on total available width
          final itemWidth = constraints.maxWidth / items.length;
          
          return Stack(
            alignment: Alignment.center,
            children: [
              // The Sliding Rectangle
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: selectedIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBC02D), // Primary Yellow
                    borderRadius: BorderRadius.all(Radius.circular(0)), // Square edges or slight radius if preferred
                  ),
                ),
              ),
              
              // The Icons and Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = selectedIndex == index;

                  return SizedBox( // Use SizedBox instead of Expanded inside Row for fixed width logic if needed, but Expanded is fine here
                    width: itemWidth, // Explicitly enforce width to match calculation
                    child: GestureDetector(
                      onTap: () => onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 4),
                            child: Icon(
                              item['icon'],
                              color: isSelected ? Colors.white : unselectedColor,
                              size: 24,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: isSelected ? 1.0 : 0.6,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              item['label'],
                              style: TextStyle(
                                color: isSelected ? Colors.black : unselectedColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}