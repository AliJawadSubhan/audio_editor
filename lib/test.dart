import 'dart:developer';
import 'dart:math' as m;

import 'package:audio_editor/wavebar.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart'
    as ffmpeg_kit_flutter_full;

class Apppp extends StatefulWidget {
  @override
  _AppppState createState() => _AppppState();
}

class _AppppState extends State<Apppp> {
  final audioPlayer = AudioPlayer();
  bool isPlaying = false;
  double volume = 1.0; // Default volume level (1.0 is original)
  File? selectedFile;
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

  final m.Random random = m.Random();

  @override
  Widget build(BuildContext context) {
    List<double> samples = List.generate(500, (index) => random.nextDouble());

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Player and Editor'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              if (selectedFile != null)
                Slider(
                  min: 0.2,
                  max: 20.0,
                  divisions: 15,
                  label: 'Volume: ${volume.toStringAsFixed(2)}',
                  value: volume,
                  onChanged: (newVolume) async {
                    setState(() {
                      volume = newVolume;
                    });
                    await processAudio();
                  },
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                      );
                      if (result != null) {
                        setState(() {
                          selectedFile = File(result.files.single.path!);
                        });
                      }
                    },
                    child: const Text('Pick Audio File'),
                  ),
                  ElevatedButton(
                    onPressed: selectedFile == null ? null : processAudio,
                    child: const Text('Process Audio'),
                  ),
                ],
              ),
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
                  setState(() {});
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
                        setState(() {});
                      } else {
                        await audioPlayer.play(
                          DeviceFileSource(selectedFile!.path),
                          // mode: Player
                        );
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              if (selectedFile != null)
                Expanded(
                  child: WaveSlider(
                    // heightWaveSlider: 129,
                    // widthWaveSlider: 180
                    // ,

                    samples: samples,
                    wavDeactiveColor: Colors.deepPurple,
                    // backgroundColor: Colors.black,
                    sliderColor: Colors.red,
                    // widthWaveSlider: 200,
                    duration: duration.inSeconds.toDouble(),
                    callbackStart: (callbackStart) {
                      log('call backStart');
                    },
                    callbackEnd: (callbackEnd) {
                      log('call backEnd');
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> processAudio() async {
    final tempDir = await getTemporaryDirectory();
    final outputFile = File('${tempDir.path}/modified_audio.mp3');

    final increaseVolumeCommand =
        '-y -i ${selectedFile!.path} -filter:a "volume=$volume" ${outputFile.path}';

    await ffmpeg_kit_flutter_full.FFmpegKit.execute(increaseVolumeCommand)
        .then((session) async {
      final returnCode = await session.getReturnCode();
      if (returnCode!.isValueSuccess()) {
        await audioPlayer.setSourceUrl(outputFile.path);
        audioPlayer.play(DeviceFileSource(outputFile.path));
      } else {
        log("FFmpegKit Error: Failed to modify volume");
      }
      session.getFailStackTrace().then((stackTrace) {
        log("FFmpegKit StackTrace: $stackTrace");
      });
    }).catchError((error) {
      log("FFmpegKit Error: $error");
    });
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }
}
