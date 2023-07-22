class Recording {
  final int id;
  final String transcription;
  final String audioUrl;
  final String comments;

  Recording({
    required this.id,
    required this.transcription,
    required this.audioUrl,
    required this.comments,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'],
      transcription: json['transcription'],
      audioUrl: json['audio_url'],
      comments: json['comments'],
    );
  }
}
