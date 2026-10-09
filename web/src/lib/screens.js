// Copyright (c) 2025 Oliver Tran

const base = '/screenshots/';

function pair(light, dark) {
  return { light: base + light, dark: base + dark };
}

export const screens = {
  recordings: pair('recordings-iphone-light.png', 'recordings-iphone-dark.png'),
  recordingDetails: pair('recording-deatils-iphone%20light.png', 'recordings-details-iphone-dark.png'),
  practice: pair('practice-phone-light.png', 'practice-phone-dark.png'),
  metronome: pair('metronome-iphone-light.png', 'metronome-iphone-dark.png'),
  tuner: pair('tuner-iphone-light.png', 'tuner-iphone-dark.png'),
  dictionary: pair('dictionary-iphone-light.png', 'dictionary-iphone-dark.png'),
  dictionaryDetails: pair('dictionary-details-iphone-light.png', 'dictionary-details-iphone-dark.png')
};

export function screenSrc(screen, dark) {
  return dark ? screen.dark : screen.light;
}
