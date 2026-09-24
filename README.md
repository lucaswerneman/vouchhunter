# VoucherHunt

Arbetsnamnet är **VoucherHunt**. Projektmapp, Xcode-projekt/scheman, app-ID:n och GitHub-repo behåller tills vidare sina tekniska namn med `Vouchhunter`/`vouchhunter`.

Plattform för kampanjer med skattjakter utomhus, AR-insamling och voucherinlösen.

**Under aktiv utveckling. Inte lanseringsklar.** Projektet innehåller en fungerande lokal API-/portalgrund och en iOS-app under uppbyggnad. iOS- och Android-byggen verifieras i CI. Fysisk AR och hela skarpa kundflödet är ännu inte verifierade. Skarp drift och butikspublicering återstår. Se `docs/STATUS.md` för verifieringsstatus.

## Testa på Odenplan

Börja med [startguiden för iPhone 16e](docs/STARTA-HAR-ODENPLAN.md). Den beskriver installation, testplats och hela resan till testkupongen. Apple-signering och fysisk verifiering återstår; inget TestFlight-bygge är uppladdat.

## Struktur

- `backend/` – WSGI-API, SQLite, konton, kampanjer, reservationer, vouchers och Stripe-koppling.
- `web/` – företagsportal och offentliga kampanjsidor, utan byggsteg.
- `ios/` – native SwiftUI-app med MapKit och RealityKit; öppna `Vouchhunter.xcodeproj`.
- `packages/HuntCore/` – Swift-modeller och geoberäkning med tester.
- `android/` – Kotlin-klient, ARCore/SceneView, Google Maps och Gradle-wrapper; bygge och lint verifieras i CI.
- `docs/` – designbeslut, drift och kvarvarande arbete.

## Lokal start

Python 3.11 eller senare:

```sh
python3 -m backend.app
```

Öppna http://127.0.0.1:8787 och skapa ett företagskonto. Databasen skapas i `data/` och ingår inte i Git. Inga fiktiva kampanjer eller användare skapas automatiskt. Publicering kräver betalning och är spärrad tills betalningsleverantören konfigurerats.

Projektet är proprietärt tills ägaren beslutar annat. Ett publikt repo är inte en open source-licens.
