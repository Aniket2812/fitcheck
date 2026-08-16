import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youcam2/app.dart';
import 'package:youcam2/components/outfit_post_image.dart';
import 'package:youcam2/models/closet_item.dart';
import 'package:youcam2/models/model_photo.dart';
import 'package:youcam2/models/social_post.dart';
import 'package:youcam2/services/share_intent_service.dart';

Future<List<SocialPost>> emptyFeed() async => const [];
Future<List<ModelPhoto>> emptyModelPhotos() async => const [];

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
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMPETE'), findsOneWidget);
    expect(find.text('No outfits yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-tab')));
    await tester.pump();
    expect(find.text('Nothing saved'), findsOneWidget);

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
    await tester.pump();
    expect(find.text('Nothing saved'), findsOneWidget);
  });

  testWidgets('plus button opens the post composer and tags a product', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<ClosetItem> fakeIngest(String url) async {
      return const ClosetItem(
        id: 'item-1',
        title: 'Test jacket',
        brand: 'Compete',
        pageUrl: 'https://example.com/jacket',
        originalImage: 'https://example.com/jacket.jpg',
        image:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
      );
    }

    await tester.pumpWidget(
      CompeteApp(
        ingestLink: fakeIngest,
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        persistCloset: false,
        shareIntentReceiver: FakeShareIntentReceiver(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-post-button')));
    await tester.pumpAndSettle();
    expect(find.text('New outfit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tag-product-button')));
    await tester.pump();
    expect(find.text('Paste a product link first.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('post-product-link-field')),
      'https://example.com/jacket',
    );
    await tester.tap(find.byKey(const Key('tag-product-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test jacket'), findsOneWidget);

    await tester.tap(find.byKey(const Key('publish-post-button')));
    await tester.pump();
    expect(find.text('Choose an outfit photo.'), findsOneWidget);
  });

  testWidgets('shared fashion link opens a prefilled post composer', (
    WidgetTester tester,
  ) async {
    String? ingestedUrl;
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

    await tester.pumpWidget(
      CompeteApp(
        ingestLink: fakeIngest,
        fetchPosts: emptyFeed,
        fetchModelPhotos: emptyModelPhotos,
        persistCloset: false,
        shareIntentReceiver: FakeShareIntentReceiver(
          initialLink: 'https://www.myntra.com/shared-top/buy',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Post shared item'), findsOneWidget);
    expect(ingestedUrl, 'https://www.myntra.com/shared-top/buy');
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
    await tester.tap(find.bySemanticsLabel('Shop Test jacket'));
    await tester.pumpAndSettle();
    expect(find.text('Test jacket'), findsOneWidget);
    expect(find.text('View product'), findsOneWidget);
  });
}
