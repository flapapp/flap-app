import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_creation_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/video_upload_screen.dart';
import 'screens/video_main_screen.dart';
import 'screens/video_player_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/challenge_list_screen.dart';
import 'screens/challenge_create_screen.dart';
import 'screens/challenge_details_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/matches_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initMessaging();
  }
  runApp(const MyApp());
}

Future<void> _initMessaging() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set({
      'deviceTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  FirebaseMessaging.onMessage.listen((message) {
    // Optionally show in-app notification UI
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4caf50)),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FLAP',
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/profile': (context) => ProfileScreen(),
        '/profile-creation': (context) => ProfileCreationScreen(),
        '/profile-edit': (context) => ProfileCreationScreen(isEditing: true),
        '/mode': (context) => ModeSelectionScreen(),
        '/video-upload': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return VideoUploadScreen(
                challengeId: args?['challengeId'],
                challengeTitle: args?['challengeTitle'],
              );
            },
        '/video-main': (context) => VideoMainScreen(),
        '/challenge-list': (context) => ChallengeListScreen(),
        '/challenge-create': (context) => ChallengeCreateScreen(),
        '/matches': (context) => MatchesScreen(), 
        // VideoPlayerScreen не має маршруту, оскільки він викликається з параметрами
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e7d32), Color(0xFF2e7d32)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип як у MVP
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_soccer,
                      size: 60,
                      color: Color(0xFF1e7d32),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Назва
                  const Text(
                    'FLAP',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 8,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Підзаголовок
                  Text(
                    'Feel Like A Pro\nТвоя футбольна соціальна мережа',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Кнопки як у MVP
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4caf50).withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            child: const Text(
                              'УВІЙТИ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              'РЕЄСТРАЦІЯ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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