# YouCam Social

Flutter social-shopping app for publishing outfits, tagging garments, opening
shoppable cutouts, and generating virtual try-on images with YouCam AI Clothes.

## Run

```sh
flutter pub get
flutter run
```

The project targets iOS, Android, and web.

The backend in this repository's `server/` directory must be running on port
`8787`. It owns authentication, posts, uploaded media, likes, comments, product
extraction, and YouCam requests. Keep all API secrets in the backend `.env`;
never pass them to Flutter.

```sh
cd server
npm install
npm start
```

Android emulators use `http://10.0.2.2:8787`; iOS simulators and web use
`http://localhost:8787`.
For a physical device or another host, pass the server URL explicitly:

```sh
flutter run --dart-define=API_URL=http://192.168.1.10:8787
```

## Outfit publishing flow

1. Tap the center plus button and choose an outfit photo.
2. Paste one or more product links and extract each garment.
3. Select a garment and tap the outfit photo to position its hotspot.
4. Optionally generate the final outfit with YouCam.
5. Publish. The feed updates immediately.

Opening a post and tapping a hotspot enlarges the transparent garment cutout
and exposes its original buying link. Likes and comments are persisted by the
backend.

In local development the app creates a persistent development session. Set
`GOOGLE_CLIENT_ID` on the server and provide a real Google ID token for
production authentication.

The extraction dialog shows elapsed processing time. The server bounds page
fetching, image download, metadata, and OpenAI cutout stages independently; the
client waits long enough to display the specific server-side failure instead
of replacing it with a premature generic timeout.
