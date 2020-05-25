import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import '../theme/theme.dart';
import 'cache/neumorphic_painter_cache.dart';
import 'neumorphic_box_decoration_helper.dart';
import 'neumorphic_emboss_decoration_painter.dart';

class NeumorphicDecorationTextPainter extends BoxPainter {
  final NeumorphicStyle style;
  final String text;
  final TextStyle textStyle;
  final TextAlign textAlign;

  NeumorphicPainterCache _cache;

  Paint _backgroundPaint;
  Paint _whiteShadowPaint;
  Paint _whiteShadowMaskPaint;
  Paint _blackShadowPaint;
  Paint _blackShadowMaskPaint;
  Paint _gradientPaint;
  Paint _borderPaint;

  ui.Paragraph _textParagraph;
  ui.Paragraph _innerTextParagraph;
  ui.Paragraph _whiteShadowParagraph;
  ui.Paragraph _whiteShadowMaskParagraph;
  ui.Paragraph _blackShadowTextParagraph;
  ui.Paragraph _blackShadowTextMaskParagraph;
  ui.Paragraph _gradientParagraph;

  void generatePainters() {
    this._backgroundPaint = Paint();
    this._whiteShadowPaint = Paint();
    this._whiteShadowMaskPaint = Paint()..blendMode = BlendMode.dstOut;
    this._blackShadowPaint = Paint();
    this._blackShadowMaskPaint = Paint()..blendMode = BlendMode.dstOut;
    this._gradientPaint = Paint();

    this._borderPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.bevel
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.border.width
      ..color = style.border.color;
  }

  final bool drawGradient;
  final bool drawShadow;
  final bool drawBackground;
  final bool renderingByPath;

  NeumorphicDecorationTextPainter({
    @required this.style,
    @required this.textStyle,
    @required this.text,
    @required this.drawGradient,
    @required this.drawShadow,
    @required this.drawBackground,
    @required VoidCallback onChanged,
    this.renderingByPath = true,
    @required this.textAlign,
  }) : super(onChanged);

  void _updateCache(Offset offset, ImageConfiguration configuration) {
    if (_cache == null) {
      _cache = NeumorphicPainterCache();
      generatePainters();
    } else {
      //print("reuse painter");
    }

    final bool invalidateSize =
        this._cache.updateSize(newOffset: offset, newSize: configuration.size);

    final bool invalidateLightSource = this
        ._cache
        .updateLightSource(style.lightSource, style.oppositeShadowLightSource);
    final bool invalidateColor = this._cache.updateStyleColor(style.color);
    if (invalidateColor) {
      _backgroundPaint..color = _cache.backgroundColor;
    }

    final bool invalidateDepth = this._cache.updateStyleDepth(style.depth, 3);
    if (invalidateDepth) {
      _blackShadowPaint..maskFilter = _cache.maskFilterBlur;
      _whiteShadowPaint..maskFilter = _cache.maskFilterBlur;
    }

    final bool invalidateShadowColors = this._cache.updateShadowColor(
          newShadowLightColorEmboss: style.shadowLightColor,
          newShadowDarkColorEmboss: style.shadowDarkColor,
          newIntensity: style.intensity,
        );
    if (invalidateShadowColors) {
      _whiteShadowPaint..color = _cache.shadowLightColor;
      _blackShadowPaint..color = _cache.shadowDarkColor;
    }

    final constraints = ui.ParagraphConstraints(width: _cache.width);
    final paragraphStyle = textStyle.getParagraphStyle(
        textDirection: TextDirection.ltr, textAlign: this.textAlign);

    final textParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _borderPaint,
      ))
      ..addText(text);

    final innerTextParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _backgroundPaint,
      ))
      ..addText(text);

    final whiteShadowParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _whiteShadowPaint,
      ))
      ..addText(text);

    final whiteShadowMaskParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _whiteShadowMaskPaint,
      ))
      ..addText(text);

    final blackShadowParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _blackShadowPaint,
      ))
      ..addText(text);

    final blackShadowMaskParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _blackShadowMaskPaint,
      ))
      ..addText(text);

    _textParagraph = textParagraphBuilder.build()..layout(constraints);
    _innerTextParagraph = innerTextParagraphBuilder.build()
      ..layout(constraints);

    _whiteShadowParagraph = whiteShadowParagraphBuilder.build()
      ..layout(constraints);
    _whiteShadowMaskParagraph = whiteShadowMaskParagraphBuilder.build()
      ..layout(constraints);

    _blackShadowTextParagraph = blackShadowParagraphBuilder.build()
      ..layout(constraints);
    _blackShadowTextMaskParagraph = blackShadowMaskParagraphBuilder.build()
      ..layout(constraints);

    //region gradient
    final gradientParagraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        foreground: _gradientPaint
          ..shader = getGradientShader(
            gradientRect: Rect.fromLTRB(0, 0, _cache.width, _cache.height),
            intensity: style.surfaceIntensity,
            source: style.shape == NeumorphicShape.concave
                ? this.style.lightSource
                : this.style.lightSource.invert(),
          ),
      ))
      ..addText(text);

    _gradientParagraph = gradientParagraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: _cache.width));
    //endregion

    if (invalidateDepth || invalidateLightSource) {
      _cache.updateDepthOffset();
    }

    if (invalidateLightSource || invalidateDepth || invalidateSize) {
      _cache.updateTranslations();
    }
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    _updateCache(offset, configuration);

    _drawShadow(offset: offset, canvas: canvas, path: _cache.path);

    _drawElement(offset: offset, canvas: canvas, path: _cache.path);
  }

  void _drawElement({Canvas canvas, Offset offset, Path path}) {
    if (true) {
      _drawBackground(offset: offset, canvas: canvas, path: path);
    }
    if (this.drawGradient) {
      _drawGradient(offset: offset, canvas: canvas, path: path);
    }
    if (style.border != null && style.border.isEnabled) {
      _drawBorder(canvas: canvas, offset: offset, path: path);
    }
  }

  void _drawBorder({Canvas canvas, Offset offset, Path path}) {
    if (style.border.width > 0) {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawParagraph(_textParagraph, Offset.zero)
        ..restore();
    }
  }

  void _drawBackground({Canvas canvas, Offset offset, Path path}) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawParagraph(_innerTextParagraph, Offset.zero)
      ..restore();
  }

  void _drawShadow({Canvas canvas, Offset offset, Path path}) {
    if (style.depth.abs() >= 0.1) {
      canvas
        ..saveLayer(_cache.layerRect, _whiteShadowPaint)
        ..translate(offset.dx + _cache.depthOffset.dx,
            offset.dy + _cache.depthOffset.dy)
        ..drawParagraph(_whiteShadowParagraph, Offset.zero)
        ..translate(-_cache.depthOffset.dx, -_cache.depthOffset.dy)
        ..drawParagraph(_whiteShadowMaskParagraph, Offset.zero)
        ..restore();

      canvas
        ..saveLayer(_cache.layerRect, _blackShadowPaint)
        ..translate(offset.dx - _cache.depthOffset.dx,
            offset.dy - _cache.depthOffset.dy)
        ..drawParagraph(_blackShadowTextParagraph, Offset.zero)
        ..translate(_cache.depthOffset.dx, _cache.depthOffset.dy)
        ..drawParagraph(_blackShadowTextMaskParagraph, Offset.zero)
        ..restore();
    }
  }

  void _drawGradient({Canvas canvas, Offset offset, Path path}) {
    if (style.shape == NeumorphicShape.concave ||
        style.shape == NeumorphicShape.convex) {
      canvas
        ..saveLayer(_cache.layerRect, _gradientPaint)
        ..translate(offset.dx, offset.dy)
        ..drawParagraph(_gradientParagraph, Offset.zero)
        ..restore();
    }
  }
}
