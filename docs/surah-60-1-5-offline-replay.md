# Surah 60:1–5 deterministic offline replay

Date: 2026-07-19

## Result

The ASR recognized the recitation well enough to cover 139 of 140 expected words, and the locator ultimately reached `60:5:13`. The main defect is neither model quality nor compute capacity: it is a locator continuity error around a repeated phrase in ayah 1.

At 11.835 s, progress correctly reached `60:1:12`. At 12.348 s, a two-word match for the repeated phrase `اليهم بالمودة` incorrectly advanced progress to its later occurrence at `60:1:36`. That skipped 24 words visually. The locator then did not advance again until `60:1:38` at 27.703 s, a 15.356 s stall.

Classification: **other — correct current transcript, incorrect advancing locator match**. This is a locator candidate-selection/continuity bug, not a normalization `no_match` and not primarily a model/decoder problem.

## Method

- Source: the supplied 97.408 s AAC/M4A file, mono at 48 kHz.
- Replay input: temporary mono 16 kHz PCM conversion; audited duration 97.364 s.
- Production-style rolling replay: 1.0 s minimum window, 0.25 s inference interval, 5.0 s maximum window.
- 377 deterministic windows through the current ONNX model, normalizer, and locator.
- The source audio was not changed. The temporary WAV and transcript-bearing JSON were removed after measurement; this report retains only aggregate metrics and Quran reference positions.

## Timing

| Measurement | Result |
|---|---:|
| Focused test wall time | 24.375 s |
| Summed ASR processing time | 23.469 s |
| Processing / audio duration | 0.241× realtime |
| First transcript | 1.046 s |
| First provisional highlight | none; authoritative progress arrived first |
| First authoritative highlight | 5.952 s (`60:1:4`) |
| Replay cadence, p50 / p95 | 255.938 / 255.938 ms |
| Per-window total, p50 / p95 / max | 62.947 / 65.131 / 72.509 ms |
| Feature extraction, p50 / p95 | 36.969 / 38.200 ms |
| ONNX inference, p50 / p95 | 20.641 / 22.195 ms |
| Decode, p50 / p95 | 5.220 / 5.449 ms |

The pipeline consumes about one quarter of the available 250 ms cadence budget. Feature extraction is the largest compute component, but it is not the user-visible bottleneck in this recording.

## Progress milestones

| Ayah | First applied progress | Final applied progress |
|---|---:|---:|
| 60:1 | `60:1:4` at 5.952 s | `60:1:49` at 34.871 s |
| 60:2 | `60:2:2` at 37.685 s | `60:2:13` at 44.852 s |
| 60:3 | `60:3:3` at 47.410 s | `60:3:13` at 53.811 s |
| 60:4 | `60:4:4` at 56.369 s | `60:4:52` at 89.129 s |
| 60:5 | `60:5:5` at 91.689 s | `60:5:13` at 96.551 s |

Locator outcomes across 377 windows: 79 `progress_applied`, 189 `not_advancing`, 78 `no_match`, and 31 `fresh_evidence_required`.

The merged rolling transcript has 139/140 expected-word LCS recall (99.29%). Its aggregate precision and WER are intentionally not used: each rolling window repeats prior words, so concatenating all window transcripts inflates insertions.

## Bottleneck and next step

Add one focused regression test for the first and second occurrences of `اليهم بالمودة` in 60:1. After accepting through word 12, replaying a rolling suffix that still describes the first occurrence must return `notAdvancing`, not jump to words 35–36.

Then make the smallest locator change that prefers continuity near the accepted offset and requires intervening or stronger fresh evidence before accepting a distant repeated two-word candidate. Re-run this fixture with these success criteria:

- no `60:1:12` → `60:1:36` jump;
- normal progress through words 13 onward without the 15.356 s stall;
- final progress still reaches `60:5:13`;
- full `swift test` and `swift build` remain green.

Defer more CPU/render optimization and the 0.15 s cadence change. There is ample processing headroom, and a faster cadence would reproduce the same incorrect jump sooner rather than fix it.
