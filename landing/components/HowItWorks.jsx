'use client';

import Image from 'next/image';
import { useState } from 'react';

const steps = [
  {
    title: 'Post what you are wearing',
    description: 'Add a caption and tag the pieces in your fit.',
    image: '/images/maya-city-layers.jpg',
    label: 'FIT POSTED',
    result: 'Your outfit becomes a social post.',
  },
  {
    title: 'Scroll society’s fashion sense',
    description: 'Follow people, react, comment, and find new ideas.',
    image: '/images/zoya-gallery-night.jpg',
    label: 'TRENDING NOW',
    result: 'Discover how your community is dressing.',
  },
  {
    title: 'Tap “Try this fit on me”',
    description: 'YouCam renders the community look on your photo.',
    image: '/images/maya-red-cardigan.jpg',
    label: 'YOUCAM FULL LOOK',
    result: 'Try another person’s outfit on yourself.',
  },
  {
    title: 'Save the fits you love',
    description: 'Keep the full look, revisit it, or make it your own.',
    image: '/images/zoya-pink-kicks.jpg',
    label: 'SAVED TO FITS',
    result: 'Keep the looks that shape your taste.',
  },
];

export default function HowItWorks() {
  const [activeStep, setActiveStep] = useState(0);
  const active = steps[activeStep];

  return (
    <section className="how section-pad" id="how">
      <div className="how-copy reveal">
        <p className="eyebrow eyebrow-light"><span>04</span> How it works</p>
        <h2 className="section-title">The feed, but<br /><em>made wearable.</em></h2>
        <p className="how-lead">The familiar rhythm of social media, rebuilt around what people wear and what you want to try next.</p>

        <div className="process-list" role="tablist" aria-label="How fitcheck works">
          {steps.map((step, index) => (
            <button
              className={`process-step${activeStep === index ? ' active' : ''}`}
              type="button"
              role="tab"
              aria-selected={activeStep === index}
              key={step.title}
              onClick={() => setActiveStep(index)}
            >
              <span>{String(index + 1).padStart(2, '0')}</span>
              <div><strong>{step.title}</strong><p>{step.description}</p></div>
              <i>↗</i>
            </button>
          ))}
        </div>
      </div>

      <div className="process-visual reveal">
        <div className="process-phone">
          <div className="phone-status"><span>9:41</span><span>● ● ▰</span></div>
          <div className="try-header"><span>×</span><strong>New try-on</strong><span>•••</span></div>
          <div className="process-image">
            <Image
              src={active.image}
              alt={active.result}
              fill
              sizes="332px"
              key={active.image}
            />
            <div className="processing-grid" aria-hidden="true" />
            <div className="process-image-label">{active.label}</div>
          </div>
          <div className="process-result">
            <small>STEP {String(activeStep + 1).padStart(2, '0')} OF 04</small>
            <h3>{active.result}</h3>
            <div className="progress-track"><span style={{ width: `${(activeStep + 1) * 25}%` }} /></div>
          </div>
        </div>
        <div className="process-note note-one"><span>✦</span> Every community post<br />becomes try-on ready.</div>
        <div className="process-note note-two"><span>♡</span> Save the complete fit,<br />not just one product.</div>
      </div>
    </section>
  );
}
