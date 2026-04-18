// pahe 1
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindSync',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 80,
                  color: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 40),

              // Title
              const Text(
                'Welcome to\nMindSync',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              const Text(
                'Your personal mental wellness companion. Track your mood, habits, and screen time to stay balanced.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, height: 1.4),
              ),

              const SizedBox(height: 50),

              // Features
              _buildFeature(Icons.emoji_emotions, 'Emotion Detection'),
              const SizedBox(height: 20),
              _buildFeature(Icons.bar_chart, 'Habit Tracking'),
              const SizedBox(height: 20),
              _buildFeature(Icons.phone_android, 'Screen Time Analysis'),

              const Spacer(),

              // Get Started Button
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Log In
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Already have an account? Log In',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 32, color: Colors.deepPurple),
        ),
        const SizedBox(width: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

 // page 2
 import 'package:flutter/material.dart';

 void main() => runApp(const MyApp());

 class MyApp extends StatelessWidget {
   const MyApp({super.key});

   @override
   Widget build(BuildContext context) {
     return MaterialApp(
       title: 'MindSync',
       theme: ThemeData(primarySwatch: Colors.blue),
       home: const LoginScreen(),
       debugShowCheckedModeBanner: false,
     );
   }
 }

 class LoginScreen extends StatelessWidget {
   const LoginScreen({super.key});

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       body: SafeArea(
         child: Padding(
           padding: const EdgeInsets.all(24.0),
           child: Column(
             children: [
               const SizedBox(height: 80),

               // Title
               const Text(
                 'Welcome Back',
                 style: TextStyle(
                   fontSize: 32,
                   fontWeight: FontWeight.bold,
                 ),
               ),

               const SizedBox(height: 50),

               // Email Field
               Container(
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.grey.shade300),
                 ),
                 child: const Padding(
                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                   child: TextField(
                     decoration: InputDecoration(
                       border: InputBorder.none,
                       hintText: 'Email',
                     ),
                   ),
                 ),
               ),

               const SizedBox(height: 16),

               // Password Field
               Container(
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.grey.shade300),
                 ),
                 child: const Padding(
                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                   child: TextField(
                     obscureText: true,
                     decoration: InputDecoration(
                       border: InputBorder.none,
                       hintText: 'Password',
                     ),
                   ),
                 ),
               ),

               const SizedBox(height: 30),

               // Login Button
               GestureDetector(
                 onTap: () {},
                 child: Container(
                   width: double.infinity,
                   padding: const EdgeInsets.symmetric(vertical: 18),
                   decoration: BoxDecoration(
                     color: Colors.blue,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: const Center(
                     child: Text(
                       'LOGIN',
                       style: TextStyle(
                         color: Colors.white,
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ),
                 ),
               ),

               const SizedBox(height: 24),

               // Sign Up Text
               GestureDetector(
                 onTap: () {},
                 child: RichText(
                   text: const TextSpan(
                     style: TextStyle(fontSize: 16),
                     children: [
                       TextSpan(
                         text: "Don't have an account? ",
                         style: TextStyle(color: Colors.black),
                       ),
                       TextSpan(
                         text: 'Sign Up',
                         style: TextStyle(
                           color: Colors.blue,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ),
       ),
     );
   }
 }


// page 3
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindSync',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AnalyticsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 8),
            const Text(
              'MindSync',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 10),
                SizedBox(width: 6),
                Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.person_outline, color: Colors.black, size: 28),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Four Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.monitor_heart,
                    iconColor: Colors.blue,
                    value: '78/100',
                    label: 'Wellbeing Score',
                    change: '+5%',
                    changeColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.phone_android,
                    iconColor: Colors.purple,
                    value: '0m',
                    label: 'Screen Time',
                    change: '-12%',
                    changeColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.bolt,
                    iconColor: Colors.green,
                    value: 'Low',
                    label: 'Stress Level',
                    change: 'Better',
                    changeColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.warning_amber,
                    iconColor: Colors.red,
                    value: '2',
                    label: 'Active Alerts',
                    change: 'Action',
                    changeColor: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Activity Monitor
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 15),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Monitor',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Real-time usage tracking',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Today's Activity",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _ActivityItem(icon: Icons.phone_android, value: '0m', label: 'Screen Time'),
                      _ActivityItem(icon: Icons.chat_bubble_outline, value: '12', label: 'Messages'),
                      _ActivityItem(icon: Icons.camera_alt_outlined, value: '5', label: 'App Opens'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Parent'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String change;
  final Color changeColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.change,
    required this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 15),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(change, style: TextStyle(color: changeColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ActivityItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.grey.shade700),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
*/