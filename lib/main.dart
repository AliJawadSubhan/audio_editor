import 'dart:developer';

// import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart' as ffmpeg_kit_flutter;
import 'package:audio_editor/test.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart'
    as ffmpeg_kit_flutter_full;

void main() => runApp(Apppp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Listen to audio player state changes
    audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
    });

    // Listen to audio duration changes
    audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        duration = newDuration;
      });
    });

    // Listen to audio position changes
    audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        position = newPosition;
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Player'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Slider(
                min: 0,
                max: duration.inSeconds.toDouble(),
                value: position.inSeconds.toDouble(),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  var data = await Future.wait(
                    [
                      audioPlayer.seek(position),
                      audioPlayer.resume(),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () async {
                      if (isPlaying) {
                        await audioPlayer.pause();
                      } else {
                        await audioPlayer.play(
                          AssetSource('audio/sample.mp3'),
                          // mode: Player
                        );
                      }
                    },
                  ),
                ],
              ),
              Text(position.inSeconds.toString()),
              ElevatedButton(
                onPressed: () {
                  processAudioAsset();
                },
                child: const Text('Process Audio Asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void processAudioAsset() async {
    final byteData = await rootBundle.load('assets/audio/sample.mp3');
    final originalFile =
        File('${(await getTemporaryDirectory()).path}/sample.mp3');
    await originalFile.writeAsBytes(byteData.buffer.asUint8List());

    final outputFile =
        File('${(await getTemporaryDirectory()).path}/sample_louder.mp3');

    final increaseVolumeCommand =
        '-y -i ${originalFile.path} -filter:a "volume=1.2"  ${outputFile.path}';
    // -c:a libmp3lame
    await ffmpeg_kit_flutter_full.FFmpegKit.execute(increaseVolumeCommand)
        .then((session) async {
      final returnCode = await session.getReturnCode();
      session.getLogs().then((logs) {
        for (var element in logs) {
          log("element.getMessage() ${element.getMessage()} ");
        }
      });
      session.getFailStackTrace().then((stackTrace) {
        log("FFmpegKit StackTrace: $stackTrace");
      });

      log(returnCode!.isValueSuccess().toString() + " if it is true or not");
      if (returnCode?.isValueSuccess() ?? false) {
        log("FFmpegKit Success: Volume increased");
        // Step 3: Play the processed audio file
        await audioPlayer.setSourceUrl(outputFile.path);
        audioPlayer.play(DeviceFileSource(outputFile.path));
      } else {
        // returnCode.er
        log("FFmpegKit Error: Failed to increase volume");
      }
    }).catchError((error) {
      log("FFmpegKit Error: $error");
    });
  }
}
  // void processAudioAsset() async {
  //   final byteData = await rootBundle.load('assets/audio/sample.mp3');
  //   final originalFile =
  //       File('${(await getTemporaryDirectory()).path}/sample.mp3');
  //   await originalFile.writeAsBytes(byteData.buffer.asUint8List());

  //   // Step 1: Convert to WAV
  //   final wavFile = File('${(await getTemporaryDirectory()).path}/sample.wav');
  //   final convertToWavCommand = '-y -i ${originalFile.path} ${wavFile.path}';
  //   await ffmpeg_kit_flutter_full.FFmpegKit.execute(convertToWavCommand);

  //   // Step 2: Increase Volume of WAV
  //   final louderWavFile =
  //       File('${(await getTemporaryDirectory()).path}/sample_louder.wav');
  //   final increaseVolumeCommand =
  //       '-y -i ${wavFile.path} -filter:a "volume=5.0" -t 5 ${louderWavFile.path}';

  //   await ffmpeg_kit_flutter_full.FFmpegKit.execute(increaseVolumeCommand)
  //       .then((session) async {
  //     final returnCode = await session.getReturnCode();
  //     session.getLogs().then((logs) {
  //       for (var losg in logs) {
  //         log("FFmpeg Log: ${losg.getMessage()}");
  //       }
  //     });

  //     if (returnCode?.isValueSuccess() ?? false) {
  //       log("FFmpegKit Success: Volume increased");
  //       // Step 3: Play the processed louder WAV audio file
  //       await audioPlayer.setSourceUrl(louderWavFile.path);
  //       audioPlayer.play(DeviceFileSource(louderWavFile.path));
  //     } else {
  //       log("FFmpegKit Error: Failed to increase volume or convert file.");
  //     }
  //   }).catchError((error) {
  //     log("FFmpegKit Error: $error");
  //   });
  // }