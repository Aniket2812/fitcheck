import Image from 'next/image';

export default function Closing() {
  return (
    <>
      <section className="hackathon-fit section-pad" id="experience">
        <div className="hackathon-fit-head reveal">
          <p className="eyebrow"><span>05</span> Built for this challenge</p>
          <h2 className="section-title">A real social behavior.<br /><em>A new YouCam action.</em></h2>
        </div>
        <div className="criteria-grid">
          <article className="criterion reveal"><span>01</span><h3>Technological implementation</h3><p>Social posts become structured full looks, then move through asynchronous YouCam generation and back into a persistent feed.</p></article>
          <article className="criterion reveal"><span>02</span><h3>Complete product design</h3><p>Profiles, outfit posts, follows, reactions, comments, full-look try-on, saved fits, and shoppable piece metadata.</p></article>
          <article className="criterion reveal"><span>03</span><h3>Credible consumer value</h3><p>People discover style through society already. fitcheck makes that inspiration personal, testable, and reusable.</p></article>
          <article className="criterion criterion-accent reveal"><span>04</span><h3>Quality of the idea</h3><p>YouCam becomes a native social action: not merely “try this product,” but “try this person&apos;s complete expression on me.”</p></article>
        </div>
        <div className="architecture reveal">
          <div className="arch-node"><small>SOCIAL INPUT</small><strong>Community outfit post</strong><span>Person + complete tagged fit</span></div>
          <div className="arch-arrow">→</div>
          <div className="arch-node"><small>STYLE GRAPH</small><strong>Fit + people + pieces</strong><span>Caption, reactions, garment data</span></div>
          <div className="arch-arrow">→</div>
          <div className="arch-node arch-youcam"><small>AI ENGINE</small><strong>YouCam Apparel VTO</strong><span>Personal try-on render</span></div>
          <div className="arch-arrow">→</div>
          <div className="arch-node"><small>PERSONAL OUTPUT</small><strong>Their fit, on you</strong><span>Save, react, remix</span></div>
        </div>
      </section>

      <section className="closing section-pad">
        <Image className="closing-image closing-image-one" src="/images/maya-city-layers.jpg" alt="fitcheck look featuring black tailoring" width={250} height={350} sizes="250px" />
        <Image className="closing-image closing-image-two" src="/images/zoya-pink-kicks.jpg" alt="fitcheck look featuring a pink cardigan" width={250} height={350} sizes="250px" />
        <div className="closing-copy reveal">
          <p className="eyebrow eyebrow-light"><span>06</span> Fashion is a conversation</p>
          <h2>See the fit.<br /><em>Try the fit.</em></h2>
          <p>Post your style. Discover theirs. Save what moves you. fitcheck is where society gets dressed together.</p>
          <div className="closing-actions">
            <a className="button button-lime" href="#top">Back to the top <span>↑</span></a>
            <a href="https://youcam-api.devpost.com/" target="_blank" rel="noreferrer">View the hackathon ↗</a>
          </div>
        </div>
      </section>

      <footer>
        <a className="brand brand-light" href="#top" aria-label="fitcheck home">
          <Image className="brand-mark" src="/images/fitcheck-logo.png" alt="" width={40} height={40} />
          <span className="brand-name">fitcheck</span>
        </a>
        <p>The social network for what society wears.</p>
        <div><span>Built with YouCam API</span><span>© 2026 fitcheck</span></div>
      </footer>
    </>
  );
}
