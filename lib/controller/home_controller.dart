import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart'; // Add this for storing the last URL.

class PlaybackController extends GetxController {
  late VideoPlayerController videoPlayerController;

  RxBool isPlaying = false.obs;
  RxInt currentTime = 0.obs;
  RxBool isInitialized = false.obs;
  RxBool isBuffering = false.obs;
  RxBool isLastDownloadedUrl = false.obs;
  final DatabaseReference videoRef =
      FirebaseDatabase.instance.ref('videoPlayback');
  final DatabaseReference videoUrlRef =
      FirebaseDatabase.instance.ref('videoUrl');

  Timer? _syncTimer;
  Timer? _debounceTimer;
  static const int SYNC_INTERVAL = 800;
  static const int DEBOUNCE_DURATION = 500;
  bool _isUpdatingState = false;
  static const int SYNC_THRESHOLD = 2;

  @override
  void onInit() {
    super.onInit();
    fetchVideoUrl().then((url) {
      downloadVideo(url);
    });
    // Set both devices to a paused state initially
    videoRef.set({
      'isPlaying': false,
      'currentTime': 0,
    }).then((_) {
      isPlaying.value = false;
    });
  }

  RxDouble progress = 0.0.obs;

  Future<void> downloadVideo(String url) async {
    RxString filePath = ''.obs;
    Dio dio = Dio();
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      filePath.value = '${directory.path}/downloaded_video.mp4';

      // Check if the URL is the same as the last downloaded URL.
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastDownloadedUrl = prefs.getString('lastDownloadedUrl');

      // If the URL is the same as the last one, use the cached video.
      if (lastDownloadedUrl != null && lastDownloadedUrl == url) {
        print('Loading video from cache');
        isLastDownloadedUrl.value = true;
        videoPlayerController = VideoPlayerController.file(File(filePath.value))
          ..initialize().then((_) {
            print('Video initialized successfully from local storage');
            isInitialized.value = true;
            videoPlayerController.addListener(_videoListener);
            videoPlayerController.seekTo(Duration(seconds: currentTime.value));
            setupFirebaseListener();
          }).catchError((error) {
            print('Error initializing video from local storage: $error');
          });
      } else {
        // If the URL is different or not found, download the video.
        print('Downloading new video');
        await dio.download(url, filePath.value,
            onReceiveProgress: (received, total) {
          if (total != -1) {
            progress.value = (received / total);
          }
        });

        // Save the new URL after downloading the video.
        await prefs.setString('lastDownloadedUrl', url);

        // Initialize the video from the downloaded file.
        videoPlayerController = VideoPlayerController.file(File(filePath.value))
          ..initialize().then((_) {
            print('Video initialized successfully after download');
            isInitialized.value = true;
            videoPlayerController.addListener(_videoListener);
            videoPlayerController.seekTo(Duration(seconds: currentTime.value));
            setupFirebaseListener();
          }).catchError((error) {
            print('Error initializing video after download: $error');
          });
      }
    } catch (e) {
      print('Error downloading video: $e');
    }
  }

  void setupFirebaseListener() {
    videoRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (data["isPlaying"] != null) {
          bool remotePlayingState = data["isPlaying"];
          if (remotePlayingState != isPlaying.value) {
            _handlePlayPause(remotePlayingState);
          }
        }
        if (data["currentTime"] != null) {
          final seconds = data["currentTime"] as int;
          if ((seconds - currentTime.value).abs() > SYNC_THRESHOLD) {
            currentTime.value = seconds;
            videoPlayerController.seekTo(Duration(seconds: seconds));
            print('Syncing to current time: $seconds');
          }
        }
      }
    });
  }

  void _videoListener() {
    if (videoPlayerController.value.isPlaying) {
      currentTime.value = videoPlayerController.value.position.inSeconds;
      updatePlaybackState(); // Update Firebase with the new time
    }
  }

  void _handlePlayPause(bool shouldPlay) async {
    if (_isUpdatingState) return;

    isPlaying.value = shouldPlay; // Update state immediately

    if (shouldPlay) {
      isBuffering.value = true;

      // Check if the devices are synced
      if ((videoPlayerController.value.position.inSeconds - currentTime.value)
              .abs() <=
          1) {
        await videoPlayerController.play();
        print('Playing video at synced time');
      } else {
        await syncToCurrentTime(
            currentTime.value); // Sync the time before playing
        await videoPlayerController.play();
        print('Video started after syncing');
      }

      isBuffering.value = false;
    } else {
      await videoPlayerController.pause();
      print('Video paused');
    }

    // Update Firebase immediately
    updatePlaybackState();
  }

  Future<void> syncToCurrentTime(int targetTime) async {
    videoPlayerController.seekTo(Duration(seconds: targetTime));
    print('Seeking video to $targetTime');

    // Wait until the player is at the correct time
    while ((videoPlayerController.value.position.inSeconds - targetTime).abs() >
        0) {
      await Future.delayed(
          const Duration(milliseconds: 300)); // Poll every 300 ms
      currentTime.value = videoPlayerController.value.position.inSeconds;
    }
  }

  void startSyncTimer() {
    stopSyncTimer();
    _syncTimer = Timer.periodic(Duration(milliseconds: SYNC_INTERVAL), (timer) {
      updatePlaybackState(); // Sync state at regular intervals
    });
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  void updatePlaybackState() {
    videoRef.set({
      'isPlaying': isPlaying.value,
      'currentTime': currentTime.value,
    }).then((_) {
      if (kDebugMode) {
        print(
            'Firebase updated: isPlaying=${isPlaying.value}, currentTime=${currentTime.value}');
      }
    }).catchError((error) {
      print('Error updating Firebase: $error');
    });
  }

  Future<String> fetchVideoUrl() async {
    DataSnapshot snapshot = await videoUrlRef.get();
    if (snapshot.exists) {
      return snapshot.value.toString();
    } else {
      throw Exception('No video URL found');
    }
  }

  void togglePlayPause() {
    isPlaying.value = !isPlaying.value;
    _handlePlayPause(isPlaying.value);
  }

  void skipForward(int seconds) {
    final newPosition =
        videoPlayerController.value.position + Duration(seconds: seconds);
    videoPlayerController.seekTo(newPosition);
    currentTime.value = newPosition.inSeconds;
    updatePlaybackState();
    print('Skipped forward by $seconds seconds');
  }

  @override
  void onClose() {
    videoPlayerController.removeListener(_videoListener);
    videoPlayerController.dispose();
    stopSyncTimer();
    _debounceTimer?.cancel();
    super.onClose();
  }
}
