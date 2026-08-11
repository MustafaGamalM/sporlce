import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

class CallService {
  static final Uuid _uuid = Uuid();
  static String? _currentUuid;

  static String? get currentUuid => _currentUuid;

  static Future<void> showIncomingCall() async {
    final callUuid = _uuid.v4();
    _currentUuid = callUuid;

    final callKitParams = CallKitParams(
      id: callUuid,
      nameCaller: 'منبه المذاكرة',
      appName: 'Sporcle',
      handle: 'حان وقت المذاكرة',
      type: 0,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'فاتك تذكير مذاكرة',
        callbackText: 'افتح المذاكرة',
      ),
      callingNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'منبه المذاكرة شغال',
        callbackText: 'إيقاف',
      ),
      duration: 30000,
      extra: <String, dynamic>{'type': 'study_reminder'},
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isCustomSmallExNotification: true,
        isShowLogo: false,
        isShowCallID: true,
        isShowFullLockedScreen: true,
        isImportant: true,
        isFullScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#D93025',
        actionColor: '#D93025',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'تذكير المذاكرة',
        missedCallNotificationChannelName: 'تذكيرات فائتة',
        textAccept: 'ابدأ',
        textDecline: 'إيقاف',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }
}
