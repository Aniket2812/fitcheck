import SiteHeader from '@/components/SiteHeader';
import Hero from '@/components/Hero';
import Story from '@/components/Story';
import Features from '@/components/Features';
import HowItWorks from '@/components/HowItWorks';
import Closing from '@/components/Closing';

export default function HomePage() {
  return (
    <>
      <SiteHeader />
      <main id="main">
        <Hero />
        <Story />
        <Features />
        <HowItWorks />
        <Closing />
      </main>
    </>
  );
}
