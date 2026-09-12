# CadenceEngine

Coeur Swift pur d'OpenCadence. Le package ne depend ni de SwiftUI, ni de
SwiftData, ni de HealthKit, ni d'un service tiers.

```bash
swift test --package-path ios/CadenceEngine
```

Les tests lisent l'oracle canonique
`fixtures/ios-engine-v1/cases.json` directement depuis le depot et executent
les 42 cas. Le catalogue et les profils sont injectes dans le moteur ; l'heure
est toujours fournie par l'appelant.
