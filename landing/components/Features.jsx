import Image from 'next/image';

export default function Features() {
  return (
    <section className="features section-pad" id="features">
      <div className="section-intro reveal">
        <p className="eyebrow"><span>03</span> Features</p>
        <h2 className="section-title">A social network<br /><em>you can actually wear.</em></h2>
        <p>
          Profiles, posts, reactions, saves, and a YouCam-powered action no other fashion feed has:
          “try this whole outfit on me.”
        </p>
      </div>

      <div className="feature-grid">
        <article className="feature-card feature-ingest reveal">
          <div className="feature-heading">
            <span className="feature-icon">↗</span>
            <div><small>OUTFIT POSTS</small><h3>Your fit is the status update.</h3></div>
          </div>
          <p>Post what you are wearing, add the story behind it, and tag every piece. Your profile becomes a living timeline of personal style.</p>
          <div className="share-sheet" aria-label="Illustration of creating an outfit post on fitcheck">
            <div className="sheet-grabber" />
            <div className="composer-head"><span>×</span><strong>New outfit post</strong><button type="button">Post</button></div>
            <div className="composer-body">
              <Image src="/images/maya-city-layers.jpg" alt="Outfit ready to be posted" width={92} height={133} sizes="92px" />
              <div><span className="avatar-mini">M</span><p>Soft tailoring for a very unstructured Saturday...</p></div>
            </div>
            <div className="composer-tags"><span>#citylayers</span><span>4 pieces tagged</span><span>Public</span></div>
            <div className="shared-url"><span>✦</span><p><strong>Ready for the community</strong><small>People can like, save, and try this full fit</small></p><b>✓</b></div>
          </div>
        </article>

        <article className="feature-card feature-vto reveal">
          <div className="feature-heading">
            <span className="feature-icon">✦</span>
            <div><small>TRY COMMUNITY FIT</small><h3>See their whole outfit on you.</h3></div>
          </div>
          <p>Every outfit post has a “Try on me” action. YouCam transfers the community look to your saved model photo in one continuous social flow.</p>
          <div className="vto-window">
            <Image
              src="/images/maya-brown-leather.jpg"
              alt="Maya wearing a brown leather overshirt generated as a try-on"
              fill
              sizes="(max-width: 820px) 90vw, 45vw"
            />
            <div className="scan-line" aria-hidden="true" />
            <div className="vto-label"><span /> YOUCAM RESULT</div>
            <div className="product-float social-action"><span className="action-avatar">M</span><strong>Maya&apos;s fit</strong><span>Try on me →</span></div>
          </div>
        </article>

        <article className="feature-card feature-compare reveal">
          <div className="feature-heading">
            <span className="feature-icon">⌑</span>
            <div><small>SAVED FITS</small><h3>Build a library of looks that move you.</h3></div>
          </div>
          <p>Bookmark complete outfits—not disconnected products. Organize the people, moods, and ideas you want to return to later.</p>
          <div className="compare-window">
            <figure>
              <Image src="/images/zoya-gallery-night.jpg" alt="Saved gallery-night outfit" fill sizes="(max-width: 820px) 45vw, 23vw" />
              <figcaption>SAVED FIT <b>Gallery night</b></figcaption>
            </figure>
            <figure>
              <Image src="/images/arjun-denim-day.jpg" alt="Saved relaxed denim outfit" fill sizes="(max-width: 820px) 45vw, 23vw" />
              <figcaption>SAVED FIT <b>Denim day</b></figcaption>
            </figure>
            <span className="versus">♡</span>
          </div>
        </article>

        <article className="feature-card feature-social reveal">
          <div className="feature-heading">
            <span className="feature-icon">♡</span>
            <div><small>THE FASHION FEED</small><h3>Society&apos;s style,<br />in motion.</h3></div>
          </div>
          <p>Follow people, like and comment on fits, discover emerging combinations, and watch collective taste evolve one outfit at a time.</p>
          <div className="social-grid">
            <figure><Image src="/images/zoya-gallery-night.jpg" alt="Zoya in a black gallery-night look" fill sizes="(max-width: 820px) 55vw, 27vw" /><span>♡ 284</span></figure>
            <figure><Image src="/images/arjun-denim-day.jpg" alt="Arjun in a white tee and jeans" fill sizes="(max-width: 820px) 40vw, 20vw" /><span>♡ 196</span></figure>
            <figure><Image src="/images/zoya-pink-kicks.jpg" alt="Zoya in a pink cardigan and jeans" fill sizes="(max-width: 820px) 40vw, 20vw" /><span>♡ 312</span></figure>
          </div>
        </article>
      </div>
    </section>
  );
}
