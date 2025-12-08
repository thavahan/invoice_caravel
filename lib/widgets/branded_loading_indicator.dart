import 'package:flutter/material.dart';

/// Professional branded loading indicator with Caravel logo
/// Shows centered logo with rotating progress circle in transparent overlay
class BrandedLoadingIndicator extends StatelessWidget {
  /// Logo size (width and height)
  final double logoSize;

  /// Progress circle size
  final double circleSize;

  /// Progress circle stroke width
  final double strokeWidth;

  /// Background color (defaults to theme scaffold background)
  final Color? backgroundColor;

  /// Progress circle color (defaults to theme primary color)
  final Color? progressColor;

  /// Create a branded loading indicator
  const BrandedLoadingIndicator({
    Key? key,
    this.logoSize = 45.0,
    this.circleSize = 60.0,
    this.strokeWidth = 3.0,
    this.backgroundColor,
    this.progressColor,
  }) : super(key: key);

  /// Large variant for main screens
  const BrandedLoadingIndicator.large({
    Key? key,
    this.logoSize = 60.0,
    this.circleSize = 80.0,
    this.strokeWidth = 4.0,
    this.backgroundColor,
    this.progressColor,
  }) : super(key: key);

  /// Small variant for inline loading
  const BrandedLoadingIndicator.small({
    Key? key,
    this.logoSize = 30.0,
    this.circleSize = 45.0,
    this.strokeWidth = 2.0,
    this.backgroundColor,
    this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Caravel Logo
            Image.asset(
              'asset/images/brand_logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
            // Rotating progress circle around logo
            SizedBox(
              width: circleSize,
              height: circleSize,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressColor ?? Theme.of(context).primaryColor,
                ),
                strokeWidth: strokeWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline branded loading widget (without Scaffold)
/// Use this for embedding within existing layouts
class BrandedLoadingWidget extends StatelessWidget {
  /// Logo size (width and height)
  final double logoSize;

  /// Progress circle size
  final double circleSize;

  /// Progress circle stroke width
  final double strokeWidth;

  /// Progress circle color (defaults to theme primary color)
  final Color? progressColor;

  /// Create an inline branded loading widget
  const BrandedLoadingWidget({
    Key? key,
    this.logoSize = 45.0,
    this.circleSize = 60.0,
    this.strokeWidth = 3.0,
    this.progressColor,
  }) : super(key: key);

  /// Small inline variant
  const BrandedLoadingWidget.small({
    Key? key,
    this.logoSize = 24.0,
    this.circleSize = 36.0,
    this.strokeWidth = 2.0,
    this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Caravel Logo
        Image.asset(
          'asset/images/brand_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
        // Rotating progress circle around logo
        SizedBox(
          width: circleSize,
          height: circleSize,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              progressColor ?? Theme.of(context).primaryColor,
            ),
            strokeWidth: strokeWidth,
          ),
        ),
      ],
    );
  }
}
