import 'package:flutter/material.dart';

import 'package:universal_io/io.dart';



import '../core/platform/platform_storage.dart';

import '../core/theme/design_tokens.dart';

import '../core/theme/theme_surfaces.dart';



/// Local file or remote URL for comparison slider images.

class ComparisonImageSource {

  const ComparisonImageSource._({this.filePath, this.networkUrl});



  const ComparisonImageSource.file(String path)

      : this._(filePath: path);



  const ComparisonImageSource.network(String url)

      : this._(networkUrl: url);



  final String? filePath;

  final String? networkUrl;



  bool get isAvailable {

    if (filePath != null) {

      return PlatformStorage.supportsLocalFileSystem &&

          File(filePath!).existsSync();

    }

    return networkUrl != null && networkUrl!.isNotEmpty;

  }

}



/// Draggable before/after image comparison using the user's staged files.

class ComparisonSlider extends StatefulWidget {

  const ComparisonSlider({

    super.key,

    required this.beforeImage,

    required this.afterImage,

    this.height = 320,

    this.beforeLabel = 'ORIGINAL',

    this.afterLabel = 'CLEANED',

  });



  final ComparisonImageSource beforeImage;

  final ComparisonImageSource afterImage;

  final double height;

  final String beforeLabel;

  final String afterLabel;



  @override

  State<ComparisonSlider> createState() => _ComparisonSliderState();

}



class _ComparisonSliderState extends State<ComparisonSlider> {

  double _position = 0.5;



  @override

  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;

    final handleColor = colorScheme.surface;

    final dividerColor = colorScheme.onSurface;



    return ClipRRect(

      borderRadius: BorderRadius.circular(AppRadius.lg),

      child: SizedBox(

        height: widget.height,

        width: double.infinity,

        child: LayoutBuilder(

          builder: (context, constraints) {

            final width = constraints.maxWidth;

            final dividerX = width * _position;



            return Stack(

              fit: StackFit.expand,

              children: [

                _ComparisonImage(

                  source: widget.afterImage,

                  alignment: Alignment.centerRight,

                ),

                ClipRect(

                  clipper: _LeftClipper(dividerX),

                  child: _ComparisonImage(

                    source: widget.beforeImage,

                    alignment: Alignment.centerLeft,

                  ),

                ),

                Positioned(

                  left: dividerX - 1,

                  top: 0,

                  bottom: 0,

                  child: Container(

                    width: 2,

                    color: dividerColor.withValues(alpha: 0.9),

                  ),

                ),

                Positioned(

                  left: dividerX - 16,

                  top: 0,

                  bottom: 0,

                  child: Center(

                    child: GestureDetector(

                      onHorizontalDragUpdate: (details) {

                        setState(() {

                          _position = ((_position * width) + details.delta.dx) /

                              width;

                          _position = _position.clamp(0.08, 0.92);

                        });

                      },

                      child: Container(

                        width: 32,

                        height: 32,

                        decoration: BoxDecoration(

                          color: handleColor,

                          shape: BoxShape.circle,

                          boxShadow: [

                            BoxShadow(

                              color: Colors.black.withValues(alpha: 0.12),

                              blurRadius: 8,

                              offset: const Offset(0, 2),

                            ),

                          ],

                        ),

                        child: Icon(

                          Icons.swap_horiz_rounded,

                          color: colorScheme.onSurface,

                          size: 20,

                        ),

                      ),

                    ),

                  ),

                ),

                Positioned(

                  top: AppSpacing.x4,

                  left: AppSpacing.x4,

                  child: _ComparisonLabel(text: widget.beforeLabel),

                ),

                Positioned(

                  top: AppSpacing.x4,

                  right: AppSpacing.x4,

                  child: _ComparisonLabel(text: widget.afterLabel),

                ),

              ],

            );

          },

        ),

      ),

    );

  }

}



class _ComparisonLabel extends StatelessWidget {

  const _ComparisonLabel({required this.text});



  final String text;



  @override

  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;



    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: AppSpacing.x4,

        vertical: AppSpacing.x2,

      ),

      decoration: BoxDecoration(

        color: ThemeSurfaces.cardElevated(context).withValues(alpha: 0.92),

        borderRadius: BorderRadius.circular(AppRadius.full),

      ),

      child: Text(

        text,

        style: Theme.of(context).textTheme.labelSmall?.copyWith(

              color: colorScheme.onSurface,

              letterSpacing: 0.4,

              fontWeight: FontWeight.w600,

            ),

      ),

    );

  }

}



class _ComparisonImage extends StatelessWidget {

  const _ComparisonImage({

    required this.source,

    required this.alignment,

  });



  final ComparisonImageSource source;

  final Alignment alignment;



  @override

  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    final path = source.filePath;

    if (path != null &&

        PlatformStorage.supportsLocalFileSystem &&

        File(path).existsSync()) {

      final file = File(path);
      final stamp = file.existsSync()
          ? file.lastModifiedSync().millisecondsSinceEpoch
          : 0;
      return ColoredBox(
        color: surface,
        child: Image.file(
          file,
          key: ValueKey('img-$path-$stamp'),
          fit: BoxFit.contain,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          // Bust Flutter's ImageCache when the same logical preview is rewritten.
          cacheWidth: null,
          errorBuilder: (context, error, stackTrace) => _Unavailable(context),
        ),
      );

    }



    final url = source.networkUrl;

    if (url != null && url.isNotEmpty) {

      return ColoredBox(
        color: surface,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) => _Unavailable(context),
        ),
      );

    }



    return _Unavailable(context);

  }

}



class _Unavailable extends StatelessWidget {

  const _Unavailable(this.context);



  final BuildContext context;



  @override

  Widget build(BuildContext _) {

    return ColoredBox(

      color: Theme.of(context).colorScheme.surfaceContainerHighest,

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Icon(

            Icons.image_not_supported_outlined,

            size: 40,

            color: Theme.of(context).colorScheme.onSurfaceVariant,

          ),

          const SizedBox(height: AppSpacing.x2),

          Text(

            'Preview unavailable',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ],

      ),

    );

  }

}



class _LeftClipper extends CustomClipper<Rect> {

  _LeftClipper(this.width);



  final double width;



  @override

  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);



  @override

  bool shouldReclip(covariant _LeftClipper oldClipper) =>

      oldClipper.width != width;

}

