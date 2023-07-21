import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:http_parser/http_parser.dart';
import 'package:audio_session/audio_session.dart';
import '../../../../constants/recorder_constants.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../constants/APIConstants.dart';
import '../recording_list/recording_list.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  RecordingScreenState createState() => RecordingScreenState();
}

class RecordingScreenState extends State<RecordingScreen> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final TextEditingController _commentController = TextEditingController();

  String? _completeAudioFilePath;
  String? _audioFileName;
  String _transcribedText = '';
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isPlaying = false;
  bool _hasTranscribed = false;
  bool _isUploading = false;
  int _transcriptionId = -1;

  @override
  void initState() {
    super.initState();
    _player.openPlayer();
    _isRecording = false;
    _isPlaying = false;
    _hasTranscribed = false;
    _hasRecorded = false;
    _transcribedText = '';
    _transcriptionId = -1;
  }

  @override
  void dispose() {
    _isRecording = false;
    _isPlaying = false;
    _hasTranscribed = false;
    _hasRecorded = false;
    _audioRecorder.closeRecorder();
    _player.closePlayer();
    _commentController.dispose();
    super.dispose();
  }

  void _startRecording() async {
    if (_hasTranscribed) {
      setState(() {
        _hasTranscribed = false;
        _transcriptionId = -1;
        _transcribedText = "";
      });
    }

    final statusMic = await Permission.microphone.request();
    if (statusMic != PermissionStatus.granted) {
      throw RecordingPermissionException('microphone permission');
    }

    final Directory tempDir = await getTemporaryDirectory();
    bool appFolderExists = await tempDir.exists();
    if (!appFolderExists) {
      final created = await tempDir.create(recursive: true);
      print(created.path);
    }

    _audioFileName =
        '${DateTime.now().millisecondsSinceEpoch}${RecorderConstants.fileExtention}';
    _completeAudioFilePath = '${tempDir.path}/$_audioFileName';

    print(_completeAudioFilePath);

    File(_completeAudioFilePath!)
        .create(recursive: true)
        .then((File file) async {
      //write to file
      Uint8List bytes = await file.readAsBytes();
      file.writeAsBytes(bytes);
      print("FILE CREATED AT : " + file.path);
    });

    await _audioRecorder.openRecorder();

    await _audioRecorder.startRecorder(
        toFile: _completeAudioFilePath, codec: Codec.defaultCodec);
  }

  void _stopRecordingAndUpload() async {
    await _audioRecorder.stopRecorder();

    bool uploaded = await _sendAudioToServer();
    // if ( uploaded){
    //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //     backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
    //     content: Text('File uploaded successfully.'),
    //     duration: Duration(seconds: 3),
    //   ));
    // }
    // setState(() {
    //   _hasRecorded = true;
    // });
  }

  Future<bool> _sendAudioToServer() async {
    setState(() {
      _isUploading = true;
    });

    var url = Uri.parse(APIConstants.baseUrl);
    var request = http.MultipartRequest('POST', url);

    request.files.add(await http.MultipartFile.fromPath(
        'audio_data', _completeAudioFilePath!,
        filename: _audioFileName, contentType: MediaType('audio', 'wav')));
    var streamedResponse = await request.send();

    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      print("response body of create: $response.body");
      print('Transcribed Successfully');

      var data = jsonDecode(response.body);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
          content: Text('Transcribed successfully.'),
          duration: Duration(seconds: 3),
        ));
      }
      setState(() {
        _hasTranscribed = true;
        _transcribedText = data["transcription"];
        _transcriptionId = data["id"];
        _completeAudioFilePath = _completeAudioFilePath;
        _isUploading = false;
      });

      return true;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.body),
          duration: const Duration(seconds: 3),
        ));
      }
      setState(() {
        _isUploading = false;
        _hasTranscribed = false;
        _transcribedText = "";
        _transcriptionId = -13;
      });

      return false;
    }
  }

  void _sendComment() async {
    // TODO
    if (!_hasTranscribed) {
      return;
    }

    var request = http.MultipartRequest(
        'PATCH', Uri.parse("${APIConstants.baseUrl}/$_transcriptionId"));

    request.fields.addAll({'comments': _commentController.text});

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      print(await response.stream.bytesToString());
    } else {
      print(response.reasonPhrase);
    }
    _commentController.text = "";
  }

  void _playRecording() async {
    if (!_hasRecorded || _isPlaying) {
      return;
    }
    await _player.openPlayer();
    await _player.startPlayer(fromURI: _completeAudioFilePath);
    setState(() {
      _isPlaying = true;
    });
  }

  void _pauseRecording() async {
    if (!_isPlaying) {
      return;
    }
    await _player.pausePlayer();
    setState(() {
      _isPlaying = false;
    });
  }

  void _onRecordButtonPressed() async {
    if (_isRecording) {
      _stopRecordingAndUpload();
    } else {
      _startRecording();
    }

    setState(() {
      _isRecording = !_isRecording;
    });
  }

  @override
  Widget build(BuildContext context) {
    var transcribedTextView = Expanded(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        margin: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: TextField(
          readOnly: true,
          maxLines: 5,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: _transcribedText.isNotEmpty
                ? _transcribedText
                : 'Your Transcribed text will appear here!',
          ),
        ),
      ),
    );
    var commentView = Padding(
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
                enabled: _hasTranscribed,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your comments',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: _hasTranscribed ? _sendComment : null,
          ),
        ],
      ),
    );

    var buttonRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
          onPressed: _onRecordButtonPressed,
          color: _isRecording ? Colors.red : Colors.blue,
          iconSize: 50,
        ),
        if (_hasRecorded)
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _hasRecorded ? _playRecording : _pauseRecording,
            color: _hasRecorded ? Colors.grey : Colors.blue,
            iconSize: 50,
          )
        else
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _hasRecorded ? _playRecording : null,
            color: _hasRecorded ? Colors.grey : Colors.blue,
            iconSize: 50,
          ),
      ],
    );

    var centeredMic = Expanded(
        child: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
          if (_isUploading) ...[
            const CircularProgressIndicator(), // Show loading spinner when uploading
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Text(
                'Transcribing...',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            IconButton(
              icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
              onPressed: _isUploading ? null : _onRecordButtonPressed,
              color: _isRecording ? Colors.red : Colors.blue,
              iconSize: 100,
            ),
            if (_isRecording)
              const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text(
                  'Click to Stop Recording',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text(
                  'Click to Start Recording',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ]
        ])));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes Transcriber'),
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
      body: Column(
        children: <Widget>[
          if (_hasTranscribed) ...[
            transcribedTextView,
            commentView,
            buttonRow,
          ] else
            centeredMic
        ],
      ),
    );
  }
}
