# adaptive_liquid_glass

A new Flutter plugin project.

## Fidelity

The shipped glass constants are certified against Apple's SwiftUI
`.glassEffect` on the reference simulator (iPhone 17 Pro, iOS 26.4):
**46/75 scenes pass** the official bars (SSIM ≥ 0.97, CIEDE2000 ΔE ≤ 2.0),
median SSIM 0.9828 / median ΔE 1.09, min SSIM 0.9532, **0 scenes below
SSIM 0.95** on the 75 in-set scenes (a 48-scene held-out set the fit never
saw scores 18/48, min 0.9470). Model↔Flutter parity is 75/75. The full
per-scene record, diagnosis and known residuals:
`docs/superpowers/notes/fidelity-status.md`.

To re-run, follow `tool/fidelity/README.md`: capture both renderers with
`tool/fidelity/capture.sh build/fidelity/<run>` (setup and options
documented there), then score with
`tool/fidelity/.venv/bin/python tool/fidelity/compare.py build/fidelity/<run>`.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

