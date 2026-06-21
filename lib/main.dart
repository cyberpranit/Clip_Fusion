import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clip_fusion/screens/home_screen.dart';
import 'package:clip_fusion/screens/downloads_screen.dart';
import 'package:clip_fusion/screens/favorites_screen.dart';
import 'package:clip_fusion/screens/whatsapp_saver_screen.dart';
import 'package:clip_fusion/widgets/floating_island.dart';
import 'package:clip_fusion/theme/theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Router configuration
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RootLayout(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ClipFusion',
      debugShowCheckedModeBanner: false,
      theme: ClipFusionTheme.amoledTheme,
      routerConfig: _router,
    );
  }
}

class RootLayout extends StatefulWidget {
  const RootLayout({super.key});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              HomeScreen(
                onNavigateToDownloads: () => _navigateToTab(1),
                onNavigateToWhatsApp: () => _navigateToTab(3),
              ),
              const DownloadsScreen(),
              const FavoritesScreen(),
              const WhatsAppSaverScreen(),
            ],
          ),
          
          // Floating Dynamic Island (globally positioned on top)
          const FloatingIsland(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ClipFusionTheme.border, width: 0.5)),
          color: ClipFusionTheme.black,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: ClipFusionTheme.black,
          selectedItemColor: ClipFusionTheme.cyan,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(PhosphorIcons.house),
              activeIcon: const Icon(PhosphorIcons.houseFill),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(PhosphorIcons.download),
              activeIcon: const Icon(PhosphorIcons.downloadFill),
              label: 'Downloads',
            ),
            BottomNavigationBarItem(
              icon: const Icon(PhosphorIcons.heart),
              activeIcon: const Icon(PhosphorIcons.heartFill),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: const Icon(PhosphorIcons.whatsappLogo),
              activeIcon: const Icon(PhosphorIcons.whatsappLogoFill),
              label: 'WhatsApp',
            ),
          ],
        ),
      ),
    );
  }
}
