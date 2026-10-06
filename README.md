# UMLForge

Native macOS-App (SwiftUI, macOS 15+) zum Zeichnen von UML-Klassendiagrammen.

## Starten
    swift run                 # direkt aus dem Terminal
    open Package.swift        # in Xcode öffnen → ▶︎ Run
    ./make_app.sh             # eigenständige UMLForge.app bauen

## Bedienung
- Werkzeuge in der linken Hover-Sidebar oder per Taste: V Auswahl · C/A/I/E/N Elemente · L/P/G/R/O/K/D/T Beziehungen
- Beziehung: Quelle anklicken → Ziel anklicken, oder von der Quelle zum Ziel ziehen
- Scrollen/Trackpad verschiebt, ⌘-Scrollen oder Pinch zoomt, ⌥-Ziehen verschiebt die Ansicht
- Ziehen auf leerer Fläche = Rahmenauswahl, ⇧ erweitert die Auswahl, Pfeiltasten verschieben (⇧ = 10 px)
- ⌘Z / ⇧⌘Z, ⌘D Duplizieren, ⌫ Löschen, ⇧⌘L automatisch anordnen
- Speichern als .umlforge (JSON), Export als PNG (3×) / PDF (Vektor), PlantUML-Code kopieren
