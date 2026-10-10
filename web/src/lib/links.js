// Copyright (c) 2025 Oliver Tran

export const APP_STORE_URL = 'https://apps.apple.com/us/app/claveo-music-companion/id6755795790';
export const CONTACT_EMAIL = 'claveo.app@gmail.com';
export const GITHUB_URL = 'https://github.com/olivertransf/Claveo';
export const LICENSE_URL = 'https://github.com/olivertransf/Claveo/blob/main/LICENSE';

export function appStoreBadge(dark) {
  const color = dark ? 'white' : 'black';
  return `https://tools.applemediaservices.com/api/badges/download-on-the-app-store/${color}/en-us?size=250x83&releaseDate=1289433600`;
}
