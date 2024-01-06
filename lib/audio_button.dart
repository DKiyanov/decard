import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:io';

Future<void> playAudio(String fileName) async {
  final audioFile = File(fileName);

  if (!audioFile.existsSync()) return;

  final player = AudioPlayer();

  await player.setSourceDeviceFile(fileName);
  player.resume();

  await player.onPlayerComplete.first;
}

class SimpleAudioButton extends StatefulWidget {
  final String? localFilePath;
  final String? httpUrl;
  final Color color;
  final Color playColor;

  const SimpleAudioButton({this.localFilePath, this.httpUrl, this.color = Colors.white, this.playColor = Colors.lightGreenAccent, Key? key}) : super(key: key);

  @override
  State<SimpleAudioButton> createState() => _SimpleAudioButtonState();
}

class _SimpleAudioButtonState extends State<SimpleAudioButton> {
  AudioPlayer? _player;
  bool _playing = false;


  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    Widget icon;
    if (_playing) {
      icon = Icon(Icons.volume_up, color: widget.playColor);
    } else {
      icon = Icon(Icons.volume_mute, color: widget.color);
    }

    return GestureDetector(
      child: icon,

      onTap: (){
        if (_playing) {
          _stop();
        } else {
          _play();
        }

      },
    );
  }

  Future<void> _play() async {
    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }

    _player = AudioPlayer();

    _player!.onPlayerComplete.listen((_) {
      setState(() {
        _playing = false;
      });
    });


    if (widget.localFilePath != null) {
      await _player!.setSourceDeviceFile(widget.localFilePath!);
    }

    if (widget.httpUrl != null) {
      await _player!.setSourceUrl(widget.httpUrl!);
    }

    _player!.resume();

    setState(() {
      _playing = true;
    });
  }

  void _stop() {
    if (_player == null) return;
    _player!.dispose();
    _player = null;

    setState(() {
      _playing = false;
    });
  }

}
