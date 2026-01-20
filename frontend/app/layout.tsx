import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AI Digital Twin',
  description: 'Your AI-powered Digital Twin - AI in Production Week 2',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
