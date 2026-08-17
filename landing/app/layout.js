import { Cormorant_Garamond, DM_Sans } from 'next/font/google';
import './globals.css';

const dmSans = DM_Sans({
  subsets: ['latin'],
  variable: '--font-dm-sans',
  display: 'swap',
});

const editorial = Cormorant_Garamond({
  subsets: ['latin'],
  weight: ['500', '600'],
  style: ['normal', 'italic'],
  variable: '--font-editorial',
  display: 'swap',
});

export const metadata = {
  title: 'fitcheck — the social network for outfits',
  description:
    'fitcheck is a social fashion app where outfits are posts—share your style, try community looks on yourself with YouCam, and save the fits you love.',
  icons: {
    icon: '/images/favicon.png',
  },
};

export const viewport = {
  themeColor: '#191a17',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={`${dmSans.variable} ${editorial.variable}`}>
      <body>{children}</body>
    </html>
  );
}
