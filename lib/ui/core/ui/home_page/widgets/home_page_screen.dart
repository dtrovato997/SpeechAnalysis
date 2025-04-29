import 'package:flutter/material.dart';
import 'package:mobile_speech_recognition/ui/core/ui/home_page/widgets/carousel_with_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Define a consistent horizontal padding value
  final double horizontalPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.android),
        title: const Text('Speech Analysis'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            height: 60,
            child: const Center(
              child: Text(
                'Start a new analysis...',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          Expanded(child: Container(child: createMainOptionWidgets())),

          // Add headline with the same left padding as options
          Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              top: 16.0,
              bottom: 8.0,
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Most recent analysis',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Self-contained carousel with its own ViewModel
          Container(
            height: 150,
            child: CarouselWithIndicator(
              horizontalPadding: horizontalPadding,
              onItemTap: (item) {
                // Handle tap on carousel item
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: ${item.title}')),
                );
                // Navigate to details page or perform action
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), 
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined), 
              label: 'Analysis'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget createMainOptionWidgets() {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding), // Use consistent padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                // Handle option 1 tap
              },
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: const Center(
                  child: Text('Option 1', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: InkWell(
              onTap: () {
                // Handle option 2 tap
              },
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: const Center(
                  child: Text('Option 2', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}