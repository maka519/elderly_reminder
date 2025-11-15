import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// --- Models (โครงสร้างข้อมูล) ---
enum ItemType { reminder, income, expense, appointment, medication }

class AppItem {
  String id;
  ItemType type;
  String title;
  String description;
  double amount;
  DateTime date;
  TimeOfDay time;
  bool completed;

  AppItem({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.amount = 0.0,
    required this.date,
    required this.time,
    this.completed = false,
  });
}

// --- State Management (การจัดการข้อมูลกลาง) ---
class DataService extends ChangeNotifier {
  final List<AppItem> _items = [];
  List<AppItem> get items => _items;

  // ตัวกรองข้อมูลสำหรับแต่ละหน้า
  List<AppItem> get reminders =>
      _items.where((item) => item.type == ItemType.reminder).toList();
  List<AppItem> get financialItems => _items
      .where((item) =>
          item.type == ItemType.income || item.type == ItemType.expense)
      .toList();
  List<AppItem> get appointments =>
      _items.where((item) => item.type == ItemType.appointment).toList();
  List<AppItem> get medications =>
      _items.where((item) => item.type == ItemType.medication).toList();

  // สรุปการเงิน
  double get totalIncome => _items
      .where((item) => item.type == ItemType.income)
      .fold(0.0, (sum, item) => sum + item.amount);
  double get totalExpense => _items
      .where((item) => item.type == ItemType.expense)
      .fold(0.0, (sum, item) => sum + item.amount);

  // --- CRUD Functions ---
  void addItem(AppItem item) {
    _items.add(item);
    notifyListeners(); // แจ้งเตือน Widgets ที่ฟังอยู่
  }

  void deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void updateItem(AppItem updatedItem) {
    // หา index ของ item เก่า
    int index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem; // แทนที่ด้วย item ใหม่
      notifyListeners();
    }
  }
}

// --- AppConfig (การตั้งค่าสีและธีม) ---
class AppConfigNotifier extends ChangeNotifier {
  // ใช้ค่าเริ่มต้นจาก defaultConfig ใน JS
  String _appTitle = "Senior Helper";
  String _welcomeMessage = "Hello! How are you today?";
  Color _backgroundColor = const Color(0xFFF0F9FF);
  Color _surfaceColor = const Color(0xFFFFFFFF);
  Color _textColor = const Color(0xFF1F2937);
  Color _primaryActionColor = const Color(0xFF3B82F6);
  Color _secondaryActionColor = const Color(0xFF10B981);
  Color _emergencyColor = const Color(0xFFEF4444);
  Color _medicationColor = const Color(0xFF8B5CF6);

  String get appTitle => _appTitle;
  String get welcomeMessage => _welcomeMessage;
  Color get backgroundColor => _backgroundColor;
  Color get surfaceColor => _surfaceColor;
  Color get textColor => _textColor;
  Color get primaryActionColor => _primaryActionColor;
  Color get secondaryActionColor => _secondaryActionColor;
  Color get emergencyColor => _emergencyColor;
  Color get medicationColor => _medicationColor;
}

// --- Text Styles (สไตล์ตัวอักษร) ---
class AppStyles {
  static const TextStyle largeText = TextStyle(fontSize: 24, height: 1.4);
  static const TextStyle extraLargeText =
      TextStyle(fontSize: 32, height: 1.3, fontWeight: FontWeight.bold);
  static const TextStyle hugeText =
      TextStyle(fontSize: 40, height: 1.2, fontWeight: FontWeight.bold);

  static const TextStyle buttonText =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white);
}

// --- Main App (จุดเริ่มต้นแอป) ---
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataService()),
        ChangeNotifierProvider(create: (_) => AppConfigNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context);

    return MaterialApp(
      title: 'Senior Helper',
      theme: ThemeData(
        scaffoldBackgroundColor: config.backgroundColor,
        cardColor: config.surfaceColor,
        primaryColor: config.primaryActionColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: config.primaryActionColor,
          secondary: config.secondaryActionColor,
          error: config.emergencyColor,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: config.textColor,
              displayColor: config.textColor,
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 70),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Reusable Widgets (วิดเจ็ตใช้ซ้ำ) ---

// ปุ่มเมนู
class MenuButton extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final VoidCallback onPressed;

  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 80),
        padding: const EdgeInsets.all(20),
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: AppStyles.buttonText),
          ),
        ],
      ),
    );
  }
}

// การ์ดแสดงข้อมูล
class DataCard extends StatelessWidget {
  final Widget child;

  const DataCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);
    return Card(
      elevation: 0,
      color: config.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(width: 2, color: config.primaryActionColor),
      ),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

// นาฬิกาและวันที่
class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);
    final String dateStr = DateFormat('EEEE, MMMM d, y').format(_now);
    final String timeStr = DateFormat('h:mm a').format(_now);

    return Column(
      children: [
        Text(dateStr,
            style: AppStyles.largeText.copyWith(color: config.textColor)),
        Text(timeStr,
            style: AppStyles.largeText.copyWith(color: config.textColor)),
      ],
    );
  }
}

// --- Pages (หน้าจอต่างๆ) ---

// 1. Home Page
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Text(
                    config.appTitle,
                    style: AppStyles.hugeText.copyWith(color: config.textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    config.welcomeMessage,
                    style:
                        AppStyles.largeText.copyWith(color: config.textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const ClockWidget(),
                  const SizedBox(height: 32),
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      MenuButton(
                        label: 'Daily Reminders',
                        icon: '⏰',
                        color: config.primaryActionColor,
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RemindersScreen())),
                      ),
                      const SizedBox(height: 16),
                      MenuButton(
                        label: 'Daily Guidance',
                        icon: '🌤️',
                        color: config.secondaryActionColor,
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GuidanceScreen())),
                      ),
                      const SizedBox(height: 16),
                      MenuButton(
                        label: 'Financial Tracker',
                        icon: '💰',
                        color: config.primaryActionColor,
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FinancialScreen())),
                      ),
                      const SizedBox(height: 16),
                      MenuButton(
                        label: 'Doctor Appointments',
                        icon: '👩‍⚕️',
                        color: config.secondaryActionColor,
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AppointmentsScreen())),
                      ),
                      const SizedBox(height: 16),
                      MenuButton(
                        label: 'Emergency Contacts',
                        icon: '🚨',
                        color: config.emergencyColor,
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EmergencyScreen())),
                      ),
                      const SizedBox(height: 16),
                      MenuButton(
                        label: 'Medications',
                        icon: '💊',
                        color: config.medicationColor,
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MedicationsScreen())),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 2. Reminders Page
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Reminders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final reminders = dataService.reminders;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reminders.isEmpty ? 1 : reminders.length,
            itemBuilder: (context, index) {
              if (reminders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No reminders yet', style: AppStyles.largeText),
                  ),
                );
              }
              final item = reminders[index];
              return DataCard(
                child: ListTile(
                  title: Text(item.title, style: AppStyles.largeText),
                  subtitle: Text(
                      '${item.description}\n${DateFormat.yMd().format(item.date)} - ${item.time.format(context)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddItemScreen(
                          type: ItemType.reminder,
                          itemToEdit: item,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[700]),
                    onPressed: () => dataService.deleteItem(item.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddItemScreen(type: ItemType.reminder),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// 3. Guidance Page
class GuidanceScreen extends StatelessWidget {
  const GuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Guidance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DataCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🌡️ Today's Weather", style: AppStyles.largeText),
                const SizedBox(height: 16),
                Text("Nice weather, 82°F", style: AppStyles.largeText),
                Text("Recommended: Light long-sleeve shirt",
                    style: AppStyles.largeText),
              ],
            ),
          ),
          DataCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("💡 Daily Tips", style: AppStyles.largeText),
                const SizedBox(height: 16),
                Text("• Drink plenty of water", style: AppStyles.largeText),
                Text("• Take a light walk", style: AppStyles.largeText),
                Text("• Eat a balanced diet", style: AppStyles.largeText),
                Text("• Get adequate rest", style: AppStyles.largeText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Financial Page
class FinancialScreen extends StatelessWidget {
  const FinancialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final config = Provider.of<AppConfigNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Tracker'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddItemScreen(type: ItemType.income),
                      ),
                    );
                  },
                  child: const Text('+ Add Income'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddItemScreen(type: ItemType.expense),
                      ),
                    );
                  },
                  child: const Text('+ Add Expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DataCard(
                  child: Column(
                    children: [
                      const Text('Total Income', style: AppStyles.largeText),
                      Text(
                        '\$${dataService.totalIncome.toStringAsFixed(2)}',
                        style: AppStyles.extraLargeText.copyWith(
                            color: config.secondaryActionColor),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: DataCard(
                  child: Column(
                    children: [
                      const Text('Total Expenses', style: AppStyles.largeText),
                      Text(
                        '\$${dataService.totalExpense.toStringAsFixed(2)}',
                        style: AppStyles.extraLargeText
                            .copyWith(color: config.emergencyColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...dataService.financialItems.map((item) {
            bool isIncome = item.type == ItemType.income;
            return DataCard(
              child: ListTile(
                leading: Text(isIncome ? '💰' : '💸',
                    style: const TextStyle(fontSize: 32)),
                title: Text(item.title, style: AppStyles.largeText),
                subtitle: Text(DateFormat.yMd().format(item.date)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddItemScreen(
                        type: item.type,
                        itemToEdit: item,
                      ),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}\$${item.amount.toStringAsFixed(2)}',
                      style: AppStyles.largeText.copyWith(
                        color: isIncome
                            ? config.secondaryActionColor
                            : config.emergencyColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red[700]),
                      onPressed: () => dataService.deleteItem(item.id),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// 5. Appointments Page
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Appointments')),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final appointments = dataService.appointments;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.isEmpty ? 1 : appointments.length,
            itemBuilder: (context, index) {
              if (appointments.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No appointments yet', style: AppStyles.largeText),
                  ),
                );
              }
              final item = appointments[index];
              return DataCard(
                child: ListTile(
                  title: Text(item.title, style: AppStyles.largeText),
                  subtitle: Text(
                      '${item.description}\n${DateFormat.yMd().format(item.date)} - ${item.time.format(context)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddItemScreen(
                          type: ItemType.appointment,
                          itemToEdit: item,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[700]),
                    onPressed: () => dataService.deleteItem(item.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddItemScreen(type: ItemType.appointment),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// 6. Emergency Page
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DataCard(
            child: ListTile(
              title: const Text('Police', style: AppStyles.largeText),
              subtitle:
                  const Text('911', style: AppStyles.extraLargeText),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.emergencyColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 60), // ขนาดปุ่ม
                ),
                onPressed: () => _makeCall('911'),
                child: const Text('Call'),
              ),
            ),
          ),
          DataCard(
            child: ListTile(
              title: const Text('Fire Department', style: AppStyles.largeText),
              subtitle:
                  const Text('911', style: AppStyles.extraLargeText),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.emergencyColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 60),
                ),
                onPressed: () => _makeCall('911'),
                child: const Text('Call'),
              ),
            ),
          ),
          DataCard(
            child: ListTile(
              title: const Text('Ambulance', style: AppStyles.largeText),
              subtitle:
                  const Text('911', style: AppStyles.extraLargeText),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.emergencyColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 60),
                ),
                onPressed: () => _makeCall('911'),
                child: const Text('Call'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 7. Medications Page
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final medications = dataService.medications;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: medications.isEmpty ? 1 : medications.length,
            itemBuilder: (context, index) {
              if (medications.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No medications yet', style: AppStyles.largeText),
                  ),
                );
              }
              final item = medications[index];
              return DataCard(
                child: ListTile(
                  title: Text(item.title, style: AppStyles.largeText),
                  subtitle: Text(
                      '${item.description}\nTime: ${item.time.format(context)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddItemScreen(
                          type: ItemType.medication,
                          itemToEdit: item,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[700]),
                    onPressed: () => dataService.deleteItem(item.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddItemScreen(type: ItemType.medication),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


// --- Add/Edit Item Page (หน้าฟอร์ม) ---
class AddItemScreen extends StatefulWidget {
  final ItemType type;
  final AppItem? itemToEdit; // รับ item ที่จะแก้ไข

  const AddItemScreen({
    super.key,
    required this.type,
    this.itemToEdit,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool get _isEditing => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    
    if (_isEditing) {
      final item = widget.itemToEdit!;
      _titleController = TextEditingController(text: item.title);
      _descriptionController = TextEditingController(text: item.description);
      _amountController = TextEditingController(text: item.amount > 0 ? item.amount.toStringAsFixed(2) : '');
      _selectedDate = item.date;
      _selectedTime = item.time;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _amountController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      bool dateRequired = widget.type == ItemType.reminder ||
          widget.type == ItemType.income ||
          widget.type == ItemType.expense ||
          widget.type == ItemType.appointment;
          
      bool timeRequired = widget.type == ItemType.reminder ||
          widget.type == ItemType.appointment ||
          widget.type == ItemType.medication;

      if (dateRequired && _selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date')),
        );
        return;
      }
      
      if (timeRequired && _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time')),
        );
        return;
      }

      if (_isEditing) {
        // --- อัปเดต Item ---
        final updatedItem = AppItem(
          id: widget.itemToEdit!.id,
          type: widget.type,
          title: _titleController.text,
          description: _descriptionController.text,
          amount: double.tryParse(_amountController.text) ?? 0.0,
          date: _selectedDate ?? DateTime.now(),
          time: _selectedTime ?? TimeOfDay.now(),
          completed: widget.itemToEdit!.completed,
        );
        
        Provider.of<DataService>(context, listen: false).updateItem(updatedItem);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data updated successfully')),
        );

      } else {
        // --- สร้าง Item ใหม่ ---
        final newItem = AppItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: widget.type,
          title: _titleController.text,
          description: _descriptionController.text,
          amount: double.tryParse(_amountController.text) ?? 0.0,
          date: _selectedDate ?? DateTime.now(),
          time: _selectedTime ?? TimeOfDay.now(),
        );

        Provider.of<DataService>(context, listen: false).addItem(newItem);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data saved successfully')),
        );
      }
      
      Navigator.pop(context); // กลับไปหน้า List
    }
  }

  String _getFormTitle() {
    if (_isEditing) {
      switch (widget.type) {
        case ItemType.reminder:
          return 'Edit Reminder';
        case ItemType.income:
          return 'Edit Income';
        case ItemType.expense:
          return 'Edit Expense';
        case ItemType.appointment:
          return 'Edit Appointment';
        case ItemType.medication:
          return 'Edit Medication';
      }
    }
    switch (widget.type) {
      case ItemType.reminder:
        return 'Add Reminder';
      case ItemType.income:
        return 'Add Income';
      case ItemType.expense:
        return 'Add Expense';
      case ItemType.appointment:
        return 'Add Appointment';
      case ItemType.medication:
        return 'Add Medication';
    }
  }

  List<Widget> _buildFormFields() {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);

    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(width: 3, color: config.primaryActionColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(width: 3, color: config.primaryActionColor),
      ),
      labelStyle: const TextStyle(fontSize: 20),
      contentPadding: const EdgeInsets.all(15),
    );

    List<Widget> fields = [];

    // --- Title ---
    if (widget.type == ItemType.reminder) {
      fields.add(
        TextFormField(
          controller: _titleController,
          decoration: inputDecoration.copyWith(labelText: 'What to remember'),
          style: const TextStyle(fontSize: 20),
          validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
        ),
      );
    } else if (widget.type == ItemType.income || widget.type == ItemType.expense) {
       fields.add(
        TextFormField(
          controller: _titleController,
          decoration: inputDecoration.copyWith(labelText: 'Description'),
          style: const TextStyle(fontSize: 20),
          validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
        ),
      );
    } else if (widget.type == ItemType.appointment) {
       fields.add(
        TextFormField(
          controller: _titleController,
          decoration: inputDecoration.copyWith(labelText: 'Hospital/Clinic'),
          style: const TextStyle(fontSize: 20),
          validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
        ),
      );
    } else if (widget.type == ItemType.medication) {
       fields.add(
        TextFormField(
          controller: _titleController,
          decoration: inputDecoration.copyWith(labelText: 'Medication Name'),
          style: const TextStyle(fontSize: 20),
          validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
        ),
      );
    }
    
    fields.add(const SizedBox(height: 24));

    // --- Description ---
    if (widget.type == ItemType.reminder) {
      fields.add(
        TextFormField(
          controller: _descriptionController,
          decoration: inputDecoration.copyWith(labelText: 'Details'),
          maxLines: 3,
          style: const TextStyle(fontSize: 20),
        ),
      );
    } else if (widget.type == ItemType.income || widget.type == ItemType.expense) {
      fields.add(
        TextFormField(
          controller: _descriptionController,
          decoration: inputDecoration.copyWith(labelText: 'Notes'),
          maxLines: 3,
          style: const TextStyle(fontSize: 20),
        ),
      );
    } else if (widget.type == ItemType.appointment) {
      fields.add(
        TextFormField(
          controller: _descriptionController,
          decoration: inputDecoration.copyWith(labelText: 'Doctor/Department'),
          style: const TextStyle(fontSize: 20),
        ),
      );
    } else if (widget.type == ItemType.medication) {
      fields.add(
        TextFormField(
          controller: _descriptionController,
          decoration: inputDecoration.copyWith(labelText: 'Instructions (e.g., Take after meals)'),
          maxLines: 3,
          style: const TextStyle(fontSize: 20),
        ),
      );
    }

    // --- Amount ---
    if (widget.type == ItemType.income || widget.type == ItemType.expense) {
      fields.add(const SizedBox(height: 24));
      fields.add(
        TextFormField(
          controller: _amountController,
          decoration: inputDecoration.copyWith(labelText: 'Amount (\$)'),
          style: const TextStyle(fontSize: 20),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Cannot be empty';
            if (double.tryParse(value) == null) return 'Invalid number';
            return null;
          },
        ),
      );
    }

    // --- Date Picker ---
    if (widget.type == ItemType.reminder ||
        widget.type == ItemType.income ||
        widget.type == ItemType.expense ||
        widget.type == ItemType.appointment) {
      fields.add(const SizedBox(height: 16));
      fields.add(
        ListTile(
          shape: RoundedRectangleBorder(
              side: BorderSide(color: config.primaryActionColor, width: 2),
              borderRadius: BorderRadius.circular(8)),
          title: Text(
            _selectedDate == null
                ? 'Select Date'
                : DateFormat.yMMMd().format(_selectedDate!),
            style: AppStyles.largeText,
          ),
          trailing: const Icon(Icons.calendar_month),
          onTap: _pickDate,
        ),
      );
    }

    // --- Time Picker ---
    if (widget.type == ItemType.reminder ||
        widget.type == ItemType.appointment ||
        widget.type == ItemType.medication) {
      fields.add(const SizedBox(height: 16));
      fields.add(
        ListTile(
          shape: RoundedRectangleBorder(
              side: BorderSide(color: config.primaryActionColor, width: 2),
              borderRadius: BorderRadius.circular(8)),
          title: Text(
            _selectedTime == null
                ? 'Select Time'
                : _selectedTime!.format(context),
            style: AppStyles.largeText,
          ),
          trailing: const Icon(Icons.access_time),
          onTap: _pickTime,
        ),
      );
    }

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getFormTitle(), style: AppStyles.extraLargeText.copyWith(fontSize: 28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildFormFields(),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.primaryActionColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submitForm,
                  child: Text(_isEditing ? 'Update' : 'Save'), // เปลี่ยนข้อความปุ่ม
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                   style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    side: BorderSide(width: 2, color: config.textColor),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(fontSize: 20, color: config.textColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
