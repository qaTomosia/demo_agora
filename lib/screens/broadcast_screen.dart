import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../utils/utils.dart';

// import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
// import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;

class BroadcastScreen extends StatefulWidget {
  final String channelName;
  final RoomRole role;

  const BroadcastScreen({
    Key? key,
    required this.channelName,
    required this.role,
  }) : super(key: key);

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _users = <int>[];
  late final RtcEngine _engine;
  bool muted = false;
  int? streamId;
  bool _localUserJoined = false;

  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initializeAgora();
  }

  @override
  void dispose() {
    // clear users
    _disposeEngine();
    super.dispose();
  }

  Future<void> initializeAgora() async {
    // init agora
    await _initAgoraRtcEngine();

    // register event
    _registerEventHandler();
    // set user type
    await _setUserType();
    // enable video
    await _enableVideo();
    // if (widget.isBroadcaster) {
    //   streamId = await _engine.createDataStream(const DataStreamConfig());
    // } else {
    //   streamId = -1;
    // }

    await joinChannel();
  }

  Future<void> joinChannel() async {
    late ChannelMediaOptions options;

    if (widget.role != RoomRole.viewer) {
      options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
    } else {
      options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
    }

    await _engine.joinChannel(
        token: AppId.appToken,
        channelId: widget.channelName,
        uid: 0,
        options: options);

    if (widget.role != RoomRole.viewer) {
      await _engine.startPreview();
    }
  }

  Future<void> _initAgoraRtcEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: AppId.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.role.toString()),
      ),
      body: Center(
        child: Stack(
          children: <Widget>[
            _broadcastView(),
            _toolbar(),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return widget.role != RoomRole.viewer
        ? Container(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RawMaterialButton(
                  onPressed: _onToggleMute,
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: muted ? Colors.blueAccent : Colors.white,
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: muted ? Colors.white : Colors.blueAccent,
                    size: 20.0,
                  ),
                ),
                RawMaterialButton(
                  onPressed: () => _onCallEnd(context),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Colors.redAccent,
                  padding: const EdgeInsets.all(15.0),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 35.0,
                  ),
                ),
                RawMaterialButton(
                  onPressed: _onSwitchCamera,
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Colors.white,
                  padding: const EdgeInsets.all(12.0),
                  child: const Icon(
                    Icons.switch_camera,
                    color: Colors.blueAccent,
                    size: 20.0,
                  ),
                ),
              ],
            ),
          )
        : Container();
  }

  /// Helper function to get list of native views
  List<Widget> _getRenderViews() {
    final List<Widget> list = [];
    switch (widget.role) {
      case RoomRole.host:
        list.add(
          _localUserJoined
              ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
              : const CircularProgressIndicator(),
        );
        for (var uid in _users) {
          list.add(AgoraVideoView(
              controller: VideoViewController(
                  rtcEngine: _engine, canvas: VideoCanvas(uid: uid))));
        }
        return list;
      case RoomRole.streamer:
        list.add(
          _localUserJoined
              ? AgoraVideoView(
                  controller: VideoViewController(
                      rtcEngine: _engine, canvas: const VideoCanvas(uid: 0)),
                )
              : const CircularProgressIndicator(),
        );
       list.add(
          _localUserJoined
              ? AgoraVideoView(
                  controller: VideoViewController(
                      rtcEngine: _engine, canvas: const VideoCanvas(uid: 0)),
                )
              : const CircularProgressIndicator(),
        );
        return list;

      case RoomRole.viewer:
        for (var uid in _users) {
          print(">>>>>> uid is $uid");
          list.add(AgoraVideoView(
              controller: VideoViewController(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: uid),
          )));
        }
        return list;
    }
  }

  /// Video view row wrapper
  Widget _expandedVideoView(List<Widget> views) {
    final wrappedViews = views
        .map<Widget>((view) => Expanded(child: Container(child: view)))
        .toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  /// Video layout wrapper
  Widget _broadcastView() {
    final views = _getRenderViews();
    switch (views.length) {
      case 1:
        return Column(
          children: <Widget>[
            _expandedVideoView([views[0]])
          ],
        );
      case 2:
        return Column(
          children: <Widget>[
            _expandedVideoView([views[0]]),
            _expandedVideoView([views[1]])
          ],
        );
      case 3:
        return Column(
          children: <Widget>[
            _expandedVideoView(views.sublist(0, 2)),
            _expandedVideoView(views.sublist(2, 3))
          ],
        );
      case 4:
        return Column(
          children: <Widget>[
            _expandedVideoView(views.sublist(0, 2)),
            _expandedVideoView(views.sublist(2, 4))
          ],
        );
      default:
    }
    return Container();
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  void _onSwitchCamera() {
    //if (streamId != null) _engine.sendStreamMessage(streamId, "mute user blet");
    _engine.switchCamera();
  }

  _disposeEngine() async {
    await _engine.leaveChannel();
    await _engine.stopPreview();
    await _engine.release();
  }

  _enableVideo() async {
    await _engine.enableVideo();
  }

  void _registerEventHandler() {
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (conn, time) {
        setState(() {
          streamId = conn.localUid;
          _localUserJoined = true;
        });

        print('>>>> $streamId');
      },
      onLeaveChannel: (conn, stats) {
        setState(() {
          debugPrint('onLeaveChannel');
          _users.clear();
        });
      },
      onUserJoined: (RtcConnection conn, int uid, int elapsed) {
        setState(() {
          _users.add(uid);
        });
      },
      onUserOffline: (conn, uid, elapsed) {
        setState(() {
          debugPrint('userOffline: $uid');
          _users.remove(uid);
        });
      },
      onStreamMessage: (conn, _, __, message, ___, ____) {
        String msgDecode = String.fromCharCodes(message);
        final String info = "here is the message $msgDecode";
        debugPrint(info);
      },
      onStreamMessageError: (conn, _, __, error, ___, ____) {
        final String info = "here is the error ${error.value()}";
        debugPrint(info);
      },
    ));
  }

  _setUserType() async {
    await _engine.setClientRole(
      role: ClientRoleType.clientRoleBroadcaster,
    );
  }

  Widget _remoteStreamView() {
    return Align(
        alignment: Alignment.topRight,
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            return SizedBox(
              height: 300,
              width: 300,
              child: AgoraVideoView(
                  controller: VideoViewController.remote(
                      connection: const RtcConnection(channelId: "demo"),
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _users[index]))),
            );
          },
        ));
  }
}
