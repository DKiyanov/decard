import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum _PlayerState {
  stop,
  pause,
  play,
  complete
}

class AudioPanelWidget extends StatefulWidget {
  final String? localFilePath;
  final String? httpUrl;
  const AudioPanelWidget({super.key, this.localFilePath, this.httpUrl});

  @override
  State<AudioPanelWidget> createState() => _AudioPanelWidgetState();
}

class _AudioPanelWidgetState extends State<AudioPanelWidget> {
  AudioPlayer? _player;
  var playerState = _PlayerState.stop;
  Duration? fileDuration;
  Duration? fileCurrentPos;

  @override
  void initState() {
    super.initState();

    _setSource().then((value)  {
      setState(() {
        playerState = _PlayerState.pause;
      });
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (playerState == _PlayerState.stop) {
      return Row(children: [
        IconButton(
            onPressed: _setSource,
            icon: const Icon(Icons.speaker_phone)
        )
      ]);
    }

    return Row(children: [
      if (playerState == _PlayerState.play)
        IconButton(
            onPressed: _pause,
            icon: const Icon(Icons.pause)
        ),

      if (playerState == _PlayerState.pause)
        IconButton(
            onPressed: _play,
            icon: const Icon(Icons.play_arrow)
        ),

      if (playerState == _PlayerState.complete)
        IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.restart_alt)
        ),

      if (fileDuration != null)
        Expanded(
          child: Slider(
            min : 0,
            max : fileDuration!.inMilliseconds.toDouble(),
            value: fileCurrentPos!.inMilliseconds.toDouble(),
            onChanged: (double value) => setPos(value.toInt()),
          ),
        ),
    ]);
  }

  Future<void> _setSource() async {
    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }

    fileDuration   = null;
    fileCurrentPos = null;

    _player = AudioPlayer();
    _player!.onPositionChanged.listen((pos) {
      if (pos.inMilliseconds >= fileDuration!.inMilliseconds) {
        setState(() {
          fileCurrentPos = fileDuration;
        });
      } else {
        setState(() {
          fileCurrentPos = pos;
        });
      }
    });

    _player!.onDurationChanged.listen((length) {
      setState(() {
        fileDuration = length;
        fileCurrentPos = const Duration(milliseconds: 0);
      });
    });

    _player!.onPlayerComplete.listen((_) {
      setState(() {
        playerState = _PlayerState.complete;
        fileCurrentPos = fileDuration;
      });
    });

    if (widget.localFilePath != null) {
      await _player!.setSourceDeviceFile(widget.localFilePath!);
    }

    if (widget.httpUrl != null) {
      await _player!.setSourceUrl(widget.httpUrl!);
    }
  }

  void _pause() {
    if (_player == null) return;

    _player!.pause();

    setState(() {
      playerState = _PlayerState.pause;
    });
  }

  void _play() {
    if (_player == null) return;

    _player!.resume();

    setState(() {
      playerState = _PlayerState.play;
    });
  }

  Future<void> setPos(int pos) async {
    if (_player == null) return;

    if (_player!.state == PlayerState.completed){
      await _setSource();
    }

    if (playerState != _PlayerState.pause){
      playerState = _PlayerState.pause;
      await _player!.pause();
      setState(() {});
    }

    fileCurrentPos = Duration(milliseconds: pos);
    await _player!.seek(fileCurrentPos!);
  }

  Future<void> _restart() async {
    await _setSource();
    _play();
  }
}
