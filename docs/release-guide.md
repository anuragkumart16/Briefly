# Release and Update Guide

This document describes the step-by-step procedure for building and pushing new production releases of Briefly and updating the database to trigger mandatory/optional client updates.

---

## Step 1: Determine the Next Version & Build Number

1. Check the current active release in the MongoDB database using the API endpoint or database client:
   `GET /api/v1/update/check?platform=android`
2. Decide the next release details, e.g.:
   - **New Version Name**: `1.0.2`
   - **New Build Number**: `3` (Must be strictly greater than the current latest build number in the database).

---

## Step 2: Build the Production Release APK

Build the release APK using the explicit version parameters to avoid mismatched version warnings:

```bash
cd briefly_app
flutter build apk --release --build-name=<VERSION> --build-number=<BUILD_NUMBER>
```

*Example:*
```bash
flutter build apk --release --build-name=1.0.2 --build-number=3
```

---

## Step 3: Copy and Package the APK

Copy the compiled release APK into the `app_builds` directory at the root of the project:

```bash
cp build/app/outputs/flutter-apk/app-release.apk ../app_builds/app-release.apk
```

---

## Step 4: Upload Release Asset via GitHub CLI

Deploy the compiled APK to the GitHub release tag (`PROD`) using `gh release upload` with `--clobber` to overwrite the existing asset:

```bash
cd briefly_app
gh release upload PROD ../app_builds/app-release.apk --clobber
```

---

## Step 5: Update the Database Version Info

To inform active applications about the update, write a new version entry into the `AppVersion` collection in MongoDB.

### Method A: Execute Seed Script (Recommended)
Create a temporary typescript runner `src/add-version.ts` in the `briefly_service` directory:

```typescript
import prisma from "./config/prisma";

async function main() {
    await prisma.appVersion.create({
        data: {
            platform: "android",
            version: "<VERSION>",
            buildNumber: <BUILD_NUMBER>,
            url: "https://github.com/anuragkumart16/Briefly/releases/download/PROD/app-release.apk",
            releaseNotes: "<NOTES>",
            mandatory: true // Set to true to enforce update dialog on startup
        }
    });
}
main().finally(() => prisma.$disconnect());
```

Run the script:
```bash
cd briefly_service
npx ts-node src/add-version.ts
rm src/add-version.ts
```

### Method B: API POST Endpoint
If the backend is running, submit a POST request to `/api/v1/update`:
```bash
curl -X POST http://localhost:PORT/api/v1/update \
  -H "Content-Type: application/json" \
  -d '{
    "platform": "android",
    "version": "1.0.2",
    "buildNumber": 3,
    "url": "https://github.com/anuragkumart16/Briefly/releases/download/PROD/app-release.apk",
    "releaseNotes": "Bug fixes and stability improvements",
    "mandatory": true
  }'
```

---

## Step 6: Send Update Notifications to All Users

Once the new build is successfully registered in the database, broadcast a push notification to all active users to inform them about the new version. Clicking this notification will open the app.

### Execute Broadcast Script
Create a temporary typescript runner `src/send-update-notification.ts` in the `notification_service` directory:

```typescript
import prisma from "./config/prisma";
import { sendNotificationToUser } from "./services/fcm.service";

async function main() {
    const users = await prisma.user.findMany({
        where: {
            fcmTokens: {
                isEmpty: false
            }
        },
        select: {
            id: true,
            email: true
        }
    });

    for (const user of users) {
        await sendNotificationToUser(
            user.id,
            "New Update Available! 🚀",
            "Version <VERSION> is now live. Tap to open Briefly and update to get the latest features and bug fixes.",
            {
                type: "app_update",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
        );
    }
}
main().finally(() => prisma.$disconnect());
```

Run the script:
```bash
cd notification_service
npx ts-node src/send-update-notification.ts
rm src/send-update-notification.ts
```

