import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';


import 'package:http_parser/http_parser.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_session/audio_session.dart';
// import 'package:rapid_note/screens/recordings_list/cubit/files/files_cubit.dart';
import '../../../../constants/paths.dart';
import '../../../../constants/recorder_constants.dart';
// import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';
// import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
part 'record_state.dart';

class RecordCubit extends Cubit<RecordState> {
  RecordCubit() : super(RecordInitial());

  Codec _codec = Codec.pcm16WAV;

  String? audioFileName;

  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();

  void startRecording() async {
    
    // Map<Permission, PermissionStatus> permissions = await [
    //   Permission.storage,
    //   Permission.microphone,
    // ].request();

    // bool permissionsGranted = permissions[Permission.microphone]!.isGranted;
    // // && permissions[Permission.storage]!.isGranted 
        

    // if (permissionsGranted) {
    //   final Directory tempDir = await getTemporaryDirectory();
    //   // Directory appFolder = Directory(Paths.recording);
    //   // bool appFolderExists = await appFolder.exists();
    //   // if (!appFolderExists) {
    //   //   final created = await appFolder.create(recursive: true);
    //   //   print(created.path);
    //   // }

    //   final filepath = '$tempDir/${DateTime.now().millisecondsSinceEpoch}${RecorderConstants.fileExtention}';
    //   print(filepath);

    //   await _audioRecorder.start(path: filepath);

    //   emit(RecordOn());
    // } else {
    //   print('Permissions not granted');
    // }



/////////////////////////////////////

    final statusMic = await Permission.microphone.request();
    if(statusMic != PermissionStatus.granted){
      throw RecordingPermissionException('microphone permission');
    }

    final Directory tempDir = await getTemporaryDirectory();
    bool appFolderExists = await tempDir.exists();
    if (!appFolderExists) {
      final created = await tempDir.create(recursive: true);
      print(created.path);
    }

    // audioFileName = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}${RecorderConstants.fileExtention}';
    audioFileName = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}';
      var completeAudioFilePath = '${tempDir.path}/$audioFileName';

      print(completeAudioFilePath);

    File(completeAudioFilePath)
      .create(recursive: true)
      .then((File file) async {
    //write to file
    Uint8List bytes = await file.readAsBytes();
    file.writeAsBytes(bytes);
    print("FILE CREATED AT : "+file.path);
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

    // print("starting check");
    // print(await _audioRecorder.isEncoderSupported(Codec.aacADTS));
    // print(await _audioRecorder.isEncoderSupported(Codec.defaultCodec));
    // print("pcm16wav");
    // print(await _audioRecorder.isEncoderSupported(Codec.pcm16WAV));
    // print(await _audioRecorder.isEncoderSupported(Codec.aacADTS));
    // print(await _audioRecorder.isEncoderSupported(Codec.aacADTS));

    await _audioRecorder.startRecorder(toFile: audioFileName, codec: Codec.defaultCodec);

    
    
    emit(RecordOn());


    //+++++++++++++++++++++++++++++++++++++++++++++++++++//

    // if (await _audioRecorder.hasPermission()) {
    //   // Start recording
    //   final Directory tempDir = await getTemporaryDirectory();
    //   bool appFolderExists = await tempDir.exists();
    //   if (!appFolderExists) {
    //     final created = await tempDir.create(recursive: true);
    //     print(created.path);
    //   }
    //   audioFileName = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}${RecorderConstants.fileExtention}';
    //   var completeAudioFilePath = '${tempDir.path}/$audioFileName';

    //   print(completeAudioFilePath);

    //   File(completeAudioFilePath)
    //     .create(recursive: true)
    //     .then((File file) async {
    //   //write to file
    //   Uint8List bytes = await file.readAsBytes();
    //   file.writeAsBytes(bytes);
    //   print("FILE CREATED AT : "+file.path);
    // });



    //   await _audioRecorder.start(
    //     path: completeAudioFilePath,
    //     encoder: AudioEncoder.aacLc, // by default
    //     bitRate: 128000, // by default
    //   );
    //   emit(RecordOn());
    // }

     //+++++++++++++++++++++++++++++++++++++++++++++++++++//


  }

  void stopRecording() async {
    String? path = await _audioRecorder.stopRecorder();
    emit(RecordStopped());
    if (path != null) {
      print('Output path $path');
      _sendAudioToServer(path);
    }
  }

  Future<void> _sendAudioToServer(String filePath) async {

    var url = Uri.parse('http://10.0.2.2:3000/api/v1/audio_recording');
    var request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('audio_data', filePath, filename: audioFileName, contentType: MediaType('audio', 'ogg')));
    var streamedResponse = await request.send();

    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      print("trying to print return");
      
      print(response.body);
      print('Audio Uploaded Successfully');
    } else {
      print(response.reasonPhrase);
      print(response.statusCode);
      print('Audio Upload Failed');
    }
  }

  // Future<Amplitude> getAmplitude() async {
  //   final amplitude = await _audioRecorder.getAmplitude();
  //   return amplitude;
  // }

  // Stream<double> aplitudeStream() async* {
  //   while (true) {
  //     await Future.delayed(Duration(
  //         milliseconds: RecorderConstants.amplitudeCaptureRateInMilliSeconds));
  //     final ap = await _audioRecorder.getAmplitude();
  //     yield ap.current;
  //   }
  // }
}