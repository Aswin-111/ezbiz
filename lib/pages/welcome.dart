// import 'package:ezbiz/pages/dashboard.dart';
// import 'package:ezbiz/testpages/testpage.dart';
// import 'package:flutter/material.dart';

// class WelcomePage extends StatelessWidget {
//   const WelcomePage({super.key});

//   void _onOrderPressed(BuildContext context) {
//      Navigator.pushReplacement(context, MaterialPageRoute(builder:  (context) => UserDataPage()));
//     print('Order button pressed');
//   }

//   void _onTestPressed(BuildContext context) {
//     // Handle Test button press
//       Navigator.pushReplacement(context, MaterialPageRoute(builder:  (context) => TestUserDataPage()));
//     print('Test button pressed');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
     
//       body: Center(
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Order Button
//             Card(
//               elevation: 10, // Elevation for shadow effect
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10), // Rounded corners
//               ),
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.deepPurple, // Button color
//                   minimumSize: const Size(150, 50), // Button size
//                   textStyle: const TextStyle(fontSize: 18), // Text size
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10), // Rounded corners
//                   ),
//                 ),
//                 onPressed: () => _onOrderPressed(context),
//                 child: const Text('Order',style: TextStyle(color: Colors.white),),
//               ),
//             ),
//             const SizedBox(width: 20), // Space between buttons
//             // Test Button
//             Card(
//               elevation: 10, // Elevation for shadow effect
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10), // Rounded corners
//               ),
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.deepPurple, // Button color
//                   minimumSize: const Size(150, 50), // Button size
//                   textStyle: const TextStyle(fontSize: 18), // Text size
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10), // Rounded corners
//                   ),
//                 ),
//                 onPressed:()=> _onTestPressed(context),
//                child: const Text('Test',style: TextStyle(color: Colors.white),),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:ezbiz/pages/home.dart';
import 'package:ezbiz/testpages/testpage.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Scale animation for buttons
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onOrderPressed(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => UserDataPage()),
    );
  }

  void _onTestPressed(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => TestUserDataPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6C63FF),
              Color(0xFF8B83FF),
              Color(0xFFA5A6F6),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background circles
            _buildBackgroundCircles(),
            
            // Main content
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo/Icon
                          _buildLogo(),
                          
                          const SizedBox(height: 40),
                          
                          // Welcome text
                          _buildWelcomeText(),
                          
                          const SizedBox(height: 20),
                          
                          // Subtitle
                          _buildSubtitle(),
                          
                          const SizedBox(height: 60),
                          
                          // Buttons
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildButtons(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundCircles() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          top: 150,
          left: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          size: 60,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome to',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'EzBiz',
          style: TextStyle(
            fontSize: 48,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Your Business Management Solution',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: Colors.white.withOpacity(0.85),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        _buildAnimatedButton(
          context: context,
          label: 'Start Ordering',
          icon: Icons.shopping_cart_rounded,
          onPressed: () => _onOrderPressed(context),
          isPrimary: true,
          delay: 0,
        ),
        // const SizedBox(height: 20),
        // _buildAnimatedButton(
        //   context: context,
        //   label: 'Stock',
        //   icon: Icons.science_rounded,
        //   onPressed: () => _onTestPressed(context),
        //   isPrimary: false,
        //   delay: 150,
        // ),
      ],
    );
  }

  Widget _buildAnimatedButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isPrimary ? Colors.white : Colors.white.withOpacity(0.2),
            foregroundColor: isPrimary ? Color(0xFF6C63FF) : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: isPrimary
                  ? BorderSide.none
                  : BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 15),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}