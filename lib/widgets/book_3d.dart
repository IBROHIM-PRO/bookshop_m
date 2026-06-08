import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    this.width = 110,
    this.height = 160,
    this.depth = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015) // perspective
        ..rotateY(-0.4) // ~23 degrees
        ..rotateX(0.05), // slight tilt
      alignment: Alignment.center,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Drop shadow at the bottom
            Positioned(
              bottom: -4,
              left: 5,
              right: 5,
              height: 10,
              child: Transform(
                transform: Matrix4.identity()..translate(0.0, 0.0, -depth / 2),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Back Cover
            Positioned.fill(
              child: Transform(
                transform: Matrix4.identity()..translate(0.0, 0.0, -depth / 2),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a2e),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            
            // Top Edge (Pages)
            Positioned(
              top: -depth / 2,
              left: 0,
              right: 0,
              height: depth,
              child: Transform(
                transform: Matrix4.identity()..rotateX(-math.pi / 2),
                alignment: Alignment.center,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFb8b8b8), Color(0xFFe8e8e8), Color(0xFFf5f5f0), Color(0xFFe8e8e8), Color(0xFFcccccc)],
                      stops: [0.0, 0.05, 0.5, 0.95, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom Edge (Pages)
            Positioned(
              bottom: -depth / 2,
              left: 0,
              right: 0,
              height: depth,
              child: Transform(
                transform: Matrix4.identity()..rotateX(math.pi / 2),
                alignment: Alignment.center,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFaaaaaa), Color(0xFFdddddd), Color(0xFFd5d0c8), Color(0xFFdddddd), Color(0xFFaaaaaa)],
                      stops: [0.0, 0.05, 0.5, 0.95, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            
            // Right Edge (Pages)
            Positioned(
              right: -depth / 2,
              top: 0,
              bottom: 0,
              width: depth,
              child: Transform(
                transform: Matrix4.identity()..rotateY(math.pi / 2),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFf8f6f0),
                    border: Border.all(color: Colors.black12, width: 0.5),
                  ),
                  child: Row(
                    children: List.generate(
                      5,
                      (index) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.black.withOpacity(0.03),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Spine (Left Edge)
            Positioned(
              left: -depth / 2,
              top: 0,
              bottom: 0,
              width: depth,
              child: Transform(
                transform: Matrix4.identity()..rotateY(-math.pi / 2),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade600,
                        Colors.grey.shade400,
                        Colors.grey.shade300,
                        Colors.grey.shade400,
                        Colors.grey.shade600,
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 0),
                        blurStyle: BlurStyle.inner,
                      )
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Front Cover
            Positioned.fill(
              child: Transform(
                transform: Matrix4.identity()..translate(0.0, 0.0, depth / 2),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    child: imageUrl != null && imageUrl!.startsWith('http')
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackCover(),
                          )
                        : _buildFallbackCover(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4338ca), Color(0xFF6366f1), Color(0xFF818cf8)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, color: Color(0xFFe0e7ff), size: 28),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFe0e7ff),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
