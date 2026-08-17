import Image from 'next/image';

export default function Hero() {
  return (
    <>
      <section className="hero" id="top">
        <div className="hero-copy reveal">
          <p className="eyebrow"><span>01</span> Post. Discover. Try. Save.</p>
          <h1>Outfits are the new <em>posts.</em></h1>
          <p className="hero-subhead">
            fitcheck is a social app where people post what they wear. Discover the fashion
            sense of your community, try anyone&apos;s full look on <em>yourself</em> with YouCam,
            and save the fits that feel like you.
          </p>
          <div className="hero-actions">
            <a className="button button-dark" href="#how">See how it works <span>↓</span></a>
            <a className="text-link" href="#features">Explore features <span>↗</span></a>
          </div>
          <div className="hero-proof" aria-label="Social product highlights">
            <div><strong>Post your fit</strong><span>Your outfit says what words cannot</span></div>
            <div><strong>Try their look</strong><span>Full-look VTO on your own photo</span></div>
            <div><strong>Save your taste</strong><span>Keep every fit worth revisiting</span></div>
          </div>
        </div>

        <div className="hero-stage reveal" aria-label="fitcheck app preview">
          <div className="orbit orbit-one" aria-hidden="true" />
          <div className="orbit orbit-two" aria-hidden="true" />

          <article className="phone phone-main">
            <div className="phone-status"><span>9:41</span><span>● ● ▰</span></div>
            <div className="app-header">
              <span className="app-logo">
                <Image src="/images/fitcheck-logo.png" alt="" width={24} height={24} />
                <strong>fitcheck</strong>
              </span>
              <div className="app-icons" aria-hidden="true"><span>⌕</span><span className="avatar-mini">M</span></div>
            </div>
            <div className="app-kicker">DISCOVER</div>
            <div className="app-title-row"><strong>Looks worth trying</strong><small>POST · TRY · SAVE</small></div>
            <div className="filter-row"><span className="active">For you</span><span>Following</span><span>Trending</span></div>
            <div className="post-card">
              <div className="post-image-wrap">
                <Image
                  src="/images/hero-maya-city-layers.jpg"
                  alt="Maya wearing a black tailored look with red sneakers"
                  fill
                  priority
                  loading="eager"
                  fetchPriority="high"
                  sizes="310px"
                />
                <button className="hotspot hotspot-jacket" type="button" aria-label="Black blazer product hotspot"><span /></button>
                <button className="hotspot hotspot-shoe" type="button" aria-label="Red sneaker product hotspot"><span /></button>
                <div className="fresh-badge">TRENDING FIT</div>
              </div>
              <div className="post-meta">
                <div><span className="avatar-mini">M</span><p><strong>Maya Kapoor</strong><small>@mayamixes · now</small></p></div>
                <span>♡ 38</span>
              </div>
              <p className="post-caption">Soft tailoring for a very unstructured Saturday. #citylayers</p>
            </div>
            <div className="phone-nav" aria-hidden="true"><span>⌂</span><span>♡</span><b>＋</b><span>▦</span><span>◯</span></div>
          </article>

          <article className="phone phone-side" aria-hidden="true">
            <div className="phone-status"><span>9:41</span><span>● ● ▰</span></div>
            <div className="try-header"><span>←</span><strong>Try it on</strong><span>•••</span></div>
            <div className="try-image">
              <Image src="/images/maya-red-cardigan.jpg" alt="" fill priority sizes="245px" />
              <div className="try-chip"><span /> Generated with YouCam</div>
            </div>
            <div className="try-bottom">
              <p className="app-kicker">YOUR RESULT</p>
              <strong>Maya&apos;s fit, now on you.</strong>
              <button type="button">Save this fit</button>
            </div>
          </article>

          <div className="share-card floating-card" aria-hidden="true">
            <div className="share-icon">↗</div>
            <div><small>COMMUNITY FIT</small><strong>Try Maya&apos;s city layers</strong><span>4 pieces · Full-look try-on</span></div>
            <span className="done-mark">✦</span>
          </div>

          <div className="api-pill floating-card" aria-hidden="true">
            <span className="spark">✦</span>
            <div><small>POWERED BY</small><strong>YouCam Apparel VTO</strong></div>
          </div>
        </div>
      </section>

      <div className="idea-strip" aria-label="fitcheck product loop">
        <div className="strip-track">
          <span>POST YOUR OUTFIT</span><i>✦</i><span>SCROLL THE CULTURE</span><i>✦</i>
          <span>TRY THEIR FIT</span><i>✦</i><span>SAVE WHAT FEELS LIKE YOU</span><i>✦</i>
          <span>POST YOUR OUTFIT</span><i>✦</i><span>SCROLL THE CULTURE</span><i>✦</i>
          <span>TRY THEIR FIT</span><i>✦</i><span>SAVE WHAT FEELS LIKE YOU</span><i>✦</i>
        </div>
      </div>
    </>
  );
}
