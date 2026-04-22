import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ValetudiOS — App Store Screenshots",
  description: "Screenshot generator",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body
        className="min-h-full"
        style={{
          fontFamily:
            '-apple-system, "SF Pro Display", "SF Pro Text", system-ui, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif',
        }}
      >
        {children}
      </body>
    </html>
  );
}
