import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:http_parser/http_parser.dart';
import '../../../../constants/recorder_constants.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../constants/APIConstants.dart';
import '../../models/audio_recording.dart';
import '../recorder_display/recorder_display.dart';
import '../recording_list/recording_list.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  RecordingScreenState createState() => RecordingScreenState();
}

class RecordingScreenState extends State<RecordingScreen> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final TextEditingController _commentController = TextEditingController();

  String? _completeAudioFilePath;
  String? _audioFileName;
  bool _isRecording = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _isRecording = false;
  }

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
    _commentController.dispose();
    super.dispose();
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

    await _audioRecorder.startRecorder(
        toFile: _completeAudioFilePath, codec: Codec.defaultCodec);
  }

  void _stopRecordingAndUpload() async {
    await _audioRecorder.stopRecorder();

    setState(() {
      _isUploading = true;
    });

    var request =
        http.MultipartRequest('POST', Uri.parse(APIConstants.baseUrl));
    request.files.add(await http.MultipartFile.fromPath(
        'audio_data', _completeAudioFilePath!,
        filename: _audioFileName, contentType: MediaType('audio', 'wav')));
    try {
      var streamedResponse = await request.send();

      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) {
        print("response body of create: $response.body");
        print('Transcribed Successfully');

        var data = jsonDecode(response.body);
        setState(() {
          _completeAudioFilePath = _completeAudioFilePath;
          _isUploading = false;
        });

        Recording recording = Recording(
            id: data["data"]["id"],
            transcription: data["data"]["transcription"],
            audioUrl: data["data"]["audio_url"],
            comments: data["data"]["comments"] ?? "");

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color.fromRGBO(0, 255, 0, 0.5),
            content: Text('Transcribed successfully.'),
            duration: Duration(seconds: 3),
          ));

          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    RecordingDisplayScreen(recording: recording)),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Color.fromRGBO(250, 0, 0, 0.5),
            content: Text(response.body),
            duration: const Duration(seconds: 3),
          ));
        }
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      print("Error \n!!!$e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color.fromRGBO(250, 0, 0, 0.5),
          content: Text("Please check your internet"),
          duration: Duration(seconds: 3),
        ));
      }
    }
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
    // The view used to display the transcribed text

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
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecordingsListPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[centeredMic],
      ),
    );
  }
}
