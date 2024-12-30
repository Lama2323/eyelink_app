import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'screens/forgot_password_page.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if (Platform.isAndroid) {
    await Permission.notification.request();
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  timeago.setLocaleMessages('vi', timeago.ViMessages());

  // Khởi tạo Background Service
  await initializeService();

  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    'background_service_channel',
    'Background Service Notifications',
    description: 'Channel for background service notifications',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(serviceChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'background_service_channel',
      // initialNotificationTitle: 'Ứng dụng đang chạy ngầm',
      // initialNotificationContent: 'Đang giám sát...',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('reloadSettings').listen((event) async {
    print('Reloading settings...');
    final prefs = await SharedPreferences.getInstance();
    final selectedInterval = prefs.getInt('checkInterval') ?? 5;

    Supabase.instance.client.dispose();
    Supabase.instance.client
        .channel('access_log_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'access_log',
          callback: (payload) async {
            if (payload.newRecord != null &&
                payload.newRecord!['stranger'] > 0) {
              final int strangerCount = payload.newRecord!['stranger'] as int;
              final lastNotificationTime =
                  prefs.getInt('lastNotificationTime') ?? 0;
              final now = DateTime.now().millisecondsSinceEpoch;

              if (lastNotificationTime == 0 ||
                  now - lastNotificationTime >= selectedInterval * 1000) {
                flutterLocalNotificationsPlugin.show(
                  0,
                  'Phát hiện người lạ!',
                  'Phát hiện $strangerCount người lạ.',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'high_importance_channel',
                      'High Importance Notifications',
                      priority: Priority.high,
                      importance: Importance.max,
                      icon: '@mipmap/ic_launcher',
                    ),
                  ),
                );
                await prefs.setInt('lastNotificationTime', now);
              }
            }
          },
        )
        .subscribe();
  });

  final prefs = await SharedPreferences.getInstance();
  final selectedInterval = prefs.getInt('checkInterval') ?? 5;
  if (selectedInterval != 0) {
    Supabase.instance.client
        .channel('access_log_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'access_log',
          callback: (payload) async {
            if (payload.newRecord != null &&
                payload.newRecord!['stranger'] > 0) {
              final int strangerCount = payload.newRecord!['stranger'] as int;
              final lastNotificationTime =
                  prefs.getInt('lastNotificationTime') ?? 0;
              final now = DateTime.now().millisecondsSinceEpoch;

              if (lastNotificationTime == 0 ||
                  now - lastNotificationTime >= selectedInterval * 1000) {
                flutterLocalNotificationsPlugin.show(
                  0,
                  'Phát hiện người lạ!',
                  'Phát hiện $strangerCount người lạ.',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'high_importance_channel',
                      'High Importance Notifications',
                      priority: Priority.high,
                      importance: Importance.max,
                      icon: '@mipmap/ic_launcher',
                    ),
                  ),
                );
                await prefs.setInt('lastNotificationTime', now);
              }
            }
          },
        )
        .subscribe();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  print('FLUTTER BACKGROUND FETCH');
  return true;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => Supabase.instance.client.auth.currentUser == null
            ? const LoginPage()
            : HomePage(key: homePageKey),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}