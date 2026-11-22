# TajweedFormer v4 for Hifz Tracker

November 22, 2026 · App source `c4418c2` · Model version 4.0.0

Keep FastConformer for live word highlighting. It made fewer word errors on the same recordings, and the app’s locator reached the final word more often with its transcripts. TajweedFormer is a candidate for optional pronunciation feedback on a known ayah. Its higher rate of false alarms matters for learners who recite correctly.

## Word tracking

Quran Lab evaluated the upstream FastConformer checkpoint and TajweedFormer on 1,780 correct studio recitations from 16 reciters, then on phone versions of the same takes. The 3,560 inputs cover 748 distinct ayahs. I paired the two prediction files by recording ID and audio condition and checked that the ayah and reference text agreed on every pair. The word error rates below reproduce the published scores from the per-recording error counts. Quran Lab has yet to check FastConformer’s training data for overlap with these studio recordings. [FastConformer predictions][fc] · [V4 predictions][v4] · [Benchmark scores and method][board]

| Measure | FastConformer | TajweedFormer v4 |
| --- | ---: | ---: |
| Word error rate, studio | 0.52% | 2.06% |
| Word error rate, phone | 1.21% | 6.38% |
| Word error rate, both conditions | 0.86% | 4.22% |
| App locator reached final word, studio | 1,756 / 1,780 (98.7%) | 1,683 / 1,780 (94.6%) |
| App locator reached final word, phone | 1,728 / 1,780 (97.1%) | 1,526 / 1,780 (85.7%) |

The WER calculation pools 24,344 reference words across the two conditions. FastConformer made 210 word errors and v4 made 1,028. The benchmark converts v4’s sounds to Arabic via `quran-p2g` without giving the converter the ayah. The app’s word locator receives that converted text. A locator built to align sounds directly to a known ayah could give a different result. [Benchmark scoring method][board]

For the locator measurement, I compiled the repository’s Swift normalizer, reference-word builder and progressive locator. For each prediction I started a fresh locator at the labelled ayah, gave it the bundled Tanzil words from there through the end of the following surah, and submitted the final transcript once. Success means its accepted word was exactly the last word of the labelled ayah. On phone audio, the remaining FastConformer transcripts ended at an earlier word 31 times and produced no lock 21 times. For v4 those counts were 159 and 95. [Locator source](../Sources/HifzCore/TranscriptPositionLocator.swift) · [App reference scope](../HifzTracker/Services/RecitationViewModel.swift)

These are completed-ayah results from published model predictions. First-highlight latency, recovery after a pause or repeat, and live false advances on a learner’s microphone require a streaming replay. The project’s earlier FastConformer replay of 60:1–5 retained 139 of 140 expected words and reached 60:5:13 after the repeated-phrase fix. That is a useful fixture for a future paired run. [Replay method](surah-60-1-5-offline-replay.md) · [Post-fix replay evidence](../feature_list.json)

## Pronunciation feedback

| Quran Lab checker measure | FastConformer | TajweedFormer v4 |
| --- | ---: | ---: |
| Recitations with one planted mistake where only the right word was flagged | 13.32% | 47.74% |
| Correct recitations with a false alarm | 3.46% | 20.96% |

The public checker uses v4’s main CTC output. The model also exposes timing and pronunciation signals that an application can score against a known ayah. The publisher disables shadda feedback at its calibrated thresholds, describes qalqalah as experimental, and reports no validated thresholds for ghunna or tafkheem. [Benchmark scores and method][board] · [Model card][card]

## Deployment

The app manifest’s SHA-256 matches the historical FP32 ONNX export of `Muno459/fastconformer-quran`. The exporter’s Hugging Face repository subsequently changed its main branch to Zipformer. Use the historical revision to identify the shipped model. [App manifest](../HifzTracker/Resources/asset-manifest.json) · [Historical export](https://huggingface.co/Saboorhsn/quran-stt-onnx/tree/3d3c2336d591990c88e135e2d0292e74897bc56d/onnx)

V4’s Apple SDK delivers an approximately 57 MB model on first use. It requires an app key and an online first run. Cached inference works offline, although a later model open can require a connection. This changes the tracker’s current ability to start on a freshly installed, offline Mac. Quran Lab also reviews requests for raw weights. A local experiment would need authorized access and a choice of how to map the emitted sounds to the displayed words. [Model card][card] · [SDK offline behavior](https://sdk.quranlab.ai/docs/4/offline) · [Word mapping](https://sdk.quranlab.ai/docs/reference)

[fc]: https://huggingface.co/spaces/Quran-Lab/quranic-asr-leaderboard/blob/f8074b2b247cc246b63240ab2378510522c5adc6/predictions/fastconformer-quran.json
[v4]: https://huggingface.co/spaces/Quran-Lab/quranic-asr-leaderboard/blob/f8074b2b247cc246b63240ab2378510522c5adc6/predictions/tajweedformer-v4.json
[board]: https://huggingface.co/spaces/Quran-Lab/quranic-asr-leaderboard/blob/f8074b2b247cc246b63240ab2378510522c5adc6/board.json
[card]: https://huggingface.co/Quran-Lab/tajweedformer-v4/blob/9386369ddaddf60bf2a8663d163fcdf3447cd7c4/README.md
