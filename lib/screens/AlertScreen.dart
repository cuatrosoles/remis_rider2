import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../utils/Extensions/app_common.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../model/ContactNumberListModel.dart';
import '../../network/RestApis.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

class AlertScreen extends StatefulWidget {
  final int? rideId;
  final int? regionId;

  AlertScreen({this.rideId, this.regionId});

  @override
  AlertScreenState createState() => AlertScreenState();
}

class AlertScreenState extends State<AlertScreen> {
  List<ContactModel> sosListData = [];
  LatLng? sourceLocation;
  bool enviarWhatsapp = false;
  bool sendNotification = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    getCurrentUserLocation();
    appStore.setLoading(true);
    _refreshList();
    await getSosList(regionId: widget.regionId).then((value) {
      sosListData.addAll(value.data!);
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  List selectedSOS = [];
  void _refreshList() {
    // Clear the current list
    selectedSOS.clear();
  }

  Future<void> shareWithAdmin(
      selectedSOS, enviarWhatsapp, ride_request_id, latitud, longitud) async {
    sendNotification = false;
    appStore.setLoading(true);
    Map req = {
      "ride_request_id": widget.rideId,
      "latitude": sourceLocation!.latitude,
      "longitude": sourceLocation!.longitude,
    };
    await adminNotify(request: req).then((value) {
      appStore.setLoading(false);
      sendNotification = true;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });

    if (enviarWhatsapp) {
      selectedSOS.forEach((phone) async {
        var thisPhone = phone
            .replaceAll("+54 9 ", "")
            .replaceAll("-", "")
            .replaceAll(" ", "");
        var newPhone = '549' + thisPhone;
        print('New Phone: ' + newPhone);
        await WhatsappShare.share(
          text:
              'Alerta! Voy en viaje con Remis Saenz Peña - Viaje #$ride_request_id\nEsta es mi ubicación actual:',
          linkUrl: 'https://www.google.com/maps/@$latitud,$longitud,15z',
          phone: newPhone,
        );
        ////Navigator.pop(context);
      });
    }
    ;
  }

  Future<void> getCurrentUserLocation() async {
    final geoPosition = await Geolocator.getLastKnownPosition();
    setState(() {
      sourceLocation = LatLng(geoPosition!.latitude, geoPosition.longitude);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  int selectedOption = 1;

  @override
  Widget build(BuildContext context) {
    var ride_request_id = widget.rideId;
    double latitud = sourceLocation?.latitude ?? 0.0;
    double longitud = sourceLocation?.longitude ?? 0.0;
    int? value = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Observer(builder: (context) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 50),
                    SizedBox(height: 8),
                    Text(language.useInCaseOfEmergency,
                        style: boldTextStyle(color: Colors.red)),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Column(
                                  children: [
                                    Text(language.notifyAdmin,
                                        style: boldTextStyle()),
                                    if (sendNotification) SizedBox(height: 4),
                                    if (sendNotification)
                                      Text(language.notifiedSuccessfully,
                                          style: secondaryTextStyle(
                                              color: Colors.green)),
                                  ],
                                ),
                                SizedBox(width: 32),
                                Icon(Icons.check_box_rounded,
                                    color: primaryColor),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    /*
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Column(
                                  children: [
                                    Text('Notificar por Whatsapp',
                                        textAlign: TextAlign.left,
                                        style: boldTextStyle()),
                                  ],
                                ),
                                SizedBox(width: 30),
                                Checkbox(
                                    value: enviarWhatsapp,
                                    onChanged: (val) {
                                      setState(() {
                                        enviarWhatsapp = val!;
                                        if (enviarWhatsapp == true) {
                                          enviarWhatsapp = true;
                                        } else {
                                          enviarWhatsapp = false;
                                        }
                                        print(
                                            'Estado WhatsappSOS: $enviarWhatsapp');
                                      });
                                    }),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                                'Se abrirá la aplicación para que envíes\nel mensaje a tus contactos.',
                                style: secondaryTextStyle(
                                    color: Colors.black87, size: 12)),
                          ],
                        ),
                      ],
                    ),
                    */

                    SizedBox(height: 14),

                    ///////////////////////

                    Container(
                      height: 150,
                      width: MediaQuery.of(context).size.width,
                      child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sosListData.length,
                          itemBuilder: (_, index) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(sosListData[index].title.validate(),
                                          style: boldTextStyle()),
                                      SizedBox(height: 4),
                                      Text(
                                          sosListData[index]
                                              .contactNumber
                                              .validate(),
                                          style: primaryTextStyle()),
                                    ],
                                  ),
                                  Radio<int>(
                                      activeColor: Colors.black,
                                      value: sosListData[index].id as int,
                                      groupValue: selectedOption,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedOption = value!;
                                          if (selectedOption ==
                                              sosListData[index].id) {
                                            selectedSOS.add(sosListData[index]
                                                .contactNumber);
                                            enviarWhatsapp = true;
                                          } else {
                                            selectedSOS.remove(
                                                sosListData[index]
                                                    .contactNumber);
                                          }
                                          print('SelectedOption: ' +
                                              selectedOption.toString());
                                        });
                                      })

                                  /*
                                  Checkbox(
                                      value: enviarWhatsapp,
                                      onChanged: (val) {
                                        setState(() {
                                          enviarWhatsapp = val!;
                                          if (enviarWhatsapp == true) {
                                            selectedSOS.add(sosListData[index]
                                                .contactNumber);
                                          } else {
                                            selectedSOS.remove(
                                                sosListData[index]
                                                    .contactNumber);
                                          }
                                          print(
                                              'SOS seleccionados: $selectedSOS');

                                          ///SOS seleccionados: [+54 9 2477 38-2564, 2477 31-0296]
                                        });
                                      }),
                                  */
                                  /*
                                  inkWellWidget(
                                    onTap: () {
                                      share(sosListData[index].contactNumber,
                                          ride_request_id, latitud, longitud);
                                      /////////////////////////
                                      /*
                                      launchUrl(
                                          Uri.parse(
                                              'tel:${sosListData[index].contactNumber}'),
                                          mode: LaunchMode.externalApplication);
                                      */
                                    },
                                    child: Icon(Icons.message_outlined),
                                  ),
                                  */
                                ],
                              ),
                            );
                          }),
                    ),

                    ////////////////
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            shareWithAdmin(selectedSOS, enviarWhatsapp,
                                ride_request_id, latitud, longitud);

                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Enviar SOS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: appStore.isLoading,
                child: IntrinsicHeight(
                  child: loaderWidget(),
                ),
              )
            ],
          );
        }),
      ],
    );
  }
}
