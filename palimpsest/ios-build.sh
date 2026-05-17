#!/bin/bash
set -e
npm run build
npx cap sync ios
echo "iOS project synced. Open ios/App/App.xcworkspace in Xcode to build."
