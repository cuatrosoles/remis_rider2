import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

///import 'package:taxi_booking/screens/prueba.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../main.dart';

///import '../../screens/WalkThroughtScreen.dart';
import '../../utils/Colors.dart';
import '../../utils/Constants.dart';
import '../../utils/Extensions/app_common.dart';
import '../network/RestApis.dart';
import '../utils/images.dart';
import 'EditProfileScreen.dart';
import 'SignInScreen.dart';
import 'DashBoardScreen.dart';

class SplashScreen extends StatefulWidget {
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('Está logueado1: $appStore.isLoggedIn');
    init();
  }

  void init() async {
    await Future.delayed(Duration(seconds: 2));
    if (sharedPref.getBool(IS_FIRST_TIME) ?? true) {
      await Geolocator.requestPermission().then((value) async {
        await Geolocator.getLastKnownPosition().then((value) {
          sharedPref.setDouble(LATITUDE, value!.latitude);
          sharedPref.setDouble(LONGITUDE, value.longitude);
          sharedPref.setBool(IS_FIRST_TIME, false);
          //// launchScreen(context, WalkThroughScreen(),
          launchScreen(context, SignInScreen(),
              pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        });
      });
    } else {
      print('Está logueado2: $appStore.isLoggedIn');

      if (!appStore.isLoggedIn) {
        launchScreen(context, SignInScreen(),
            pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      } else {
        if (sharedPref.getString(CONTACT_NUMBER).validate().isEmptyOrNull) {
          launchScreen(context, EditProfileScreen(isGoogle: true),
              isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        } else {
          ///launchScreen(context, Prueba(),

          launchScreen(context, DashBoardScreen(),
              pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        }
      }
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      ///backgroundColor: primaryColor,
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(ic_logo_white,
                fit: BoxFit.contain, height: 150, width: 150),
            SizedBox(height: 16),
            Text(language.appName,
                style: boldTextStyle(color: Colors.black87, size: 22)),
          ],
        ),
      ),
    );
  }
}
