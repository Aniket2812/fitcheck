import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youcam2/app.dart';
import 'package:youcam2/components/outfit_post_image.dart';
import 'package:youcam2/components/editorial_photo_frame.dart';
import 'package:youcam2/models/closet_item.dart';
import 'package:youcam2/models/fashion_collection.dart';
import 'package:youcam2/models/model_photo.dart';
import 'package:youcam2/models/post_try_on_result.dart';
import 'package:youcam2/models/saved_fit.dart';
import 'package:youcam2/models/social_post.dart';
import 'package:youcam2/models/user_profile.dart';
import 'package:youcam2/services/share_intent_service.dart';
import 'package:youcam2/screens/feed_screen.dart';
import 'package:youcam2/screens/try_on_yourself_screen.dart';
import 'package:youcam2/theme/app_theme.dart';

Future<List<SocialPost>> emptyFeed() async => const [];
Future<List<ModelPhoto>> emptyModelPhotos() async => const [];
Future<List<FashionCollection>> emptyCollections() async => const [];
Future<List<SavedFit>> emptySavedFits() async => const [];
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

    expect(find.text('fitcheck'), findsOneWidget);
    expect(find.text('Fresh looks incoming'), findsOneWidget);
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
    expect(find.text('Find your next vibe'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'jacket');
    await tester.pump();
    expect(find.text('No match yet'), findsOneWidget);
    expect(
      find.text('Nothing for “jacket” yet. Try a broader vibe.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('clear-search-button')));
    await tester.pump();
    expect(find.text('Find your next vibe'), findsOneWidget);

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

    expect(find.textContaining('feed took a little too long'), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('visited tabs keep their loaded state between switches', (
    WidgetTester tester,
  ) async {
    var feedLoads = 0;
    var photoLoads = 0;
    var collectionLoads = 0;

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async {
          feedLoads += 1;
          return const [];
        },
        fetchModelPhotos: () async {
          photoLoads += 1;
          return const [];
        },
        fetchCollections: () async {
          collectionLoads += 1;
          return const [];
        },
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();
    expect((feedLoads, photoLoads, collectionLoads), (1, 0, 0));

    await tester.tap(find.byKey(const Key('collections-tab')));
    await tester.pumpAndSettle();
    expect((feedLoads, photoLoads, collectionLoads), (1, 0, 1));

    await tester.tap(find.byKey(const Key('photos-tab')));
    await tester.pumpAndSettle();
    expect((feedLoads, photoLoads, collectionLoads), (1, 1, 1));

    await tester.tap(find.byKey(const Key('collections-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-tab')));
    await tester.pumpAndSettle();
    expect((feedLoads, photoLoads, collectionLoads), (1, 1, 1));
  });

  testWidgets('feed refreshes in place and ignores stale responses', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <Completer<List<SocialPost>>>[];
    Future<List<SocialPost>> fetch() {
      final request = Completer<List<SocialPost>>();
      requests.add(request);
      return request.future;
    }

    SocialPost post(String id, String caption) => SocialPost(
      id: id,
      caption: caption,
      imageUrl: 'https://example.com/$id.jpg',
      garments: const [
        PostGarment(
          id: 'refresh-top',
          title: 'Refresh top',
          imageUrl: 'https://example.com/top.jpg',
          buyUrl: 'https://example.com/top',
          category: 'upper_body',
          x: 0.5,
          y: 0.3,
        ),
      ],
      author: const SocialUser(
        id: 'refresh-user',
        name: 'Refresh User',
        handle: 'refreshuser',
      ),
      likeCount: 0,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );

    Widget feed(int generation) => MaterialApp(
      home: FeedScreen(
        onSearch: () {},
        onProfile: () {},
        fetchPosts: fetch,
        refreshGeneration: generation,
      ),
    );

    await tester.pumpWidget(feed(0));
    final originalState = tester.state(find.byType(FeedScreen));
    expect(requests.length, 1);

    await tester.pumpWidget(feed(1));
    expect(tester.state(find.byType(FeedScreen)), same(originalState));
    expect(requests.length, 2);

    requests[1].complete([post('latest-refresh', 'Latest fit')]);
    await tester.pumpAndSettle();
    expect(find.text('Latest fit'), findsOneWidget);

    requests[0].complete([post('stale-refresh', 'Stale fit')]);
    await tester.pumpAndSettle();
    expect(find.text('Latest fit'), findsOneWidget);
    expect(find.text('Stale fit'), findsNothing);
  });

  testWidgets('collections use tailored cards, filters and quick add', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const pixel =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==';
    final collections = [
      const FashionCollection(
        id: 'tees',
        name: 'T-shirts',
        kind: 'tshirt',
        isDefault: true,
        items: [],
      ),
      const FashionCollection(
        id: 'shirts',
        name: 'Shirts & Tops',
        kind: 'shirt',
        isDefault: true,
        items: [
          CollectionItem(
            id: 'saved-shirt',
            collectionId: 'shirts',
            title: 'Blue shirt',
            imageUrl: pixel,
            buyUrl: 'https://example.com/blue-shirt',
            category: 'upper_body',
          ),
        ],
      ),
      const FashionCollection(
        id: 'shoes',
        name: 'Shoes',
        kind: 'shoes',
        isDefault: true,
        items: [],
      ),
    ];

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: () async => collections,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collections-tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wardrobe-overview')), findsOneWidget);
    expect(find.text('Drop in a tee you’d wear on repeat.'), findsOneWidget);
    expect(
      find.text('Add the pair that pulls your next look together.'),
      findsOneWidget,
    );
    expect(
      find.text('Share a product here or paste its buying link.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('collection-filter-ready')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-card-shirts')), findsOneWidget);
    expect(find.byKey(const Key('collection-card-tees')), findsNothing);

    await tester.tap(find.byKey(const Key('quick-add-product-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-add-collection-shirts')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quick-add-collection-shirts')));
    await tester.pumpAndSettle();
    expect(find.text('Add to Shirts & Tops'), findsOneWidget);
    expect(find.byKey(const Key('collection-product-link')), findsOneWidget);
  });

  testWidgets('all home filters stay visible when unselected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final post = SocialPost(
      id: 'filter-post',
      caption: 'A filtered fit',
      imageUrl: 'https://example.com/filter-fit.jpg',
      garments: const [
        PostGarment(
          id: 'filter-top',
          title: 'Visible top',
          imageUrl: 'https://example.com/top.jpg',
          buyUrl: 'https://example.com/top',
          category: 'upper_body',
          x: 0.5,
          y: 0.3,
        ),
      ],
      author: const SocialUser(
        id: 'filter-user',
        name: 'Filter User',
        handle: 'filteruser',
      ),
      likeCount: 0,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async => [post],
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: emptyCollections,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    const labels = ['for you', 'tops', 'bottoms', 'shoes', 'dresses'];
    for (final label in labels) {
      final tile = find.byKey(Key('feed-filter-$label'));
      expect(tile, findsOneWidget);
      expect(tester.getTopRight(tile).dx, lessThanOrEqualTo(360));
    }

    Text filterText(String key) => tester.widget<Text>(
      find.descendant(
        of: find.byKey(Key('feed-filter-$key')),
        matching: find.byType(Text),
      ),
    );

    expect(filterText('for you').style?.color, AppColors.textOnAccent);
    expect(filterText('tops').style?.color, AppColors.textPrimary);

    await tester.tap(find.byKey(const Key('feed-filter-tops')));
    await tester.pumpAndSettle();
    expect(filterText('for you').style?.color, AppColors.textPrimary);
    expect(filterText('tops').style?.color, AppColors.textOnAccent);
  });

  testWidgets('home feed uses stable varied masonry tile heights', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SocialPost post(String id) => SocialPost(
      id: id,
      caption: 'A discovery fit',
      imageUrl: 'https://example.com/$id.jpg',
      garments: const [
        PostGarment(
          id: 'tile-top',
          title: 'Tile top',
          imageUrl: 'https://example.com/top.jpg',
          buyUrl: 'https://example.com/top',
          category: 'upper_body',
          x: 0.5,
          y: 0.3,
        ),
      ],
      author: const SocialUser(
        id: 'tile-user',
        name: 'Tile User',
        handle: 'tileuser',
      ),
      likeCount: 0,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async => [
          post('masonry-alpha'),
          post('masonry-bravo'),
          post('masonry-charlie'),
          post('masonry-delta'),
          post('masonry-echo'),
          post('masonry-foxtrot'),
        ],
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: emptyCollections,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    final ratios = tester
        .widgetList<EditorialPhotoFrame>(find.byType(EditorialPhotoFrame))
        .map((frame) => frame.aspectRatio)
        .toSet();
    expect(ratios.length, greaterThanOrEqualTo(3));
    expect(ratios.every((ratio) => ratio >= 0.62 && ratio <= 0.80), isTrue);
  });

  testWidgets('another feed viewer can shop every posted collection item', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const pixel =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==';
    final post = SocialPost(
      id: 'shared-shop-post',
      caption: 'Everything linked',
      imageUrl: 'https://example.com/look.jpg',
      garments: const [
        PostGarment(
          id: 'shared-shirt',
          title: 'Blue shirt',
          imageUrl: pixel,
          buyUrl: 'https://www.myntra.com/blue-shirt',
          category: 'upper_body',
          x: 0.5,
          y: 0.3,
        ),
        PostGarment(
          id: 'shared-shoes',
          title: 'White shoes',
          imageUrl: pixel,
          buyUrl: 'https://www.ajio.com/white-shoes',
          category: 'shoes',
          x: 0.5,
          y: 0.87,
        ),
      ],
      author: const SocialUser(
        id: 'another-creator',
        name: 'Another Creator',
        handle: 'anothercreator',
      ),
      likeCount: 0,
      likedByMe: false,
      comments: const [],
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async => [post],
        fetchModelPhotos: emptyModelPhotos,
        fetchCollections: emptyCollections,
        checkYouCamConfigured: youCamOff,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHOP 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop-post-shared-shop-post')));
    await tester.pumpAndSettle();

    expect(find.text('Every piece, one tap away'), findsOneWidget);
    expect(
      find.byKey(const Key('shop-piece-shared-shop-post-shared-shirt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shop-piece-shared-shop-post-shared-shoes')),
      findsOneWidget,
    );
    expect(find.textContaining('myntra.com'), findsOneWidget);
    expect(find.textContaining('ajio.com'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('shop-piece-shared-shop-post-shared-shirt')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shop this exact piece'), findsOneWidget);
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
    expect(find.text('Put the fit together'), findsOneWidget);
    expect(find.byKey(const Key('choose-outfit-photo')), findsNothing);
    expect(find.byKey(const Key('composer-new-photo')), findsNothing);
    expect(find.text('Choose from gallery'), findsNothing);
    expect(find.text('Take a photo'), findsNothing);
    expect(
      find.byKey(const Key('composer-no-collection-items')),
      findsOneWidget,
    );
    expect(find.text('Start with a piece you love'), findsOneWidget);
    expect(find.byKey(const Key('composer-step-1')), findsOneWidget);
    expect(find.byKey(const Key('composer-active-step-1')), findsOneWidget);
    expect(find.byKey(const Key('composer-step-2')), findsNothing);
    expect(find.byKey(const Key('composer-no-saved-photos')), findsNothing);
    expect(find.byKey(const Key('outfit-preview-empty')), findsNothing);
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

    expect(find.text('Where should it live?'), findsOneWidget);
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

    expect(find.text('My photos'), findsOneWidget);
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
        fetchSavedFits: emptySavedFits,
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
    expect(find.text('Your first fit goes here'), findsOneWidget);

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
          productImageUrls: [
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
          ],
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

    // A preselected default photo must not skip the first guided step.
    expect(find.byKey(const Key('composer-active-step-1')), findsOneWidget);
    expect(find.byKey(const Key('composer-active-step-2')), findsNothing);
    await tester.tap(find.byKey(const Key('collection-item-top-1')));
    await tester.pump();
    expect(find.byKey(const Key('outfit-preview-empty')), findsNothing);

    await tester.tap(find.byKey(const Key('composer-pieces-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-active-step-2')), findsOneWidget);
    expect(find.byKey(const Key('outfit-preview-empty')), findsNothing);

    await tester.tap(find.byKey(const Key('composer-photo-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-active-step-3')), findsOneWidget);

    expect(find.byKey(const Key('outfit-preview-empty')), findsOneWidget);
    expect(find.text('Your look lands here'), findsOneWidget);

    await tester.tap(find.byKey(const Key('generate-outfit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(generatedItems, ['top-1']);
    expect(find.byKey(const Key('outfit-preview-empty')), findsNothing);
    expect(find.text('Remix the look'), findsOneWidget);
    expect(find.byKey(const Key('publish-background-note')), findsOneWidget);
  });

  testWidgets('saved fit moves from composer to Get Ready and then feed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const pixel =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==';
    final profile = UserProfile(
      id: 'draft-owner',
      name: 'Draft Owner',
      handle: 'draftowner',
      bio: '',
      createdAt: DateTime(2026),
    );
    final model = ModelPhoto(
      id: 'draft-model',
      imageUrl: pixel,
      label: 'Full body',
      isPrimary: true,
      createdAt: DateTime(2026),
    );
    final collection = FashionCollection(
      id: 'draft-tops',
      name: 'Tops',
      kind: 'shirt',
      isDefault: true,
      items: const [
        CollectionItem(
          id: 'draft-shirt',
          collectionId: 'draft-tops',
          title: 'Saved white shirt',
          imageUrl: pixel,
          productImageUrls: [pixel, pixel, pixel, pixel],
          originalImageUrl: 'https://example.com/white-shirt.jpg',
          buyUrl: 'https://example.com/white-shirt',
          category: 'upper_body',
        ),
      ],
    );
    var savedFits = <SavedFit>[];
    var posts = <SocialPost>[];

    Future<SavedFit> saveDraft({
      required String caption,
      required String imageUrl,
      required List<PostGarment> garments,
      String? modelPhotoId,
    }) async {
      final fit = SavedFit(
        id: 'saved-dinner-fit',
        caption: caption,
        imageUrl: imageUrl,
        garments: garments,
        modelPhotoId: modelPhotoId,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      savedFits = [fit];
      return fit;
    }

    Future<SocialPost> publishDraft(String fitId, String caption) async {
      expect(fitId, 'saved-dinner-fit');
      final fit = savedFits.single;
      final post = SocialPost(
        id: 'published-dinner-fit',
        caption: caption,
        imageUrl: fit.imageUrl,
        garments: fit.garments,
        author: profile.toSocialUser(),
        likeCount: 0,
        likedByMe: false,
        comments: const [],
        createdAt: DateTime(2026),
      );
      savedFits = [];
      posts = [post];
      return post;
    }

    Future<void> deleteDraft(String fitId) async {
      savedFits = savedFits.where((fit) => fit.id != fitId).toList();
    }

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async => posts,
        fetchProfile: () async => profile,
        updateProfile:
            ({
              required String name,
              required String handle,
              required String bio,
            }) async => profile,
        fetchCollections: () async => [collection],
        fetchModelPhotos: () async => [model],
        checkYouCamConfigured: () async => true,
        generateOutfitLook:
            ({
              required ModelPhoto modelPhoto,
              required List<PostGarment> garments,
            }) async => pixel,
        fetchSavedFits: () async => savedFits,
        saveFitDraft: saveDraft,
        publishSavedFit: publishDraft,
        deleteSavedFit: deleteDraft,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-post-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-item-draft-shirt')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-pieces-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composer-photo-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate-outfit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('composer-caption-field')),
      'Dinner downtown',
    );
    await tester.tap(find.byKey(const Key('save-fit-button')));
    await tester.pumpAndSettle();
    expect(savedFits.single.caption, 'Dinner downtown');

    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('saved-fit-card-saved-dinner-fit')),
      findsOneWidget,
    );
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byKey(const Key('saved-fit-card-saved-dinner-fit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('get-ready-screen')), findsOneWidget);
    expect(find.text('Ready when you are.'), findsOneWidget);
    expect(
      find.byKey(const Key('get-ready-piece-draft-shirt')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('get-ready-post-button')));
    await tester.pumpAndSettle();
    expect(savedFits, isEmpty);
    expect(
      find.byKey(const ValueKey('profile-post-published-dinner-fit')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('saved-fits-count')), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('composer-pieces-next')));
      await tester.pumpAndSettle();

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

  testWidgets('garment hotspot shows only genuine product gallery images', (
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
          brand: 'fitcheck',
          imageUrl:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
          originalImageUrl: 'https://example.com/model-crop.jpg',
          productImageUrls: [
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
          ],
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
    expect(find.text('fitcheck · example.com'), findsOneWidget);
    expect(find.text('1 retailer product image'), findsOneWidget);
    expect(find.byKey(const Key('product-gallery-page-view')), findsOneWidget);
    expect(find.byKey(const Key('product-gallery-image-0')), findsOneWidget);
    expect(find.byKey(const Key('product-gallery-image-1')), findsNothing);
    expect(find.byKey(const Key('product-gallery-thumbnails')), findsNothing);
    expect(find.text('Shop this exact piece'), findsOneWidget);
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
    String? savedImageUrl;
    String? savedModelPhotoId;
    List<PostGarment>? savedGarments;

    await tester.pumpWidget(
      CompeteApp(
        persistCloset: false,
        fetchPosts: () async => [post],
        fetchModelPhotos: () async => [model],
        fetchCollections: emptyCollections,
        checkYouCamConfigured: () async => true,
        generatePostTryOn:
            ({required ModelPhoto modelPhoto, required SocialPost post}) {
              expect(modelPhoto.id, 'my-photo');
              expect(post.id, 'post-try-on');
              return result.future.then(
                (imageUrl) => PostTryOnResult(
                  imageUrl: imageUrl,
                  appliedCount: post.garments.length,
                  preservesSourceComposition: true,
                ),
              );
            },
        saveFitDraft:
            ({
              required String caption,
              required String imageUrl,
              required List<PostGarment> garments,
              String? modelPhotoId,
            }) async {
              expect(caption, 'Borrow this look');
              savedImageUrl = imageUrl;
              savedModelPhotoId = modelPhotoId;
              savedGarments = garments;
              return SavedFit(
                id: 'saved-from-try-on',
                caption: caption,
                imageUrl: imageUrl,
                garments: garments,
                modelPhotoId: modelPhotoId,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              );
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
    expect(find.byKey(const Key('processing-piece-sparkle-0')), findsOneWidget);
    expect(find.byKey(const Key('processing-wave-bar-0')), findsOneWidget);
    expect(find.text('Fitting every piece…'), findsOneWidget);

    result.complete('https://example.com/my-look.jpg');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Okay, this is so you.'), findsOneWidget);
    expect(find.byKey(const Key('try-on-result-summary')), findsOneWidget);
    expect(find.textContaining('pose and background kept'), findsOneWidget);
    expect(find.text('PINCH TO ZOOM'), findsOneWidget);
    final zoomViewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('try-on-zoom-viewer')),
    );
    expect(zoomViewer.scaleEnabled, isTrue);
    expect(zoomViewer.maxScale, 4);

    await tester.tap(find.byKey(const Key('try-on-zoom-viewer')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('try-on-zoom-viewer')));
    await tester.pumpAndSettle();
    expect(
      zoomViewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    expect(find.text('RESET VIEW'), findsOneWidget);

    await tester.tap(find.text('RESET VIEW'));
    await tester.pumpAndSettle();
    expect(
      zoomViewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(1, 0.001),
    );

    await tester.ensureVisible(find.byKey(const Key('save-try-on-fit-button')));
    await tester.tap(find.byKey(const Key('save-try-on-fit-button')));
    await tester.pumpAndSettle();

    expect(savedImageUrl, 'https://example.com/my-look.jpg');
    expect(savedModelPhotoId, 'my-photo');
    expect(savedGarments?.map((garment) => garment.id), ['garment-try-on']);
    expect(find.text('Saved for later'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      find.text('Saved for later. It’s waiting in Profile → Saved Fits.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editorial-frame-post-try-on')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-try-on-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-try-on-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('try-on-yourself-screen')), findsOneWidget);
    expect(find.byKey(const Key('try-on-photo-my-photo')), findsOneWidget);
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
