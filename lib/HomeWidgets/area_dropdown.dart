// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// class AreaDropdownFilter extends StatelessWidget {
//   final List<String> areas;
//   final String selectedArea;
//   final ValueChanged<String> onChanged;

//   const AreaDropdownFilter({
//     super.key,
//     required this.areas,
//     required this.selectedArea,
//     required this.onChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 20.w),
//       child: Row(
//         children: [
//           // ALL BUTTON
//           GestureDetector(
//             onTap: () => onChanged("All"),
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
//               decoration: BoxDecoration(
//                 color: selectedArea == "All"
//                     ? const Color(0xFF6C63FF)
//                     : const Color(0xFFEEEDFF),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 "All",
//                 style: TextStyle(
//                   fontSize: 14.sp,
//                   fontWeight: FontWeight.w600,
//                   color: selectedArea == "All"
//                       ? Colors.white
//                       : const Color(0xFF6C63FF),
//                 ),
//               ),
//             ),
//           ),

//           SizedBox(width: 12.w),

//           // DROPDOWN
//           Expanded(
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 14.w),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFF8F9FE),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: DropdownButtonHideUnderline(
//                 child: DropdownButton<String>(
//   value: selectedArea == "All" ? null : selectedArea,
//   hint: Text(
//     "Select Area",
//     style: TextStyle(
//       fontSize: 14.sp,
//       color: Colors.grey[600],
//     ),
//   ),
//   isExpanded: true,

//   // ✅ ADD THIS LINE
//   dropdownColor: const Color(0xFFF8F9FE), // your desired background

//   items: areas
//       .where((e) => e != "All")
//       .map(
//         (area) => DropdownMenuItem(
//           value: area,
//           child: Text(
//             area,
//             style: TextStyle(
//               fontSize: 14.sp,
//               color: Colors.black87,
//             ),
//           ),
//         ),
//       )
//       .toList(),
//   onChanged: (value) {
//     if (value != null) onChanged(value);
//   },
// ),

//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AreaSearchDropdown extends StatelessWidget {
  final List<String> areas; // should include "All" (we'll handle it)
  final String selectedArea;
  final ValueChanged<String> onChanged;

  const AreaSearchDropdown({
    super.key,
    required this.areas,
    required this.selectedArea,
    required this.onChanged,
  });

  void _openAreaPicker(BuildContext context) {
    final allAreas = areas.map((e) => e.toString()).toList();
    final listAreas = allAreas.where((a) => a.trim().isNotEmpty).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AreaPickerSheet(
        allAreas: listAreas,
        selectedArea: selectedArea,
        onPick: (val) {
          Navigator.pop(context);
          onChanged(val);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          // ALL button
          GestureDetector(
            onTap: () => onChanged("All"),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selectedArea == "All"
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFFEEEDFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "All",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: selectedArea == "All"
                      ? Colors.white
                      : const Color(0xFF6C63FF),
                ),
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // "Dropdown" button (opens sheet)
          Expanded(
            child: InkWell(
              onTap: () => _openAreaPicker(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedArea == "All" ? "Select Area" : selectedArea,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: selectedArea == "All"
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaPickerSheet extends StatefulWidget {
  final List<String> allAreas;
  final String selectedArea;
  final ValueChanged<String> onPick;

  const _AreaPickerSheet({
    required this.allAreas,
    required this.selectedArea,
    required this.onPick,
  });

  @override
  State<_AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<_AreaPickerSheet> {
  final TextEditingController _search = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _dedupe(widget.allAreas);
  }

  List<String> _dedupe(List<String> input) {
    final set = <String>{};
    final out = <String>[];
    for (final a in input) {
      final v = a.trim();
      if (v.isEmpty) continue;
      if (set.add(v)) out.add(v);
    }
    // ensure All is present at top
    out.removeWhere((e) => e.toLowerCase() == "all");
    out.insert(0, "All");
    return out;
  }

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    final base = _dedupe(widget.allAreas);

    if (query.isEmpty) {
      setState(() => _filtered = base);
      return;
    }

    setState(() {
      _filtered = base.where((a) {
        if (a == "All") return true; // keep All
        return a.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Container(
        height: media.size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            SizedBox(height: 12.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: _search,
                onChanged: _applyFilter,
                decoration: InputDecoration(
                  hintText: "Search area...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            _applyFilter("");
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),

            SizedBox(height: 10.h),

            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final area = _filtered[index];
                  final isSelected = area == widget.selectedArea;

                  return ListTile(
                    title: Text(
                      area,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF6C63FF))
                        : null,
                    onTap: () => widget.onPick(area),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

