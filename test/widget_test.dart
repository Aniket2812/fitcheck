import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youcam2/app.dart';
import 'package:youcam2/components/outfit_post_image.dart';
import 'package:youcam2/models/closet_item.dart';
import 'package:youcam2/models/social_post.dart';

Future<List<SocialPost>> emptyFeed() async => const [];

void main() {
  testWidgets('feed, saved, and search match the original shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CompeteApp(persistCloset: false, fetchPosts: emptyFeed),
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
        persistCloset: false,
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
