import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'dev.palimpsest.app',
  appName: 'Social',
  webDir: 'build',
  server: {
    androidScheme: 'https'
  }
};

export default config;
