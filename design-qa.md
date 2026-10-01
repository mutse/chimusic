# Immersive player design QA

final result: passed

## Scope and evidence

Implemented in the existing Flutter application, not a replacement web mockup. Final comparison captured in the Codex in-app browser on 2026-09-25. Native device chrome is outside the comparison.

Source visual truth:
- Dark: `/Users/mutse/.codex/generated_images/01a0c42b-6c33-74a1-8ac8-d83755b946c3/exec-d54c690b-bd7e-45cd-be49-954b0825454a.png`
- Light: `/Users/mutse/.codex/generated_images/01a0c42b-6c33-74a1-8ac8-d83755b946c3/exec-5bbe2a01-cf0d-4a5e-8d4c-dd51a1cacf2a.png`

Implementation screenshots:
- `docs/design-qa/dark-final.png`
- `docs/design-qa/light-final.png`
- `docs/design-qa/history-resume.png` (interaction evidence before final spacing-only refinement)

Viewport: 390×844 logical/CSS pixels. Sources are 853×1844, normalized to 390×844. Browser screenshots are 390×844, effective screenshot density 1. Each comparison image places the normalized source on the left and the implementation on the right.

Full-view comparisons: `docs/design-qa/dark-comparison-final.jpg` and `docs/design-qa/light-comparison-final.jpg`.
Focused controls/copy comparisons: `docs/design-qa/dark-controls-comparison.jpg` and `docs/design-qa/light-controls-comparison.jpg`. Both were opened and reviewed alongside their source regions.

States match the selected mockups: dark “潮汐之间” at 02:18/04:36, light “日落以后” at 01:42/05:08, playing state. The light history item retains 02:16.

## Findings and iteration history

- Fixed P2: first light implementation pushed the local-save footer below the viewport. Reduced header sizing and vertical gaps. Final capture shows the complete history region and footer.
- Fixed P2: player transport sat too low relative to the source. Adjusted theme-specific spacing; source and final controls now occupy the same primary regions.
- Fixed P2: enlarged skip icons overflowed the 320-pixel phone layout by 10 pixels. Reduced internal button padding while retaining minimum touch target height. Both large-text small-phone tests pass.
- Fixed accessibility issue: pause/play exposed nested buttons. Combined the semantic action and label into one accessible control.
- Replaced duplicate foreground art behind dark controls with a subdued blurred treatment of the actual image.
- First dark screenshot accidentally captured settings; it is excluded from player fidelity judgments. Final dark screenshot is the full player.

No remaining actionable P0/P1/P2 UI findings.

## Required fidelity surfaces

- Typography: serif light headings and sans-serif dark hierarchy are present; titles and artists remain legible. Long titles wrap or truncate without hiding controls. Native font fallback can differ for characters outside the bundled serif subset.
- Spacing/layout: large square/record artwork, metadata, progress, transport and history remain in the reference order and proportions. At 390×844, neither theme clips bottom controls. Small displays and accessibility text scroll.
- Colors: deep blue-black/mint and ivory/rust-brown palettes remain distinct and consistent with their references. Dark background is intentionally subdued for readability.
- Images: individual generated ocean, vinyl and grass-cover PNGs are used, not rasterized UI. Real imported album art overrides fallback art. Regenerated photography is an art-direction match, not an identical crop of the mock. Generic fallback covers omit fictional printed album lettering.
- Copy/content: production uses actual track data. History copy describes automatic local saving rather than claiming a particular disk-write success. No dated footer is fabricated. Lyrics show an honest empty state when unavailable.

## Interaction and validation

Browser checked: pause/play state, opening history, resuming “昨日的风” at 02:16, theme change through the options menu, and opening the mobile player from its mini player. Latest browser error log query returned no errors.

Automated: complete suite 44 passed; after final spacing change, all 3 immersive-player tests passed. Tests cover theme persistence, seeking, playback pause, history resume, restoring a fresh controller, 320×568 viewport, 1.6× text and long titles. Final static analysis passed.

iOS simulator build passed earlier in this work. No real-device audio or store signing verification. Android package validation is blocked by an incomplete Gradle 8.14 distribution download (`zip END header not found`), separate from the visual QA result. Browser preview uses demonstration data with audio disabled and no production persistence.

## Follow-up polish

P3: the dark title and icon strokes are slightly heavier than the concept; the generated vinyl's reflections and ocean crop differ. These do not obstruct use or materially alter layout.

## Implementation checklist

- [x] Two selected visual themes integrated with Flutter playback controller.
- [x] Theme choice and history reuse local persistence.
- [x] History rows resume saved progress.
- [x] Real assets, readable states, accessible controls, small-phone regression checks.
- [x] Full-view and focused final comparisons.
- [ ] Android build verification after repairing Gradle download; physical-device audio checks.
