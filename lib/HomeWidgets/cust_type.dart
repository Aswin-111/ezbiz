// lib/widgets/cust_type_box.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustTypeBox extends StatelessWidget {
  final String custType;

  const CustTypeBox({
    Key? key,
    required this.custType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color? boxColor;
    String? label;

    if (custType == 'W') {
      boxColor = Color(0xFFFF6B9D);
      label = 'W';
    } else if (custType == 'R') {
      boxColor = Color(0xFFFFC947);
      label = 'R';
    } else {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: boxColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15.sp,
        ),
      ),
    );
  }
}
