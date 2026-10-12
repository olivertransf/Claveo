// Copyright (c) 2025 Oliver Tran

const base = '/screenshots/';

function pair(light, dark) {
  return { light: base + light, dark: base + dark };
}

export const screens = {
  recordings: pair('recordings-iphone-light.png', 'recordings-iphone-dark.png'),
  practice: pair('practice-phone-light.png', 'practice-phone-dark.png'),
  practiceEntry: pair('practice-entry-iphone-light.png', 'practice-entry-iphone-dark.png'),
  metronome: pair('metronome-iphone-light.png', 'metronome-iphone-dark.png'),
  tuner: pair('tuner-iphone-light.png', 'tuner-iphone-dark.png'),
  keys: pair('keys-iphone-light.png', 'keys-iphone-dark.png'),
  chords: pair('chords-iphone-light.png', 'chords-iphone-dark.png'),
  dictionary: pair('dictionary-iphone-light.png', 'dictionary-iphone-dark.png')
};

export function screenSrc(screen, dark) {
  return dark ? screen.dark : screen.light;
}
