// import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart';

// class AudioPlayerWidget extends StatefulWidget {
//   final String url;

//   AudioPlayerWidget({required this.url});

//   @override
//   _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
// }

// class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
//   late AudioPlayer audioPlayer;
//   bool isPlaying = false;
//   Duration currentTime = Duration();
//   Duration completeTime = Duration();

//   @override
//   void initState() {
//     super.initState();
//     audioPlayer = AudioPlayer();
//     audioPlayer.onAudioPositionChanged.listen((Duration duration) {
//       setState(() {
//         currentTime = duration;
//       });
//     });

//     audioPlayer.onDurationChanged.listen((Duration duration) {
//       setState(() {
//         completeTime = duration;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     audioPlayer.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: <Widget>[
//         Slider(
//           value: currentTime.inSeconds.toDouble(),
//           min: 0.0,
//           max: completeTime.inSeconds.toDouble(),
//           onChanged: (value) {
//             seekToSecond(value.toInt());
//             currentTime = Duration(seconds: value.toInt());
//           },
//         ),
//         Text(
//             "${currentTime.toString().split(".")[0]} / ${completeTime.toString().split(".")[0]}"),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             IconButton(
//               onPressed: () async {
//                 if (!isPlaying) {
//                   print(widget.url);
//                   int result = await audioPlayer.play(widget.url);
//                   if (result == 1) {
//                     setState(() {
//                       isPlaying = true;
//                     });
//                   }
//                 } else {
//                   int result = await audioPlayer.pause();
//                   if (result == 1) {
//                     setState(() {
//                       isPlaying = false;
//                     });
//                   }
//                 }
//               },
//               icon: isPlaying ? Icon(Icons.pause) : Icon(Icons.play_arrow),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void seekToSecond(int second) {
//     Duration newDuration = Duration(seconds: second);

//     audioPlayer.seek(newDuration);
//   }
// }
