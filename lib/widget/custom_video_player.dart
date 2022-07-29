import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CustomVideoPlayer extends StatefulWidget {
  CustomVideoPlayer({Key? key, required this.videoControlAndInit}) : super(key: key);

  
  // VideoPlayerController videoPlayerController;
  // late Future<void> initializeVideoPlayerFuture;

  Map<VideoPlayerController,Future<void>> videoControlAndInit;

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = widget.videoControlAndInit.keys.first;
    _initializeVideoPlayerFuture = widget.videoControlAndInit.values.first;
    //_initializeVideoPlayerFuture = widget.initializeVideoPlayerFuture;
    // _controller = widget.videoPlayerController
    //   ..setLooping(true)
    //   ..play()
    //   ..setVolume(0);
    // _initializeVideoPlayerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    //_controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller));
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
