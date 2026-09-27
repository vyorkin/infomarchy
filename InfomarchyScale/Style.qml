pragma Singleton

import QtQuick
import qs.Commons as Base

// Infomarchy's own UI scale.
//
// The dashboard's QML imports this module *after* `qs.Commons`, so inside the
// plugin the name `Style` means this wrapper instead of Omarchy's shell-wide
// singleton: the same tokens, multiplied by `uiScale`. Nothing outside the
// plugin moves — the bar, menus and notifications keep the stock tokens and
// the stock `omarchy display text size`.
//
// Every token below is a real pixel size, so the shell rasterises the larger
// text at its final size. The earlier approach (zooming the whole window with
// an `Item.scale`) magnified a texture instead and made glyphs soft; token
// scaling keeps them crisp.
//
// The property list mirrors exactly what the dashboard reads. Re-derive it
// after adding a token with:
//   grep -oh 'Style\.[A-Za-z0-9.]*' InfoView.qml Apps.qml Overlay.qml | sort -u
QtObject {
  id: root

  // Bump to make the desk larger. 1.0 is the shell's stock size.
  readonly property real uiScale: 1.5

  function px(value) {
    var n = Number(value)
    return isFinite(n) && n > 0 ? Math.max(1, Math.round(n * uiScale)) : 0
  }

  readonly property real fontScale: Base.Style.fontScale * uiScale
  readonly property string resolvedFontFamily: Base.Style.resolvedFontFamily
  readonly property int cornerRadius: px(Base.Style.cornerRadius)

  readonly property QtObject font: QtObject {
    readonly property int caption: root.px(Base.Style.font.caption)
    readonly property int bodySmall: root.px(Base.Style.font.bodySmall)
    readonly property int body: root.px(Base.Style.font.body)
    readonly property int subtitle: root.px(Base.Style.font.subtitle)
  }

  readonly property QtObject spacing: QtObject {
    readonly property int xs: root.px(Base.Style.spacing.xs)
    readonly property int sm: root.px(Base.Style.spacing.sm)
    readonly property int md: root.px(Base.Style.spacing.md)
    readonly property int lg: root.px(Base.Style.spacing.lg)
    readonly property int xl: root.px(Base.Style.spacing.xl)
  }
}
