import 'package:unity_kit/unity_kit.dart';

class SequenceController {
  final UnityBridge _bridge;

  SequenceController(this._bridge);

  void setSequence({
    required String sequenceName,
    required List<String> animations,
    bool reloadAfterApply = true,
  }) {
    _bridge.send(
      UnityMessage.to('SequenceFlutterBridge', 'SetSequence', {
        'sequenceName': sequenceName,
        'animations': animations,
        'reloadAfterApply': reloadAfterApply,
      }),
    );
  }

  void addAnimation(String animationName) {
    _bridge.send(
      UnityMessage.to('SequenceFlutterBridge', 'AddAnimation', {
        'animationName': animationName,
      }),
    );
  }

  void clearSequence() {
    _bridge.send(UnityMessage.to('SequenceFlutterBridge', 'ClearSequence', {}));
  }

  void reloadSequence() {
    _bridge.send(
      UnityMessage.to('SequenceFlutterBridge', 'ReloadSequence', {}),
    );
  }
}
