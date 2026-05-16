import 'package:flutter/material.dart';
import 'tabs/analytics_screen.dart';
import 'tabs/chat_screen.dart';
import 'tabs/home_screen.dart';
import 'tabs/more_screen.dart';
import 'tabs/parent_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int selectedTab;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab;
    selectedTab = tab < 0
        ? 0
        : tab > 4
            ? 4
            : tab;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const AnalyticsScreen(),
      const ParentScreen(),
      const ChatScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      body: pages[selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (value) => setState(() => selectedTab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.auto_graph), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Parent'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
