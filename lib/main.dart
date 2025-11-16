import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert'; // สำหรับ JSON
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- (เพิ่มใหม่) Enums สำหรับฟีเจอร์ยา ---
enum FrequencyType { specificTimes, everyXHours }
enum MealRelation { any, beforeMeal, afterMeal, withMeal }


// --- (เพิ่มใหม่) คลาสสำหรับเก็บรายละเอียดยา ---
class MedicationDetails {
  String dosage; // "2 เม็ด", "10ml"
  MealRelation mealRelation;
  FrequencyType frequencyType;
  List<TimeOfDay> specificTimes; // [Time(8,0), Time(18,0)]
  int? intervalHours; // 8
  DateTime? endDate;

  MedicationDetails({
    required this.dosage,
    this.mealRelation = MealRelation.any,
    this.frequencyType = FrequencyType.specificTimes,
    this.specificTimes = const [],
    this.intervalHours,
    this.endDate,
  });

  // --- ฟังก์ชันแปลงเป็น JSON (สำหรับบันทึก) ---
  Map<String, dynamic> toJson() => {
        'dosage': dosage,
        'mealRelation': mealRelation.toString(),
        'frequencyType': frequencyType.toString(),
        'specificTimes': specificTimes.map((t) => '${t.hour}:${t.minute}').toList(),
        'intervalHours': intervalHours,
        'endDate': endDate?.toIso8601String(),
      };

  // --- ฟังก์ชันแปลงจาก JSON (สำหรับโหลด) ---
  factory MedicationDetails.fromJson(Map<String, dynamic> json) {
    var timesList = (json['specificTimes'] as List)
        .map((timeString) {
          final parts = (timeString as String).split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        })
        .toList();

    return MedicationDetails(
      dosage: json['dosage'],
      mealRelation: MealRelation.values.firstWhere((e) => e.toString() == json['mealRelation']),
      frequencyType: FrequencyType.values.firstWhere((e) => e.toString() == json['frequencyType']),
      specificTimes: timesList,
      intervalHours: json['intervalHours'],
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }
}


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
  MedicationDetails? medicationDetails;

  AppItem({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.amount = 0.0,
    required this.date,
    required this.time,
    this.completed = false,
    this.medicationDetails,
  });

  // --- ฟังก์ชันแปลงเป็น JSON (สำหรับบันทึก) ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'title': title,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'time': '${time.hour}:${time.minute}',
        'completed': completed,
        'medicationDetails': medicationDetails?.toJson(),
      };

  // --- ฟังก์ชันแปลงจาก JSON (สำหรับโหลด) ---
  factory AppItem.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    final time = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
    final type = ItemType.values.firstWhere((e) => e.toString() == json['type']);

    return AppItem(
      id: json['id'],
      type: type,
      title: json['title'],
      description: json['description'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      time: time,
      completed: json['completed'],
      medicationDetails: json['medicationDetails'] != null
          ? MedicationDetails.fromJson(json['medicationDetails'])
          : null,
    );
  }
}

// --- State Management (การจัดการข้อมูลกลาง) ---
class DataService extends ChangeNotifier {
  List<AppItem> _items = [];
  List<AppItem> get items => _items;
  
  static const _storageKey = "seniorHelperData";

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
  double get totalIncome => _items
      .where((item) => item.type == ItemType.income)
      .fold(0.0, (sum, item) => sum + item.amount);
  double get totalExpense => _items
      .where((item) => item.type == ItemType.expense)
      .fold(0.0, (sum, item) => sum + item.amount);

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? dataStrings = prefs.getStringList(_storageKey);

    if (dataStrings != null) {
      _items = dataStrings.map((itemString) {
        return AppItem.fromJson(jsonDecode(itemString));
      }).toList();
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> dataStrings = _items.map((item) {
      return jsonEncode(item.toJson());
    }).toList();
    
    await prefs.setStringList(_storageKey, dataStrings);
  }

  Future<void> addItem(AppItem item) async {
    _items.add(item);
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateItem(AppItem updatedItem) async {
    int index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      await _saveData();
      notifyListeners();
    }
  }
}

// --- AppConfig (เหมือนเดิม) ---
class AppConfigNotifier extends ChangeNotifier {
  final String _appTitle = "Eldereminder";
  final String _welcomeMessage = "こんにちは";
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
}

// --- Text Styles (เหมือนเดิม) ---
class AppStyles {
  static const TextStyle largeText = TextStyle(fontSize: 24, height: 1.4);
  static const TextStyle extraLargeText =
      TextStyle(fontSize: 32, height: 1.3, fontWeight: FontWeight.bold);
  static const TextStyle hugeText =
      TextStyle(fontSize: 40, height: 1.2, fontWeight: FontWeight.bold);

  static const TextStyle buttonText =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white);
}

// --- Main App (เหมือนเดิม) ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  final dataService = DataService();
  await dataService.loadData(); 
  final configNotifier = AppConfigNotifier();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dataService),
        ChangeNotifierProvider.value(value: configNotifier),
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
      title: 'Eldereminder',
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

// --- Reusable Widgets (เหมือนเดิม) ---
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
      // --- (อัปเดต) ⭐️ เปลี่ยน Padding กลับเป็น all(20) ---
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
} 

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

// 1. Home Page (เหมือนเดิม)
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

// ---
// --- 2. ⭐️ Reminders Page (UI แบบแบน) ⭐️
// ---
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
                // --- (อัปเดต) ⭐️ เปลี่ยนกลับไปใช้ Row/Column ---
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนของข้อความ (จะขยายเต็มที่)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: AppStyles.largeText),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              style: AppStyles.largeText.copyWith(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700]),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat.yMd().format(item.date)} - ${item.time.format(context)}',
                            style: AppStyles.largeText.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                    // ปุ่มลบ
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red[700]),
                      onPressed: () => dataService.deleteItem(item.id),
                    ),
                  ],
                ),
                // --- จบส่วนอัปเดต ---
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

// 3. Guidance Page (เหมือนเดิม)
class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({super.key});
  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}
class _GuidanceScreenState extends State<GuidanceScreen> {
  final String _apiKey = "d460fbcb93c90da221b310c85b14cda5"; // ❗️❗️❗️ ใส่ API KEY ❗️❗️❗️
  bool _isLoading = true;
  String _cityName = "Loading location...";
  String? _weatherInfo;
  String? _weatherRecommendation;
  String? _dailyTip;
  String? _errorMessage;

  final List<String> _allTips = [
    "• Drink plenty of water - at least 6-8 glasses per day",
    "• Take a light walk for 15-20 minutes",
    "• Eat a balanced diet with all food groups",
    "• Get adequate rest and sleep",
    "• Stretch your body gently after waking up",
    "• Call a family member or friend to chat",
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    _getRandomTip();
    try {
      Position position = await _determinePosition();
      await _getWeatherFromGps(position);
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = e.toString(); }); }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { throw Exception('Location services are disabled. Please enable them in your settings.'); }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { throw Exception('Location permissions are denied. We cannot get your weather.'); }
    }
    if (permission == LocationPermission.deniedForever) { throw Exception('Location permissions are permanently denied. Please enable them in your phone\'s settings.'); } 
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getWeatherFromGps(Position position) async {
    if (_apiKey == "---") { throw Exception('Please set your OpenWeatherMap API Key in the `_GuidanceScreenState` class.'); }
    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        double temp = data['main']['temp'];
        String description = data['weather'][0]['main'];
        String iconCode = data['weather'][0]['icon'];
        String weatherIcon = _getWeatherIcon(iconCode);
        if (mounted) {
          setState(() {
            _cityName = data['name'];
            _weatherInfo = "$weatherIcon $description, ${temp.toStringAsFixed(1)}°C";
            if (temp > 30) { _weatherRecommendation = "Recommended: Stay hydrated and wear light clothes."; } 
            else if (temp < 15) { _weatherRecommendation = "Recommended: Wear a warm jacket."; } 
            else { _weatherRecommendation = "Recommended: A light long-sleeve shirt is perfect."; }
          });
        }
      } else { throw Exception("Could not load weather data. (API Error: ${response.body})"); }
    } catch (e) { throw Exception("Failed to connect to weather service. Check internet connection."); }
  }

  String _getWeatherIcon(String iconCode) {
    switch (iconCode) {
      case '01d': return '☀️'; case '01n': return '🌙'; case '02d': return '🌤️'; case '02n': return '☁️';
      case '03d': case '03n': return '☁️'; case '04d': case '04n': return '☁️'; case '09d': case '09n': return '🌧️';
      case '10d': case '10n': return '🌦️'; case '11d': case '11n': return '⛈️'; case '13d': case '13n': return '❄️';
      case '50d': case '50n': return '🌫️'; default: return '🌡️';
    }
  }

  void _getRandomTip() {
    final random = Random();
    if(mounted) { setState(() { _dailyTip = _allTips[random.nextInt(_allTips.length)]; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Guidance'), backgroundColor: Colors.transparent, elevation: 0,
        actions: [ IconButton( icon: const Icon(Icons.refresh), onPressed: _fetchData, ) ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: DataCard(
                      child: Text( 'Error: $_errorMessage', style: AppStyles.largeText.copyWith(color: Colors.red[700]), textAlign: TextAlign.center, ),
                    ),
                  ),
                DataCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🌡️ Today's Weather (in $_cityName)", style: AppStyles.largeText),
                      const SizedBox(height: 16),
                      Text(_weatherInfo ?? "Could not load weather.", style: AppStyles.largeText),
                      Text(_weatherRecommendation ?? "", style: AppStyles.largeText),
                    ],
                  ),
                ),
                DataCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("💡 Daily Tip", style: AppStyles.largeText),
                      const SizedBox(height: 16),
                      Text(_dailyTip ?? "...", style: AppStyles.largeText),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---
// --- 4. ⭐️ Financial Page (UI แบบแบน) ⭐️
// ---
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
                  onPressed: () { Navigator.push( context, MaterialPageRoute( builder: (context) => const AddItemScreen(type: ItemType.income), ), ); },
                  child: const Text('+ Add Income'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.push( context, MaterialPageRoute( builder: (context) => const AddItemScreen(type: ItemType.expense), ), ); },
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
                      Text( '\$${dataService.totalIncome.toStringAsFixed(2)}', style: AppStyles.extraLargeText.copyWith( color: config.secondaryActionColor), ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: DataCard(
                  child: Column(
                    children: [
                      const Text('Total Expenses', style: AppStyles.largeText),
                      Text( '\$${dataService.totalExpense.toStringAsFixed(2)}', style: AppStyles.extraLargeText .copyWith(color: config.emergencyColor), ),
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
              // --- (อัปเดต) ⭐️ เปลี่ยนกลับไปใช้ Row/Column ---
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(isIncome ? '💰' : '💸', style: const TextStyle(fontSize: 32)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AppStyles.largeText),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: AppStyles.largeText.copyWith(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          DateFormat.yMd().format(item.date),
                          style: AppStyles.largeText.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ),
                  // ส่วน Trailing (ปุ่มลบและจำนวนเงิน)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[700]),
                        onPressed: () => dataService.deleteItem(item.id),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${isIncome ? '+' : '-'}\$${item.amount.toStringAsFixed(2)}',
                        style: AppStyles.largeText.copyWith(
                          fontSize: 20,
                          color: isIncome ? config.secondaryActionColor : config.emergencyColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // --- จบส่วนอัปเดต ---
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ---
// --- 5. ⭐️ Appointments Page (UI แบบแบน) ⭐️
// ---
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
                // --- (อัปเดต) ⭐️ เปลี่ยนกลับไปใช้ Row/Column ---
                 child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: AppStyles.largeText), // Hospital
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.description, // Doctor/Dept
                              style: AppStyles.largeText.copyWith(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700]),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat.yMd().format(item.date)} - ${item.time.format(context)}',
                            style: AppStyles.largeText.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red[700]),
                      onPressed: () => dataService.deleteItem(item.id),
                    ),
                  ],
                ),
                // --- จบส่วนอัปเดต ---
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

// 6. Emergency Page (เหมือนเดิม)
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
                  const Text('110', style: AppStyles.extraLargeText),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.emergencyColor, foregroundColor: Colors.white, minimumSize: const Size(100, 60),
                ),
                onPressed: () => _makeCall('110'),
                child: const Text('Call'),
              ),
            ),
          ),
          DataCard(
            child: ListTile(
              title: const Text('Fire Department', style: AppStyles.largeText),
              subtitle:
                  const Text('119', style: AppStyles.extraLargeText),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.emergencyColor, foregroundColor: Colors.white, minimumSize: const Size(100, 60),
                ),
                onPressed: () => _makeCall('119'),
                child: const Text('Call'),
              ),
            ),
          ),
          DataCard(
            child: ListTile(
              title: const Text('Ambulance', style: AppStyles.largeText),
              subtitle:
                  const Text('119', style: AppStyles.extraLargeText),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.emergencyColor, foregroundColor: Colors.white, minimumSize: const Size(100, 60),
                ),
                onPressed: () => _makeCall('119'),
                child: const Text('Call'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---
// --- 7. ⭐️ Medications Page (UI แบบแบน) ⭐️
// ---
// ---
// --- 7. (อัปเดต) ⭐️ Medications Page (แก้ไข UI ให้แสดง Duration) ⭐️
// ---
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  // (Helper functions - เหมือนเดิม)
  String _formatMealRelation(MealRelation relation) {
    switch (relation) {
      case MealRelation.beforeMeal: return 'ก่อนอาหาร';
      case MealRelation.afterMeal: return 'หลังอาหาร';
      case MealRelation.withMeal: return 'พร้อมอาหาร';
      case MealRelation.any: return 'เวลาใดก็ได้';
    }
  }
  String _formatFrequency(MedicationDetails details, BuildContext context) {
    if (details.frequencyType == FrequencyType.everyXHours) {
      String startTime = details.specificTimes.isNotEmpty ? details.specificTimes.first.format(context) : "N/A";
      return 'ทุก ${details.intervalHours} ชั่วโมง (เริ่ม ${startTime})';
    } else {
      if (details.specificTimes.isEmpty) return 'กรุณาระบุเวลา';
      String times = details.specificTimes.map((t) => t.format(context)).join(', ');
      return 'เวลา: $times';
    }
  }
  String _formatDuration(DateTime startDate, DateTime? endDate) {
    String start = DateFormat.yMd().format(startDate);
    if (endDate == null) { return 'เริ่ม $start (ไม่มีวันสิ้นสุด)'; }
    String end = DateFormat.yMd().format(endDate);
    return 'จาก $start ถึง $end';
  }


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
              final details = item.medicationDetails;

              return DataCard(
                // --- (อัปเดต) ⭐️ เปลี่ยนกลับไปใช้ Row/Column ---
                 child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: AppStyles.largeText), // Med Name
                          const SizedBox(height: 8),
                          
                          if (details != null) ...[
                            // ข้อมูลยาใหม่
                            Text(
                              '${details.dosage} (${_formatMealRelation(details.mealRelation)})',
                              style: AppStyles.largeText.copyWith(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFrequency(details, context),
                              style: AppStyles.largeText.copyWith(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700]),
                            ),
                             const SizedBox(height: 8),
                            Text(
                              _formatDuration(item.date, details.endDate),
                              style: AppStyles.largeText.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey[800]),
                            ),
                          ] else ... [
                            // ข้อมูลยาเก่า (ถ้ามี)
                            Text(
                              '${item.description}\nTime: ${item.time.format(context)}',
                              style: AppStyles.largeText.copyWith(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700]),
                            ),
                          ]
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red[700]),
                      onPressed: () => dataService.deleteItem(item.id),
                    ),
                  ],
                ),
                // --- จบส่วนอัปเดต ---
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

// --- 
// --- 8. ⭐️ Add/Edit Item Page (ฟอร์มยา) ⭐️
// ---
class AddItemScreen extends StatefulWidget {
  final ItemType type;
  final AppItem? itemToEdit;

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

  late TextEditingController _dosageController;
  late TextEditingController _intervalController;
  MealRelation _mealRelation = MealRelation.any;
  FrequencyType _frequencyType = FrequencyType.specificTimes;
  List<TimeOfDay> _specificTimes = [];
  DateTime? _endDate;

  bool get _isEditing => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
    _dosageController = TextEditingController();
    _intervalController = TextEditingController();
    
    if (_isEditing) {
      final item = widget.itemToEdit!;
      _titleController.text = item.title;
      _descriptionController.text = item.description;
      _amountController.text = item.amount > 0 ? item.amount.toStringAsFixed(2) : '';
      _selectedDate = item.date;
      _selectedTime = item.time;
      
      if (item.medicationDetails != null) {
        final details = item.medicationDetails!;
        _dosageController.text = details.dosage;
        _mealRelation = details.mealRelation;
        _frequencyType = details.frequencyType;
        _specificTimes = List.from(details.specificTimes);
        _intervalController.text = details.intervalHours?.toString() ?? '';
        _endDate = details.endDate;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _dosageController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  // --- ฟังก์ชัน Submit (แก้ไขบั๊ก) ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) { return; }

    final dataService = Provider.of<DataService>(context, listen: false);

    // --- ตรรกะใหม่สำหรับยา ---
    if (widget.type == ItemType.medication) {
      if (_selectedDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Start Date'))); return; }
      if (_frequencyType == FrequencyType.specificTimes && _specificTimes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one specific time'))); return; }
      if (_frequencyType == FrequencyType.everyXHours && _intervalController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the hour interval'))); return; }

      final medDetails = MedicationDetails(
        dosage: _dosageController.text,
        mealRelation: _mealRelation,
        frequencyType: _frequencyType,
        specificTimes: _specificTimes,
        intervalHours: int.tryParse(_intervalController.text),
        endDate: _endDate,
      );
      
      if (_isEditing) {
        final updatedItem = AppItem(
          id: widget.itemToEdit!.id,
          type: ItemType.medication,
          title: _titleController.text,
          date: _selectedDate!,
          medicationDetails: medDetails,
          completed: widget.itemToEdit!.completed,
          time: TimeOfDay(hour: 0, minute: 0), 
          description: '', 
          amount: 0, 
        );
        await dataService.updateItem(updatedItem);
      } else {
        final newItem = AppItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: ItemType.medication,
          title: _titleController.text,
          date: _selectedDate!,
          medicationDetails: medDetails,
          time: TimeOfDay(hour: 0, minute: 0),
        );
        await dataService.addItem(newItem);
      }
      
    } else {
      // --- ตรรกะเดิมสำหรับประเภทอื่นๆ ---
      bool dateRequired = widget.type == ItemType.reminder || widget.type == ItemType.income || widget.type == ItemType.expense || widget.type == ItemType.appointment;
      bool timeRequired = widget.type == ItemType.reminder || widget.type == ItemType.appointment;

      if (dateRequired && _selectedDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date'))); return; }
      if (timeRequired && _selectedTime == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a time'))); return; }
      
      if (_isEditing) {
        final updatedItem = AppItem(
          id: widget.itemToEdit!.id,
          type: widget.type,
          title: _titleController.text,
          description: _descriptionController.text,
          amount: double.tryParse(_amountController.text) ?? 0.0,
          date: _selectedDate ?? DateTime.now(),
          time: _selectedTime ?? TimeOfDay.now(),
          completed: widget.itemToEdit!.completed,
          medicationDetails: widget.itemToEdit!.medicationDetails, 
        );
        await dataService.updateItem(updatedItem);
      } else {
        final newItem = AppItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: widget.type,
          title: _titleController.text,
          description: _descriptionController.text,
          amount: double.tryParse(_amountController.text) ?? 0.0,
          date: _selectedDate ?? DateTime.now(),
          time: _selectedTime ?? TimeOfDay.now(),
        );
        await dataService.addItem(newItem);
      }
    }
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Data ${ _isEditing ? 'updated' : 'saved'} successfully')), );
      Navigator.pop(context);
    }
  }
  
  // (Helpers for pickers)
  Future<void> _pickDate(String type) async {
    DateTime? picked = await showDatePicker(
      context: context, initialDate: (type == 'start' ? _selectedDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (type == 'start') { _selectedDate = picked; } 
        else { _endDate = picked; }
      });
    }
  }
  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker( context: context, initialTime: _selectedTime ?? TimeOfDay.now(), );
    if (picked != null) {
      setState(() {
        if (widget.type == ItemType.medication) {
          if (!_specificTimes.contains(picked)) {
             _specificTimes.add(picked);
             _specificTimes.sort((a,b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
          }
        } else {
          _selectedTime = picked;
        }
      });
    }
  }
  
  // (Helper for title)
  String _getFormTitle() {
    if (_isEditing) {
      switch (widget.type) {
        case ItemType.reminder: return 'Edit Reminder';
        case ItemType.income: return 'Edit Income';
        case ItemType.expense: return 'Edit Expense';
        case ItemType.appointment: return 'Edit Appointment';
        case ItemType.medication: return 'Edit Medication';
      }
    }
    switch (widget.type) {
      case ItemType.reminder: return 'Add Reminder';
      case ItemType.income: return 'Add Income';
      case ItemType.expense: return 'Add Expense';
      case ItemType.appointment: return 'Add Appointment';
      case ItemType.medication: return 'Add Medication';
    }
  }

  // --- (อัปเดต) _buildFormFields ---
  List<Widget> _buildFormFields() {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);

    final inputDecoration = InputDecoration(
      border: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(width: 3, color: config.primaryActionColor), ),
      enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(width: 3, color: config.primaryActionColor), ),
      labelStyle: const TextStyle(fontSize: 20),
      contentPadding: const EdgeInsets.all(15),
    );
    
    final dropdownDecoration = inputDecoration.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18)
    );

    // --- (ฟอร์มยา) ---
    if (widget.type == ItemType.medication) {
      return [
        TextFormField(
          controller: _titleController,
          decoration: inputDecoration.copyWith(labelText: 'Medication Name'),
          style: const TextStyle(fontSize: 20),
          validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _dosageController,
          decoration: inputDecoration.copyWith(labelText: 'Dosage (e.g., 2 pills)'),
          style: const TextStyle(fontSize: 20),
          validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<MealRelation>(
          decoration: dropdownDecoration,
          initialValue: _mealRelation,
          style: const TextStyle(fontSize: 20, color: Colors.black),
          items: MealRelation.values.map((relation) {
            return DropdownMenuItem( value: relation, child: Text(_formatMealRelation(relation)), );
          }).toList(),
          onChanged: (value) { setState(() { _mealRelation = value ?? MealRelation.any; }); },
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<FrequencyType>(
          decoration: dropdownDecoration,
          initialValue: _frequencyType,
          style: const TextStyle(fontSize: 20, color: Colors.black),
          items: const [
            DropdownMenuItem(value: FrequencyType.specificTimes, child: Text('Specific Times')),
            DropdownMenuItem(value: FrequencyType.everyXHours, child: Text('Every X Hours')),
          ],
          onChanged: (value) { setState(() { _frequencyType = value ?? FrequencyType.specificTimes; }); },
        ),
        const SizedBox(height: 16),
        if (_frequencyType == FrequencyType.everyXHours) ...[
          TextFormField(
            controller: _intervalController,
            decoration: inputDecoration.copyWith(labelText: 'Interval (in hours)'),
            style: const TextStyle(fontSize: 20),
            keyboardType: TextInputType.number,
            validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null,
          ),
          const SizedBox(height: 16),
           ListTile(
            shape: RoundedRectangleBorder( side: BorderSide(color: config.primaryActionColor, width: 2), borderRadius: BorderRadius.circular(8)),
            title: Text( _specificTimes.isEmpty ? 'Select Start Time' : 'Start Time: ${_specificTimes.first.format(context)}', style: AppStyles.largeText, ),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
                TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (picked != null) { setState(() { _specificTimes = [picked]; }); }
            },
          ),
        ] else ...[
          Wrap(
            spacing: 8.0,
            children: _specificTimes.map((time) {
              return Chip(
                label: Text(time.format(context), style: const TextStyle(fontSize: 18)),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () { setState(() { _specificTimes.remove(time); }); },
              );
            }).toList(),
          ),
          OutlinedButton.icon(
             style: OutlinedButton.styleFrom( minimumSize: const Size(double.infinity, 60), side: BorderSide(width: 2, color: config.textColor), ),
            icon: const Icon(Icons.add_alarm),
            label: Text('Add Time', style: TextStyle(fontSize: 20, color: config.textColor)),
            onPressed: _pickTime,
          ),
        ],
        const SizedBox(height: 24),
        ListTile(
          shape: RoundedRectangleBorder( side: BorderSide(color: config.primaryActionColor, width: 2), borderRadius: BorderRadius.circular(8)),
          title: Text( _selectedDate == null ? 'Select Start Date' : 'Start Date: ${DateFormat.yMMMd().format(_selectedDate!)}', style: AppStyles.largeText, ),
          trailing: const Icon(Icons.calendar_month),
          onTap: () => _pickDate('start'),
        ),
        const SizedBox(height: 16),
         ListTile(
          shape: RoundedRectangleBorder( side: BorderSide(color: config.primaryActionColor, width: 2), borderRadius: BorderRadius.circular(8)),
          title: Text( _endDate == null ? 'Select End Date (Optional)' : 'End Date: ${DateFormat.yMMMd().format(_endDate!)}', style: AppStyles.largeText.copyWith(color: _endDate == null ? Colors.grey[700] : Colors.black), ),
          trailing: const Icon(Icons.calendar_month),
          onTap: () => _pickDate('end'),
        ),
      ];
    }

    // --- (ฟอร์มประเภทอื่น) ---
    List<Widget> fields = [];
    if (widget.type == ItemType.reminder) {
      fields.add( TextFormField( controller: _titleController, decoration: inputDecoration.copyWith(labelText: 'What to remember'), style: const TextStyle(fontSize: 20), validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null, ), );
    } else if (widget.type == ItemType.income || widget.type == ItemType.expense) {
       fields.add( TextFormField( controller: _titleController, decoration: inputDecoration.copyWith(labelText: 'Description'), style: const TextStyle(fontSize: 20), validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null, ), );
    } else if (widget.type == ItemType.appointment) {
       fields.add( TextFormField( controller: _titleController, decoration: inputDecoration.copyWith(labelText: 'Hospital/Clinic'), style: const TextStyle(fontSize: 20), validator: (value) => (value == null || value.isEmpty) ? 'Cannot be empty' : null, ), );
    }
    fields.add(const SizedBox(height: 24));
    if (widget.type == ItemType.reminder) {
      fields.add( TextFormField( controller: _descriptionController, decoration: inputDecoration.copyWith(labelText: 'Details'), maxLines: 3, style: const TextStyle(fontSize: 20), ), );
    } else if (widget.type == ItemType.income || widget.type == ItemType.expense) {
      fields.add( TextFormField( controller: _descriptionController, decoration: inputDecoration.copyWith(labelText: 'Notes'), maxLines: 3, style: const TextStyle(fontSize: 20), ), );
    } else if (widget.type == ItemType.appointment) {
      fields.add( TextFormField( controller: _descriptionController, decoration: inputDecoration.copyWith(labelText: 'Doctor/Department'), style: const TextStyle(fontSize: 20), ), );
    }
    if (widget.type == ItemType.income || widget.type == ItemType.expense) {
      fields.add(const SizedBox(height: 24));
      fields.add( TextFormField( controller: _amountController, decoration: inputDecoration.copyWith(labelText: 'Amount (\$)'), style: const TextStyle(fontSize: 20), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) { if (value == null || value.isEmpty) return 'Cannot be empty'; if (double.tryParse(value) == null) return 'Invalid number'; return null; }, ), );
    }
    if (widget.type == ItemType.reminder || widget.type == ItemType.income || widget.type == ItemType.expense || widget.type == ItemType.appointment) {
      fields.add(const SizedBox(height: 16));
      fields.add( ListTile( shape: RoundedRectangleBorder( side: BorderSide(color: config.primaryActionColor, width: 2), borderRadius: BorderRadius.circular(8)), title: Text( _selectedDate == null ? 'Select Date' : DateFormat.yMMMd().format(_selectedDate!), style: AppStyles.largeText, ), trailing: const Icon(Icons.calendar_month), onTap: () => _pickDate('start'), ), );
    }
    if (widget.type == ItemType.reminder || widget.type == ItemType.appointment) {
      fields.add(const SizedBox(height: 16));
      fields.add( ListTile( shape: RoundedRectangleBorder( side: BorderSide(color: config.primaryActionColor, width: 2), borderRadius: BorderRadius.circular(8)), title: Text( _selectedTime == null ? 'Select Time' : _selectedTime!.format(context), style: AppStyles.largeText, ), trailing: const Icon(Icons.access_time), onTap: _pickTime, ), );
    }
    return fields;
  }
  
  String _formatMealRelation(MealRelation relation) {
    switch (relation) {
      case MealRelation.beforeMeal: return 'before meal';
      case MealRelation.afterMeal: return 'after meal';
      case MealRelation.withMeal: return 'with meal';
      case MealRelation.any: return 'anytime';
    }
  }


  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigNotifier>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(_getFormTitle(), style: AppStyles.extraLargeText.copyWith(fontSize: 28)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton( icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context), ),
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
                  style: ElevatedButton.styleFrom( backgroundColor: config.primaryActionColor, foregroundColor: Colors.white, ),
                  onPressed: _submitForm,
                  child: Text(_isEditing ? 'Update' : 'Save'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                   style: OutlinedButton.styleFrom( minimumSize: const Size(double.infinity, 60), side: BorderSide(width: 2, color: config.textColor), ),
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