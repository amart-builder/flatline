# Flatline ☠️

**A countdown to your phone's death.**

When your iPhone battery gets low, Flatline puts a live countdown on your Lock Screen and Dynamic Island telling you roughly when your phone will die.

```
TIME OF DEATH: 3:42 PM
        1:47:12
```

## How it works

- iOS won't let apps run in the background to watch your battery. Flatline uses a side door: a **Shortcuts personal automation** ("When battery falls below 20%") fires a Flatline App Intent with no confirmation needed.
- The intent estimates your time of death from your phone's recent drain rate (learned on-device) and starts a **Live Activity** with a system-rendered countdown that ticks live without the app running.
- A home screen **widget** shows the estimate any time.
- Estimates are honest guesses. iOS gives apps battery level in 5% steps and no screen-on data, so Flatline says "around 3:42 PM" and means the "around."

## Privacy

No accounts. No tracking. No network. Just death.

Everything is computed and stored on your phone. The app makes zero network calls.

## Project layout

- `Flatline/`: SwiftUI app
- `FlatlineWidgets/`: widget + Live Activity extension
- `Packages/FlatlineKit/`: the estimation engine (pure Swift, unit-tested: `cd Packages/FlatlineKit && swift test`)

## Building

Open `Flatline.xcodeproj` in Xcode 16+, set your own team + bundle ID, run. Or `./deploy.sh device` with an iPhone connected.

## License

MIT
