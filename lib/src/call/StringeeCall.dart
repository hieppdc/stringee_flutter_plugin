import 'dart:async';
import 'dart:io';
import '../StringeeClient.dart';
import '../StringeeConstants.dart';

class StringeeCall {
  String _id;
  String _from;
  String _to;
  String _fromAlias;
  String _toAlias;
  StringeeCallType _callType;
  String _customDataFromYourServer;
  bool _isVideoCall = false;
  StreamController<dynamic> _eventStreamController = StreamController();
  StreamSubscription<dynamic> _subscriber;

  String get id => _id;

  String get from => _from;

  String get to => _to;

  String get fromAlias => _fromAlias;

  String get toAlias => _toAlias;

  bool get isVideoCall => _isVideoCall;

  StringeeCallType get callType => _callType;

  String get customDataFromYourServer => _customDataFromYourServer;

  StreamController<dynamic> get eventStreamController => _eventStreamController;

  StringeeCall() {
    _subscriber = StringeeClient().eventStreamController.stream.listen(this._listener);
  }

  StringeeCall.fromCallInfo(Map<dynamic, dynamic> info) {
    this.initCallInfo(info);
    _subscriber = StringeeClient().eventStreamController.stream.listen(this._listener);
  }

  void initCallInfo(Map<dynamic, dynamic> callInfo) {
    if (callInfo == null) {
      return;
    }

    this._id = callInfo['callId'];
    this._from = callInfo['from'];
    this._to = callInfo['to'];
    this._fromAlias = callInfo['fromAlias'];
    this._toAlias = callInfo['toAlias'];
    this._isVideoCall = callInfo['isVideoCall'];
    this._customDataFromYourServer = callInfo['customDataFromYourServer'];
    this._callType = StringeeCallType.values[callInfo['callType']];
  }

  void _listener(dynamic event) {
    assert(event != null);
    final Map<dynamic, dynamic> map = event;
    if (map['typeEvent'] == StringeeType.StringeeCall.index) {
      switch (map['event']) {
        case 'didChangeSignalingState':
          handleSignalingStateChange(map['body']);
          break;
        case 'didChangeMediaState':
          handleMediaStateChange(map['body']);
          break;
        case 'didReceiveCallInfo':
          handleCallInfoDidReceive(map['body']);
          break;
        case 'didHandleOnAnotherDevice':
          handleAnotherDeviceHadHandle(map['body']);
          break;
        case 'didReceiveLocalStream':
          handleReceiveLocalStream(map['body']);
          break;
        case 'didReceiveRemoteStream':
          handleReceiveRemoteStream(map['body']);
          break;
        case 'didChangeAudioDevice':
          handleChangeAudioDevice(map['body']);
          break;
      }
    } else {
      eventStreamController.add(event);
    }
  }

  void handleSignalingStateChange(Map<dynamic, dynamic> map) {
    String callId = map['callId'];
    if (callId != this._id) return;

    StringeeSignalingState signalingState = StringeeSignalingState.values[map['code']];
    _eventStreamController.add({
      "typeEvent": StringeeCallEvents,
      "eventType": StringeeCallEvents.DidChangeSignalingState,
      "body": signalingState
    });
  }

  void handleMediaStateChange(Map<dynamic, dynamic> map) {
    String callId = map['callId'];
    if (callId != this._id) return;

    StringeeMediaState mediaState = StringeeMediaState.values[map['code']];
    _eventStreamController.add(
        {"typeEvent": StringeeCallEvents, "eventType": StringeeCallEvents.DidChangeMediaState, "body": mediaState});
  }

  void handleCallInfoDidReceive(Map<dynamic, dynamic> map) {
    String callId = map['callId'];
    if (callId != this._id) return;

    Map<dynamic, dynamic> data = map['info'];
    _eventStreamController
        .add({"typeEvent": StringeeCallEvents, "eventType": StringeeCallEvents.DidReceiveCallInfo, "body": data});
  }

  void handleAnotherDeviceHadHandle(Map<dynamic, dynamic> map) {
    StringeeSignalingState signalingState = StringeeSignalingState.values[map['code']];
    _eventStreamController.add({
      "typeEvent": StringeeCallEvents,
      "eventType": StringeeCallEvents.DidHandleOnAnotherDevice,
      "body": signalingState
    });
  }

  void handleReceiveLocalStream(Map<dynamic, dynamic> map) {
    _eventStreamController.add({
      "typeEvent": StringeeCallEvents,
      "eventType": StringeeCallEvents.DidReceiveLocalStream,
      "body": map['callId']
    });
  }

  void handleReceiveRemoteStream(Map<dynamic, dynamic> map) {
    _eventStreamController.add({
      "typeEvent": StringeeCallEvents,
      "eventType": StringeeCallEvents.DidReceiveRemoteStream,
      "body": map['callId']
    });
  }

  void handleChangeAudioDevice(Map<dynamic, dynamic> map) {
    AudioDevice selectedAudioDevice = AudioDevice.values[map['code']];
    List<dynamic> codeList = List();
    codeList.addAll(map['codeList']);
    List<AudioDevice> availableAudioDevices = List();
    for (int i = 0; i < codeList.length; i++) {
      AudioDevice audioDevice = AudioDevice.values[codeList[i]];
      availableAudioDevices.add(audioDevice);
    }
    _eventStreamController.add({
      "typeEvent": StringeeCallEvents,
      "eventType": StringeeCallEvents.DidChangeAudioDevice,
      "selectedAudioDevice": selectedAudioDevice,
      "availableAudioDevices": availableAudioDevices
    });
  }

  /// Make a new coll
  Future<Map<dynamic, dynamic>> makeCall(Map<dynamic, dynamic> parameters) async {
    final params = parameters;
    if (parameters.containsKey('isVideoCall')) {
      if (parameters['isVideoCall']) {
        switch (parameters['videoResolution']) {
          case VideoQuality.NORMAL:
            params['videoResolution'] = "NORMAL";
            break;
          case VideoQuality.HD:
            params['videoResolution'] = "HD";
            break;
          case VideoQuality.FULLHD:
            params['videoResolution'] = "FULLHD";
            break;
        }
      }
    }
    Map<dynamic, dynamic> results = await StringeeClient.methodChannel.invokeMethod('makeCall', params);
    Map<dynamic, dynamic> callInfo = results['callInfo'];

    print('callInfo' + callInfo.toString());

    this.initCallInfo(callInfo);

    final Map<String, dynamic> resultDatas = {
      'status': results['status'],
      'code': results['code'],
      'message': results['message']
    };

    return resultDatas;
  }

  /// Make a new coll with [MakeCallParams]
  Future<Map<dynamic, dynamic>> makeCallFromParams(MakeCallParams params) async {
    Map<dynamic, dynamic> parameters = {
      'from': params.from,
      'to': params.to,
      'isVideoCall': params.isVideoCall,
    };
    if (params.isVideoCall) {
      parameters['videoResolution'] = params.videoQuality;
    }
    if (params.customData != null) parameters['customData'] = params.customData;
    return await makeCall(parameters);
  }

  /// Init an answer from incoming call
  Future<Map<dynamic, dynamic>> initAnswer() async {
    return await StringeeClient.methodChannel.invokeMethod('initAnswer', this._id);
  }

  /// Answer a call
  Future<Map<dynamic, dynamic>> answer() async {
    return await StringeeClient.methodChannel.invokeMethod('answer', this._id);
  }

  /// Hang up a call
  Future<Map<dynamic, dynamic>> hangup() async {
    return await StringeeClient.methodChannel.invokeMethod('hangup', this._id);
  }

  /// Reject a call
  Future<Map<dynamic, dynamic>> reject() async {
    return await StringeeClient.methodChannel.invokeMethod('reject', this._id);
  }

  /// Send a [dtmf]
  Future<Map<dynamic, dynamic>> sendDtmf(String dtmf) async {
    final params = {
      'callId': this._id,
      'dtmf': dtmf,
    };
    return await StringeeClient.methodChannel.invokeMethod('sendDtmf', params);
  }

  /// Send a call info
  Future<Map<dynamic, dynamic>> sendCallInfo(Map<dynamic, dynamic> callInfo) async {
    final params = {
      'callId': this._id,
      'callInfo': callInfo,
    };
    return await StringeeClient.methodChannel.invokeMethod('sendCallInfo', params);
  }

  /// Get call stats
  Future<Map<dynamic, dynamic>> getCallStats() async {
    return await StringeeClient.methodChannel.invokeMethod('getCallStats', this._id);
  }

  /// Mute/Unmute
  Future<Map<dynamic, dynamic>> mute(bool mute) async {
    final params = {
      'callId': this._id,
      'mute': mute,
    };
    return await StringeeClient.methodChannel.invokeMethod('mute', params);
  }

  /// Enable/ Disable video
  Future<Map<dynamic, dynamic>> enableVideo(bool enableVideo) async {
    final params = {
      'callId': this._id,
      'enableVideo': enableVideo,
    };
    return await StringeeClient.methodChannel.invokeMethod('enableVideo', params);
  }

  /// Set speaker phone on/off
  Future<Map<dynamic, dynamic>> setSpeakerphoneOn(bool on) async {
    final params = {
      'callId': this._id,
      'speaker': on,
    };
    return await StringeeClient.methodChannel.invokeMethod('setSpeakerphoneOn', params);
  }

  /// Switch camera
  Future<Map<dynamic, dynamic>> switchCamera(bool isMirror) async {
    final params = {
      'callId': this._id,
      'isMirror': isMirror,
    };
    return await StringeeClient.methodChannel.invokeMethod('switchCamera', params);
  }

  /// Resume local video
  Future<Map<dynamic, dynamic>> resumeVideo() async {
    if (Platform.isIOS) {
      final params = {
        'status': false,
        "code": '-4',
        "message": "This function work only for Android",
      };
      return params;
    } else {
      final params = {
        'callId': this._id,
      };
      return await StringeeClient.methodChannel.invokeMethod('resumeVideo', params);
    }
  }

  /// close event stream
  void destroy() {
    if (_subscriber != null) {
      _subscriber.cancel();
      _eventStreamController.close();
    }
  }
}
