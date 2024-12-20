// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../screens/WalletScreen.dart';
import '../utils/Extensions/context_extension.dart';
import '../screens/ReviewScreen.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../../components/CouPonWidget.dart';
import '../../components/RideAcceptWidget.dart';
import '../../main.dart';
import '../../network/RestApis.dart';
import '../../utils/Colors.dart';
import '../../utils/Common.dart';
import '../../utils/Constants.dart';
import '../../utils/Extensions/AppButtonWidget.dart';
import '../../utils/Extensions/app_common.dart';
import '../../utils/Extensions/app_textfield.dart';
import '../components/BookingWidget.dart';
import '../components/CarDetailWidget.dart';
import '../model/CurrentRequestModel.dart';
import '../model/EstimatePriceModel.dart';
import '../utils/images.dart';
import 'DashBoardScreen.dart';

class NewEstimateRideListWidget extends StatefulWidget {
  final LatLng sourceLatLog;
  final LatLng destinationLatLog;
  final String sourceTitle;
  final String destinationTitle;
  bool isCurrentRequest;
  final int? servicesId;
  final int? id;

  NewEstimateRideListWidget(
      {required this.sourceLatLog,
      required this.destinationLatLog,
      required this.sourceTitle,
      required this.destinationTitle,
      this.isCurrentRequest = false,
      this.servicesId,
      this.id});

  @override
  NewEstimateRideListWidgetState createState() =>
      NewEstimateRideListWidgetState();
}

class NewEstimateRideListWidgetState extends State<NewEstimateRideListWidget> {
  late PolylinePoints polylinePoints;
  NewEstimateRideListWidgetState() {
    polylinePoints = PolylinePoints();
  }
  Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _googleMapController;
  final Set<Marker> markers = {};
  String countryCode = defaultCountryCode;
  Set<Polyline> _polyLines = Set<Polyline>();

  late Marker sourceMarker;
  late Marker destinationMarker;
  late LatLng userLatLong = LatLng(0.0, 0.0);
  late DateTime scheduleData;

  double locationDistance = 0.0;
  String? distanceUnit = 'KM';
  double? durationOfDrop = 0.0;
  double? distance = 0;
  TextEditingController promoCode = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  bool isBooking = false;
  bool isRideSelection = false;
  bool isOther = true;
  int selectedIndex = 0;
  int rideRequestId = 0;
  num mTotalAmount = 0;
  num totalAmount = 0;
  String? mSelectServiceAmount;
  List<String> cashList = ['cash', 'wallet'];
  List<ServicesListData> serviceList = [];
  List<LatLng> polylineCoordinates = [];
  List listAdicionales = [];
  late BitmapDescriptor sourceIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor driverIcon;
  LatLng? driverLatitudeLocation = LatLng(0, 0);
  LatLng? currentLocation = LatLng(0, 0);
  String paymentMethodType = '';
  ServicesListData? servicesListData;
  OnRideRequest? rideRequest;
  Driver? driverData;
  Timer? timer;
  LocationPermission? permissionData;
  late LocationSettings locationSettings;
  static const TargetPlatform defaultTargetPlatform = TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _refreshList();
    selectedAdditional.clear();
    selectedAdditionalCosto.clear();
    selectedAdditionalName.clear();
    getCurrentUserLocation();
    init();
    Timer.periodic(Duration(seconds: 3), (timer) {
      setState(() {
        serviceSelectWidget();
      });
    });
  }

  void init() async {
    sourceIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    destinationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
    driverIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);

    mqttForUser();
    if (!widget.isCurrentRequest) getNewService();
    isBooking = widget.isCurrentRequest;
    await getAdditionalFees().then((value) {
      for (int i = 0; i < value.data!.length; i++) {
        listAdicionales.add({
          "id": value.data![i].id,
          "title": value.data![i].title,
          "cost": value.data![i].cost
        });
      }
      setState(() {});
    }).catchError((error) {
      log(error.toString());
    });
    getCurrentRequest();
  }

  Future<void> getCurrentRequest() async {
    await getCurrentRideRequest().then((value) {
      if (value.rideRequest != null || value.onRideRequest != null) {
        setState(() {
          rideRequest = value.rideRequest ?? value.onRideRequest;
        });
      }
      if (value.driver != null) {
        driverData = value.driver!;
      }
      if (rideRequest != null) {
        if (driverData != null &&
            (rideRequest!.status != COMPLETED ||
                rideRequest!.status != IN_PROGRESS)) {
          timer = Timer.periodic(
              Duration(seconds: 5), (Timer t) => getUserDetailLocation());
        } else {
          timer?.cancel();
          timer = null;
        }
        setState(() {});
      }
      if (rideRequest!.status == IN_PROGRESS &&
          rideRequest != null &&
          driverData != null) {
        timer!.cancel();
        timer = null;
        startLocationTracking();
        getServiceList();
      }
      if (rideRequest!.status == COMPLETED &&
          rideRequest != null &&
          driverData != null) {
        timer!.cancel();
        timer = null;
        launchScreen(context,
            ReviewScreen(rideRequest: rideRequest!, driverData: driverData),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
            isNewTask: true);
      }
    }).catchError((error) {
      log(error.toString());
    });
  }

  Future<void> getServiceList() async {
    markers.clear();
    polylinePoints = PolylinePoints();
    setPolyLines(
        sourceLocation: rideRequest != null &&
                (rideRequest!.status == IN_PROGRESS)
            ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
            : LatLng(
                widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
        destinationLocation: LatLng(widget.destinationLatLog.latitude,
            widget.destinationLatLog.longitude),
        driverLocation: driverLatitudeLocation);
    MarkerId id = MarkerId('Source');
    rideRequest != null && (rideRequest!.status == IN_PROGRESS)
        ? markers.add(
            Marker(
              markerId: id,
              position:
                  LatLng(currentLocation!.latitude, currentLocation!.longitude),
              infoWindow: InfoWindow(title: widget.sourceTitle),
              icon: sourceIcon,
            ),
          )
        : markers.add(
            Marker(
              markerId: id,
              position: LatLng(
                  widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
              infoWindow: InfoWindow(title: widget.sourceTitle),
              icon: sourceIcon,
            ),
          );
    MarkerId id2 = MarkerId('DriverLocation');
    markers.remove(id2);
    MarkerId id3 = MarkerId('Destination');
    markers.remove(id3);
    rideRequest != null &&
            (rideRequest!.status == ACCEPTED ||
                rideRequest!.status == ARRIVING ||
                rideRequest!.status == ARRIVED ||
                rideRequest!.status == IN_PROGRESS)
        ? markers.add(
            Marker(
              markerId: id3,
              position: LatLng(widget.destinationLatLog.latitude,
                  widget.destinationLatLog.longitude),
              infoWindow: InfoWindow(title: widget.destinationTitle),
              icon: destinationIcon,
            ),
          )
        : markers.add(
            Marker(
              markerId: id2,
              position: driverLatitudeLocation!,
              icon: driverIcon,
            ),
          );
    setState(() {});
  }

  Future<void> getNewService({bool coupon = false}) async {
    int sumaDeAdicionales = 0;
    _refreshList();
    selectedAdditional.clear();
    selectedAdditionalCosto.clear();
    selectedAdditionalName.clear();
    appStore.setLoading(true);
    Map req = {
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      if (coupon) "coupon_code": promoCode.text.trim(),
    };
    setPolyLines(
        sourceLocation: widget.sourceLatLog,
        destinationLocation: widget.destinationLatLog,
        driverLocation: driverLatitudeLocation);
    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();
      value.data!.sort((a, b) => a.totalAmount!.compareTo(b.totalAmount!));
      serviceList.addAll(value.data!);
      if (serviceList.isNotEmpty) {
        locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble();
        if (serviceList[0].distanceUnit == 'km') {
          locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble();
          distanceUnit = 'km';
        } else {
          locationDistance =
              serviceList[0].dropoffDistanceInKm!.toDouble() * 0.621371;
          distanceUnit = 'mile';
        }
        durationOfDrop = serviceList[0].duration!.toDouble();
      }
      if (serviceList.isNotEmpty) servicesListData = serviceList[0];
      if (serviceList.isNotEmpty)
        paymentMethodType = serviceList[0].paymentMethod!;
      if (serviceList.isNotEmpty)
        cashList = paymentMethodType == 'cash_wallet'
            ? cashList = ['cash', 'wallet']
            : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) {
        if (serviceList[0].discountAmount != 0) {
          mSelectServiceAmount = (serviceList[0].subtotal! + sumaDeAdicionales)
              .toStringAsFixed(fixedDecimal);
        } else {
          mSelectServiceAmount =
              (serviceList[0].totalAmount! + sumaDeAdicionales)
                  .toStringAsFixed(fixedDecimal);
        }
      }
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString(), print: true);
    });
  }

  Future<void> getCouponNewService() async {
    appStore.setLoading(true);
    Map req = {
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      "coupon_code": promoCode.text.trim(),
    };
    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();
      value.data!.sort((a, b) => a.totalAmount!.compareTo(b.totalAmount!));
      serviceList.addAll(value.data!);
      if (serviceList.isNotEmpty) {
        locationDistance =
            serviceList[selectedIndex].dropoffDistanceInKm!.toDouble();
        if (serviceList[selectedIndex].distanceUnit == 'km') {
          locationDistance =
              serviceList[selectedIndex].dropoffDistanceInKm!.toDouble();
          distanceUnit = 'km';
        } else {
          locationDistance =
              serviceList[selectedIndex].dropoffDistanceInKm!.toDouble() *
                  0.621371;
          distanceUnit = 'mile';
        }
        durationOfDrop = serviceList[selectedIndex].duration!.toDouble();
      }
      if (serviceList.isNotEmpty) servicesListData = serviceList[selectedIndex];
      if (serviceList.isNotEmpty)
        cashList = paymentMethodType == 'cash_wallet'
            ? cashList = ['cash', 'wallet']
            : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) {
        if (serviceList[selectedIndex].discountAmount != 0) {
          mSelectServiceAmount = serviceList[selectedIndex]
              .subtotal!
              .toStringAsFixed(fixedDecimal);
        } else {
          mSelectServiceAmount = serviceList[selectedIndex]
              .totalAmount!
              .toStringAsFixed(fixedDecimal);
        }
      }
      setState(() {});
      Navigator.pop(context);
    }).catchError((error) {
      promoCode.clear();
      Navigator.pop(context);
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future<void> getUserDetailLocation() async {
    if (rideRequest!.status != COMPLETED &&
        rideRequest!.status != IN_PROGRESS) {
      getUserDetail(userId: driverData!.id).then((value) {
        driverLatitudeLocation = LatLng(double.parse(value.data!.latitude!),
            double.parse(value.data!.longitude!));
        getServiceList();
      }).catchError((error) {
        log(error.toString());
      });
    } else {
      if (timer != null) timer?.cancel();
    }
  }

  Future<void> getCurrentUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    await Geolocator.isLocationServiceEnabled().then((enabled) async {
      if (enabled) {
        await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 30))
            .then((value) async {
          setState(() {
            currentLocation = LatLng(value.latitude, value.longitude);
          });
        });
      }
    });
    Map req = {
      "latitude": currentLocation!.latitude.toString(),
      "longitude": currentLocation!.longitude.toString(),
    };
    sharedPref.setDouble(LATITUDE, currentLocation!.latitude);
    sharedPref.setDouble(LONGITUDE, currentLocation!.longitude);
    await updateStatus(req).then((value) {
      setState(() {});
    }).catchError((error) {
      log(error);
    });
  }

  Future<void> setPolyLines({
    required LatLng sourceLocation,
    required LatLng destinationLocation,
    LatLng? driverLocation,
    LatLng? currentLocation,
  }) async {
    _polyLines.clear();
    polylineCoordinates.clear();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: GOOGLE_MAP_API_KEY,
      request: PolylineRequest(
        origin: rideRequest != null && (rideRequest! == IN_PROGRESS)
            ? PointLatLng(currentLocation!.latitude, currentLocation.longitude)
            : PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
        destination: rideRequest != null &&
                rideRequest!.status != null &&
                (rideRequest!.status == ACCEPTED ||
                    rideRequest!.status == ARRIVING ||
                    rideRequest!.status == ARRIVED)
            ? PointLatLng(driverLocation!.latitude, driverLocation.longitude)
            : PointLatLng(
                destinationLocation.latitude, destinationLocation.longitude),
        mode: TravelMode.driving,
      ),
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((element) {
        polylineCoordinates.add(LatLng(element.latitude, element.longitude));
      });
      _polyLines.add(Polyline(
        visible: true,
        width: 5,
        polylineId: PolylineId('poly'),
        color: Color.fromARGB(255, 40, 122, 198),
        points: polylineCoordinates,
      ));
      setState(() {});
    }
  }

  Future<void> setMapPins() async {
    markers.clear();
    MarkerId id = MarkerId("DeliveryBoy");
    markers.remove(id);
    markers.add(
      Marker(
        markerId: id,
        position: userLatLong,
        icon: sourceIcon,
        infoWindow: InfoWindow(title: ''),
      ),
    );
    if (servicesListData != null)
      servicesListData!.status != IN_PROGRESS
          ? markers.add(
              Marker(
                markerId: MarkerId('sourceLocation'),
                position: widget.destinationLatLog,
                icon: sourceIcon,
                infoWindow: InfoWindow(title: servicesListData!.startAddress),
              ),
            )
          : markers.add(
              Marker(
                markerId: MarkerId('destinationLocation'),
                position: LatLng(double.parse(servicesListData!.endLatitude!),
                    double.parse(servicesListData!.endLongitude!)),
                icon: destinationIcon,
                infoWindow: InfoWindow(title: servicesListData!.endAddress),
              ),
            );
  }

  Future<void> startLocationTracking() async {
    _polyLines.clear();
    polylineCoordinates.clear();
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 3),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      if (appStore.isLoggedIn) {
        userLatLong = LatLng(position.latitude, position.longitude);
        Timer.periodic(Duration(seconds: 3), (t) async {
          stutasCount = stutasCount! + 1;
          if (stutasCount == 60) {
            Map req = {
              "latitude": userLatLong.latitude.toString(),
              "longitude": userLatLong.longitude.toString(),
            };
            sharedPref.setDouble(LATITUDE, userLatLong.latitude);
            sharedPref.setDouble(LONGITUDE, userLatLong.longitude);
            await updateStatus(req).then((value) {
              setState(() {});
            }).catchError((error) {
              log(error);
            });
            stutasCount = 0;
          }
        });
        _polyLines.clear();
        polylineCoordinates.clear();
        if (rideRequest != null || widget.destinationLatLog != '') setMapPins();
        if (rideRequest != null || widget.destinationLatLog != '')
          setPolyLines(
              sourceLocation: userLatLong,
              destinationLocation: (widget.destinationLatLog != '')
                  ? widget.destinationLatLog
                  : LatLng(double.parse(rideRequest!.endLatitude!),
                      double.parse(rideRequest!.endLongitude!)));
      }
    }, onError: (error) {});
  }

  onMapCreated(GoogleMapController controller) async {
    _googleMapController = controller;
    _controller.complete(controller);
    await Future.delayed(Duration(milliseconds: 50));
    _googleMapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(
                widget.sourceLatLog.latitude <=
                        widget.destinationLatLog.latitude
                    ? widget.sourceLatLog.latitude
                    : widget.destinationLatLog.latitude,
                widget.sourceLatLog.longitude <=
                        widget.destinationLatLog.longitude
                    ? widget.sourceLatLog.longitude
                    : widget.destinationLatLog.longitude),
            northeast: LatLng(
                widget.sourceLatLog.latitude <=
                        widget.destinationLatLog.latitude
                    ? widget.destinationLatLog.latitude
                    : widget.sourceLatLog.latitude,
                widget.sourceLatLog.longitude <=
                        widget.destinationLatLog.longitude
                    ? widget.destinationLatLog.longitude
                    : widget.sourceLatLog.longitude)),
        100));
    setState(() {});
  }

  Future<void> saveBookingData() async {
    if (isOther == false && nameController.text.isEmpty) {
      return toast(language.nameFieldIsRequired);
    } else if (isOther == false && phoneController.text.isEmpty) {
      return toast(language.phoneNumberIsRequired);
    }
    appStore.setLoading(true);
    Map req = {
      "rider_id": sharedPref.getInt(USER_ID).toString(),
      "service_id": servicesListData!.id.toString(),
      "selected_additional": selectedAdditional,
      "extra_charges": selectedAdditionalName,
      "extra_charges_amount": sumaDeAdicionales,
      "datetime": DateTime.now().toString(),
      "start_latitude": widget.sourceLatLog.latitude.toString(),
      "start_longitude": widget.sourceLatLog.longitude.toString(),
      "start_address": widget.sourceTitle,
      "end_latitude": widget.destinationLatLog.latitude.toString(),
      "end_longitude": widget.destinationLatLog.longitude.toString(),
      "end_address": widget.destinationTitle,
      "seat_count": servicesListData!.capacity.toString(),
      "status": NEW_RIDE_REQUESTED,
      "estimate_fare": servicesListData!.totalAmount,
      "payment_type": isOther == false
          ? 'cash'
          : paymentMethodType == 'cash_wallet'
              ? 'cash'
              : paymentMethodType,
      if (promoCode.text.isNotEmpty) "coupon_code": promoCode.text,
      "is_schedule": 0,
      if (isOther == false) "is_ride_for_other": 1,
      if (isOther == false)
        "other_rider_data": {
          "name": nameController.text.trim(),
          "contact_number": '$countryCode${phoneController.text.trim()}',
        }
    };
    await saveRideRequest(req).then((value) async {
      rideRequestId = value.rideRequestId!;
      widget.isCurrentRequest = true;
      isBooking = true;
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  mqttForUser() async {
    client.setProtocolV311();
    client.logging(on: true);
    client.keepAlivePeriod = 120;
    client.autoReconnect = true;
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint(e.toString());
      client.connect();
    }
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.onSubscribed = onSubscribed;
    } else if (client.connectionStatus!.state ==
        MqttConnectionState.disconnected) {
      client.connect();
    } else if (client.connectionStatus!.state ==
        MqttConnectionState.disconnecting) {
      client.connect();
    } else if (client.connectionStatus!.state == MqttConnectionState.faulted) {
      client.connect();
    }

    void onconnected() {
      debugPrint('connected');
    }

    client.subscribe(
        mMQTT_UNIQUE_TOPIC_NAME +
            'ride_request_status_' +
            sharedPref.getInt(USER_ID).toString(),
        MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print("jsonDecode(pt)['success_type']" +
          jsonDecode(pt)['success_type'].toString());

      if (jsonDecode(pt)['success_type'] == ACCEPTED ||
          jsonDecode(pt)['success_type'] == ARRIVING ||
          jsonDecode(pt)['success_type'] == ARRIVED ||
          jsonDecode(pt)['success_type'] == IN_PROGRESS) {
        isBooking = true;
        getCurrentRequest();
      } else if (jsonDecode(pt)['success_type'] == CANCELED) {
        launchScreen(context, DashBoardScreen(), isNewTask: true);
      } else if (jsonDecode(pt)['success_type'] == COMPLETED) {
        if (timer != null) timer!.cancel();
        getCurrentRequest();
        if (timer != null) timer!.cancel();
      } else if (appStore.isRiderForAnother == "1" &&
          jsonDecode(pt)['success_type'] == SUCCESS) {
        if (timer != null) timer!.cancel();
        launchScreen(context, DashBoardScreen(), isNewTask: true);
      }
    });
    client.onConnected = onconnected;
  }

  void onConnected() {
    log('Connected');
  }

  void onSubscribed(String topic) {
    log('Subscription confirmed for topic $topic');
  }

  Future<void> cancelRequest() async {
    Map req = {
      "id": rideRequestId == 0 ? widget.id : rideRequestId,
      "cancel_by": RIDER,
      "status": CANCELED,
    };
    await rideRequestUpdate(
            request: req,
            rideId: rideRequestId == 0 ? widget.id : rideRequestId)
        .then((value) async {
      launchScreen(context, DashBoardScreen(), isNewTask: true);
      toast(value.message);
    }).catchError((error) {
      log(error.toString());
    });
  }

  @override
  void dispose() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((value) {
      polylineSource = LatLng(value.latitude, value.longitude);
    });
    if (timer != null) timer!.cancel();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Widget mSomeOnElse() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child:
                    Text(language.lblRideInformation, style: boldTextStyle()),
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              controller: nameController,
              autoFocus: false,
              isValidationRequired: false,
              textFieldType: TextFieldType.NAME,
              keyboardType: TextInputType.name,
              errorThisFieldRequired: language.thisFieldRequired,
              decoration: inputDecoration(context, label: language.enterName),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              controller: phoneController,
              autoFocus: false,
              isValidationRequired: false,
              textFieldType: TextFieldType.PHONE,
              keyboardType: TextInputType.number,
              errorThisFieldRequired: language.thisFieldRequired,
              decoration: inputDecoration(
                context,
                label: language.enterContactNumber,
                prefixIcon: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryCodePicker(
                        padding: EdgeInsets.zero,
                        initialSelection: countryCode,
                        showCountryOnly: false,
                        dialogSize: Size(MediaQuery.of(context).size.width - 60,
                            MediaQuery.of(context).size.height * 0.6),
                        showFlag: true,
                        showFlagDialog: true,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: primaryTextStyle(),
                        dialogBackgroundColor: Theme.of(context).cardColor,
                        barrierColor: Colors.black12,
                        dialogTextStyle: primaryTextStyle(),
                        searchDecoration: InputDecoration(
                          iconColor: Theme.of(context).dividerColor,
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: primaryColor)),
                        ),
                        searchStyle: primaryTextStyle(),
                        onInit: (c) {
                          countryCode = c!.dialCode!;
                        },
                        onChanged: (c) {
                          countryCode = c.dialCode!;
                        },
                      ),
                      VerticalDivider(color: Colors.grey.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: AppButtonWidget(
              width: MediaQuery.of(context).size.width,
              text: language.done,
              textStyle: boldTextStyle(color: Colors.white),
              color: primaryColor,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  double calculateTotalAmount({required ServicesListData? serviceList}) {
    num? baseFare = serviceList!.baseFare;
    num? perDistance = serviceList.perDistance;
    num? perMinuteDrive = serviceList.perMinuteDrive;
    num? minimunDistance = serviceList.minimumDistance;
    num? distance = serviceList.distance;
    num? duration = serviceList.duration;
    num? discountAmount = serviceList.discountAmount;
    num? timePrice = duration! * perMinuteDrive!;

    if (distance! < minimunDistance!) {
      totalAmount = baseFare! + timePrice + sumaDeAdicionales;
    } else {
      num? distancePrice = distance * perDistance!;
      totalAmount = baseFare! + distancePrice + timePrice + sumaDeAdicionales;
    }

    if (totalAmount < serviceList.minimumFare!) {
      totalAmount = serviceList.minimumFare! + sumaDeAdicionales;
    }
    if (promoCode.text.isNotEmpty) {
      totalAmount = totalAmount + sumaDeAdicionales - discountAmount!;
    }
    return totalAmount.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 40,
        leading: Visibility(
          visible: !isBooking,
          child: inkWellWidget(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              margin: EdgeInsets.only(left: 8),
              padding: EdgeInsets.all(0),
              decoration: BoxDecoration(
                  color: context.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: dividerColor)),
              child: Icon(Icons.close, color: context.iconColor, size: 20),
            ),
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: GoogleMap(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.25),
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: onMapCreated,
              initialCameraPosition: CameraPosition(
                target: widget.sourceLatLog,
                zoom: 17,
              ),
              markers: markers,
              mapType: MapType.normal,
              polylines: _polyLines,
            ),
          ),
          !isBooking
              ? bookRideWidget()
              : Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(defaultRadius),
                          topRight: Radius.circular(defaultRadius))),
                  child: rideRequest != null
                      ? rideRequest!.status == NEW_RIDE_REQUESTED
                          ? BookingWidget(id: widget.id, isLast: true)
                          : RideAcceptWidget(
                              rideRequest: rideRequest, driverData: driverData)
                      : BookingWidget(
                          id: rideRequestId == 0 ? widget.id : rideRequestId,
                          isLast: true),
                ),
          Observer(builder: (context) {
            return Visibility(
                visible: appStore.isLoading, child: loaderWidget());
          }),
        ],
      ),
    );
  }

  Widget bookRideWidget() {
    return Stack(
      children: [
        Visibility(
          visible: serviceList.isNotEmpty,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(defaultRadius),
                    topRight: Radius.circular(defaultRadius))),
            child: SingleChildScrollView(
              child:
                  isRideSelection == false && appStore.isRiderForAnother == "1"
                      ? riderSelectionWidget()
                      : serviceSelectWidget(),
            ),
          ),
        ),
        Visibility(
          visible: !appStore.isLoading && serviceList.isEmpty,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(defaultRadius),
                    topRight: Radius.circular(defaultRadius))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                emptyWidget(),
                Text(language.servicesNotFound, style: boldTextStyle()),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget riderSelectionWidget() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              alignment: Alignment.center,
              margin: EdgeInsets.only(bottom: 16),
              height: 5,
              width: 70,
              decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(defaultRadius)),
            ),
          ),
          Text(language.whoWillBeSeated, style: primaryTextStyle(size: 18)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              inkWellWidget(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: textSecondaryColorGlobal, width: 1)),
                            padding: EdgeInsets.all(12),
                            child: Image.asset(ic_add_user, fit: BoxFit.fill),
                          ),
                          if (!isOther)
                            Container(
                              height: 70,
                              width: 70,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54),
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(language.lblSomeoneElse, style: primaryTextStyle()),
                    ],
                  ),
                  onTap: () {
                    isOther = false;
                    showDialog(
                      context: context,
                      builder: (_) {
                        return StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return AlertDialog(
                            contentPadding: EdgeInsets.all(0),
                            content: mSomeOnElse(),
                          );
                        });
                      },
                    ).then((value) {
                      setState(() {});
                    });
                    setState(() {});
                  }),
              SizedBox(width: 30),
              inkWellWidget(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: commonCachedNetworkImage(
                                appStore.userProfile.validate(),
                                height: 70,
                                width: 70,
                                fit: BoxFit.cover),
                          ),
                          if (isOther)
                            Container(
                              height: 70,
                              width: 70,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54),
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(language.lblYou, style: primaryTextStyle()),
                    ],
                  ),
                  onTap: () {
                    isOther = true;
                    setState(() {});
                  })
            ],
          ),
          SizedBox(height: 12),
          Text(language.lblWhoRidingMsg, style: secondaryTextStyle()),
          SizedBox(height: 8),
          AppButtonWidget(
            color: primaryColor,
            onTap: () async {
              if (!isOther) {
                if (nameController.text.isEmptyOrNull ||
                    phoneController.text.isEmptyOrNull) {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return StatefulBuilder(builder:
                          (BuildContext context, StateSetter setState) {
                        return AlertDialog(
                          contentPadding: EdgeInsets.all(0),
                          content: mSomeOnElse(),
                        );
                      });
                    },
                  ).then((value) {
                    setState(() {});
                  });
                } else {
                  isRideSelection = true;
                }
              } else {
                isRideSelection = true;
              }
              setState(() {});
            },
            text: language.lblNext,
            textStyle: boldTextStyle(color: Colors.white),
            width: MediaQuery.of(context).size.width,
          ),
        ],
      ),
    );
  }

  Widget serviceSelectWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(bottom: 8, top: 16),
            height: 5,
            width: 70,
            decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(defaultRadius)),
          ),
        ),
        Row(
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(16, 6, 16, 6),
              decoration: BoxDecoration(
                  border: Border.all(color: dividerColor),
                  borderRadius: BorderRadius.circular(defaultRadius)),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adicionales', style: secondaryTextStyle(size: 12)),
                  SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: EdgeInsets.all(0),
                          margin: EdgeInsets.all(2),
                          width: MediaQuery.of(context).size.width / 1.23,
                          height: MediaQuery.of(context).size.height / 7,
                          decoration: BoxDecoration(
                              color: Color.fromARGB(255, 255, 255, 255),
                              borderRadius:
                                  BorderRadius.circular(defaultRadius)),
                          child: ListView(
                            padding: EdgeInsets.all(0),
                            physics: ClampingScrollPhysics(),
                            children: listAdicionales.map((e) {
                              setState(() {});
                              return Container(
                                padding: EdgeInsets.all(0),
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height / 20,
                                child: Exercise(
                                    id: (e['id']).toString(),
                                    title: e['title'],
                                    cost: e['cost']),
                              );
                            }).toList(),
                          )),
                      SizedBox(width: 1),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(left: 8, right: 8),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: serviceList.map((e) {
                  return GestureDetector(
                    onTap: () {
                      if (e.discountAmount != 0) {
                        mSelectServiceAmount =
                            e.subtotal!.toStringAsFixed(fixedDecimal);
                      } else {
                        mSelectServiceAmount =
                            e.totalAmount!.toStringAsFixed(fixedDecimal);
                      }
                      selectedIndex = serviceList.indexOf(e);
                      servicesListData = e;
                      if (e.distanceUnit == 'km') {
                        locationDistance = e.dropoffDistanceInKm!.toDouble();
                        distanceUnit = 'KM';
                      } else {
                        locationDistance =
                            e.dropoffDistanceInKm!.toDouble() * 0.621371;
                        distanceUnit = 'Mile';
                      }
                      durationOfDrop = serviceList[0].duration!.toDouble();
                      paymentMethodType = e.paymentMethod!;
                      cashList = paymentMethodType == 'cash_wallet'
                          ? cashList = ['cash', 'wallet']
                          : cashList = [paymentMethodType];
                      setState(() {});
                    },
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      margin: EdgeInsets.only(top: 16, left: 8, right: 8),
                      decoration: BoxDecoration(
                        color: selectedIndex == serviceList.indexOf(e)
                            ? primaryColor
                            : Colors.white,
                        border: Border.all(color: dividerColor),
                        borderRadius: BorderRadius.circular(defaultRadius),
                      ),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Servicio ' + e.name.validate(),
                                  style: boldTextStyle(
                                      color: selectedIndex ==
                                              serviceList.indexOf(e)
                                          ? Colors.white
                                          : textPrimaryColorGlobal)),
                              SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(language.capacity,
                                      style: secondaryTextStyle(
                                          size: 12,
                                          color: selectedIndex ==
                                                  serviceList.indexOf(e)
                                              ? Colors.white
                                              : textPrimaryColorGlobal)),
                                  SizedBox(width: 4),
                                  Text(e.capacity.toString() + " + 1",
                                      style: secondaryTextStyle(
                                          color: selectedIndex ==
                                                  serviceList.indexOf(e)
                                              ? Colors.white
                                              : textPrimaryColorGlobal)),
                                ],
                              ),
                              SizedBox(height: 6),
                              inkWellWidget(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.only(
                                            topRight:
                                                Radius.circular(defaultRadius),
                                            topLeft: Radius.circular(
                                                defaultRadius))),
                                    builder: (_) {
                                      return CarDetailWidget(service: e);
                                    },
                                  );
                                },
                                child: Icon(Icons.info_outline_rounded,
                                    size: 16,
                                    color:
                                        selectedIndex == serviceList.indexOf(e)
                                            ? Colors.white
                                            : textPrimaryColorGlobal),
                              ),
                            ],
                          ),
                          SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            printDistanceUnit(locationDistance
                                                .toStringAsFixed(
                                                    digitAfterDecimal)),
                                            style: TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.white),
                                          ),
                                          SizedBox(
                                            width: 9,
                                          ),
                                          Text(
                                            printAmount(e.totalAmount!
                                                .toStringAsFixed(
                                                    digitAfterDecimal)),
                                            style: e.discountAmount != 0
                                                ? secondaryTextStyle(
                                                    color: selectedIndex ==
                                                            serviceList
                                                                .indexOf(e)
                                                        ? Colors.white
                                                        : textSecondaryColorGlobal,
                                                    textDecoration:
                                                        e.discountAmount != 0
                                                            ? TextDecoration
                                                                .lineThrough
                                                            : null,
                                                  )
                                                : secondaryTextStyle(
                                                    color: selectedIndex ==
                                                            serviceList
                                                                .indexOf(e)
                                                        ? Colors.white
                                                        : textPrimaryColorGlobal,
                                                  ),
                                          ),
                                          if (e.discountAmount != 0)
                                            Text(
                                              printAmount(e.subtotal!
                                                  .toStringAsFixed(
                                                      digitAfterDecimal)),
                                              style: secondaryTextStyle(
                                                  color: selectedIndex ==
                                                          serviceList.indexOf(e)
                                                      ? Colors.white
                                                      : primaryColor),
                                            ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        'Adicionales: \$' +
                                            sumaDeAdicionales.toString(),
                                        style: e.discountAmount != 0
                                            ? secondaryTextStyle(
                                                color: selectedIndex ==
                                                        serviceList.indexOf(e)
                                                    ? Colors.white
                                                    : textSecondaryColorGlobal,
                                                textDecoration:
                                                    e.discountAmount != 0
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                              )
                                            : secondaryTextStyle(
                                                color: selectedIndex ==
                                                        serviceList.indexOf(e)
                                                    ? Colors.white
                                                    : textPrimaryColorGlobal,
                                              ),
                                      ),
                                      SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        'Total Estimado: ' +
                                            printAmount((e.totalAmount! +
                                                    sumaDeAdicionales)
                                                .toStringAsFixed(
                                                    digitAfterDecimal)),
                                        style: e.discountAmount != 0
                                            ? secondaryTextStyle(
                                                color: selectedIndex ==
                                                        serviceList.indexOf(e)
                                                    ? Colors.white
                                                    : textSecondaryColorGlobal,
                                                textDecoration:
                                                    e.discountAmount != 0
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                              )
                                            : secondaryTextStyle(
                                                color: selectedIndex ==
                                                        serviceList.indexOf(e)
                                                    ? Colors.white
                                                    : textPrimaryColorGlobal,
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        inkWellWidget(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                  return Observer(builder: (context) {
                    return Stack(
                      children: [
                        AlertDialog(
                          contentPadding: EdgeInsets.all(16),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(language.paymentMethod,
                                        style: boldTextStyle()),
                                    inkWellWidget(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle),
                                        child: Icon(Icons.close,
                                            color: Colors.white),
                                      ),
                                    )
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(language.chooseYouPaymentLate,
                                    style: secondaryTextStyle()),
                                Text(isOther.toString(),
                                    style: secondaryTextStyle()),
                                isOther == false
                                    ? RadioListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        controlAffinity:
                                            ListTileControlAffinity.trailing,
                                        activeColor: primaryColor,
                                        value: 'cash',
                                        groupValue: 'cash',
                                        title: Text(language.cash,
                                            style: boldTextStyle()),
                                        onChanged: (String? val) {},
                                      )
                                    : Column(
                                        children: cashList.map((e) {
                                          return RadioListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity:
                                                ListTileControlAffinity
                                                    .trailing,
                                            activeColor: primaryColor,
                                            value: e,
                                            groupValue: paymentMethodType ==
                                                    'cash_wallet'
                                                ? 'cash'
                                                : paymentMethodType,
                                            title: Text(paymentStatus(e),
                                                style: boldTextStyle()),
                                            onChanged: (String? val) {
                                              paymentMethodType = val!;
                                              setState(() {});
                                            },
                                          );
                                        }).toList(),
                                      ),
                                SizedBox(height: 16),
                                AppTextField(
                                  controller: promoCode,
                                  autoFocus: false,
                                  textFieldType: TextFieldType.EMAIL,
                                  keyboardType: TextInputType.emailAddress,
                                  errorThisFieldRequired:
                                      language.thisFieldRequired,
                                  readOnly: true,
                                  onTap: () async {
                                    var data = await showModalBottomSheet(
                                      context: context,
                                      builder: (_) {
                                        return CouPonWidget();
                                      },
                                    );
                                    if (data != null) {
                                      promoCode.text = data;
                                    }
                                  },
                                  decoration: inputDecoration(context,
                                      label: language.enterPromoCode,
                                      suffixIcon: promoCode.text.isNotEmpty
                                          ? inkWellWidget(
                                              onTap: () {
                                                getNewService(coupon: false);
                                                promoCode.clear();
                                              },
                                              child: Icon(Icons.close,
                                                  color: Colors.black,
                                                  size: 25),
                                            )
                                          : null),
                                ),
                                SizedBox(height: 16),
                                AppButtonWidget(
                                  width: MediaQuery.of(context).size.width,
                                  text: language.confirm,
                                  textStyle: boldTextStyle(color: Colors.white),
                                  color: primaryColor,
                                  onTap: () {
                                    if (promoCode.text.isNotEmpty) {
                                      getCouponNewService();
                                      //getNewService(coupon: true);
                                    } else {
                                      // getNewService();
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Observer(builder: (context) {
                          return Visibility(
                              visible: appStore.isLoading,
                              child: loaderWidget());
                        }),
                      ],
                    );
                  });
                });
              },
            ).then((value) {
              setState(() {});
            });
          },
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
                border: Border.all(color: dividerColor),
                borderRadius: BorderRadius.circular(defaultRadius)),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(language.paymentVia, style: secondaryTextStyle(size: 12)),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(defaultRadius)),
                      child: Icon(Icons.wallet_outlined,
                          size: 20, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isOther == false
                                      ? language.cash
                                      : paymentMethodType == 'cash_wallet'
                                          ? language.cash
                                          : paymentStatus(paymentMethodType),
                                  style: boldTextStyle(size: 14),
                                ),
                              ),
                              if (mSelectServiceAmount != null &&
                                  paymentMethodType != 'cash_wallet' &&
                                  paymentMethodType == 'wallet' &&
                                  double.parse(mSelectServiceAmount!) >=
                                      mTotalAmount.toDouble())
                                inkWellWidget(
                                  onTap: () {
                                    launchScreen(context, WalletScreen())
                                        .then((value) {
                                      init();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        border: Border.all(color: dividerColor),
                                        color: primaryColor,
                                        borderRadius: radius()),
                                    child: Text(language.addMoney,
                                        style: primaryTextStyle(
                                            size: 14, color: Colors.white)),
                                  ),
                                )
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                              paymentMethodType != 'cash_wallet'
                                  ? language.forInstantPayment
                                  : language.lblPayWhenEnds,
                              style: secondaryTextStyle(size: 12)),
                          if (mSelectServiceAmount != null &&
                              paymentMethodType != 'cash_wallet' &&
                              paymentMethodType == 'wallet' &&
                              double.parse(mSelectServiceAmount!) >=
                                  mTotalAmount.toDouble())
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(language.lblLessWalletAmount,
                                  style: boldTextStyle(
                                      size: 12,
                                      color: Colors.red,
                                      letterSpacing: 0.5,
                                      weight: FontWeight.w500)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: AppButtonWidget(
            onTap: () {
              saveBookingData();
            },
            text: language.bookNow,
            textStyle: boldTextStyle(color: Colors.white),
            width: MediaQuery.of(context).size.width,
          ),
        ),
      ],
    );
  }
}

class Exercise extends StatefulWidget {
  final String title;
  final String id;
  final int cost;

  Exercise({required this.id, required this.title, required this.cost});
  @override
  _ExerciseState createState() => _ExerciseState();
}

int sumaDeAdicionales = 0;
List selectedAdditional = [];
List selectedAdditionalCosto = [];
List selectedAdditionalName = [];

void _refreshList() {
  selectedAdditional.clear();
  selectedAdditionalCosto.clear();
  selectedAdditionalName.clear();
}

class _ExerciseState extends State<Exercise> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var titulo = widget.title;
    var costo = widget.cost;
    return ListTile(
      title: Text(
        titulo + ' (Costo: \$' + costo.toString() + ')',
        style: TextStyle(fontSize: 12, color: Colors.black87),
      ),
      trailing: Checkbox(
          value: selected,
          onChanged: (val) {
            setState(() {
              selected = val!;
              if (selected == true) {
                selectedAdditional.add(widget.id);
                selectedAdditionalCosto.add(widget.cost);
                selectedAdditionalName.add(widget.title);
                sumaDeAdicionales = (sumaDeAdicionales + widget.cost);
              } else {
                selectedAdditional.remove(widget.id);
                selectedAdditionalCosto.remove(widget.cost);
                selectedAdditionalName.remove(widget.title);
                sumaDeAdicionales = (sumaDeAdicionales - widget.cost);
              }
            });
          }),
    );
  }
}
