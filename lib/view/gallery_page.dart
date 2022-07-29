import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_gallery/main.dart';
import 'package:photo_gallery/widget/custom_video_player.dart';
import 'package:video_player/video_player.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({Key? key}) : super(key: key);

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> with WidgetsBindingObserver {
  CameraController? controller;
  FlashMode? _currentFlashMode;
  bool _isCameraInitialized = false;
  bool _isVideoCameraSelected = false;
  bool _isRecordingInProgress = false;
  bool isAddChoosen = false;
  bool _isRearCameraSelected = true;
  //bool _isLoading = false;

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;

  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;

  File? _videoFile;
  File? _imageFile;

  List<File> allFileList = [];
  List<Map<bool, File>> imageAndVideoFileList = [];

  VideoPlayerController? videoController;

  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  List<Map<int, dynamic>> fileNames = [];


  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;
    if (controller != null) _currentFlashMode = controller!.value.flashMode;
    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Dispose the previous controller
    await previousCameraController?.dispose();

    // Replace with the new controller

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize controller
    try {
      await cameraController.initialize();
      cameraController
          .getMaxZoomLevel()
          .then((value) => _maxAvailableZoom = value);

      cameraController
          .getMinZoomLevel()
          .then((value) => _minAvailableZoom = value);

      cameraController
          .getMinExposureOffset()
          .then((value) => _minAvailableExposureOffset = value);

      cameraController
          .getMaxExposureOffset()
          .then((value) => _maxAvailableExposureOffset = value);
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    refreshAlreadyCapturedImages();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.0,
        centerTitle: true,
        title: Text(!isAddChoosen ? 'Gallery' : 'Camera'),
        actions: [
          isAddChoosen
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _clearButton(),
                )
              : const SizedBox.shrink()
        ],
      ),
      body: SizedBox(
        height: size.height,
        width: size.width,
        child: Stack(
          children: [
            _isCameraInitialized
                ? SizedBox(
                    height: size.height,
                    width: size.width,
                    child: _isCameraInitialized
                        ? controller!.buildPreview()
                        : Container())
                : allFileList.isNotEmpty
                    ? gridViewBuild()
                    : Container(),
            //Container(),
            // aspectRatio: 1 / controller!.value.aspectRatio,
            isAddChoosen
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: size.height * 0.3, top: size.height * 0.1),
                      child: exposureSlider(),
                    ),
                  )
                : const SizedBox.shrink(),
            isAddChoosen
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: bottomCameraStuff(size))
                : const SizedBox.shrink(),
            isAddChoosen
                ? Align(
                    alignment: Alignment.topRight,
                    child: qualityDropDownButton(),
                  )
                : const SizedBox.shrink(),
            !isAddChoosen
                ? Align(alignment: Alignment.bottomCenter, child: _addButton())
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Column bottomCameraStuff(Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        zoomAndTake(size),
        bottomPart(size),
      ],
    );
  }

  Column zoomAndTake(Size size) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
          child: zoomSlider(),
        ),
        takePictureRow(size)
      ],
    );
  }

  Row flashMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () async {
            setState(() {
              _currentFlashMode = FlashMode.off;
            });
            await controller!.setFlashMode(
              FlashMode.off,
            );
          },
          child: Icon(
            Icons.flash_off,
            color: _currentFlashMode == FlashMode.off
                ? Colors.amber
                : Colors.white,
          ),
        ),
        InkWell(
          onTap: () async {
            setState(() {
              _currentFlashMode = FlashMode.auto;
            });
            await controller!.setFlashMode(
              FlashMode.auto,
            );
          },
          child: Icon(
            Icons.flash_auto,
            color: _currentFlashMode == FlashMode.auto
                ? Colors.amber
                : Colors.white,
          ),
        ),
        InkWell(
          onTap: () async {
            // setState(() {
            //   _isCameraInitialized = false;
            // });
            // onNewCameraSelected(
            //   cameras[_isRearCameraSelected ? 1 : 0],
            // );
            // setState(() {
            //   _isRearCameraSelected = !_isRearCameraSelected;
            // });
          },
          child: Icon(
            Icons.flash_on,
            color: _currentFlashMode == FlashMode.always
                ? Colors.amber
                : Colors.white,
          ),
        ),
        InkWell(
          onTap: () async {
            setState(() {
              _currentFlashMode = FlashMode.torch;
            });
            await controller!.setFlashMode(
              FlashMode.torch,
            );
          },
          child: Icon(
            Icons.highlight,
            color: _currentFlashMode == FlashMode.torch
                ? Colors.amber
                : Colors.white,
          ),
        ),
      ],
    );
  }

  InkWell flipCameraButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _isCameraInitialized = false;
        });
        onNewCameraSelected(
          cameras[_isRearCameraSelected ? 0 : 1],
        );
        setState(() {
          _isRearCameraSelected = !_isRearCameraSelected;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.circle,
            color: Colors.black38,
            size: 60,
          ),
          Icon(
            _isRearCameraSelected ? Icons.camera_front : Icons.camera_rear,
            color: Colors.white,
            size: 30,
          ),
        ],
      ),
    );
  }

  SizedBox takePictureRow(Size size) {
    return SizedBox(
        height: size.height * 0.13,
        width: size.width,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              flipCameraButton(),
              _isVideoCameraSelected ? startStopRecordButton() : cameraButton(),
              cameraPreviewBox()
            ],
          ),
        ));
  }

  InkWell cameraButton() {
    return InkWell(
      onTap: () async {
        XFile? rawImage = await takePicture(controller);
        File imageFile = File(rawImage!.path);

        int currentUnix = DateTime.now().millisecondsSinceEpoch;
        final directory = await getApplicationDocumentsDirectory();
        String fileFormat = imageFile.path.split('.').last;

        _imageFile = await imageFile.copy(
          '${directory.path}/$currentUnix.$fileFormat',
        );
        //_videoFile = null;
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Icon(Icons.circle, color: Colors.white38, size: 80),
          Icon(Icons.circle, color: Colors.white, size: 65),
        ],
      ),
    );
  }

  Container bottomPart(Size size) {
    return Container(
      // height: size.height * 0.13,
      // width: size.width,
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            whichModeRow(),
            SizedBox(height: size.height * 0.018),
            flashMenu()
          ],
        ),
      ),
    );
  }

  Row whichModeRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 8.0,
              right: 4.0,
            ),
            child: TextButton(
              onPressed: _isRecordingInProgress
                  ? null
                  : () {
                      if (_isVideoCameraSelected) {
                        setState(() {
                          _isVideoCameraSelected = false;
                        });
                      }
                    },
              style: TextButton.styleFrom(
                primary: _isVideoCameraSelected ? Colors.black54 : Colors.black,
                backgroundColor:
                    _isVideoCameraSelected ? Colors.white30 : Colors.white,
              ),
              child: const Text('IMAGE'),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 8.0),
            child: TextButton(
              onPressed: () {
                if (!_isVideoCameraSelected) {
                  setState(() {
                    _isVideoCameraSelected = true;
                  });
                }
              },
              style: TextButton.styleFrom(
                primary: _isVideoCameraSelected ? Colors.black : Colors.black54,
                backgroundColor:
                    _isVideoCameraSelected ? Colors.white : Colors.white30,
              ),
              child: Text('VIDEO'),
            ),
          ),
        ),
      ],
    );
  }

  DropdownButton<ResolutionPreset> qualityDropDownButton() {
    return DropdownButton<ResolutionPreset>(
      dropdownColor: Colors.black87,
      underline: Container(),
      value: currentResolutionPreset,
      items: [
        for (ResolutionPreset preset in resolutionPresets)
          DropdownMenuItem(
            child: Text(
              preset.toString().split('.')[1].toUpperCase(),
              style: TextStyle(color: Colors.white),
            ),
            value: preset,
          )
      ],
      onChanged: (value) {
        setState(() {
          currentResolutionPreset = value!;
          _isCameraInitialized = false;
        });
        onNewCameraSelected(controller!.description);
      },
      hint: const Text("Select item"),
    );
  }

  IconButton _clearButton() {
    return IconButton(
        onPressed: () {
          setState(() {
            isAddChoosen = false;
            _isCameraInitialized = false;
            refreshAlreadyCapturedImages();
          });
        },
        icon: const Icon(
          Icons.clear,
          color: Colors.white,
        ));
  }

  ElevatedButton _addButton() {
    return ElevatedButton(
      child: Icon(Icons.add),
      onPressed: () {
        print('false: $isAddChoosen');
        onNewCameraSelected(cameras[0]);
        setState(() {
          isAddChoosen = true;
        });
        print('true: $isAddChoosen');
      },
      style: _elevatedButtonStyle(),
    );
  }

  ButtonStyle _elevatedButtonStyle() {
    return ElevatedButton.styleFrom(
        primary: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(80),
        ));
  }

  Column exposureSlider() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _currentExposureOffset.toStringAsFixed(1) + 'x',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Container(
              height: 30,
              child: Slider(
                value: _currentExposureOffset,
                min: _minAvailableExposureOffset,
                max: _maxAvailableExposureOffset,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged: (value) async {
                  setState(() {
                    _currentExposureOffset = value;
                  });
                  await controller!.setExposureOffset(value);
                },
              ),
            ),
          ),
        )
      ],
    );
  }

  Row zoomSlider() {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _currentZoomLevel,
            min: _minAvailableZoom,
            max: _maxAvailableZoom,
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: (value) async {
              setState(() {
                _currentZoomLevel = value;
              });
              await controller!.setZoomLevel(value);
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _currentZoomLevel.toStringAsFixed(1) + 'x',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;
    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }
    try {
      await cameraController!.startVideoRecording();
      setState(() {
        _isRecordingInProgress = true;
        print(_isRecordingInProgress);
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }
    try {
      XFile file = await controller!.stopVideoRecording();
      setState(() {
        _isRecordingInProgress = false;
        print(_isRecordingInProgress);
      });
      return file;
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
      return null;
    }
  }

  InkWell startStopRecordButton() {
    return InkWell(
      onTap: _isVideoCameraSelected
          ? () async {
              if (_isRecordingInProgress) {
                XFile? rawVideo = await stopVideoRecording();
                File videoFile = File(rawVideo!.path);

                int currentUnix = DateTime.now().millisecondsSinceEpoch;

                final directory = await getApplicationDocumentsDirectory();
                String fileFormat = videoFile.path.split('.').last;

                _videoFile = await videoFile.copy(
                  '${directory.path}/$currentUnix.$fileFormat',
                );

                _startVideoPlayer();
              } else {
                await startVideoRecording();
              }
            }
          : () async {
              // code to handle image clicking
            },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.circle,
            color: _isVideoCameraSelected ? Colors.white : Colors.white38,
            size: 80,
          ),
          Icon(
            Icons.circle,
            color: _isVideoCameraSelected ? Colors.red : Colors.white,
            size: 65,
          ),
          _isVideoCameraSelected && _isRecordingInProgress
              ? const Icon(
                  Icons.stop_rounded,
                  color: Colors.white,
                  size: 32,
                )
              : Container(),
        ],
      ),
    );
  }

  Container cameraPreviewBox() {
    return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: Colors.white, width: 2),
          image: _imageFile != null
              //_isLastOneImage &&
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: videoController != null && videoController!.value.isInitialized
            //&&
            //!_isLastOneImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: AspectRatio(
                  aspectRatio: videoController!.value.aspectRatio,
                  child: VideoPlayer(videoController!),
                ),
              )
            : Container());
  }



  getVideoControlAndInitList() {
    List<Map<VideoPlayerController, Future<void>>> videoControlAndInit = [];
    for (var file in allFileList) {
      if (file.path.contains('.mp4')) {
        var _controller = VideoPlayerController.file(file)
          ..setLooping(true)
          ..play()
          ..setVolume(0);
        videoControlAndInit.add({_controller: _controller.initialize()});
      }
    }
    //print('controllerList : $controllerList');
    return videoControlAndInit;
  }

  List<Widget> gridWidgets() {
    List<Widget> _gridItems = [];
    //List<VideoPlayerController> videoControllers = getInitializeVideoPlayerFutureList();
    //List<Future<void>> _initializeVideoPlayerFutureList = [];
    List<Map<VideoPlayerController, Future<void>>> videoControlAndInit = getVideoControlAndInitList();
    int j = 0;
    for (int i = 0; i < allFileList.length; i++) {
      if (allFileList[i].path.contains('.jpg')) {
        _gridItems.add(Image.file(allFileList[i]));
      } else if (allFileList[i].path.contains('.mp4')) {
        _gridItems.add(CustomVideoPlayer(videoControlAndInit: {
          videoControlAndInit[j].keys.first: videoControlAndInit[j].values.first
        }));
        j++;
      }
    }
    return _gridItems;
  }

  GridView gridViewBuild() {
    return GridView(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
      children: gridWidgets(),
    );
  }

  refreshAlreadyCapturedImages() async {
    // setState(() {
    //   _isLoading = true;
    // });
    // Get the directory
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();

    List<Map<int, dynamic>> fileNames = [];

    // Searching for all the image and video files using
    // their default format, and storing them
    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    print('allFileList : $allFileList');

    // Retrieving the recent file
    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      // Checking whether it is an image or a video file
      if (recentFileName.contains('.mp4')) {
        _videoFile = File('${directory.path}/$recentFileName');
        _startVideoPlayer();
        // setState(() {
        //   _isLastOneImage = false;
        // });
      } else {
        _imageFile = File('${directory.path}/$recentFileName');
        // setState(() {
        //   _isLastOneImage = true;
        // });
      }

      setState(() {
        // _isLoading = false;
      });
      print(fileNames);
    }
  }

  Future<void> _startVideoPlayer() async {
    if (_videoFile != null) {
      videoController = VideoPlayerController.file(_videoFile!);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.setVolume(0);
      await videoController!.setLooping(true);
      await videoController!.play();
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }
    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      print('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }
    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      print('Error resuming video recording: $e');
    }
  }

  Future<XFile?> takePicture(CameraController? controller) async {
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }
}
