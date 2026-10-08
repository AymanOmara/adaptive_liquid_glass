# Gemini's answer (2026-10-08) to gemini-fidelity-question.md — verbatim equations

Source claims about Apple internals are unverified; treat every item as a hypothesis.

1. Linear light: un-gamma the backdrop before lens, tone, saturation; re-encode at the end.
2. Compressive vibrancy (use the code form, not the text form):
   Y = 0.2126R+0.7152G+0.0722B (linear); C = rgb - Y; gain = 1/(1 + k_vib*|C|), k_vib ~1.5-2.5
   C_vibrant = Y + C*(1 + S_boost*gain)
3. Luma-keyed tone LUT: C_base = ToneLUT(Y_local, family) instead of a fixed grey ramp.
4. Gated ambient: C_ambient = (C_wide - Y_wide) * k_amb * (1 - tintStrength) * K_family
   K_family = 1 rect/capsule, 0 fully tinted; merges K = clamp(Area_union/Area_bbox, 0.5, 1).
   Fill = C_base + C_ambient.
5. Merged shapes: size terms from the union: R_eff = sqrt(Area_union/pi) (Gemini wrote it without
   the sqrt; dimensionally the sqrt is needed), applied uniformly across the neck.
6. Clear edge over text: w_band = exp(-(d/sigma_edge)^2), sigma_edge ~1.2-1.4 pt;
   C_lens = mix(C_blur(uv_lens), C_sharp(uv_lens), w_band*k_sharp), k_sharp ~0.45-0.65 clear only.
7. Metric: rejected as a gate (keeps SSIM>=0.97, dE<=2.0); blurred-SSIM may be a diagnostic column.
