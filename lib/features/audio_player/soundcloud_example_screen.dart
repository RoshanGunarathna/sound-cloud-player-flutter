import 'package:flutter/material.dart';

import 'package:soundcloud_flutter_app/features/audio_player/soundcloud_player_widget.dart';

class SoundCloudExampleScreen extends StatelessWidget {
  const SoundCloudExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SoundCloud Example')),
      body: const SoundCloudPlayerWidget(
        // soundCloudUrl:
        //     'https://soundcloud.com/mahamevnawalk/metta-meditation-chanting',
        soundCloudUrl:
            'https://soundcloud.com/shewon-nimshara/sets/sinhala-songs?si=2c9766229bb04bd6ac7413b8ca53d41c&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing',
      ),
      floatingActionButton: null,
    );
  }
}
