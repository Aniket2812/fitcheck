import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youcam2/app.dart';
import 'package:youcam2/components/outfit_post_image.dart';
import 'package:youcam2/models/closet_item.dart';
import 'package:youcam2/models/fashion_collection.dart';
import 'package:youcam2/models/model_photo.dart';
import 'package:youcam2/models/social_post.dart';
import 'package:youcam2/models/user_profile.dart';
import 'package:youcam2/services/share_intent_service.dart';
import 'package:youcam2/screens/try_on_yourself_screen.dart';

Future<List<SocialPost>> emptyFeed() async => const [];
Future<List<ModelPhoto>> emptyModelPhotos() async => const [];
Future<List<FashionCollection>> emptyCollections() async => const [];
Future<bool> youCamOff() async => false;

class FakeShareIntentReceiver implements ShareIntentReceiver {
  FakeShareIntentReceiver({this.initialLink});

  final String? initialLink;

  @override
  Future<String?> initialProductLink() async => initialLink;

  @override
  Stream<String> get productLinks => const Stream.empty();

  @override
  Future<void> reset() async {}
}

void main() {
  testWidgets('feed, saved, and search match the original shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: emptyCollections,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMPETE'), findsOneWidget);
    expect(find.text('No outfits yet'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('feed-tab'))),
      const Size.square(44),
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const Key('feed-tab'))),
      ).textTheme.bodyMedium?.fontFamily,
      'Jost',
    );

    await tester.tap(find.byKey(const Key('collections-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Collections'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pump();
    expect(find.text('Search Compete'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'jacket');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
    expect(find.text('Nothing matches “jacket” yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-search-button')));
    await tester.pump();
    expect(find.text('Search Compete'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Collections'), findsOneWidget);
  });

  testWidgets('feed replaces raw timeout exceptions with recovery guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () => Future<List<SocialPost>>.error(
          TimeoutException('Future not completed'),
        ),
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: emptyCollections,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('feed server is not reachable'), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('plus button builds outfits only from saved collections', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CompeteApp(
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: emptyCollections,
        checkYouCamConfigured: youCamOff,
        persistCloset: false,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-post-button')));
    await tester.pumpAndSettle();
    expect(find.text('Build an outfit'), findsOneWidget);
    expect(find.byKey(const Key('choose-outfit-photo')), findsNothing);
    expect(find.byKey(const Key('composer-new-photo')), findsNothing);
    expect(find.text('Choose from gallery'), findsNothing);
    expect(find.text('Take a photo'), findsNothing);
    expect(
      find.byKey(const Key('composer-no-collection-items')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composer-no-saved-photos')), findsOneWidget);

    expect(
      find.text('Choose at least one product to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('shared fashion link asks which collection should receive it', (
    WidgetTester tester,
  ) async {
    String? ingestedUrl;
    String? savedCollectionId;
    final shirts = FashionCollection(
      id: 'shirts',
      name: 'Shirts & Tops',
      kind: 'shirt',
      isDefault: true,
      items: const [],
    );
    Future<ClosetItem> fakeIngest(String url) async {
      ingestedUrl = url;
      return ClosetItem(
        id: 'shared-item',
        title: 'Shared top',
        image:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
        pageUrl: url,
      );
    }

    Future<CollectionItem> fakeSave(
      String collectionId,
      ClosetItem item,
    ) async {
      savedCollectionId = collectionId;
      return CollectionItem(
        id: item.id,
        collectionId: collectionId,
        title: item.title,
        imageUrl: item.image,
        buyUrl: item.pageUrl!,
        category: item.category ?? 'upper_body',
      );
    }

    await tester.pumpWidget(
      CompeteApp(
        ingestLink: fakeIngest,
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: () async => [shirts],
        saveCollectionItem: fakeSave,
        checkYouCamConfigured: youCamOff,
        persistCloset: false,
        shareIntentReceiver: FakeShareIntentReceiver(
          initialLink: 'https://www.myntra.com/shared-top/buy',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a collection'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-collection-shirts')));
    await tester.pumpAndSettle();
    expect(ingestedUrl, 'https://www.myntra.com/shared-top/buy');
    expect(savedCollectionId, 'shirts');
    expect(find.text('Collections'), findsOneWidget);
  });

  test('shared text extracts the first clean web link', () {
    expect(
      SystemShareIntentReceiver.extractProductLink(
        'Found this on AJIO: https://www.ajio.com/product/p/12345).',
      ),
      'https://www.ajio.com/product/p/12345',
    );
  });

  testWidgets('full-body photos have a dedicated navigation tab', (
    WidgetTester tester,
  ) async {
    Future<List<ModelPhoto>> photos() async => [
      ModelPhoto(
        id: 'model-1',
        imageUrl: 'https://example.com/full-body.jpg',
        label: 'Front pose',
        isPrimary: true,
        createdAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: emptyFeed,
        fetchModelPhotos: photos,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photos-tab')));
    await tester.pumpAndSettle();

    expect(find.text('My full-body photos'), findsOneWidget);
    expect(find.text('Front pose'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('profile button opens themed profile and saves edits', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var profile = UserProfile(
      id: 'creator-1',
      name: 'YouCam Creator',
      handle: 'youcam_creator',
      bio: 'Everyday fits, virtually styled.',
      createdAt: DateTime(2026),
    );
    Future<UserProfile> fetchProfile() async => profile;
    Future<UserProfile> updateProfile({
      required String name,
      required String handle,
      required String bio,
    }) async {
      profile = UserProfile(
        id: profile.id,
        name: name,
        handle: handle,
        bio: bio,
        createdAt: profile.createdAt,
      );
      return profile;
    }

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        checkYouCamConfigured: youCamOff,
        fetchProfile: fetchProfile,
        updateProfile: updateProfile,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-screen')), findsOneWidget);
    expect(find.text('YouCam Creator'), findsOneWidget);
    expect(find.text('@youcam_creator'), findsOneWidget);
    expect(find.text('Everyday fits, virtually styled.'), findsOneWidget);
    expect(find.text('Your outfit story starts here.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Aniket Styles',
    );
    await tester.enterText(
      find.byKey(const Key('profile-handle-field')),
      'aniket_styles',
    );
    await tester.enterText(
      find.byKey(const Key('profile-bio-field')),
      'Building tomorrow’s closet.',
    );
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Aniket Styles'), findsOneWidget);
    expect(find.text('@aniket_styles'), findsOneWidget);
    expect(find.text('Building tomorrow’s closet.'), findsOneWidget);
  });

  testWidgets('collection pieces generate a multi-item YouCam preview', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = ModelPhoto(
      id: 'model-preview',
      imageUrl: 'https://example.com/model.jpg',
      label: 'Studio pose',
      isPrimary: true,
      createdAt: DateTime(2026),
    );
    List<String> generatedItems = const [];
    final collection = FashionCollection(
      id: 'shirts',
      name: 'Shirts & Tops',
      kind: 'shirt',
      isDefault: true,
      items: const [
        CollectionItem(
          id: 'top-1',
          collectionId: 'shirts',
          title: 'Black top',
          imageUrl:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
          originalImageUrl: 'https://example.com/top.jpg',
          buyUrl: 'https://example.com/top',
          category: 'upper_body',
        ),
      ],
    );
    Future<String> fakeGenerate({
      required ModelPhoto modelPhoto,
      required List<PostGarment> garments,
    }) async {
      generatedItems = garments.map((garment) => garment.id).toList();
      expect(modelPhoto.id, 'model-preview');
      return 'https://example.com/generated-look.jpg';
    }

    await tester.pumpWidget(
      CompeteApp(
        fetchPosts: emptyFeed,
        fetchModelPhotos: () async => [model],
        fetchCollections: () async => [collection],
        checkYouCamConfigured: () async => true,
        generateOutfitLook: fakeGenerate,
        persistCloset: false,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-post-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-item-top-1')));
    await tester.tap(find.byKey(const Key('generate-outfit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(generatedItems, ['top-1']);
    expect(find.text('Regenerate outfit'), findsOneWidget);
  });

  testWidgets(
    'outfit studio creates collections, adds links and uploads photos',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var collections = <FashionCollection>[];
      Future<FashionCollection> createCollection(String name) async {
        final collection = FashionCollection(
          id: 'studio-collection',
          name: name,
          kind: 'custom',
          isDefault: false,
          items: const [],
        );
        collections = [collection];
        return collection;
      }

      Future<ClosetItem> ingest(String url) async => ClosetItem(
        id: 'studio-shirt',
        title: 'Studio shirt',
        image:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
        originalImage: 'https://example.com/studio-shirt.jpg',
        pageUrl: url,
        category: 'upper_body',
      );

      Future<CollectionItem> saveItem(
        String collectionId,
        ClosetItem item,
      ) async {
        final saved = CollectionItem(
          id: item.id,
          collectionId: collectionId,
          title: item.title,
          imageUrl: item.image,
          originalImageUrl: item.originalImage,
          buyUrl: item.pageUrl!,
          category: item.category!,
        );
        collections = [
          FashionCollection(
            id: collections.single.id,
            name: collections.single.name,
            kind: collections.single.kind,
            isDefault: false,
            items: [saved],
          ),
        ];
        return saved;
      }

      await tester.pumpWidget(
        CompeteApp(
          persistCloset: false,
          fetchPosts: emptyFeed,
          fetchCollections: () async => collections,
          createCollection: createCollection,
          ingestLink: ingest,
          saveCollectionItem: saveItem,
          fetchModelPhotos: emptyModelPhotos,
          uploadModelPhoto: (file) async => ModelPhoto(
            id: 'studio-photo',
            imageUrl: 'https://example.com/studio-photo.jpg',
            label: 'Studio photo',
            isPrimary: true,
            createdAt: DateTime(2026),
          ),
          checkYouCamConfigured: () async => true,
          shareIntentReceiver: FakeShareIntentReceiver(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-post-button')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('composer-create-collection-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('composer-new-collection-name')),
        'Studio picks',
      );
      await tester.tap(
        find.byKey(const Key('composer-create-collection-submit')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('composer-add-product-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('composer-target-studio-collection')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('composer-product-link')),
        'https://example.com/studio-shirt',
      );
      await tester.tap(find.byKey(const Key('composer-fetch-product-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('selected-piece-studio-shirt')),
        findsOneWidget,
      );

      // Camera/gallery choice is available inline; its platform picker is
      // separately covered by the try-on upload test.
      await tester.ensureVisible(
        find.byKey(const Key('composer-add-photo-button')),
      );
      await tester.tap(find.byKey(const Key('composer-add-photo-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer-gallery-option')), findsOneWidget);
      expect(find.byKey(const Key('composer-camera-option')), findsOneWidget);
    },
  );

  testWidgets('garment hotspot opens the enlarged shoppable product', (
    WidgetTester tester,
  ) async {
    final post = SocialPost(
      id: 'post-1',
      caption: 'Tagged fit',
      imageUrl: 'https://example.com/outfit.jpg',
      garments: const [
        PostGarment(
          id: 'garment-1',
          title: 'Test jacket',
          brand: 'Compete',
          imageUrl:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
          buyUrl: 'https://example.com/jacket',
          x: 0.5,
          y: 0.5,
        ),
      ],
      author: const SocialUser(
        id: 'user-1',
        name: 'Creator',
        handle: 'creator',
      ),
      likeCount: 0,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: OutfitPostImage(post: post)),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('garment-hotspot-post-1-garment-1'))),
      const Size.square(48),
    );
    await tester.tap(find.bySemanticsLabel('Shop Test jacket'));
    await tester.pumpAndSettle();
    expect(find.text('Test jacket'), findsOneWidget);
    expect(find.text('Compete · example.com'), findsOneWidget);
    expect(find.text('View product'), findsOneWidget);
  });

  testWidgets('feed try-on uses a saved photo and shows diagonal processing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final post = SocialPost(
      id: 'post-try-on',
      caption: 'Borrow this look',
      imageUrl: 'https://example.com/outfit.jpg',
      garments: const [
        PostGarment(
          id: 'garment-try-on',
          title: 'Blue shirt',
          imageUrl: 'https://example.com/shirt-cutout.png',
          originalImageUrl: 'https://example.com/shirt.jpg',
          buyUrl: 'https://example.com/shirt',
          category: 'upper_body',
          x: 0.5,
          y: 0.3,
        ),
      ],
      author: const SocialUser(id: 'creator-2', name: 'Maya', handle: 'maya'),
      likeCount: 4,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );
    final model = ModelPhoto(
      id: 'my-photo',
      imageUrl: 'https://example.com/me.jpg',
      label: 'My default',
      isPrimary: true,
      createdAt: DateTime(2026),
    );
    final result = Completer<String>();

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async => [post],
        fetchModelPhotos: () async => [model],
        fetchCollections: emptyCollections,
        checkYouCamConfigured: () async => true,
        generateOutfitLook:
            ({
              required ModelPhoto modelPhoto,
              required List<PostGarment> garments,
            }) {
              expect(modelPhoto.id, 'my-photo');
              expect(garments.single.id, 'garment-try-on');
              return result.future;
            },
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('editorial-frame-post-try-on')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('try-on-post-post-try-on')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('try-on-yourself-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-try-on-button')));
    await tester.pump();
    expect(
      find.byKey(const Key('try-on-processing-animation')),
      findsOneWidget,
    );
    expect(find.text('FITTING EVERY PIECE'), findsOneWidget);
    expect(find.byKey(const Key('processing-piece-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('processing-ellipsis-dot-0')), findsOneWidget);
    expect(find.text('Fitting every piece…'), findsOneWidget);

    result.complete('https://example.com/my-look.jpg');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Your version is ready.'), findsOneWidget);
  });

  testWidgets('try-on can add a camera or gallery photo without leaving', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final post = SocialPost(
      id: 'post-inline-photo',
      caption: '',
      imageUrl: 'https://example.com/outfit.jpg',
      garments: const [],
      author: const SocialUser(
        id: 'creator-inline',
        name: 'Creator',
        handle: 'creator',
      ),
      likeCount: 0,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );
    ImageSource? pickedSource;
    var uploaded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TryOnYourselfScreen(
          post: post,
          fetchModelPhotos: emptyModelPhotos,
          pickPhoto: (source) async {
            pickedSource = source;
            return XFile('/tmp/new-full-body.jpg');
          },
          uploadModelPhoto: (file) async {
            uploaded = true;
            return ModelPhoto(
              id: 'new-photo',
              imageUrl: 'https://example.com/new-photo.jpg',
              label: 'New photo',
              isPrimary: true,
              createdAt: DateTime(2026),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('try-on-add-photo-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('try-on-add-photo-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('try-on-camera-option')), findsOneWidget);
    expect(find.byKey(const Key('try-on-gallery-option')), findsOneWidget);

    await tester.tap(find.byKey(const Key('try-on-gallery-option')));
    await tester.pumpAndSettle();
    expect(pickedSource, ImageSource.gallery);
    expect(uploaded, isTrue);
    expect(find.byKey(const Key('try-on-photo-new-photo')), findsOneWidget);
    expect(find.byKey(const Key('run-try-on-button')), findsOneWidget);
    expect(
      find.byKey(const Key('try-on-add-another-photo-button')),
      findsOneWidget,
    );
  });
}
