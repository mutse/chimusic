# ChiMusic Liquid Glass UI

## Visual Direction

The interface is inspired by Apple-style liquid glass, but translated into an original music product identity:

- sea-glass and midnight gradients instead of flat dark fills
- layered translucent surfaces with soft white strokes
- luminous highlights that make panels feel suspended above the background
- rounded geometry with generous radii
- subtle motion for hover, press, and panel transitions

## Palette

- background ink: `#07111E`
- deep cyan: `#0E3A4C`
- aqua glow: `#4CC9D9`
- mint glass: `#9FE7D7`
- coral accent: `#FF8D78`
- frosted white: `rgba(255,255,255,0.18)`

## Component System

### Glass panel

- blurred backdrop
- tinted gradient fill
- 1 px translucent border
- soft outer shadow plus inner highlight

### Pills and chips

- compact rounded capsules
- active state uses a brighter tint and stronger border
- used for mood filters, library filters, and small metadata tags

### Artwork cards

- generated gradient covers for a cohesive demo library
- stacked text aligned to the lower edge
- hover or press subtly lifts the surface

### Navigation

- bottom bar on phones behaves like floating frosted glass
- side rail on desktop keeps labels visible and anchors the app
- active destination uses a brighter glass fill

### Player

- mini player floats above content instead of docking hard to the bottom edge
- full player uses oversized art, large progress treatment, and glass control clusters
- queue preview stays visible so playback feels connected to the library

## Interaction Notes

- cards animate between `1.0` and `1.02` scale on hover or press
- major content sections fade and slide in when the tab changes
- the now playing view expands from the mini player affordance
- desktop surfaces use a little more density while mobile keeps stronger separation
