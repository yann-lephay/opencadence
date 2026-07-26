import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "OpenCadence — entraînement adaptatif",
    short_name: "OpenCadence",
    description: "Séances guidées, historique et adaptation locale.",
    start_url: "/",
    display: "standalone",
    background_color: "#f2ecdf",
    theme_color: "#f2ecdf",
    icons: [
      {
        src: "/icon.svg",
        sizes: "any",
        type: "image/svg+xml",
      },
    ],
  };
}
