import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../controller/home_controller.dart';

class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaybackController playbackController = Get.put(PlaybackController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Together'),
      ),
      body: Column(
        children: [
          // progress bar
          Obx(() => LinearProgressIndicator(
                value: playbackController.progress.value,
              )),
          SizedBox(height: 20),
          Obx(
            () => playbackController.isLastDownloadedUrl.value
                ? const SizedBox()
                : Obx(
                    () => Text(
                        "Video is ${(playbackController.progress.value * 100).toInt()}% downloaded"),
                  ),
          ),
          SizedBox(height: 20),
          Obx(() {
            if (!playbackController.isBuffering.value) {
              return Obx(() {
                // Check if the video controller is initialized
                if (playbackController.isInitialized.value) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Video player
                      AspectRatio(
                        aspectRatio: playbackController
                            .videoPlayerController.value.aspectRatio,
                        child: VideoPlayer(
                            playbackController.videoPlayerController),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Obx(() => !playbackController.isPlaying.value
                              ? IconButton(
                                  icon: const Icon(Icons.replay_10),
                                  onPressed: () =>
                                      playbackController.skipForward(-10),
                                )
                              : const SizedBox()),
                          // Play/Pause button wrapped in Obx to reflect isPlaying state
                          Obx(() => IconButton(
                                icon: Icon(playbackController.isPlaying.value
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                onPressed: () =>
                                    playbackController.togglePlayPause(),
                              )),
                          Obx(() => !playbackController.isPlaying.value
                              ? IconButton(
                                  icon: const Icon(Icons.forward_10),
                                  onPressed: () =>
                                      playbackController.skipForward(10),
                                )
                              : const SizedBox()),
                        ],
                      ),
                      // Display the current time of the video
                      Obx(() => Text(
                            'Current Time: ${playbackController.currentTime.value}s',
                            style: const TextStyle(fontSize: 18),
                          )),
                    ],
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              });
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          }),
        ],
      ),
    );
  }
}
