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
  @override
  _RecordingScreenState createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  FlutterSoundPlayer _player = FlutterSoundPlayer();

  String? _completeAudioFilePath;
  String? _audioFileName;
  String _transcribedText = '';
  TextEditingController _commentController = TextEditingController();
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isPlaying = false;
  bool _hasTranscribed = false;
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

  Future<bool> _resetState() async {
    setState(() {
      _isRecording = false;
      _isPlaying = false;
      _hasTranscribed = false;
      _hasRecorded = false;
      _transcribedText = '';
      _transcriptionId = -1;
    });
    return true;
  }

  void _startRecording() async {
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

    final session = await AudioSession.instance;

    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.record,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    await _audioRecorder.startRecorder(
        toFile: _completeAudioFilePath, codec: Codec.defaultCodec);
  }

  void _stopRecordingAndUpload() async {
    await _audioRecorder.stopRecorder();
    _hasRecorded = true;
    _sendAudioToServer();
  }

  Future<void> _sendAudioToServer() async {
    // const TRANSCRIBE_EDPOINT = "http://10.0.2.2:3000/api/v1/audio_recording";
    const TRANSCRIBE_EDPOINT = APIConstants.baseUrl;
    // "http://ec2-18-189-229-171.us-east-2.compute.amazonaws.com/api/v1/audio_recording";

    var url = Uri.parse(TRANSCRIBE_EDPOINT);
    var request = http.MultipartRequest('POST', url);

    request.files.add(await http.MultipartFile.fromPath(
        'audio_data', _completeAudioFilePath!,
        filename: _audioFileName, contentType: MediaType('audio', 'wav')));
    var streamedResponse = await request.send();

    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      print(response.body);
      print('Audio Uploaded Successfully');

      var data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
        content: Text('File uploaded successfully.'),
        duration: Duration(seconds: 3),
      ));

      setState(() {
        _hasTranscribed = true;
        _transcribedText = data["transcription"];
        _transcriptionId = data["id"];
        _completeAudioFilePath = _completeAudioFilePath;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.body),
        duration: Duration(seconds: 3),
      ));
      print(response.reasonPhrase);
      print(response.statusCode);
      print('Audio Upload Failed');
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
    return WillPopScope(
        onWillPop: _resetState,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Notes Transcriber'),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.list),
                onPressed: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //       builder: (context) => RecordingsListPage()),
                  // );
                },
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(10.0),
                  margin: EdgeInsets.all(10.0),
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
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 15.0),
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
              ),
              Row(
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
                      onPressed:
                          _hasRecorded ? _playRecording : _pauseRecording,
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
              )
            ],
          ),
        ));
  }
}
