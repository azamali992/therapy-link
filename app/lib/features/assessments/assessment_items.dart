import '../../core/api/models.dart';

/// PHQ-9 and GAD-7 are free to use: Pfizer allows reproduction, translation, display and
/// distribution without permission (phqscreeners.com). The Roman Urdu items are a transliteration
/// of the validated Urdu versions (PHQ-9: Ahmad et al., JPMA 2018;68:1166-70; GAD-7: Ahmad et al.,
/// JPMA 2017;67:1536-40). The Roman Urdu wording itself has not been validated, so the
/// "unvalidated translation" notice stays wherever scores are shown to a clinician. Sources and
/// item-by-item notes: docs/clinical/assessments-urdu.md (ai-clinical-review 2026-10-03; licensed
/// clinician sign-off PENDING).
List<String> assessmentItems(Instrument instrument, String lang) {
  final ur = lang == 'ur';
  return switch (instrument) {
    Instrument.phq9 => ur ? _phq9Ur : _phq9En,
    Instrument.gad7 => ur ? _gad7Ur : _gad7En,
  };
}

int assessmentMax(Instrument i) => switch (i) { Instrument.phq9 => 27, Instrument.gad7 => 21 };

const _phq9En = [
  'Little interest or pleasure in doing things',
  'Feeling down, depressed, or hopeless',
  'Trouble falling or staying asleep, or sleeping too much',
  'Feeling tired or having little energy',
  'Poor appetite or overeating',
  'Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
  'Trouble concentrating on things, such as reading or watching something',
  'Moving or speaking so slowly that other people could have noticed — or the opposite, being so restless that you have been moving around a lot more than usual',
  'Thoughts that you would be better off dead, or of hurting yourself in some way',
];

const _phq9Ur = [
  'Rozmarra ke kaamon mein dilchaspi aur lutf ki kami',
  'Udaasi, afsurdagi ya mayoosi ka ehsaas',
  'Neend ka na aana, neend aane ke baad sote rehne mein dushwari, ya neend ki zyadti',
  'Be-sabab thakawat ya kamzori ka ehsaas',
  'Bila wajah bhook mein kami ya zyadti',
  'Shikast-khurdagi ya nakami ka ehsaas, ya apne khandan ke afraad ki tawaqqoat par poora na utarne ka ehsaas',
  'Tawajjo markooz rakhne mein dushwari, jaise akhbaar parhne ya TV dekhne mein',
  'Itni sust-rawi se chalna ya bolna ke doosron ne is baat ki nishandahi ki ho, ya is ke bar-aks mamool se kai guna barhi hui bechaini ya iztiraab',
  'Zehan mein is khayal ka baar baar aana ke zinda rehne se mar jana behtar hai, ya apni zaat ko nuqsan pohanchane ke khayalat ka aana',
];

const _gad7En = [
  'Feeling nervous, anxious, or on edge',
  'Not being able to stop or control worrying',
  'Worrying too much about different things',
  'Trouble relaxing',
  'Being so restless that it is hard to sit still',
  'Becoming easily annoyed or irritable',
  'Feeling afraid, as if something awful might happen',
];

const _gad7Ur = [
  'Ghabrahat, pareshani ya shadeed nauiyat ka tanao',
  'Pareshani ya fikr par qaboo paane mein dushwari',
  'Mukhtalif cheezon ke baare mein hadd se zyada barhi hui tashweesh',
  'Pur-sukoon rehne mein dushwari',
  'Is qadar bechaini ya iztiraab ke ek jagah baithna mushkil ho jaye',
  'Mamooli baaton ka bura lagna ya chirchirapan',
  'Ek anjaane khauf ka ehsaas, jaise kuch bohat bura hone wala hai',
];
