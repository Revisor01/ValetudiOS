"use client";

import { useRef, useState } from "react";
import { toPng } from "html-to-image";

const THEME = {
  bgFrom: "#56BDE3",
  bgTo: "#3B87F6",
  blobLight: "#CEE7F6",
  blobMid: "#56BDE3",
  blobDark: "#3B87F6",
  textPrimary: "#FFFFFF",
  textSecondary: "rgba(255,255,255,0.88)",
} as const;

const CANVAS_W = 1320;
const CANVAS_H = 2868;

type Layout = "headline-top" | "mock-left" | "mock-right" | "mock-podest";

type Slide = {
  id: string;
  locale: "de" | "en" | "fr";
  headline: string;
  subline: string;
  screenshot: string;
  layout: Layout;
  bgVariant: 0 | 1 | 2;
};

type Copy = { de: { headline: string; subline: string }; en: { headline: string; subline: string }; fr: { headline: string; subline: string } };

const COPY: Record<string, Copy> = {
  "01-live-map": {
    de: { headline: "Live dabei.", subline: "Karte in Echtzeit —\ndu siehst jeden Meter." },
    en: { headline: "Watch live.", subline: "Real-time map.\nEvery move, as it happens." },
    fr: { headline: "En direct.", subline: "Carte en temps réel —\nchaque mètre, sans délai." },
  },
  "02-edit-map": {
    de: { headline: "Deine Karte,\ndeine Ordnung.", subline: "Räume umbenennen,\nzuschneiden, teilen, verbinden." },
    en: { headline: "Your map,\nyour rules.", subline: "Rename, split, merge\nand reshape rooms." },
    fr: { headline: "Votre carte,\nvos règles.", subline: "Renommer, scinder, fusionner\net retailler les pièces." },
  },
  "03-goto": {
    de: { headline: "Einmal tippen.\nRoboter fährt hin.", subline: "Orte wie Mülleimer oder Essbereich\nspeichern und gezielt ansteuern." },
    en: { headline: "Tap a spot.\nHe's there.", subline: "Save places like the trash bin\nor dining area and send him anytime." },
    fr: { headline: "Un tap.\nIl y va.", subline: "Enregistrez la poubelle, la salle à manger —\net envoyez-le d'un geste." },
  },
  "04-room-order": {
    de: { headline: "Reihenfolge?\nDu bestimmst.", subline: "Räume antippen, nummerieren,\nlosschicken." },
    en: { headline: "You pick\nthe order.", subline: "Tap rooms in sequence —\nhe cleans them that way." },
    fr: { headline: "L'ordre ?\nÀ vous de choisir.", subline: "Tapez les pièces dans l'ordre —\nil les nettoie ainsi." },
  },
  "05-notifications": {
    de: { headline: "Bleibt sauber,\nbleibt informiert.", subline: "Meldung, wenn fertig.\nWenn Hilfe gebraucht wird.\nWenn Material knapp wird." },
    en: { headline: "Quiet until\nit matters.", subline: "A ping when he's done.\nWhen he needs help.\nWhen supplies run low." },
    fr: { headline: "Silence.\nPuis un signal.", subline: "Quand il a fini.\nQuand il a besoin d'aide.\nQuand un consommable s'épuise." },
  },
  "06-update": {
    de: { headline: "Firmware frisch,\nohne Cloud.", subline: "Updates sehen, prüfen, einspielen —\ndirekt aus der App." },
    en: { headline: "Fresh firmware,\nno cloud.", subline: "See, check, and install updates —\nstraight from the app." },
    fr: { headline: "Firmware à jour,\nsans cloud.", subline: "Voir, vérifier, installer —\ndirectement depuis l'app." },
  },
  "07-robots": {
    de: { headline: "Alle Roboter.\nEine App.", subline: "Jedes Gerät, jeder Status —\nauf einen Blick." },
    en: { headline: "All robots.\nOne app.", subline: "Every device, every status —\nat a glance." },
    fr: { headline: "Tous les robots.\nUne seule app.", subline: "Chaque appareil, chaque statut —\nd'un coup d'œil." },
  },
  "08-consumables": {
    de: { headline: "Verschleiß\nim Blick.", subline: "Filter, Bürsten, Mop — sehen,\nwas bald dran ist." },
    en: { headline: "Know what's\nwearing out.", subline: "Filters, brushes, mop —\nsee what needs care." },
    fr: { headline: "L'usure\nsous contrôle.", subline: "Filtres, brosses, serpillère —\nvoyez ce qu'il faut remplacer." },
  },
  "09-full-control": {
    de: { headline: "Alles was\nValetudo kann.", subline: "Jede Einstellung, jede API —\nnativ als iOS-App." },
    en: { headline: "Everything\nValetudo does.", subline: "Every setting, every API —\nnative iOS." },
    fr: { headline: "Tout ce que\nValetudo peut.", subline: "Chaque réglage, chaque API —\nen natif iOS." },
  },
};

// Layout rotation avoids adjacent slides using the same composition.
const LAYOUT_ROTATION: Layout[] = [
  "headline-top", // 01 Live-Karte
  "mock-left",    // 02 Karte bearbeiten
  "mock-right",   // 03 GoTo
  "headline-top", // 04 Raumauswahl
  "mock-left",    // 05 Benachrichtigungen
  "mock-right",   // 06 Update
  "mock-left",    // 07 Mehrere Roboter
  "headline-top", // 08 Consumables
  "mock-right",   // 09 Volle Kontrolle
];

const SCREEN_IDS = [
  "01-live-map",
  "02-edit-map",
  "03-goto",
  "04-room-order",
  "05-notifications",
  "06-update",
  "07-robots",
  "08-consumables",
  "09-full-control",
] as const;

function sourcePath(id: string, locale: "de" | "en" | "fr"): string {
  return `/screenshots/${locale}/${id}.png`;
}

const SLIDES: Slide[] = SCREEN_IDS.flatMap((id, idx) =>
  (["de", "en", "fr"] as const).map((locale) => ({
    id,
    locale,
    headline: COPY[id][locale].headline,
    subline: COPY[id][locale].subline,
    screenshot: sourcePath(id, locale),
    layout: LAYOUT_ROTATION[idx],
    bgVariant: (idx % 3) as 0 | 1 | 2,
  }))
);

function MultilineText({ text, nowrap = true }: { text: string; nowrap?: boolean }) {
  const lines = text.split("\n");
  return (
    <>
      {lines.map((line, i) => (
        <span key={i} style={{ whiteSpace: nowrap ? "nowrap" : "normal", display: "inline-block" }}>
          {line}
          {i < lines.length - 1 && <br />}
        </span>
      ))}
    </>
  );
}

const BG_VARIANTS = [
  // Variant 0: light blob top-right, dark blob bottom-left
  {
    gradient: `linear-gradient(145deg, ${THEME.bgFrom} 0%, ${THEME.bgTo} 100%)`,
    blobs: [
      { top: "-10%", right: "-15%", left: "auto", bottom: "auto", size: 900, color: THEME.blobLight, blur: 140, opacity: 0.55 },
      { top: "auto", right: "auto", left: "-20%", bottom: "-15%", size: 1100, color: THEME.blobDark, blur: 160, opacity: 0.5 },
      { top: "40%", right: "auto", left: "20%", bottom: "auto", size: 700, color: THEME.blobMid, blur: 120, opacity: 0.35 },
    ],
  },
  // Variant 1: light blob bottom-right, dark blob top-left
  {
    gradient: `linear-gradient(200deg, ${THEME.bgTo} 0%, ${THEME.bgFrom} 100%)`,
    blobs: [
      { top: "-15%", right: "auto", left: "-10%", bottom: "auto", size: 1000, color: THEME.blobDark, blur: 150, opacity: 0.5 },
      { top: "auto", right: "-10%", left: "auto", bottom: "-10%", size: 850, color: THEME.blobLight, blur: 130, opacity: 0.55 },
      { top: "35%", right: "60%", left: "auto", bottom: "auto", size: 600, color: THEME.blobMid, blur: 110, opacity: 0.35 },
    ],
  },
  // Variant 2: blobs centered, softer
  {
    gradient: `linear-gradient(165deg, ${THEME.bgFrom} 0%, ${THEME.bgTo} 100%)`,
    blobs: [
      { top: "5%", right: "auto", left: "50%", bottom: "auto", size: 950, color: THEME.blobLight, blur: 170, opacity: 0.5 },
      { top: "auto", right: "50%", left: "auto", bottom: "5%", size: 1000, color: THEME.blobDark, blur: 170, opacity: 0.45 },
      { top: "50%", right: "-10%", left: "auto", bottom: "auto", size: 650, color: THEME.blobMid, blur: 120, opacity: 0.4 },
    ],
  },
];

function Background({ variant }: { variant: 0 | 1 | 2 }) {
  const cfg = BG_VARIANTS[variant];
  return (
    <>
      <div style={{ position: "absolute", inset: 0, background: cfg.gradient }} />
      {cfg.blobs.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            top: b.top,
            right: b.right,
            bottom: b.bottom,
            left: b.left,
            width: b.size,
            height: b.size,
            borderRadius: "50%",
            background: b.color,
            filter: `blur(${b.blur}px)`,
            opacity: b.opacity,
            transform: b.left === "50%" || b.right === "50%" ? "translate(-50%, 0)" : undefined,
          }}
        />
      ))}
    </>
  );
}

function DeviceMockup({
  screenshot,
  scaleOverride,
}: {
  screenshot: string;
  scaleOverride?: number;
}) {
  // New mockup: iPhone 16 Pro Max Black Titanium (jamesjingyi/mockup-device-frames)
  // 1520x3068, transparent screen hole at x=100..1419, y=100..2967
  // Screen hole is exactly 1320x2868 — matches iPhone 6.9" pixel-perfect
  const mockupW = 1520;
  const mockupH = 3068;
  const scale = scaleOverride ?? 0.78;
  const scaledW = mockupW * scale;
  const scaledH = mockupH * scale;

  // Screen insets as fraction of mockup
  const screenLeft = (100 / mockupW) * scaledW;
  const screenTop = (100 / mockupH) * scaledH;
  const screenW = (1320 / mockupW) * scaledW;
  const screenH = (2868 / mockupH) * scaledH;

  return (
    <div
      style={{
        position: "relative",
        width: scaledW,
        height: scaledH,
        filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.35))",
      }}
    >
      {/* Screenshot BEHIND the frame (screen area is transparent) */}
      <img
        src={screenshot}
        alt=""
        style={{
          position: "absolute",
          left: screenLeft,
          top: screenTop,
          width: screenW,
          height: screenH,
          display: "block",
          objectFit: "cover",
          borderRadius: (85 / mockupW) * scaledW,
        }}
      />
      {/* Mockup frame on top (transparent screen lets screenshot show through) */}
      <img
        src="/mockup.png"
        alt=""
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          pointerEvents: "none",
        }}
      />
    </div>
  );
}

function HeadlineBlock({
  headline,
  subline,
  headlineSize = 150,
  sublineSize = 76,
}: {
  headline: string;
  subline: string;
  headlineSize?: number;
  sublineSize?: number;
}) {
  return (
    <>
      <h1
        style={{
          fontSize: headlineSize,
          fontWeight: 800,
          lineHeight: 1.0,
          letterSpacing: "-0.025em",
          color: THEME.textPrimary,
          margin: 0,
          whiteSpace: "pre-line",
        }}
      >
        <MultilineText text={headline} />
      </h1>
      <p
        style={{
          fontSize: sublineSize,
          fontWeight: 400,
          lineHeight: 1.2,
          color: THEME.textSecondary,
          margin: "48px auto 0",
          maxWidth: 1150,
          whiteSpace: "pre-line",
        }}
      >
        <MultilineText text={subline} />
      </p>
    </>
  );
}

function SlideCanvas({ slide }: { slide: Slide }) {
  return (
    <div
      style={{
        width: CANVAS_W,
        height: CANVAS_H,
        position: "relative",
        overflow: "hidden",
        isolation: "isolate",
      }}
    >
      <Background variant={slide.bgVariant} />

      {slide.layout === "headline-top" && (
        <>
          <div
            style={{
              position: "absolute",
              top: 220,
              left: 0,
              right: 0,
              padding: "0 100px",
              textAlign: "center",
              zIndex: 2,
            }}
          >
            <HeadlineBlock headline={slide.headline} subline={slide.subline} />
          </div>
          <div
            style={{
              position: "absolute",
              top: 880,
              left: "50%",
              transform: "translateX(-50%)",
              zIndex: 2,
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} />
          </div>
        </>
      )}

      {slide.layout === "mock-left" && (
        <>
          {/* Mock oversized, cropped off left+bottom edges. Start low enough not to collide with text. */}
          <div
            style={{
              position: "absolute",
              left: -120,
              top: 900,
              zIndex: 2,
              transform: "rotate(-8deg)",
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={0.97} />
          </div>
          {/* Headline top-right, safely above mock */}
          <div
            style={{
              position: "absolute",
              top: 200,
              right: 100,
              width: 1050,
              textAlign: "right",
              zIndex: 3,
            }}
          >
            <h1
              style={{
                fontSize: 140,
                fontWeight: 800,
                lineHeight: 1.0,
                letterSpacing: "-0.025em",
                color: THEME.textPrimary,
                margin: 0,
              }}
            >
              <MultilineText text={slide.headline} />
            </h1>
            <p
              style={{
                fontSize: 68,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: "40px 0 0 0",
                whiteSpace: "pre-line",
              }}
            >
              <MultilineText text={slide.subline} />
            </p>
          </div>
        </>
      )}

      {slide.layout === "mock-right" && (
        <>
          {/* Mock oversized, cropped off right+bottom edges */}
          <div
            style={{
              position: "absolute",
              right: -120,
              top: 900,
              zIndex: 2,
              transform: "rotate(8deg)",
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={0.97} />
          </div>
          {/* Headline top-left, safely above mock */}
          <div
            style={{
              position: "absolute",
              top: 200,
              left: 100,
              width: 1050,
              textAlign: "left",
              zIndex: 3,
            }}
          >
            <h1
              style={{
                fontSize: 140,
                fontWeight: 800,
                lineHeight: 1.0,
                letterSpacing: "-0.025em",
                color: THEME.textPrimary,
                margin: 0,
              }}
            >
              <MultilineText text={slide.headline} />
            </h1>
            <p
              style={{
                fontSize: 68,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: "40px 0 0 0",
                whiteSpace: "pre-line",
              }}
            >
              <MultilineText text={slide.subline} />
            </p>
          </div>
        </>
      )}

      {slide.layout === "mock-podest" && (
        <>
          {/* Extra bright highlight blob right under the device — the "podest" */}
          <div
            style={{
              position: "absolute",
              top: 1450,
              left: "50%",
              transform: "translateX(-50%)",
              width: 1400,
              height: 1400,
              borderRadius: "50%",
              background: THEME.blobLight,
              filter: "blur(180px)",
              opacity: 0.6,
              zIndex: 1,
            }}
          />
          {/* Headline top */}
          <div
            style={{
              position: "absolute",
              top: 220,
              left: 0,
              right: 0,
              padding: "0 100px",
              textAlign: "center",
              zIndex: 3,
            }}
          >
            <h1
              style={{
                fontSize: 150,
                fontWeight: 800,
                lineHeight: 1.0,
                letterSpacing: "-0.025em",
                color: THEME.textPrimary,
                margin: 0,
              }}
            >
              <MultilineText text={slide.headline} />
            </h1>
          </div>
          {/* Mock centered, sitting on the highlight */}
          <div
            style={{
              position: "absolute",
              top: 700,
              left: "50%",
              transform: "translateX(-50%)",
              zIndex: 3,
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={0.71} />
          </div>
          {/* Subline bottom */}
          <div
            style={{
              position: "absolute",
              bottom: 180,
              left: 0,
              right: 0,
              padding: "0 120px",
              textAlign: "center",
              zIndex: 3,
            }}
          >
            <p
              style={{
                fontSize: 76,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: 0,
                maxWidth: 1150,
                marginLeft: "auto",
                marginRight: "auto",
              }}
            >
              <MultilineText text={slide.subline} />
            </p>
          </div>
        </>
      )}

      {slide.layout === "mock-edge" && (
        <>
          {/* Mock rotated 90° landscape, stretching edge-to-edge, cropped both sides */}
          <div
            style={{
              position: "absolute",
              top: "50%",
              left: "50%",
              transform: "translate(-50%, -50%) rotate(-90deg)",
              zIndex: 2,
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={0.91} />
          </div>
          {/* Headline top */}
          <div
            style={{
              position: "absolute",
              top: 220,
              left: 0,
              right: 0,
              padding: "0 100px",
              textAlign: "center",
              zIndex: 3,
            }}
          >
            <h1
              style={{
                fontSize: 150,
                fontWeight: 800,
                lineHeight: 1.0,
                letterSpacing: "-0.025em",
                color: THEME.textPrimary,
                margin: 0,
              }}
            >
              <MultilineText text={slide.headline} />
            </h1>
          </div>
          {/* Subline bottom */}
          <div
            style={{
              position: "absolute",
              bottom: 200,
              left: 0,
              right: 0,
              padding: "0 120px",
              textAlign: "center",
              zIndex: 3,
            }}
          >
            <p
              style={{
                fontSize: 76,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: 0,
                maxWidth: 1150,
                marginLeft: "auto",
                marginRight: "auto",
              }}
            >
              <MultilineText text={slide.subline} />
            </p>
          </div>
        </>
      )}
    </div>
  );
}

export default function Home() {
  const refs = useRef<Record<string, HTMLDivElement | null>>({});
  const [busy, setBusy] = useState<string | null>(null);

  async function exportSlide(slide: Slide) {
    const key = `${slide.id}-${slide.locale}`;
    const el = refs.current[key];
    if (!el) return;
    setBusy(key);
    try {
      const dataUrl = await toPng(el, {
        pixelRatio: 1,
        cacheBust: true,
        width: CANVAS_W,
        height: CANVAS_H,
      });
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${slide.id}-${slide.locale}.png`;
      a.click();
    } finally {
      setBusy(null);
    }
  }

  return (
    <div style={{ padding: 40, background: "#0f172a", minHeight: "100vh" }}>
      <h1 style={{ color: "white", fontSize: 32, marginBottom: 24 }}>
        ValetudiOS — App Store Screenshots (9 Screens × DE/EN)
      </h1>
      <p style={{ color: "#94a3b8", marginBottom: 32 }}>
        Klicke „Export" unter einem Slide, um ihn als 1320×2868 PNG herunterzuladen.
        Chrome verwenden. Screens 2–9 zeigen Placeholder-Screenshot (IMG_8036 Karte) —
        später pro Screen ersetzen.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 40,
          gridAutoRows: "min-content",
        }}
      >
        {SLIDES.map((slide) => {
          const key = `${slide.id}-${slide.locale}`;
          return (
            <div key={key}>
              <div
                style={{
                  background: "#1e293b",
                  padding: 16,
                  borderRadius: 8,
                  marginBottom: 16,
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <span style={{ color: "white", fontWeight: 600 }}>
                  {slide.id} · {slide.locale.toUpperCase()}
                </span>
                <button
                  onClick={() => exportSlide(slide)}
                  disabled={busy === key}
                  style={{
                    background: busy === key ? "#475569" : "#3B87F6",
                    color: "white",
                    border: "none",
                    padding: "10px 20px",
                    borderRadius: 6,
                    fontWeight: 600,
                    cursor: busy === key ? "wait" : "pointer",
                  }}
                >
                  {busy === key ? "Exportiere…" : "Export PNG"}
                </button>
              </div>
              {/* Visible scaled preview — purely for viewing */}
              <div
                style={{
                  width: CANVAS_W * 0.25,
                  height: CANVAS_H * 0.25,
                  overflow: "hidden",
                  background: "#0b1220",
                  borderRadius: 8,
                }}
              >
                <div
                  style={{
                    width: CANVAS_W,
                    height: CANVAS_H,
                    transform: "scale(0.25)",
                    transformOrigin: "top left",
                  }}
                >
                  <SlideCanvas slide={slide} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Hidden full-size render nodes — used ONLY for html-to-image export.
          Positioned offscreen but fully rendered at 1320x2868. */}
      <div
        aria-hidden
        style={{
          position: "fixed",
          left: 0,
          top: 0,
          width: 0,
          height: 0,
          overflow: "visible",
          opacity: 0,
          pointerEvents: "none",
          zIndex: -1,
        }}
      >
        {SLIDES.map((slide) => {
          const key = `${slide.id}-${slide.locale}`;
          return (
            <div
              key={`export-${key}`}
              ref={(el) => {
                refs.current[key] = el;
              }}
              style={{ width: CANVAS_W, height: CANVAS_H }}
            >
              <SlideCanvas slide={slide} />
            </div>
          );
        })}
      </div>
    </div>
  );
}
