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
  double volume = 1.0;
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

  double start = 0;
  double end = 0;
  @override
  Widget build(BuildContext context) {
    List<double> samples = List.generate(
      500,
      (index) => random.nextDouble(),
    );

    return MaterialApp(
      theme: ThemeData(
        colorSchemeSeed: Colors.yellow,
      ),
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
                          selectedFile = File(
                            result.files.single.path!,
                          );
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
                SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: WaveSlider(
                    samples: samples,
                    wavDeactiveColor: Colors.deepPurple,
                    sliderColor: Colors.deepPurple,
                    duration: duration.inSeconds.toDouble(),
                    callbackStart: (callbackStart) {
                      log('call backStart $start');
                      start = callbackStart;
                    },
                    callbackEnd: (callbackEnd) {
                      log('call backEnd $end');
                      end = callbackEnd;
                    },
                  ),
                ),
              if (isLoading) const Text("LOADING"),
            ],
          ),
        ),
      ),
    );
  }

  bool isLoading = false;
  Future<void> processAudio() async {
    setState(() {
      isLoading = true;
    });

    final tempDir = await getTemporaryDirectory();
    final outputFile = File('${tempDir.path}/modified_audio.mp3');

    // final trimCommand =
    //     '-y -i ${selectedFile!.path} -filter:a "volume=$volume" ${outputFile.path}';

    final trimCommand =
        '-y -i ${selectedFile!.path} -af "atrim=start=$start:end=$end" ${outputFile.path}';
    await ffmpeg_kit_flutter_full.FFmpegKit.execute(trimCommand)
        .then((session) async {
      final returnCode = await session.getReturnCode();
      log("This is the output File ${outputFile.path}");
      if (returnCode!.isValueSuccess()) {
        if (await outputFile.exists()) {
          await audioPlayer.setSourceUrl(outputFile.path);
          audioPlayer.play(DeviceFileSource(outputFile.path));
        } else {
          log("FFmpegKit Error: Output file does not exist");
        }
      } else {
        log("FFmpegKit Error: Failed to modify audio");
        session.getFailStackTrace().then((stackTrace) {
          log("FFmpegKit StackTrace: $stackTrace");
        });
      }
    }).catchError((error) {
      log("FFmpegKit Error: $error");
    });

    setState(() {
      isLoading = false;
    });
  }
}
