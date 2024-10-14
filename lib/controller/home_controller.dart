import 'dart:async';
import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackController extends GetxController {
  late VideoPlayerController videoPlayerController;
  late ChewieController chewieController;
  late DatabaseReference videoUrlRef; // Database reference for video URL
  DatabaseReference titeRef = FirebaseDatabase.instance.ref().child('title');
  late DatabaseReference
      videoRef; // Database reference for video state (play, pause, time)
  late Timer syncTimer;

  RxBool isInitialized = false.obs;
  RxBool isPlaying = false.obs;
  RxBool isBuffering = false.obs;
  RxDouble progress = 0.0.obs;
  RxInt currentTime = 0.obs;
  RxBool isLastDownloadedUrl = false.obs;
  RxString title = ''.obs;

  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    fetchTitle();

    // Fetch video URL from Firebase Realtime Database
    videoUrlRef = FirebaseDatabase.instance.ref().child('videoUrl');
    videoRef = FirebaseDatabase.instance.ref().child('video');

    videoUrlRef.once().then((DatabaseEvent event) {
      if (event.snapshot.exists) {
        String videoUrl = event.snapshot.value as String;
        checkIfVideoExists(videoUrl); // Check if video is already downloaded
      }
    });

    // Initialize the videoRef for syncing play/pause and current time
    videoRef.set({
      'isPlaying': false,
      'currentTime': 0,
    }).then((_) {
      isPlaying.value = false;
    });
  }

  Future<void> fetchTitle() async {
    titeRef.once().then((DatabaseEvent event) {
      if (event.snapshot.exists) {
        title.value = event.snapshot.value as String;
      }
    });
  }

  // Check if the video file has already been downloaded using SharedPreferences
  Future<void> checkIfVideoExists(String videoUrl) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastDownloadedUrl = prefs.getString('lastDownloadedUrl');

    // If the video URL is the same, load from local storage
    if (lastDownloadedUrl == videoUrl) {
      final documentDirectory = await getApplicationDocumentsDirectory();
      final file = File('${documentDirectory.path}/video.mp4');

      if (await file.exists()) {
        isLastDownloadedUrl.value = true;
        videoPlayerController = VideoPlayerController.file(file);
        await videoPlayerController.initialize();
        initializeChewieController();
        isInitialized.value = true;
        videoPlayerController.addListener(_videoListener);
        videoPlayerController.seekTo(Duration(seconds: currentTime.value));
        setupFirebaseListener();
      } else {
        // If the file was deleted, download the video again
        downloadVideo(videoUrl);
      }
    } else {
      // New video URL, download the video
      downloadVideo(videoUrl);
    }
  }

  // Download the video file locally
  Future<void> downloadVideo(String videoUrl) async {
    isLastDownloadedUrl.value = false;
    final dio = Dio();
    final documentDirectory = await getApplicationDocumentsDirectory();
    final file = File('${documentDirectory.path}/video.mp4');

    await dio.download(videoUrl, file.path,
        onReceiveProgress: (received, total) {
      if (total != -1) {
        progress.value = received / total;
      }
    });

    isLastDownloadedUrl.value = true;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDownloadedUrl', videoUrl); // Save the video URL

    videoPlayerController = VideoPlayerController.file(file);
    videoPlayerController.initialize().then((_) {
      initializeChewieController(); // Initialize Chewie after the video player controller
      isInitialized.value = true;
      videoPlayerController.addListener(_videoListener);
      videoPlayerController.seekTo(Duration(seconds: currentTime.value));
      setupFirebaseListener();
    });

    videoPlayerController.setLooping(false);
    videoPlayerController.setVolume(1.0);
  }

  // Initialize Chewie controller for better video controls
  void initializeChewieController() {
    chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: false,
      looping: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blueAccent,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.lightGreen,
      ),
      placeholder: Container(
        color: Colors.grey,
      ),
      autoInitialize: true,
    );
  }

  // Setup Firebase listener for video synchronization
  void setupFirebaseListener() {
    videoRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        var data = event.snapshot.value as Map;
        bool shouldPlay = data['isPlaying'];
        int newTime = data['currentTime'];

        // Handle play/pause synchronization
        if (shouldPlay != isPlaying.value) {
          if (shouldPlay) {
            videoPlayerController.play();
          } else {
            videoPlayerController.pause();
          }
          isPlaying.value = shouldPlay;
        }

        // Handle time synchronization
        if ((newTime - currentTime.value).abs() > 1) {
          videoPlayerController.seekTo(Duration(seconds: newTime));
          currentTime.value = newTime;
        }
      }
    });
  }

  // Video listener to sync the state to Firebase
  void _videoListener() {
    if (!videoPlayerController.value.isBuffering) {
      isBuffering.value = false;
      currentTime.value = videoPlayerController.value.position.inSeconds;

      // Sync the current state to Firebase (debounced)
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer!.cancel();
      }
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        videoRef.update({
          'isPlaying': videoPlayerController.value.isPlaying,
          'currentTime': currentTime.value,
        });
      });
    } else {
      isBuffering.value = true;
    }
  }

  // Play or pause the video
  void togglePlayPause() {
    if (isPlaying.value) {
      videoPlayerController.pause();
      videoRef.update({
        'isPlaying': false,
      });
      isPlaying.value = false;
    } else {
      videoPlayerController.play();
      videoRef.update({
        'isPlaying': true,
      });
      isPlaying.value = true;
    }
  }

  // Skip forward or backward
  void skipForward(int seconds) {
    int newTime = currentTime.value + seconds;
    if (newTime < 0) {
      newTime = 0;
    } else if (newTime > videoPlayerController.value.duration.inSeconds) {
      newTime = videoPlayerController.value.duration.inSeconds;
    }
    videoPlayerController.seekTo(Duration(seconds: newTime));
    videoRef.update({
      'currentTime': newTime,
    });
    currentTime.value = newTime;
  }

  // Stop the synchronization timer
  void stopSyncTimer() {
    syncTimer.cancel();
  }

  @override
  void onClose() {
    chewieController.dispose();
    videoPlayerController.removeListener(_videoListener);
    videoPlayerController.dispose();
    stopSyncTimer();
    _debounceTimer?.cancel();
    super.onClose();
  }
}
