import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// --- Models (จำลองข้อมูล) ---
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

// --- State Management (จำลอง dataSdk) ---
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

  void addItem(AppItem item) {
    _items.add(item);
    notifyListeners(); // แจ้งเตือน Widgets ที่ฟังอยู่
  }

  void deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}

// --- AppConfig (จำลอง elementSdk) ---
class AppConfigNotifier extends ChangeNotifier {
  // ใช้ค่าเริ่มต้นจาก defaultConfig ใน JS
  final String _appTitle = "Senior Helper";
  final String _welcomeMessage = "Hello! How are you today?";
  final Color _backgroundColor = const Color(0xFFF0F9FF);
  final Color _surfaceColor = const Color(0xFFFFFFFF);
  final Color _textColor = const Color(0xFF1F2937);
  final Color _primaryActionColor = const Color(0xFF3B82F6);
  final Color _secondaryActionColor = const Color(0xFF10B981);
  final Color _emergencyColor = const Color(0xFFEF4444);
  final Color _medicationColor = const Color(0xFF8B5CF6);

  String get appTitle => _appTitle;
  String get welcomeMessage => _welcomeMessage;
  Color get backgroundColor => _backgroundColor;
  Color get surfaceColor => _surfaceColor;
  Color get textColor => _textColor;
  Color get primaryActionColor => _primaryActionColor;
  Color get secondaryActionColor => _secondaryActionColor;
  Color get emergencyColor => _emergencyColor;
  Color get medicationColor => _medicationColor;

  // ในแอปจริง, อาจมีฟังก์ชัน setConfig(...) เพื่อเปลี่ยนค่าเหล่านี้
}

// --- Text Styles (จำลองคลาส CSS) ---
class AppStyles {
  static const TextStyle largeText = TextStyle(fontSize: 24, height: 1.4);
  static const TextStyle extraLargeText =
      TextStyle(fontSize: 32, height: 1.3, fontWeight: FontWeight.bold);
  static const TextStyle hugeText =
      TextStyle(fontSize: 40, height: 1.2, fontWeight: FontWeight.bold);

  static const TextStyle buttonText =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white);
}

// --- Main App ---
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
    // ดึงค่า config จาก Provider
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
        // สไตล์ปุ่มหลัก
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 70), // min-height: 70px
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

// --- Reusable Widgets ---
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
        minimumSize: const Size(double.infinity, 80), // .menu-button
        padding: const EdgeInsets.all(20),
        elevation: 5, // shadow-lg
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

// --- Pages (Screens) ---

// 1. Home Page
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // p-6
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // max-w-4xl
              child: Column(
                children: [
                  // Header
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
                  const ClockWidget(), // แสดงวันที่และเวลา
                  const SizedBox(height: 32),

                  // Navigation
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

// Widget สำหรับแสดงเวลา (จำลอง updateDateTime)
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
      setState(() {
        _now = DateTime.now();
      });
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
          // ในแอปจริงควรไปหน้า Add Form
          // Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen(type: ItemType.reminder)));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add form screen not implemented yet')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 3. Guidance Page
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
          // Add Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    /* Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen(type: ItemType.income))); */
                  },
                  child: const Text('+ Add Income'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    /* Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen(type: ItemType.expense))); */
                  },
                  child: const Text('+ Add Expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Summary
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
          // List
          ...dataService.financialItems.map((item) {
            bool isIncome = item.type == ItemType.income;
            return DataCard(
              child: ListTile(
                leading: Text(isIncome ? '💰' : '💸',
                    style: const TextStyle(fontSize: 32)),
                title: Text(item.title, style: AppStyles.largeText),
                subtitle: Text(DateFormat.yMd().format(item.date)),
                trailing: Text(
                  '${isIncome ? '+' : '-'}\$${item.amount.toStringAsFixed(2)}',
                  style: AppStyles.largeText.copyWith(
                    color: isIncome
                        ? config.secondaryActionColor
                        : config.emergencyColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// 5. Appointments Page (คล้ายกับ Reminders)
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Appointments')),
      body: Center(
        child: Text('Appointments Page - Not Implemented'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

// 6. Emergency Page
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  // ฟังก์ชันสำหรับโทรออก (จำลอง onclick="callNumber('911')")
  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // ไม่สามารถโทรออกได้ (เช่น ใน Simulator)
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

// 7. Medications Page (คล้ายกับ Reminders)
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      body: Center(
        child: Text('Medications Page - Not Implemented'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

// หมายเหตุ: หน้า Add Form (add-form) จะซับซ้อน
// ใน Flutter เรามักจะสร้างเป็น Screen แยกต่างหาก (เช่น AddItemScreen)
// ที่รับ 'type' (เช่น ItemType.reminder) เข้ามา
// แล้วใช้ 'switch' statement เพื่อสร้าง FormFields ที่ถูกต้อง

