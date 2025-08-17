import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class SoundCloudPlayerWidget extends StatefulWidget {
  final String soundCloudUrl;

  const SoundCloudPlayerWidget({super.key, required this.soundCloudUrl});

  @override
  State<SoundCloudPlayerWidget> createState() => _SoundCloudPlayerWidgetState();
}

class _SoundCloudPlayerWidgetState extends State<SoundCloudPlayerWidget> {
  late final WebViewController _webController;
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _duration = 0.0;
  bool _isUserSeeking = false;
  String? _coverImageUrl;
  String? _trackTitle;
  String? _artistName;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebController();
  }

  void _initializeWebController() {
    // Create WebViewController with platform-specific configurations
    late final PlatformWebViewControllerCreationParams params;
    
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'isPlaying',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            setState(() {
              _isPlaying = message.message == 'true';
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'position',
        onMessageReceived: (JavaScriptMessage message) {
          if (!_isUserSeeking && mounted) {
            setState(() {
              _currentPosition = double.tryParse(message.message) ?? 0.0;
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'duration',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            setState(() {
              _duration = double.tryParse(message.message) ?? 0.0;
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'coverImage',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            setState(() {
              _coverImageUrl = message.message.isNotEmpty ? message.message : null;
              _isLoading = false;
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'trackInfo',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            final parts = message.message.split('|');
            setState(() {
              _trackTitle = parts.isNotEmpty ? parts[0] : null;
              _artistName = parts.length > 1 ? parts[1] : null;
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'error',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            setState(() {
              _errorMessage = message.message;
              _isLoading = false;
            });
          }
        },
      );

    // Platform-specific configurations
    if (_webController.platform is AndroidWebViewController) {
      (_webController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // Load the HTML content
    _loadHtmlContent();
  }

  Future<void> _loadHtmlContent() async {
    try {
      await _webController.loadHtmlString(_createSoundCloudEmbedHtml(widget.soundCloudUrl));
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load SoundCloud player: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _createSoundCloudEmbedHtml(String soundCloudUrl) {
    final String embedUrl = 'https://w.soundcloud.com/player/?url=${Uri.encodeComponent(soundCloudUrl)}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&visual=true';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { 
      margin: 0; 
      padding: 0; 
      background: transparent;
      overflow: hidden;
    }
    iframe { 
      border: none; 
      width: 100%;
      height: 100%;
      display: block;
    }
    .error {
      color: #ff4444;
      text-align: center;
      padding: 20px;
      font-family: Arial, sans-serif;
    }
  </style>
</head>
<body>
  <iframe id="soundcloud_widget"
    width="100%"
    height="100%"
    scrolling="no"
    frameborder="no"
    allow="autoplay; encrypted-media; gyroscope; picture-in-picture"
    sandbox="allow-scripts allow-same-origin allow-popups allow-presentation"
    src="$embedUrl">
  </iframe>
  
  <script>
    (function(){
      // Check if SoundCloud API is available
      let retryCount = 0;
      const maxRetries = 10;
      
      function initializeWidget() {
        if (typeof SC !== 'undefined' && SC.Widget) {
          setupWidget();
        } else if (retryCount < maxRetries) {
          retryCount++;
          setTimeout(initializeWidget, 500);
        } else {
          if (window.error) {
            window.error.postMessage('SoundCloud API failed to load');
          }
        }
      }
      
      function setupWidget() {
        try {
          var widget = SC.Widget("soundcloud_widget");
          var isReady = false;
          var initializationTimeout;

          // Set a timeout for initialization
          initializationTimeout = setTimeout(function() {
            if (!isReady && window.error) {
              window.error.postMessage('Widget initialization timeout');
            }
          }, 10000);

          // Clean control functions
          window.playTrack = function() {
            if (isReady) {
              widget.play();
              return true;
            }
            return false;
          };
          
          window.pauseTrack = function() {
            if (isReady) {
              widget.pause();
              return true;
            }
            return false;
          };
          
          window.stopTrack = function() {
            if (isReady) {
              widget.pause();
              widget.seekTo(0);
              return true;
            }
            return false;
          };
          
          window.seekToPosition = function(position) {
            if (isReady) {
              widget.seekTo(position);
              return true;
            }
            return false;
          };

          widget.bind(SC.Widget.Events.READY, function() {
            isReady = true;
            clearTimeout(initializationTimeout);

            // Get track info
            widget.getCurrentSound(function(currentSound) {
              if (currentSound) {
                // Send cover image URL
                if (window.coverImage) {
                  var artworkUrl = currentSound.artwork_url;
                  if (artworkUrl) {
                    // Convert to high resolution if available
                    artworkUrl = artworkUrl.replace('-large', '-t500x500');
                    window.coverImage.postMessage(artworkUrl);
                  } else {
                    window.coverImage.postMessage('');
                  }
                }
                
                // Send track info
                if (window.trackInfo) {
                  var trackInfo = (currentSound.title || 'Unknown') + '|' + (currentSound.user?.username || 'Unknown Artist');
                  window.trackInfo.postMessage(trackInfo);
                }
              }
            });

            // Get duration
            widget.getDuration(function(duration) {
              if (window.duration) {
                window.duration.postMessage(duration.toString());
              }
            });
            
            // Bind events
            widget.bind(SC.Widget.Events.PLAY, function() {
              if (window.isPlaying) {
                window.isPlaying.postMessage('true');
              }
            });
            
            widget.bind(SC.Widget.Events.PAUSE, function() {
              if (window.isPlaying) {
                window.isPlaying.postMessage('false');
              }
            });

            widget.bind(SC.Widget.Events.FINISH, function() {
              if (window.isPlaying) {
                window.isPlaying.postMessage('false');
              }
            });

            // Listen for position changes
            widget.bind(SC.Widget.Events.PLAY_PROGRESS, function(data) {
              if (window.position && data.currentPosition !== undefined) {
                window.position.postMessage(data.currentPosition.toString());
              }
            });

            // Handle errors
            widget.bind(SC.Widget.Events.ERROR, function() {
              if (window.error) {
                window.error.postMessage('SoundCloud player error occurred');
              }
            });
          });

        } catch (e) {
          if (window.error) {
            window.error.postMessage('Error initializing widget: ' + e.message);
          }
        }
      }

      // Load SoundCloud API
      if (!window.SC) {
        var script = document.createElement('script');
        script.src = 'https://w.soundcloud.com/player/api.js';
        script.onload = initializeWidget;
        script.onerror = function() {
          if (window.error) {
            window.error.postMessage('Failed to load SoundCloud API');
          }
        };
        document.head.appendChild(script);
      } else {
        initializeWidget();
      }
    })();
  </script>
</body>
</html>
''';
  }

  Future<void> play() async {
    try {
      final result = await _webController.runJavaScriptReturningResult('playTrack()');
      if (result == true) {
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      final result = await _webController.runJavaScriptReturningResult('pauseTrack()');
      if (result == true) {
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('Pause error: $e');
    }
  }

  Future<void> stop() async {
    try {
      final result = await _webController.runJavaScriptReturningResult('stopTrack()');
      if (result == true) {
        setState(() {
          _isPlaying = false;
          _currentPosition = 0.0;
        });
      }
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  Future<void> seekTo(int milliseconds) async {
    try {
      _isUserSeeking = true;
      final result = await _webController.runJavaScriptReturningResult('seekToPosition($milliseconds)');
      if (result == true) {
        setState(() {
          _currentPosition = milliseconds.toDouble();
        });
      }
      // Reset seeking flag after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isUserSeeking = false;
        }
      });
    } catch (e) {
      _isUserSeeking = false;
      debugPrint('Seek error: $e');
    }
  }

  String _formatDuration(double milliseconds) {
    if (milliseconds <= 0) return '0:00';
    final duration = Duration(milliseconds: milliseconds.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _coverImage(),
          SizedBox(height: 0, child: WebViewWidget(controller: _webController)),
          _progressBar(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(Icons.play_arrow, 'Play', Colors.blue, play),
              const SizedBox(width: 10),
              _buildControlButton(Icons.pause, 'Pause', Colors.green, pause),
              const SizedBox(width: 10),
              _buildControlButton(Icons.stop, 'Stop', Colors.red, stop),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No Cover Image',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverImage() {
    if (_errorMessage != null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _coverImageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholder();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.orange,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Track info overlay
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_trackTitle != null)
                          Text(
                            _trackTitle!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_artistName != null)
                          Text(
                            _artistName!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Play/Pause overlay button
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _isPlaying ? pause : play,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            ),
            child: Slider(
              value: _duration > 0
                  ? _currentPosition.clamp(0.0, _duration)
                  : 0.0,
              min: 0.0,
              max: _duration > 0 ? _duration : 1.0,
              activeColor: Colors.orange,
              inactiveColor: Colors.grey[300],
              onChangeStart: (value) {
                _isUserSeeking = true;
              },
              onChanged: (value) {
                setState(() {
                  _currentPosition = value;
                });
              },
              onChangeEnd: (value) {
                seekTo(value.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onPressed,
  ) {
    return TextButton.icon(
      icon: Icon(icon, color: onPressed != null ? color : Colors.grey),
      label: Text(
        label,
        style: TextStyle(color: onPressed != null ? Colors.black : Colors.grey),
      ),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: onPressed != null ? Colors.black : Colors.grey,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}