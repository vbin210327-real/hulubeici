import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "葫芦背词 API",
  description: "Backend service for vocabulary sync"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
