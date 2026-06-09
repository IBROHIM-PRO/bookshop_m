import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';

/// 3D Book Widget that looks like a premium hardcover book.
/// Shows the front cover with spine crease, top pages, and right-side pages.
class Book3D extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final double width;
  final double height;
  final double depth;

  const Book3D({
    Key? key,
    this.imageUrl,
    required this.title,
    this.width = 150.0,
    this.height = 230.0,
    this.depth = 28.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Dynamic theme-adaptive styling
    final bookColor = isDarkMode ? const Color(0xFF2C2C35) : const Color(0xFFF9F9FB);
    final pagesColor = isDarkMode ? const Color(0xFF22222A) : const Color(0xFFF7F4EB);
    final pagesLineColor = isDarkMode ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.18);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final coverBorderColor = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return SizedBox(
      width: width + depth * 1.5 + 16.0,
      height: height + depth * 2.5 + 20.0,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Realistic Ground Shadow
          Transform(
            transform: Matrix4.identity()
              ..translate(-width * 0.06, height * 0.5, 0.0)
              ..rotateX(1.35)
              ..rotateZ(-0.28),
            child: Container(
              width: width * 1.15,
              height: depth * 2.8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  // Sharp contact shadow (directly beneath the book base)
                  BoxShadow(
                    color: isDarkMode 
                        ? Colors.black.withOpacity(0.9) 
                        : Colors.black.withOpacity(0.38),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                  // Soft wide ambient shadow (spreads out)
                  BoxShadow(
                    color: isDarkMode 
                        ? Colors.black.withOpacity(0.65) 
                        : Colors.black.withOpacity(0.18),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),

          // 2. The 3D Book Model
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateX(0.12)         // Tilt to see top
              ..rotateY(-0.35),       // Rotate to see right side
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // A. Back Cover Board (translated back in Z)
                Transform(
                  transform: Matrix4.identity()..translate(0.0, 0.0, -depth),
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: bookColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(3),
                        bottomRight: Radius.circular(3),
                      ),
                      border: Border.all(color: coverBorderColor, width: 0.5),
                    ),
                  ),
                ),

                // B. Right Edge Pages (rotated and positioned inside cover)
                Positioned(
                  right: 3,
                  top: 4,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(0.0, 0.0, -0.5)
                      ..rotateY(math.pi / 2),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: depth - 1,
                      height: height - 8,
                      decoration: BoxDecoration(
                        color: pagesColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                      child: _buildPageLines(Axis.vertical, pagesLineColor),
                    ),
                  ),
                ),

                // C. Top Edge Pages (rotated and positioned inside cover)
                Positioned(
                  top: 4 - (depth - 1),
                  left: 12,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(0.0, 0.0, -0.5)
                      ..rotateX(math.pi / 2),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: width - 15,
                      height: depth - 1,
                      decoration: BoxDecoration(
                        color: pagesColor,
                      ),
                      child: _buildPageLines(Axis.horizontal, pagesLineColor),
                    ),
                  ),
                ),

                // D. Front Cover Board
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: bookColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                    border: Border.all(color: coverBorderColor, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Base Cover Image
                        _buildCoverImage(context, theme, textColor),

                        // Spine Hinge/Crease shadow overlay
                        Positioned(
                          left: 11,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.white.withOpacity(0.1),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        
                        // Left-side spine gradient highlight (simulating rounded spine joint)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 11,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.08),
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),

                        // 3D reflection highlight across the entire cover
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.12),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageLines(Axis axis, Color lineColor) {
    return axis == Axis.vertical
        ? Row(
            children: List.generate(
              22,
              (i) => Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: lineColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : Column(
            children: List.generate(
              22,
              (i) => Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: lineColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildCoverImage(BuildContext context, ThemeData theme, Color textColor) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context, theme, textColor),
        errorWidget: (context, url, error) => _buildPlaceholder(context, theme, textColor),
      );
    }
    return _buildPlaceholder(context, theme, textColor);
  }

  Widget _buildPlaceholder(BuildContext context, ThemeData theme, Color textColor) {
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            color: textColor.withOpacity(0.3),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Serif',
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.8),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alias for backward compatibility with previous code.
typedef VerticalBook3D = Book3D;
