import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:just_audio/just_audio.dart';

import 'package:http/http.dart' as http;

import '../../constants/APIConstants.dart';
import '../../models/audio_recording.dart';
import '../recording_list/recording_list.dart';

class RecordingDisplayScreen extends StatefulWidget {
  final Recording recording;
  const RecordingDisplayScreen({super.key, required this.recording});

  @override
  RecordingDisplayScreenState createState() => RecordingDisplayScreenState();
}

class RecordingDisplayScreenState extends State<RecordingDisplayScreen> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _commentController = TextEditingController();

  String? _audioFilePath;
  bool _isPlaying = false;
  var _transcriptionId = -1;
  String _transcribedText = '';
  String _comment = '';

  @override
  void initState() {
    super.initState();

    _isPlaying = false;
    _transcriptionId = widget.recording.id;
    fetchRecordings();
  }

  fetchRecordings() async {
    try {
      var response = await http
          .get(Uri.parse("${APIConstants.baseUrl}/$_transcriptionId"));

      if (response.statusCode == 200) {
        var responseBody = json.decode(response.body);
        print(_transcriptionId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
            content: Text('Fetched record'),
            duration: Duration(seconds: 3),
          ));
        }

        setState(() {
          _transcribedText = responseBody["transcription"] ?? "";
          _audioFilePath = responseBody["audio_url"] ?? "";
          _comment = responseBody["comments"] ?? "";
        });
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
            content: Text('Fetching record from server failed'),
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

  @override
  void dispose() {
    _player.stop();
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() async {
    var request = http.MultipartRequest(
        'PATCH', Uri.parse("${APIConstants.baseUrl}/$_transcriptionId"));

    request.fields.addAll({'comments': _commentController.text});

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      setState(() {
        _comment = data["data"]["comments"];
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color.fromRGBO(0, 250, 0, 0.5),
          content: Text("Comment updated!"),
          duration: Duration(seconds: 3),
        ));
        _commentController.text = "";
        FocusScope.of(context).unfocus();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color.fromRGBO(250, 0, 0, 0.5),
          content: Text("Comment update failed!"),
          duration: Duration(seconds: 3),
        ));
        _commentController.text = "";
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _playRecording() async {
    if (_isPlaying) {
      return;
    }

    if (_player.playing) {
      // If the player is already playing a recording, we need to stop it before playing new.
      // This ensures that the state of already playing element will be properly updated.
      _player.stop();
    }
    print("url: $_audioFilePath");

    await _player.setUrl(_audioFilePath!);

    // The when complete makes sure that the isPlaying state updated when the player finishes playing
    _player.play().whenComplete(() => setState(() {
          _isPlaying = false;
        }));
    setState(() {
      _isPlaying = true;
    });
  }

  void _pauseRecording() async {
    if (!_isPlaying) {
      return;
    }
    await _player.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The view used to display the transcribed text
    var transcribedTextView = Expanded(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        margin: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Center(
          child: TextField(
            readOnly: true,
            maxLines: 10,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: _transcribedText.isNotEmpty
                  ? _transcribedText
                  : 'Your Transcribed text will appear here!',
            ),
          ),
        ),
      ),
    );

    var commentTextView = Container(
      padding: const EdgeInsets.all(10.0),
      margin: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Center(
        child: TextField(
          readOnly: true,
          maxLines: 2,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: _comment.isNotEmpty ? _comment : '[No comments]',
          ),
        ),
      ),
    );

    var commentAddView = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your comments',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: _sendComment,
          ),
        ],
      ),
    );

    var buttonRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: _isPlaying ? _pauseRecording : _playRecording,
          color: _isPlaying ? Colors.red : Colors.blue,
          iconSize: 50,
        )
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Note'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecordingsListPage()),
              );
            },
          ),
        ],
      ),
      body: Column(children: <Widget>[
        transcribedTextView,
        commentTextView,
        commentAddView,
        buttonRow,
      ]),
    );
  }
}
