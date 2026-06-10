# What's New — interner Vorlauf

**Aktueller Stand:** v1.0 ist noch nicht im App Store live. Die initiale Submission läuft als v1.0 ohne `whatsNew`-Feld (Apple akzeptiert das bei First-Release nicht).

**Diese Datei ist nur eine interne Sammlung** für den jeweils nächsten Submission-Zyklus. Wenn v1.0 live ist und v1.0.1 (oder höher) folgt, hier den passenden Text in alle drei Localizations übernehmen.

---

## Vorgemerkt für v1.0.1 (OTA-Fix, Commit b754e24 vom 2026-05-27)

Nur relevant, falls v1.0.1 nach v1.0-Launch nachgeschoben wird. Beim Submission via ASC API auf alle drei Localizations setzen.

### DE

Bugfix-Release für den Firmware-Update-Flow:

• Installieren-Button erscheint jetzt zuverlässig, wenn ein Roboter-Update verfügbar ist
• Installieren-Button und GitHub-Link reagieren getrennt — kein versehentliches Öffnen von GitHub mehr
• Banner verschwindet automatisch, sobald das Update auf dem Roboter durchgelaufen ist
• Während eines laufenden Updates erscheint eine Warnung beim Wegnavigieren
• Download-Anzeige bereinigt (kein irreführender 0%-Balken mehr)

### EN

Bugfix release for the firmware update flow:

• Install button now reliably appears when a robot update is available
• Install button and GitHub link respond independently — no more accidental jump to GitHub
• Banner disappears automatically as soon as the update has finished on the robot
• Warning prompt when navigating away during a running update
• Download indicator cleaned up (no more misleading 0% bar)

### FR

Correctifs pour le processus de mise à jour du firmware :

• Le bouton « Installer » apparaît désormais de manière fiable quand une mise à jour est disponible
• Le bouton « Installer » et le lien GitHub réagissent séparément — plus d'ouverture accidentelle de GitHub
• La bannière disparaît automatiquement dès que la mise à jour est terminée sur le robot
• Un avertissement s'affiche si vous quittez la vue pendant une mise à jour en cours
• Affichage du téléchargement nettoyé (plus de barre 0% trompeuse)

---

## v1.0 Launch-Features (für App-Description, nicht Whats-New)

Bei der initialen Submission gehören diese in die normale App-Beschreibung (`description`), nicht in `whatsNew`.

### DE

Native iOS-App zur lokalen Steuerung deiner Saugroboter mit quelloffener Firmware.

• Live-Karte in Echtzeit
• Karte bearbeiten
• GoTo-Orte
• Reinigungsreihenfolge
• Benachrichtigungen
• Firmware-Updates lokal
• Multi-Roboter
• Consumables-Tracking
• Volle lokale Kontrolle

### EN

Native iOS app for local control of your vacuum robots running open-source firmware.

• Real-time live map
• Edit your map
• GoTo spots
• Cleaning order
• Notifications
• Local firmware updates
• Multi-robot
• Consumables tracking
• Full local control

### FR

Application iOS native pour piloter en local vos aspirateurs robots avec firmware open source.

• Carte en direct
• Édition de la carte
• Points GoTo
• Ordre de nettoyage
• Notifications
• Mises à jour firmware locales
• Multi-robots
• Suivi des consommables
• Contrôle local complet
