import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'images.dart';

//region App name
const mAppName = 'Remises Saenz Peña';

//region Google map key
const GOOGLE_MAP_API_KEY = 'AIzaSyALU--rsdhd4lwvHyolP0x1tg4Dqcj-PI8';

//region DomainUrl
///const DOMAIN_URL =
///    'https://remises.juanprogramador.com'; // Don't add slash at the end of the url
const DOMAIN_URL =
    'https://saenzpenaremis.online'; // Don't add slash at the end of the url

//region MQTT port and unique name
final client = MqttServerClient.withPort("broker.hivemq.com", "", 1883);
const MQTT_UNIQUE_TOPIC_NAME =
    'remisestaxi'; // Don't add underscore at the end of the url

//region OneSignal Keys
//You have to generate 2 onesignal account one for rider and one for driver
const mOneSignalAppIdDriver = '6a153467-4baf-477a-997f-d9f9b41be1b5';
const mOneSignalRestKeyDriver =
    'NzA3MmY4YjgtZGQ1OC00ZmUxLTg5YTItMDE2Mjk5MTRmMDlh';

const mOneSignalAppIdRider = '390de166-da72-4c13-8e65-def9cf13d2e1';
const mOneSignalRestKeyRider =
    'MjcyY2UyZWUtNmEzZi00NTEzLWJkZmMtZjcyMGVhMmFhODE2';

//region Currency & country code
const currencySymbol = '\$';
const currencyNameConst = 'ars';
const defaultCountryCode = '+54';
const defaultCountry = 'AR';
const digitAfterDecimal = 2;

//region top up default value
const PRESENT_TOP_UP_AMOUNT_CONST = '10|20|30';

//region PDF configuration
const PDF_NAME = 'Remises Saenz Peña';
const PDF_ADDRESS = 'Saenz Peña, Chaco, Argentina';
const PDF_CONTACT_NUMBER = '3644-423361	/ 3644-501040';

//region walkthrough text
const walkthrough_title_1 = 'Seleccione su viaje';
const walkthrough_subtitle_1 =
    'Solicite un viaje y sea atendido\npor el conductor más cercano';
const walkthrough_image_1 = ic_walk1;

const walkthrough_title_2 = 'Navegando tu viaje';
const walkthrough_subtitle_2 =
    "Viajes sin problemas, opciones inteligentes,\nviajes a toda la zona";
const walkthrough_image_2 = ic_walk2;

const walkthrough_title_3 = 'Rastrea tu viaje';
const walkthrough_subtitle_3 =
    "Conozca su servicio y podrá ver\nubicación actual en tiempo real en el mapa";
const walkthrough_image_3 = ic_walk3;

//region url
const mBaseUrl = "$DOMAIN_URL/api/";
const mMQTT_UNIQUE_TOPIC_NAME = MQTT_UNIQUE_TOPIC_NAME + '_';

//region userType
const ADMIN = 'admin';
const DRIVER = 'driver';
const RIDER = 'rider';

const PER_PAGE = 15;
const passwordLengthGlobal = 8;
const defaultRadius = 10.0;
const defaultSmallRadius = 6.0;

const textPrimarySizeGlobal = 16.00;
const textBoldSizeGlobal = 16.00;
const textSecondarySizeGlobal = 14.00;

double tabletBreakpointGlobal = 600.0;
double desktopBreakpointGlobal = 720.0;
double statisticsItemWidth = 230.0;
double defaultAppButtonElevation = 4.0;

bool enableAppButtonScaleAnimationGlobal = true;
int? appButtonScaleAnimationDurationGlobal;
ShapeBorder? defaultAppButtonShapeBorder;

var customDialogHeight = 140.0;
var customDialogWidth = 220.0;

enum ThemeModes { SystemDefault, Light, Dark }

//region loginType
const LoginTypeApp = 'app';
const LoginTypeGoogle = 'google';
const LoginTypeOTP = 'otp';
const LoginTypeApple = 'apple';

//region SharedReference keys
const REMEMBER_ME = 'REMEMBER_ME';
const IS_FIRST_TIME = 'IS_FIRST_TIME';
const IS_LOGGED_IN = 'IS_LOGGED_IN';
const LEFT = 'left';

const USER_ID = 'USER_ID';
const FIRST_NAME = 'FIRST_NAME';
const LAST_NAME = 'LAST_NAME';
const TOKEN = 'TOKEN';
const USER_EMAIL = 'USER_EMAIL';
const USER_TOKEN = 'USER_TOKEN';
const USER_PROFILE_PHOTO = 'USER_PROFILE_PHOTO';
const USER_TYPE = 'USER_TYPE';
const USER_NAME = 'USER_NAME';
const DNI = 'DNI';
const USER_PASSWORD = 'USER_PASSWORD';
const USER_ADDRESS = 'USER_ADDRESS';
const STATUS = 'STATUS';
const CONTACT_NUMBER = 'CONTACT_NUMBER';
const PLAYER_ID = 'PLAYER_ID';
const UID = 'UID';
const ADDRESS = 'ADDRESS';
const IS_OTP = 'IS_OTP';
const IS_GOOGLE = 'IS_GOOGLE';
const GENDER = 'GENDER';
const IS_TIME = 'IS_TIME';
const REMAINING_TIME = 'REMAINING_TIME';
const LOGIN_TYPE = 'login_type';
const COUNTRY = 'COUNTRY';
const LATITUDE = 'LATITUDE';
const LONGITUDE = 'LONGITUDE';

//region Taxi Status
const ACTIVE = 'active';
const IN_ACTIVE = 'inactive';
const PENDING = 'pending';
const BANNED = 'banned';
const REJECT = 'reject';

//region Wallet keys
const CREDIT = 'credit';
const DEBIT = 'debit';
const OTHERS = 'Others';

//region paymentType
const PAYMENT_TYPE_STRIPE = 'stripe';
const PAYMENT_TYPE_RAZORPAY = 'razorpay';
const PAYMENT_TYPE_PAYSTACK = 'paystack';
const PAYMENT_TYPE_FLUTTERWAVE = 'flutterwave';
const PAYMENT_TYPE_PAYPAL = 'paypal';
const PAYMENT_TYPE_PAYTABS = 'paytabs';
const PAYMENT_TYPE_MERCADOPAGO = 'mercadopago';
const PAYMENT_TYPE_PAYTM = 'paytm';
const PAYMENT_TYPE_MYFATOORAH = 'myfatoorah';

const stripeURL = 'https://api.stripe.com/v1/payment_intents';

var errorThisFieldRequired = 'Este campo es obligatorio';

//region Ride Status
const UPCOMING = 'upcoming';
const NEW_RIDE_REQUESTED = 'new_ride_requested';
const ACCEPTED = 'accepted';
const ARRIVING = 'arriving';
const ARRIVED = 'arrived';
const IN_PROGRESS = 'in_progress';
const CANCELED = 'canceled';
const COMPLETED = 'completed';
const SUCCESS = 'payment_status_message';
const AUTO = 'auto';
const COMPLAIN_COMMENT = "complaintcomment";

///fix Decimal
const fixedDecimal = digitAfterDecimal;

//region
const CHARGE_TYPE_FIXED = 'fixed';
const CHARGE_TYPE_PERCENTAGE = 'percentage';
const CASH_WALLET = 'cash_wallet';
const CASH = 'cash';
const MALE = 'male';
const FEMALE = 'female';
const OTHER = 'other';
const Wallet = 'wallet';

//region app setting key
const CLOCK = 'clock';
const PRESENT_TOPUP_AMOUNT = 'preset_topup_amount';
const PRESENT_TIP_AMOUNT = 'preset_tip_amount';
const RIDE_FOR_OTHER = 'RIDE_FOR_OTHER';
const MAX_TIME_FOR_RIDER_MINUTE =
    'max_time_for_find_drivers_for_regular_ride_in_minute';
const MAX_TIME_FOR_DRIVER_SECOND =
    'ride_accept_decline_duration_for_driver_in_second';
const MIN_AMOUNT_TO_ADD = 'min_amount_to_add';
const MAX_AMOUNT_TO_ADD = 'max_amount_to_add';

//region FireBase Collection Name
const MESSAGES_COLLECTION = "messages";
const USER_COLLECTION = "users";
const CONTACT_COLLECTION = "contact";
const CHAT_DATA_IMAGES = "chatImages";

const IS_ENTER_KEY = "IS_ENTER_KEY";
const SELECTED_WALLPAPER = "SELECTED_WALLPAPER";
const PER_PAGE_CHAT_COUNT = 50;

const TEXT = "TEXT";
const IMAGE = "IMAGE";

const VIDEO = "VIDEO";
const AUDIO = "AUDIO";

const FIXED_CHARGES = "fixed_charges";
const MIN_DISTANCE = "min_distance";
const MIN_WEIGHT = "min_weight";
const PER_DISTANCE_CHARGE = "per_distance_charges";
const PER_WEIGHT_CHARGE = "per_weight_charges";
const PAID = 'paid';

const PAYMENT_PENDING = 'pending';
const PAYMENT_FAILED = 'failed';
const PAYMENT_PAID = 'paid';
const SELECTED_LANGUAGE_CODE = 'selected_language_code';
const THEME_MODE_INDEX = 'theme_mode_index';
const CHANGE_LANGUAGE = 'CHANGE_LANGUAGE';
const CHANGE_MONEY = 'CHANGE_MONEY';

//chat
List<String> rtlLanguage = ['ar', 'ur'];

enum MessageType { TEXT, IMAGE, VIDEO, AUDIO }

extension MessageExtension on MessageType {
  String? get name {
    switch (this) {
      case MessageType.TEXT:
        return 'TEXT';
      case MessageType.IMAGE:
        return 'IMAGE';
      case MessageType.VIDEO:
        return 'VIDEO';
      case MessageType.AUDIO:
        return 'AUDIO';
      default:
        return null;
    }
  }
}

var errorSomethingWentWrong = 'Algo salió mal';

var demoEmail = 'joy58@gmail.com';
const mRazorDescription = 'Remises Saenz Peña';
const mStripeIdentifier = 'AR';
