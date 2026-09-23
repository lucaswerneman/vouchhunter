# Arbetsstatus – 23 september 2026

Leveransmålet är hela lösningen, inte en demo. Detta dokument beskriver faktisk status, inte löften om färdig funktion.

## Skrivet, verifiering pågår
- API för registrering, inloggning, företagskonton, kampanjutkast och publiceringskontroll.
- Transaktioner för reservationer, insamling och engångsinlösen.
- Stripe Checkout och signaturkontroll för webhooks, ej testat mot ett anslutet Stripe-konto.
- Företagsportal för kampanjer, utkast, statistik, betalningsöverlämning och inlösen.
- iOS-källkod för konto, karta, kampanjer och jakt.

## Återstår
- Färdigställa och kompilera Xcode-projekt, AR och voucherplånbok.
- Implementera Android-appen och verifiera på en fysisk Android-enhet.
- Behörighets-/konkurrenstester och granskning av betalningsregler.
- Kampanjredigering, personalinbjudningar, plattformsadministration, lösenordsåterställning och e-postverifiering.
- Starkare skydd mot förfalskade positionsuppgifter (GPS från klient är inte bevis på närvaro).
- Skarp domän, HTTPS, drift, mejl, Stripe-konto, priser, återbetalning och övervakning.
- Apple Developer-/Google Play-konton, signering, appikoner, integritetsuppgifter och butikspublicering.

## Beslut under genomförandet
- iPhone får SwiftUI/MapKit/RealityKit för direkt Xcode-stöd. Det ersätter tidigare preliminärt Unity-förslag.
- Android ska dela API och regler, inte SwiftUI-kod.
- Tidsbegränsad reservation på högst 60 minuter är ett implementerat arbetsantagande, fortfarande justerbart.
- SQLite är den lokala datagrunden. Produktion behöver kapacitetsbedömning, backup och en definierad driftmodell innan lansering.

## Git
- Användaren har angett https://github.com/lucaswerneman/vouchhunter som backup.
- GitHubs API bekräftade att repot är publikt och har main som standardgren.
- Hemligheter, databaser och byggresultat ska aldrig checkas in.
- Senaste push och byggresultat uppdateras när de är verifierade.
