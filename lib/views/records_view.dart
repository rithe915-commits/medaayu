import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/health_record.dart';
import '../models/profile.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../theme/design_system.dart';

class CategoryItem {
  final String title;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.title,
    required this.icon,
    required this.color,
  });
}

class RecordsView extends StatefulWidget {
  final Profile profile;
  const RecordsView({super.key, required this.profile});

  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  String _searchQuery = '';
  CategoryItem? _selectedCategory;

  final List<CategoryItem> _categories = const [
    CategoryItem(title: 'Prescriptions', icon: Icons.description_rounded, color: Color(0xFF3A86F0)),
    CategoryItem(title: 'Lab Reports', icon: Icons.science_rounded, color: Color(0xFF00B894)),
    CategoryItem(title: 'X-Rays & Scans', icon: Icons.center_focus_strong_rounded, color: Color(0xFF6C5CE7)),
    CategoryItem(title: 'Immunizations', icon: Icons.vaccines_rounded, color: Color(0xFFFF7675)),
    CategoryItem(title: 'Vision', icon: Icons.visibility_rounded, color: Color(0xFFE17055)),
    CategoryItem(title: 'Allergies', icon: Icons.warning_amber_rounded, color: Color(0xFFD63031)),
    CategoryItem(title: 'Discharge Summaries', icon: Icons.local_hospital_rounded, color: Color(0xFF0984E3)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DbService>(context, listen: false).loadRecords(widget.profile.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final records = db.records;

    if (_selectedCategory != null) {
      return _CategoryDetailView(
        category: _selectedCategory!,
        profile: widget.profile,
        onBack: () => setState(() => _selectedCategory = null),
      );
    }

    // Filter categories by main search
    final filteredCategories = _categories.where((cat) {
      return cat.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Health Records",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            Text(
              "Profile: ${widget.profile.fullName}",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3A86F0), size: 28),
            onPressed: () => _openUploadSheet(context, widget.profile, null),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search records or categories...",
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Record Categories",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, index) {
                final cat = filteredCategories[index];
                final count = records.where((r) => r.category == cat.title).length;

                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 26),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$count records",
                              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Documents",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                TextButton(
                  onPressed: () {
                    if (_categories.isNotEmpty) {
                      setState(() => _selectedCategory = _categories.first);
                    }
                  },
                  child: const Text("View All"),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (records.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 50, color: Colors.black.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    const Text(
                      "No health records uploaded yet",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tap the + button to upload prescriptions, lab reports, or scans.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.take(4).length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final rec = records[idx];
                  return _RecordListTile(record: rec, profile: widget.profile);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDetailView extends StatefulWidget {
  final CategoryItem category;
  final Profile profile;
  final VoidCallback onBack;

  const _CategoryDetailView({
    required this.category,
    required this.profile,
    required this.onBack,
  });

  @override
  State<_CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<_CategoryDetailView> {
  String _searchQuery = '';
  bool _sortNewest = true;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    List<HealthRecord> catRecords = db.records.where((r) => r.category == widget.category.title).toList();

    if (_searchQuery.isNotEmpty) {
      catRecords = catRecords.where((r) {
        return r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (r.doctorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (r.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    catRecords.sort((a, b) => _sortNewest ? b.recordDate.compareTo(a.recordDate) : a.recordDate.compareTo(b.recordDate));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
          onPressed: widget.onBack,
        ),
        title: Text(
          widget.category.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        actions: [
          IconButton(
            icon: Icon(_sortNewest ? Icons.sort_rounded : Icons.swap_vert_rounded, color: const Color(0xFF3A86F0)),
            tooltip: _sortNewest ? "Sorted by Newest" : "Sorted by Oldest",
            onPressed: () => setState(() => _sortNewest = !_sortNewest),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUploadSheet(context, widget.profile, widget.category.title),
        backgroundColor: widget.category.color,
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        label: const Text("Upload Document", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search in ${widget.category.title}...",
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
                filled: true,
                fillColor: const Color(0xFFF4F6FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: catRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.category.icon, size: 64, color: widget.category.color.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          "No ${widget.category.title} Uploaded",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Tap 'Upload Document' to add your record.",
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: catRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final rec = catRecords[idx];
                      return _RecordListTile(record: rec, profile: widget.profile);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordListTile extends StatelessWidget {
  final HealthRecord record;
  final Profile profile;

  const _RecordListTile({required this.record, required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context, listen: false);

    return InkWell(
      onTap: () => _showRecordDetails(context, record, profile),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A86F0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                record.fileType == 'pdf'
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                color: const Color(0xFF3A86F0),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (record.doctorName != null && record.doctorName!.isNotEmpty) ...[
                        Text(
                          "Dr. ${record.doctorName} • ",
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                      Text(
                        "${record.recordDate.day}/${record.recordDate.month}/${record.recordDate.year}",
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'view') {
                  _showRecordDetails(context, record, profile);
                } else if (action == 'share') {
                  _shareRecord(context, record);
                } else if (action == 'delete') {
                  await db.deleteRecord(record.id, profile.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Record deleted")),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text("View Details")),
                const PopupMenuItem(value: 'share', child: Text("Share Record")),
                const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _openUploadSheet(BuildContext context, Profile profile, String? defaultCategory) {
  final titleController = TextEditingController();
  final doctorController = TextEditingController();
  final notesController = TextEditingController();
  String selectedCategory = defaultCategory ?? 'Prescriptions';
  DateTime selectedDate = DateTime.now();
  String? pickedFilePath;

  final categories = [
    'Prescriptions',
    'Lab Reports',
    'X-Rays & Scans',
    'Immunizations',
    'Vision',
    'Allergies',
    'Discharge Summaries',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Upload Health Record",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Category",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Document Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: "Document Title *",
                      hintText: "e.g., Blood Test Report, Dental Prescription",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Doctor / Clinic Name
                  TextField(
                    controller: doctorController,
                    decoration: InputDecoration(
                      labelText: "Doctor / Clinic Name",
                      hintText: "e.g., Dr. Sharma / City Hospital",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date Picker Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setSheetState(() => selectedDate = d);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Text("Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Notes / Remarks",
                      hintText: "Add any extra details or instructions...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pick File / Camera
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setSheetState(() => pickedFilePath = image.path);
                            }
                          },
                          icon: const Icon(Icons.image_rounded),
                          label: Text(pickedFilePath != null ? "Image Picked ✔" : "Choose File"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.camera);
                            if (image != null) {
                              setSheetState(() => pickedFilePath = image.path);
                            }
                          },
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text("Take Photo"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit Action
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text("Please enter a document title")),
                        );
                        return;
                      }

                      final record = HealthRecord(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        profileId: profile.id,
                        category: selectedCategory,
                        title: titleController.text.trim(),
                        doctorName: doctorController.text.trim().isEmpty ? null : doctorController.text.trim(),
                        recordDate: selectedDate,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        fileUrl: pickedFilePath,
                        fileType: 'image',
                        createdAt: DateTime.now(),
                      );

                      final db = Provider.of<DbService>(context, listen: false);
                      await db.addRecord(record);

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Record saved successfully! 🎉")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A86F0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Save Health Record", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showRecordDetails(BuildContext context, HealthRecord record, Profile profile) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(record.category, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3A86F0))),
                  backgroundColor: const Color(0xFF3A86F0).withOpacity(0.1),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            if (record.doctorName != null && record.doctorName!.isNotEmpty)
              Text("Doctor/Clinic: Dr. ${record.doctorName}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
            Text(
              "Date: ${record.recordDate.day}/${record.recordDate.month}/${record.recordDate.year}",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(record.notes!, style: const TextStyle(color: Colors.black87)),
              ),
              const SizedBox(height: 16),
            ],

            if (record.fileUrl != null && File(record.fileUrl!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(record.fileUrl!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareRecord(context, record);
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text("Share"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final db = Provider.of<DbService>(context, listen: false);
                      await db.deleteRecord(record.id, profile.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Record deleted")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text("Delete"),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _shareRecord(BuildContext context, HealthRecord record) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Share Health Record"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Secure summary copy:"),
            const SizedBox(height: 10),
            SelectableText(
              "📄 *MedAayu Record*\nTitle: ${record.title}\nCategory: ${record.category}\nDoctor: ${record.doctorName ?? 'N/A'}\nDate: ${record.recordDate.day}/${record.recordDate.month}/${record.recordDate.year}\nNotes: ${record.notes ?? 'None'}",
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Record details copied to clipboard!")),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text("Copy Text"),
          ),
        ],
      );
    },
  );
}
