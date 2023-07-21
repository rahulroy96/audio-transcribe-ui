import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../constants/APIConstants.dart';

// import '../widgets/audio_player.dart';

class RecordingsListPage extends StatefulWidget {
  @override
  _RecordingsListPageState createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  ScrollController _scrollController = ScrollController();
  int _page = 1;
  List _recordings = [];
  bool _isPlaying = false;
  // String _selectedAudioUrl = "";
  FlutterSoundPlayer _player = FlutterSoundPlayer();

  @override
  void initState() {
    super.initState();
    _player.openPlayer();

    _isPlaying = false;
    fetchRecordings();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        fetchRecordings();
      }
    });
  }

  fetchRecordings() async {
    // "http://ec2-18-189-229-171.us-east-2.compute.amazonaws.com/api/v1/audio_recording?page=$_page";
    // String URL = "http://10.0.2.2:3000/api/v1/audio_recording";
    var response =
        await http.get(Uri.parse("${APIConstants.baseUrl}?page=$_page"));

    if (response.statusCode == 200) {
      List newRecordings = json.decode(response.body);
      if (newRecordings.isEmpty) {
        return;
      }
      newRecordings = newRecordings
          .map(
            (e) => ({...e, "isPlaying": false}),
          )
          .toList();
      setState(() {
        _recordings.addAll(newRecordings);
        _page++;
      });
    }
  }

  void _playRecording(var index) async {
    // await _player.openPlayer();

    if (_recordings[index]["isPlaying"]) {
      return;
    }

    await _player.startPlayer(fromURI: _recordings[index]["audio_recording"]);
    setState(() {
      _recordings[index]["isPlaying"] = true;
      _isPlaying = true;
    });
  }

  void _pauseRecording(var index) async {
    // await _player.openPlayer();

    await _player.stopPlayer();
    setState(() {
      _recordings[index]["isPlaying"] = false;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
      ),
      body:
          // Column(
          //   children: <Widget>[
          //     Expanded(
          //       flex: 6,
          //       child:
          ListView.builder(
        controller: _scrollController,
        itemCount: _recordings.length,
        itemBuilder: (context, index) {
          var recording = _recordings[index];
          return ListTile(
            leading: IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              // onPressed: _isPlaying ? _playRecording(recording) : null,
              onPressed: () => _playRecording(index),
            ),
            title: Text(recording['transcription'] ?? '[No transcription]'),
            subtitle: Text(recording['comments'] ?? '[no comments]'),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _player.closePlayer();
    super.dispose();
  }
}
