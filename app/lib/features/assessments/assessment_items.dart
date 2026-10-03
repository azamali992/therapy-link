import '../../core/api/models.dart';

/// PHQ-9 and GAD-7 are public domain (Pfizer). The Roman Urdu wording is an app translation,
/// not a validated clinical instrument — say so wherever scores are shown to a clinician.
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
  'Kisi kaam mein dilchaspi ya maza na aana',
  'Udaas, mayoos ya na-umeed mehsoos karna',
  'Neend aane ya sote rehne mein mushkil, ya bohat zyada sona',
  'Thakan mehsoos karna ya energy kam hona',
  'Bhook kam lagna ya zyada khana',
  'Apne baare mein bura mehsoos karna — ke aap nakaam hain ya aap ne apne aap ko ya ghar walon ko mayoos kiya hai',
  'Kisi cheez par tawajjo dene mein mushkil, jaise kuch parhna ya dekhna',
  'Itna aahista chalna ya bolna ke doosron ne mehsoos kiya ho — ya iska ulta, itni bechaini ke aap aam se zyada hilte-julte rahe',
  'Yeh khayal ke mar jana behtar hoga, ya khud ko kisi tarah nuqsan pohanchane ke khayal',
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
  'Ghabrahat, bechaini ya tanav mehsoos karna',
  'Fikar ko rok ya control na kar paana',
  'Mukhtalif cheezon ke baare mein bohat zyada fikar karna',
  'Sukoon se baithne mein mushkil',
  'Itni bechaini ke ek jagah tik kar baithna mushkil ho',
  'Jaldi chirchira ya naraz ho jana',
  'Aisa dar ke jaise kuch bohat bura hone wala hai',
];
