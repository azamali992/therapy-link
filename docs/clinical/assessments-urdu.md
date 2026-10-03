# PHQ-9 and GAD-7 in Urdu and Roman Urdu

> **Status: ai-clinical-review, 2026-10-03. Licensed clinician sign-off: PENDING.** This page records which published Urdu versions the app follows, how the Roman Urdu was made from them, and what is and isn't validated. A licensed clinician needs to confirm the item wording and the notice before any score is shown to a clinician in the pilot (UX.md D4).

## Licensing

PHQ-9 and GAD-7 were developed by Drs Spitzer, Williams, Kroenke and colleagues with an educational grant from Pfizer. Pfizer's terms on [phqscreeners.com](https://www.phqscreeners.com/select-screener): no permission is required to reproduce, translate, display or distribute them, including the official translations. No licence fee or agreement is needed. Credit the instrument by name; the app already shows "PHQ-9" and "GAD-7".

## Validated Urdu versions

| Instrument | Source | Setting and sample | Psychometrics |
|---|---|---|---|
| PHQ-9 Urdu | Ahmad S, Hussain S, Akhtar F, Shah FS. *Urdu translation and validation of PHQ-9, a reliable identification, severity and treatment outcome tool for depression.* J Pak Med Assoc. 2018;68(8):1166–1170. [JPMA PDF](https://www.archive.jpma.org.pk/PdfDownload/8805), [ResearchGate](https://www.researchgate.net/publication/326840345) | Primary care, CMH Gilgit and Lahore, PNS Shifa Karachi; n = 293; forward and back translation, expert panel, face validation, pilot on 50 adults | One factor (loadings ≥ 0.63); Cronbach's α 0.91; split-half 0.77. No criterion (diagnostic) validity in this paper |
| PHQ-9 Urdu (simplified community version) | Gallis JA, Maselko J, O'Donnell K, et al. *Criterion-related validity and reliability of the Urdu version of the patient health questionnaire in a sample of community-based pregnant women in Pakistan.* PeerJ. 2018;6:e5185. [doi:10.7717/peerj.5185](https://peerj.com/articles/5185/) | Community, pregnant women, Kallar Syedan (Rawalpindi), rural Punjab; against SCID. Used the Urdu PHQ-9 from the Multicultural Mental Health Resource Centre, with difficult words replaced by simpler ones for low literacy | Cut-off ≥ 10: sensitivity 94.7%, specificity 88.9%, AUC 0.959; α 0.844 |
| GAD-7 Urdu | Ahmad S, Hussain S, Shah FS, Akhtar F. *Urdu translation and validation of GAD-7: A screening and rating tool for anxiety symptoms in primary health care.* J Pak Med Assoc. 2017;67(10):1536–1540. [JPMA PDF](https://www.archive.jpma.org.pk/PdfDownload/8391) | Primary care, CMH Gilgit; n = 285; same six-step translation process | One factor; Cronbach's α 0.92; convergent and discriminant validity with well-being measures |
| GAD-7 Urdu (clinical populations) | Khan A, Madihie A, Ali I. *Cross cultural adaptation and psychometric validation of the Generalized Anxiety Disorder Assessment-7 for Urdu-speaking clinical populations.* Healthcare in Low-resource Settings, 2026. [PAGEPress](https://www.pagepressjournals.org/hls/article/view/14309) (a correction was also published) | Clinical populations, n = 267 | α 0.896; cut-off 10: sensitivity 98.6%, specificity 81.4%, AUC 0.970 |

**What the app follows.** The Ahmad et al. versions, because their full item wording is printed in the papers (Figure 1 of each), they were validated in Pakistani primary care, which is the closest setting to the app's adult users, and they are the ones a Pakistani clinician is most likely to recognise. Item wording was read from the published figures on 2026-10-03.

## Item wording

### PHQ-9

Stem (Ahmad 2018): گزشتہ دو ہفتوں کے دوران مندرجہ ذیل مسائل سے آپ کتنا پریشان ہوئے؟

| # | Validated Urdu (Ahmad 2018) | App's Roman Urdu (`assessment_items.dart`) | Note |
|---|---|---|---|
| 1 | روزمرہ کے کاموں میں دلچسپی اور لطف کی کمی۔ | Rozmarra ke kaamon mein dilchaspi aur lutf ki kami | |
| 2 | اداسی، افسردگی، یا مایوسی کا احساس۔ | Udaasi, afsurdagi ya mayoosi ka ehsaas | The authors note "feeling down" has no exact Urdu |
| 3 | (ا) نیند کا نہ آنا (ب) نیند آنے کے بعد سوتے رہنے میں دشواری (ج) نیند کی زیادتی۔ | Neend ka na aana, neend aane ke baad sote rehne mein dushwari, ya neend ki zyadti | Sub-parts joined with "ya" |
| 4 | بے سبب تھکاوٹ یا کمزوری کا احساس۔ | Be-sabab thakawat ya kamzori ka ehsaas | "Be-sabab" (without reason) is an addition in the Urdu version |
| 5 | بلاوجہ بھوک میں کمی یا زیادتی۔ | Bila wajah bhook mein kami ya zyadti | |
| 6 | (ا) شکست خوردگی یا ناکامی کا احساس (ب) اپنے خاندان کے افراد کی توقعات پر پورا نہ اترنے کا احساس۔ | Shikast-khurdagi ya nakami ka ehsaas, ya apne khandan ke afraad ki tawaqqoat par poora na utarne ka ehsaas | The Urdu version has no direct equivalent of "feeling bad about yourself" |
| 7 | توجہ مرکوز رکھنے میں دشواری پیش آنا، جیسے اخبار پڑھنے یا ٹی وی دیکھنے میں۔ | Tawajjo markooz rakhne mein dushwari, jaise akhbaar parhne ya TV dekhne mein | |
| 8 | اتنی سست روی سے چلنا یا بولنا کہ دوسروں نے اس بات کی نشاندہی کی ہو۔ یا اس کے برعکس معمول سے کئی گنا بڑھی ہوئی بے چینی یا اضطراب۔ | Itni sust-rawi se chalna ya bolna ke doosron ne is baat ki nishandahi ki ho, ya is ke bar-aks mamool se kai guna barhi hui bechaini ya iztiraab | |
| 9 | (ا) ذہن میں اس خیال کا بار بار آنا کہ زندہ رہنے سے مر جانا بہتر ہے (ب) ذہن میں اپنی ذات کو نقصان پہنچانے (ضرر رسانی) کے خیالات کا آنا۔ | Zehan mein is khayal ka baar baar aana ke zinda rehne se mar jana behtar hai, ya apni zaat ko nuqsan pohanchane ke khayalat ka aana | **Any answer above "bilkul nahi" opens the crisis sheet, offline (QA CR-013).** That behaviour is unchanged |

Response options (Ahmad 2018): (بالکل نہیں) / (کئی دن، لیکن ایک ہفتے سے کم) / (ایک ہفتے سے زیادہ) / (تقریباً روزانہ). Roman Urdu: *Bilkul nahi / Kai din (lekin ek hafte se kam) / Ek hafte se zyada / Taqreeban rozana*. The authors added "but less than a week" to the second option to remove an ambiguity. The app's option strings live in the ARB files (`opt*` keys) and are outside this review's keys. **Recommendation to the l10n owner:** use the four Roman Urdu options above. The app's current "Aadhe se zyada din" is a literal translation of the English, not the validated wording.

Stem in the app (`assessmentIntro`, ur): "Pichlay do hafton mein, aap ko in cheezon ne kitni baar pareshan kiya?" The validated stem asks "kitna" (how much), not "kitni baar" (how often). Recommendation: "Guzishta do hafton ke dauran neeche diye gaye masail se aap kitna pareshan hue?"

### GAD-7

Stem (Ahmad 2017): گزشتہ دو ہفتوں کے دوران مندرجہ ذیل مسائل نے آپ کو کتنا پریشان کیا؟

| # | Validated Urdu (Ahmad 2017) | App's Roman Urdu |
|---|---|---|
| 1 | گھبراہٹ، پریشانی یا شدید نوعیت کا تناؤ۔ | Ghabrahat, pareshani ya shadeed nauiyat ka tanao |
| 2 | پریشانی یا فکر پر قابو پانے میں دشواری۔ | Pareshani ya fikr par qaboo paane mein dushwari |
| 3 | مختلف چیزوں کے بارے میں حد سے زیادہ بڑھی ہوئی تشویش۔ | Mukhtalif cheezon ke baare mein hadd se zyada barhi hui tashweesh |
| 4 | پرسکون رہنے میں دشواری۔ | Pur-sukoon rehne mein dushwari |
| 5 | اس قدر بے چینی یا اضطراب کہ ایک جگہ بیٹھنا مشکل ہو جائے۔ | Is qadar bechaini ya iztiraab ke ek jagah baithna mushkil ho jaye |
| 6 | معمولی باتوں کا برا لگنا یا چڑچڑا پن۔ | Mamooli baaton ka bura lagna ya chirchirapan |
| 7 | ایک انجانے خوف کا احساس جیسے کچھ بہت برا ہونے والا ہے۔ | Ek anjaane khauf ka ehsaas, jaise kuch bohat bura hone wala hai |

Response options as for PHQ-9.

## What is and isn't validated

- **Urdu script:** the wording above is validated (internal consistency and factor structure for both; criterion validity for PHQ-9 in Gallis 2018, on a different, simplified Urdu wording). Gallis et al. show that replacing difficult Urdu words with everyday ones kept good accuracy in a low-literacy sample, which supports a careful plain-language gloss if the clinician wants one. The app has no Urdu-script locale today; if one is added, use this wording verbatim.
- **Roman Urdu:** a transliteration of validated Urdu is **not itself validated**. Reading Urdu in Latin script changes how familiar and how formal words feel, and some terms here (afsurdagi, iztiraab, sust-rawi, nishandahi, tashweesh) are formal and may be less familiar to younger users who type Roman Urdu. Keep the "Unvalidated translation" notice (`clinicianUnvalidatedTranslation`) wherever a Roman Urdu score is shown to a clinician. Its help text now says the wording follows the published Urdu versions but is not itself validated.
- **Cut-offs:** use the standard bands (PHQ-9 5/10/15/20; GAD-7 5/10/15). Both Urdu cut-off studies support ≥ 10 for screening. None of this makes the app a diagnostic tool, and the result screens must keep saying so.
- **English:** the standard Pfizer wording, unchanged.

## Open items

1. A licensed clinician confirms the transliteration and decides whether any formal term needs a gloss. Adding a gloss changes the item, so it would need a note in the clinician view.
2. The l10n owner applies the validated response options and stem in Roman Urdu (above).
3. If the pilot collects Roman Urdu scores, a small validation (internal consistency against the Urdu-script version in bilingual users) would let the notice be removed later. That needs ethics review (pilot-protocol P8).
