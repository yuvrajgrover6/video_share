import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../controller/home_controller.dart';
import 'package:chewie/chewie.dart';

class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaybackController playbackController = Get.put(PlaybackController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(playbackController.title.value)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Progress bar
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
                        // Chewie video player
                        Container(
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width,
                              maxHeight: 300),
                          child: AspectRatio(
                            aspectRatio: playbackController
                                .videoPlayerController.value.aspectRatio,
                            child: Chewie(
                                controller:
                                    playbackController.chewieController),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.center,
                        //   children: [
                        //     Obx(() => !playbackController.isPlaying.value
                        //         ? IconButton(
                        //             icon: const Icon(Icons.replay_10),
                        //             onPressed: () =>
                        //                 playbackController.skipForward(-10),
                        //           )
                        //         : const SizedBox()),
                        //     Obx(() => IconButton(
                        //           icon: Icon(playbackController.isPlaying.value
                        //               ? Icons.pause
                        //               : Icons.play_arrow),
                        //           onPressed: () =>
                        //               playbackController.togglePlayPause(),
                        //         )),
                        //     Obx(() => !playbackController.isPlaying.value
                        //         ? IconButton(
                        //             icon: const Icon(Icons.forward_10),
                        //             onPressed: () =>
                        //                 playbackController.skipForward(10),
                        //           )
                        //         : const SizedBox()),
                        //   ],
                        // ),
                        // Display the current time of the video
                        // Obx(() => Text(
                        //       'Current Time: ${playbackController.currentTime.value}s',
                        //       style: const TextStyle(fontSize: 18),
                        //     )),
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
      ),
    );
  }
}
