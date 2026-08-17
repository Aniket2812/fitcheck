import Image from 'next/image';

export default function Story() {
  return (
    <section className="manifesto section-pad" id="why">
      <p className="eyebrow reveal"><span>02</span> The shift</p>
      <div className="manifesto-grid">
        <h2 className="section-title reveal">Style has always been <em>social.</em></h2>
        <div className="manifesto-copy reveal">
          <p>
            People shape fashion by watching one another—on the street, at work, at a party,
            and in every feed. Yet most social apps flatten a great outfit into a photo you can only admire.
          </p>
          <p>
            fitcheck makes the outfit itself the post. It turns society&apos;s living fashion sense
            into something you can discover, try on, react to, and keep.
          </p>
        </div>
      </div>
      <div className="problem-cards">
        <article className="problem-card reveal">
          <span className="card-number">01</span>
          <div className="scribble" aria-hidden="true">?</div>
          <h3>Inspiration stops at “save”</h3>
          <p>You see a great fit, like the photo, and still have to imagine whether that style belongs on you.</p>
        </article>
        <article className="problem-card problem-card-dark reveal">
          <span className="card-number">02</span>
          <div className="mini-before-after" aria-hidden="true">
            <Image src="/images/zoya-pink-kicks.jpg" alt="" width={320} height={450} sizes="240px" />
            <span>→</span>
            <Image src="/images/maya-red-cardigan.jpg" alt="" width={320} height={450} sizes="240px" />
          </div>
          <h3>A social feed you can wear</h3>
          <p>Open someone&apos;s outfit post, try the complete look on yourself, save it, and make it part of your own style.</p>
        </article>
      </div>
    </section>
  );
}
