import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';

import '../../constants/APIConstants.dart';
import '../../models/audio_recording.dart';
import '../recorder_display/recorder_display.dart';

class RecordingsListPage extends StatefulWidget {
  const RecordingsListPage({super.key});

  @override
  RecordingsListPageState createState() => RecordingsListPageState();
}

class RecordingsListPageState extends State<RecordingsListPage> {
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  List _recordings = [];

  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    fetchRecordings();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        fetchRecordings();
      }
    });
  }

  fetchRecordings() async {
    try {
      var response =
          await http.get(Uri.parse("${APIConstants.baseUrl}?page=$_page"));

      if (response.statusCode == 200) {
        List newRecordings = json.decode(response.body);
        if (newRecordings.isEmpty) {
          return;
        }
        // Add the isPlaying state to each element that is being fetched from server. Initialize it as false
        newRecordings = newRecordings
            .map(
              (e) => ({...e, "isPlaying": false}),
            )
            .toList();
        setState(() {
          _recordings.addAll(newRecordings);
          _page++;
        });
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
            content: Text('Fetching recordings from server failed'),
            duration: Duration(seconds: 3),
          ));
        }
      }
    } catch (e) {
      // Handling network exceptions here.
      print('Network error occurred: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color.fromRGBO(250, 0, 0, 0.5),
          content: Text('Please check your network connection'),
          duration: Duration(seconds: 3),
        ));
      }
    }
  }

  void _playRecording(var index) async {
    if (_recordings[index]["isPlaying"]) {
      return;
    }

    if (_player!.playing) {
      // If the player is already playing a recording, we need to stop it before playing new.
      // This ensures that the state of already playing element will be properly updated.
      _player!.stop();
    }

    await _player!.setUrl(
        // Load the recording url that is to be played.
        _recordings[index]["audio_url"]);

    // The when complete makes sure that the isPlaying state updated when the player finishes playing
    _player!.play().whenComplete(() => setState(() {
          _recordings[index]["isPlaying"] = false;
        }));

    setState(() {
      // Update the isPlaying field of all the elements in the list
      // This helps to make sure that only one of the list elements will have
      // an audio playing.
      _recordings = _recordings.map((e) {
        e["isPlaying"] = false;
        return e;
      }).toList();

      // Now set the current elements isPlaying value as true.
      _recordings[index]["isPlaying"] = true;
    });
  }

  void _stopRecording(var index) async {
    // Stop the currently playing track
    await _player!.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordings')),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _recordings.length,
        itemBuilder: (context, index) {
          var recording = _recordings[index];
          return InkWell(
              onTap: () async {
                print('Tile tapped!');

                if (context.mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RecordingDisplayScreen(
                            recording: Recording(
                                id: recording["id"],
                                transcription: recording["transcription"],
                                audioUrl: recording["audio_url"],
                                comments: recording["comments"] ?? ""))),
                  );
                  if (result != null) {
                    setState(() {
                      _recordings[index]["comments"] = result.comments;
                    });
                  }
                }
              },
              child: ListTile(
                leading: IconButton(
                  icon: Icon(
                    _recordings[index]['isPlaying']
                        ? Icons.stop
                        : Icons.play_arrow,
                    color: _recordings[index]['isPlaying']
                        ? Colors.red
                        : Colors.blue,
                  ),
                  onPressed: () => _recordings[index]['isPlaying']
                      ? _stopRecording(index)
                      : _playRecording(index),
                ),
                title: Text(recording['transcription'] ?? '[No transcription]'),
                subtitle: Text(recording['comments'] ?? '[no comments]'),
              ));
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _player!.stop();
    super.dispose();
  }
}
