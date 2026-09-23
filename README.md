# Vouchhunter

Plattform för kampanjer med skattjakter utomhus, AR-insamling och voucherinlösen.

**Under aktiv utveckling. Inte lanseringsklar.** Projektet innehåller en fungerande lokal API-/portalgrund och en iOS-app under uppbyggnad. Android, skarp drift och butikspublicering återstår. Se `docs/STATUS.md` för verifieringsstatus.

## Struktur

- `backend/` – WSGI-API, SQLite, konton, kampanjer, reservationer, vouchers och Stripe-koppling.
- `web/` – företagsportal och offentliga kampanjsidor, utan byggsteg.
- `ios/` – native SwiftUI-app med MapKit och RealityKit; öppna `Vouchhunter.xcodeproj`.
- `packages/HuntCore/` – Swift-modeller och geoberäkning med tester.
- `android/` – reserverad för Android-klienten; ej färdig.
- `docs/` – designbeslut, drift och kvarvarande arbete.

## Lokal start

Python 3.11 eller senare:

```sh
python3 -m backend.app
```

Öppna http://127.0.0.1:8080 och skapa ett företagskonto. Databasen skapas i `data/` och ingår inte i Git. Inga fiktiva kampanjer eller användare skapas automatiskt. Publicering kräver betalning och är spärrad tills betalningsleverantören konfigurerats.

Projektet är proprietärt tills ägaren beslutar annat. Ett publikt repo är inte en open source-licens.
