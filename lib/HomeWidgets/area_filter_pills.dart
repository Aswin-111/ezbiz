// lib/widgets/area_filter_pills.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AreaFilterPills extends StatelessWidget {
  final List<String> areas;
  final String? selectedArea;
  final ValueChanged<String?> onAreaSelected;

  const AreaFilterPills({
    Key? key,
    required this.areas,
    required this.selectedArea,
    required this.onAreaSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      scrollDirection: Axis.horizontal,
      itemCount: areas.length,
      itemBuilder: (context, index) {
        final area = areas[index];
        final isSelected = selectedArea == area;
        return GestureDetector(
          onTap: () => onAreaSelected(area),
          child: Container(
            margin: EdgeInsets.only(right: 12.w),
            padding:
                EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey[300]!,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 18.sp),
                  ),
                Text(
                  area,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontSize: 14.sp,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
