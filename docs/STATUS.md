# Arbetsstatus – 23 september 2026

Leveransmålet är hela lösningen. Projektet är under aktiv utveckling och inte lanseringsklart.

## Implementerat
- Separat kunddashboard för kampanjöversikt, resultat, betalningar och briefbeställningar.
- Separat adminvy/API för kundförfrågningar, kampanjkonfiguration och publicering.
- 3D-bibliotek med GLB-/USDZ-uppladdning, grundläggande filvalidering och plattformsparning.
- Konton, företagsisolering, sessionshantering, reservationer, insamling och engångsinlösen.
- Stripe Checkout med sparad order, signaturkontroll, kontroll av belopp/valuta/session och idempotenta webhook-id:n. Ej anslutet till ett skarpt konto.
- Native Xcode-projekt med SwiftUI, MapKit, RealityKit, Keychain och voucher-QR.
- Kotlin-klient med karta, ARCore/SceneView, Keystore, konto, insamling och voucher-QR.
- Båda klienterna använder kampanjens adminvalda 3D-objekt.
- Databasmigreringar, lokalt backupskript och GitHub Actions.

## Verifierat lokalt
- Xcode Debug simulatorbygge passerar efter de senaste ändringarna för native-design och modellinläsning.
- Appen startar i den separata simulatorn `Vouchhunter iPhone 17 Pro`.
- Inloggning mot lokal backend och lagring i Keychain fungerar med ad hoc-signering.
- Nekad platsåtkomst hanteras och kampanjernas tomma läge visas.
- 21 backendtester passerar: behörigheter, företagsisolering, reservationer under samtidighet, dubbelinsamling, dubbelinlösen, betalningssignaturer och filvalidering.
- 3 Swift-domäntester passerar med kampanjernas modellmetadata.
- Kundportalens inloggning, ursprungliga utkastflöde och nya briefbeställning verifierade i webbläsare. Dashboarden har granskats visuellt mot den uppdaterade Apple-riktningen, även vid 390 px skärmbredd.

## GitHub-kontroller
- Samtliga tre jobb godkända på commit `73588e8`: backendtester, iOS simulatorbygge/Swift-tester och Android APK/lint.
- Verifierad körning: https://github.com/lucaswerneman/vouchhunter/actions/runs/35891465935
- Källkoden är säkerhetskopierad på origin/main. Databas och modeller kräver separat backup.

## Återstår före skarp leverans
- Fysisk AR-, GPS- och 3D-modellverifiering på iPhone och Android.
- Adminpanelens visuella end-to-end-kontroll. Tilldelning av ett lokalt QA-adminkonto väntar på användarens uttryckliga godkännande efter automatisk behörighetsgranskning.
- Utökad platsredigering, personalinbjudningar, e-postverifiering och lösenordsåterställning.
- Återbetalning, prisvisning, kontrollerad hantering av paus/avbokning och supportprocesser.
- Starkare skydd mot förfalskade positionsuppgifter; GPS från klient är inte bevis på fysisk närvaro.
- Skarp HTTPS-domän, drift, mejl, Stripe, Google Maps-nyckel, övervakning och extern backup av databas plus modeller.
- Apple Developer-/Google Play-konton, signering, integritetsuppgifter, universallänkar och butikspublicering.

## Isolering och arbetsantaganden
- Endast `/Users/lucaswerneman/Documents/ChatGPT/Vouchhunter` används för källkod och data. Separat app-id, port 8787, databas och namngiven simulator.
- Inga andra kundprojekt har ändrats, inga globala Git-/Xcode-/molnsynkinställningar har ändrats.
- iOS 18+; native iOS ersätter tidigare Unity-förslag. Android delar API, inte SwiftUI-kod.
- Belöningsreservationen är högst 60 minuter som justerbart arbetsantagande.
- SQLite behöver lasttest och driftbedömning innan större skarp trafik.
- GitHub-repot är publikt. Hemligheter, lokala konton, databaser och uppladdade modeller ingår inte i Git.

## Senaste tillägg
- Admin kan redigera erbjudande, period och omfattning i obetalda utkast. Platser och 3D-koppling bevaras.
- Påbörjad betalning låser både upplägg och modellbyte, även om en äldre betalningssession har löpt ut. Upplåsning kräver ett kommande kontrollerat avbokningsflöde.
- Tre nya backendtester verifierar behörighet, validering, bevarade kopplingar och betalningslås. Visuell adminverifiering väntar fortfarande på godkännandet ovan.

## Betalningsåterkomst
- Kunden återvänder till betalningsöversikten med kampanjkoppling. Betald-status hämtas från servern, aldrig från returadressens parametrar.
- Manuell uppdatering, väntande/utgången betalningslänk och avbruten återkomst visas utan att påstå att en betalning lyckats.
- Utgångna kampanjperioder stoppas före kontakt med betaltjänsten.
- Statusflödet och uppdateringsknappen har kontrollerats i webbläsare. Skarp Stripe-verifiering återstår.
