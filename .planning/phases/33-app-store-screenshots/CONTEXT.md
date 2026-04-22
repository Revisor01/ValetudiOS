---
phase: 33
name: App Store Screenshots
milestone: v4.0.0
status: not_planned
created: 2026-04-13
---

# Phase 33: App Store Screenshots

## Goal

Produktionsreife App-Store-Screenshots für ValetudiOS erstellen — iPhone-only, Sprachen DE und EN, visueller Stil schlicht-dynamisch im Logo-Branding (blaue Gradient-Blobs, clean). Output: Upload-fertige Assets im korrekten Format für App Store Connect.

## Scope

**In Scope:**
- Screen-Konzept: Welche Features der App werden gezeigt, in welcher Reihenfolge, mit welchen Headlines
- Tooling-Entscheidung: ParthJadhav/app-store-screenshots Kit vs. Figma-Template vs. eigenes Next.js-Setup vs. natives Swift/SwiftUI-Rendering
- Mock-Up-Template: Device-Frame (iPhone Pro Max), Headline-Typografie, Hintergrund (blaue Gradient-Blobs wie Logo)
- Quell-Screenshots aus echter App (iOS Simulator, 6.9" Pro Max, 1290×2796)
- Rendering-Pipeline: DE- und EN-Varianten pro Screen
- Finale PNGs in exakt geforderter Apple-Auflösung

**Out of Scope:**
- iPad-Screenshots (App ist iPhone-only bisher)
- FR-Lokalisierung der Screenshots (App unterstützt DE+EN+FR, aber für initialen Release reichen DE+EN; FR kann später nachgereicht werden)
- Text-Listing (Titel/Beschreibung/Keywords) — bereits in Phase 32 erledigt

## Abgrenzung zu Phase 32

Phase 32 (App Store Listing) = Text-Content (Titel, Untertitel, Keywords, Beschreibung, Review Notes, Screenshots-Anleitung als Dokument)
Phase 33 (diese) = Visuelle Assets (die Screenshots selbst, fertig zum Upload)

## Offene Fragen (für Discuss-Phase)

1. **Anzahl und Auswahl der Screens:** 5, 8 oder 10? Apple erlaubt bis zu 10 pro Device-Größe. Welche Features wollen wir zeigen (Dashboard, Live-Map, Raumauswahl, Historie, Notifications, Settings …)?
2. **Headline-Strategie:** Feature-Titel ("Live-Karte in Echtzeit") oder Value-Claim ("Zuhause, wenn du unterwegs bist")? DE und EN separat oder parallel-übersetzt?
3. **Tooling:** ParthJadhav-Kit (Next.js + html-to-image) vs. Figma mit Export-Plugin vs. SwiftUI mit ImageRenderer. Was ist der beste Trade-off zwischen Kontrolle, Aufwand und Anpassbarkeit?
4. **Device-Frame-Stil:** Realistisches Pro Max Titanium Mockup, flacher Outline-Rahmen, oder rahmenlos mit nur leichtem Schatten?
5. **Hintergrund-Design:** Wie genau setzen wir "Logo-Stil" um? Abstrakte blaue Blobs? Gradient-Verlauf? Mit/ohne animiertes Gefühl durch Tiefenstaffelung?
6. **Status-Bar-Handling:** Fake-Statusbar (14:00, volles Signal, volles Akku) oder echte aus dem Simulator? Notch/Dynamic Island stilisieren oder weglassen?
7. **Review-Loop:** Wer prüft die Screenshots bevor sie hochgeladen werden? Nur du, oder soll jemand extern drüberschauen?

## Constraints

- App ist auf main-Branch, Phase 30-32 erledigt, Manual-Control-Fix aus aktiver Debug-Session läuft parallel
- Apple-Upload-Format: PNG, RGB, exakt 1290×2796 für 6.9" Pro Max
- App Store Connect erlaubt nur eine Screenshot-Set-Größe; 6.9" wird für alle Devices skaliert dargestellt
