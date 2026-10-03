import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Colours for the welcome hero, which always sits in Eve's night whatever the app theme.

/// Fades the Blender hero into the night so the copy below it stays readable:
/// clear to 48%, night at 55% by 66%, solid night from 92%.
const welcomeHeroOverlay = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.48, 0.66, 0.92, 1.0],
  colors: [Color(0x001D1E2C), Color(0x8C1D1E2C), Jugnu.night, Jugnu.night],
);

/// Ground behind the hero, matching the splash so there is no flash.
const welcomeGround = Jugnu.night;

/// Shown while the hero image loads.
const welcomeHeroPlaceholder = Jugnu.plum;

/// Text on the hero.
const welcomeInk = Jugnu.ink;
