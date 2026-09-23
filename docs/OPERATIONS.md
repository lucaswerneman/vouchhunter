# Drift och projektisolering

## Projektets gränser

All källkod och lokal data hör till detta repos rot. Git remote är `https://github.com/lucaswerneman/vouchhunter.git`. Inga beroenden till andra kundprojekt ska införas. Ändra inte globala Git-, Xcode- eller synkinställningar för att få detta projekt att fungera.

- iOS-projekt: `ios/Vouchhunter.xcodeproj`; delat scheme: `Vouchhunter`.
- App-id: `se.vouchhunter.app` (release), `se.vouchhunter.app.dev` (debug).
- Backendport: **8787**, bara loopback vid lokal start.
- Databas: `data/vouchhunter.sqlite3`, enbart för detta projekt, ignorerad i Git.
- Android-emulator når backend på `10.0.2.2:8787`; iPhone-simulator på `127.0.0.1:8787`.
- Lokala signing-/serverinställningar ligger i `ios/Configuration/Local.xcconfig`, ignorerad i Git.
- Använd en dedikerad simulator med Vouchhunter i namnet för fortsatt testning.

## iOS

Öppna projektet i Xcode. Debug och Release har separata plist-/xcconfig-filer. iOS 18 är lägsta version för den implementerade RealityKit-geometrin. Kamera används för AR och platsåtkomst endast medan appen används. Sessionsnyckeln sparas i Keychain.

Simulatorbygge utan utvecklarkonto:

```sh
xcodebuild -project ios/Vouchhunter.xcodeproj -scheme Vouchhunter \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/vouchhunter-derived CODE_SIGN_IDENTITY=- build
```

Simulatorn ska ad hoc-signeras för Keychain. `CODE_SIGNING_ALLOWED=NO` kompilerar men gav Keychain-fel vid körning och ska inte användas för inloggningstest. Fysisk iPhone kräver rätt Apple-utvecklarteam och en nåbar HTTPS-backend. Release har avsiktligt ingen fungerande serveradress förrän domänen konfigureras. Universallänkar kräver domän, Associated Domains och apple-app-site-association före lansering; eget `vouchhunter://campaign/<id>`-schema finns i projektet.

## Android

Öppna `android/` i Android Studio. Gradle 8.11.1 låses med officiell wrapper och distributionschecksumma. Java 17 och Android SDK 35 krävs. Bygg med `./gradlew assembleDebug lintDebug`.

`ANDROID_MAPS_API_KEY` sätts som byggmiljövariabel och måste begränsas i Google Cloud till appens identifierare och signeringscertifikat. `VOUCHHUNTER_API_URL` anger HTTPS-servern för Release. Varken nycklar eller keystores ska checkas in. Sessionsnyckeln krypteras med Android Keystore. Google Play Services för AR och en kompatibel enhet krävs för insamling. Google Maps-kontot är inte anslutet ännu.

SceneView 2.3.0 är initialt låst till det API som använts i implementationen. Kontroll av underhåll, native 16 KB-kompatibilitet och aktuellt Play-krav samt fysisk AR-verifiering återstår före publicering.

## Backend

Utvecklingsservern `python3 -m backend.app` är endast för lokal användning. Produktionsdrift kräver en WSGI-server bakom en betrodd TLS-proxy. Exempel på start efter installation av en verifierad Gunicorn-version: `gunicorn 'backend.app:create_app()' --bind 0.0.0.0:8787 --workers 1 --threads 4`.

Konfigurera `DATABASE_PATH`, `PUBLIC_URL`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` och `STRIPE_PRICE_ID` i driftens hemlighetshantering. `.env.example` är dokumentation och läses inte automatiskt in av appen. Säker cookie aktiveras när PUBLIC_URL börjar med https. Lägg rate limiting vid proxyn; den lokala login-begränsningen är inte ett distribuerat skydd.

SQLite använder transaktioner och WAL. All trafik använder för närvarande en skrivtransaktion, vilket prioriterar korrekthet men begränsar kapaciteten. Lasttest och eventuell övergång till PostgreSQL är ett krav före större trafik. Versionshanterade schemamigreringar måste införas innan skarp data börjar användas.

## Betalningar

Checkout skapas på servern. Samma ännu giltiga checkout återanvänds. Ett köp bekräftas enbart av en signerad Stripe-webhook som matchar den sparade sessionen, beloppet, valutan och kampanjen. Upprepade webhook-id:n ger inte dubbla köp. Betalning publicerar inte automatiskt kampanjen; ägaren väljer när publicering ska ske.

Webhook: `POST /api/payments/webhook`. Testa med Stripe-testläge innan live. Återbetalningar, avbokningar, prisvisning före överlämning, moms/fakturaunderlag och återhämtning om Stripe svarar men servern avbryts före lokal lagring återstår att färdigställa.

## Backup

GitHub innehåller källkod och dokumentation, inte kunddata. Det är en separat kopia av koden men ersätter inte databasbackup.

```sh
python3 scripts/backup_database.py --database data/vouchhunter.sqlite3 --destination backups
```

Skriptet använder SQLite backup-API och integritetskontroll. Varje fil får ett nytt tidsstämplat namn och skrivs med privata filrättigheter. Inga filer tas bort och inga gamla backuper skrivs över. Krypterad extern databasbackup och återställningsövning krävs innan skarp drift. Ingen molnsynkning har aktiverats eller ändrats.

## Ej lanseringsklart

Skarp publicering kräver fortfarande e-postverifiering, återställning av konton, personal-/adminhantering, kampanjredigering, granskning av villkor och personuppgifter, bättre fuskdetektion, driftsövervakning och verifierade mobila byggen. Klientens GPS är inte bevis på fysisk närvaro. Ingen testvoucher eller fiktiv kampanj får publiceras som ett skarpt erbjudande.
