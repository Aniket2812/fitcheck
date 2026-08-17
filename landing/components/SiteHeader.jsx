'use client';

import Image from 'next/image';
import { useEffect, useState } from 'react';

export default function SiteHeader() {
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    document.body.classList.toggle('menu-open', menuOpen);
    return () => document.body.classList.remove('menu-open');
  }, [menuOpen]);

  const closeMenu = () => setMenuOpen(false);

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <div className="hackathon-bar">
        <span className="pulse-dot" aria-hidden="true" />
        <p>
          Built for the{' '}
          <a href="https://youcam-api.devpost.com/" target="_blank" rel="noreferrer">
            YouCam API Skin AI &amp; Apparel VTO Hackathon
          </a>{' '}
          <span aria-hidden="true">·</span> Powered by YouCam API
        </p>
        <a
          className="banner-arrow"
          href="https://youcam-api.devpost.com/"
          target="_blank"
          rel="noreferrer"
          aria-label="Open the YouCam hackathon page"
        >
          ↗
        </a>
      </div>

      <header className="site-header">
        <a className="brand" href="#top" aria-label="fitcheck home">
          <Image className="brand-mark" src="/images/fitcheck-logo.png" alt="" width={40} height={40} priority />
          <span className="brand-name">fitcheck</span>
        </a>
        <nav className="desktop-nav" aria-label="Primary navigation">
          <a href="#features">Features</a>
          <a href="#how">How it works</a>
          <a href="#why">Why fitcheck</a>
        </nav>
        <a className="nav-cta" href="#experience">
          See the experience <span>↗</span>
        </a>
        <button
          className="menu-button"
          type="button"
          aria-expanded={menuOpen}
          aria-controls="mobile-nav"
          onClick={() => setMenuOpen((open) => !open)}
        >
          <span />
          <span />
          <span className="sr-only">Open menu</span>
        </button>
        <nav
          className={`mobile-nav${menuOpen ? ' open' : ''}`}
          id="mobile-nav"
          aria-label="Mobile navigation"
        >
          <a href="#features" onClick={closeMenu}>Features</a>
          <a href="#how" onClick={closeMenu}>How it works</a>
          <a href="#why" onClick={closeMenu}>Why fitcheck</a>
          <a href="#experience" onClick={closeMenu}>See the experience</a>
        </nav>
      </header>
    </>
  );
}
