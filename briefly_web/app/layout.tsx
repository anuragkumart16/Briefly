import type { Metadata } from "next";
import { Arya, Open_Sans } from "next/font/google";
import "./globals.css";

const arya = Arya({
  weight: ["400", "700"],
  subsets: ["latin"],
  variable: "--font-arya",
});

const openSans = Open_Sans({
  subsets: ["latin"],
  variable: "--font-open-sans",
});

export const metadata: Metadata = {
  title: "Briefly - Your Day in a Single Daily Report",
  description: "News about you, packed in clean daily reports. Briefly compiles your emails, calendar events, and todo list items into a beautiful, secure summary.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${arya.variable} ${openSans.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
