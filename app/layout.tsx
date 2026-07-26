import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "OpenCadence — entraînement adaptatif",
  description: "Ton entraînement au poids du corps, guidé et ajusté séance après séance.",
  applicationName: "OpenCadence",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "OpenCadence",
  },
};

export const viewport: Viewport = {
  themeColor: "#f2ecdf",
  colorScheme: "light",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
