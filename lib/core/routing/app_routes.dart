import 'package:get/get.dart';
import 'package:soundcloud_flutter_app/features/audio_player/soundcloud_example_screen.dart';

class AppRoutes {
  static const initial = soundcloudExample;

  static const soundcloudExample = '/soundcloudExample';

  static final routes = [
    GetPage(
      name: soundcloudExample,
      page: () => const SoundCloudExampleScreen(),
    ),
  ];
}
