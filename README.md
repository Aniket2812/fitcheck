# YouCam Social

Flutter social-shopping app for publishing outfits, tagging garments, opening
shoppable cutouts, receiving products from other shopping apps, and generating
virtual try-on images with YouCam.

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

1. Open **My photos** and upload one or more clear full-body photos once.
2. Share a product from Myntra, Flipkart, Amazon, AJIO, or another shopping app
   to **Post to Compete**. The app opens the composer and extracts the item.
   Pasting a link after tapping the center plus button also works.
3. Choose which previously saved photo YouCam should dress. The composer never
   opens the camera or gallery; new photos are managed only in **My photos**.
4. YouCam generates the virtual try-on automatically after the URL is resolved.
   Review the preview, or retry generation if the provider rejects the image.
5. Position the product hotspot and publish. The feed updates immediately.

Opening a post and tapping a hotspot enlarges the transparent garment cutout
and exposes its original buying link. Likes and comments are persisted by the
backend.

The top-right avatar opens the signed-in creator profile. It includes editable
name, handle, and bio fields, outfit/like/piece totals, and a grid of the
creator's published looks.

## Native share targets

- Android registers a `text/plain` `ACTION_SEND` target and handles both cold
  and warm app starts in a single task.
- iOS embeds `ShareExtension.appex`, stores the shared text in the app group,
  and opens the Flutter host through its private URL scheme.

Both paths extract the first `http` or `https` URL from retailer share text.
Device builds need the `group.com.compete.youcam2.share` App Group enabled for
the Runner and ShareExtension identifiers in the Apple developer account.

In local development the app creates a persistent development session. Set
`GOOGLE_CLIENT_ID` on the server and provide a real Google ID token for
production authentication.

The extraction dialog shows elapsed processing time. The server bounds page
fetching, image download, metadata, and OpenAI cutout stages independently; the
client waits long enough to display the specific server-side failure instead
of replacing it with a premature generic timeout.
