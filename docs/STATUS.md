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

## Spelupplevelse – iPhone
- Kampanjjakten har karta som huvudvy med samlingsstatus, numrerade fynd, nästa mål, GPS-avstånd och gångväg. Kampanjdetaljer ligger i en separat sheet.
- AR: tryck på modellen, laddningsläge, omstart vid spårningsfel, serverbekräftad insamlingsanimation och haptik. Slutförd jakt öppnar vouchers.
- Objekt placeras med raycast mot en identifierad horisontell yta i bildens centrum; modellens geometriska mitt normaliseras.
- Xcode simulatorbygge verifierar kompilering. AR-träfftestning, ytor, rörelse och den nya kampanjvyn med en publicerad kampanj återstår att verifiera på fysisk enhet. Android har fortfarande den tidigare spelvyn.

## Bedöm designen i simulatorn
Välj Xcode-schemat `Vouchhunter Preview` och destinationen `Vouchhunter iPhone 17 Pro`. Schemat startar den riktiga kampanjvyn med en tydligt märkt, lokal exempeljakt (3 av 10 fynd). Den använder inga backendkonton eller kampanjändringar. Endast Debug i simulatorn stöder förhandsvisningen; kamera-AR och riktiga vouchers ingår inte. Vanliga `Vouchhunter`-schemat använder riktiga API-data.

## Family-referens
Referos Family-appskärmar har nu granskats visuellt. Kampanjjakten använder solida systemytor, rundad systemtypografi, tydlig grön primärknapp och en samling med fyllda platser. Karta och native sheets bevaras. Simulatorns kampanjvy och öppning av detaljer är visuellt verifierade. AR-knappens formspråk är harmoniserat; kamera-AR är fortsatt inte verifierad i simulator.

## Avskalad karta
Vinklad, dämpad 3D-karta och ett aktivt föremål ersätter stora nummermarkörer. Den lokala pizzaförhandsvisningen har visuellt verifierats i simulator. Verkliga kampanjer laddar sin USDZ till kartmarkören; godtyckliga uppladdade modellformat behöver fortsatt enhetstestning. Kundens belöning och återstående fynd visas i spelpanelen.

## Gemensam design och interaktiv simulator
- Ordinarie iOS-flöde använder nu mörk monospaced design med gemensamma knappar, konturer och paneler: inloggning, upptäckt, kampanjdetaljer, jakt, AR, kuponger och konto.
- `Vouchhunter Preview` öppnar nu flikarna Jakten, Upptäck, Kuponger och Testläge. Lokala insamlingar uppdaterar samma Hunt-/Voucher-modeller som produktvyerna använder. Efter tio fynd skapas en tydligt ogiltig testkupong utan QR-kod. Omstart, utgången reservation och simulerad inlösen finns under Testläge.
- Testdata finns bara i processminnet och återställs vid omstart. SimulatorStore och simulatorns mötesvy kompileras endast för Debug + simulator. Ingen server, betalning, behörighet eller riktig voucher påverkas.
- Android och webbportalen har samma grundläggande designroller. Androids spelvy och fysisk AR behöver fortsatt mer arbete och separat visuell enhetsverifiering.
- Xcode Debug-simulatorbygge godkänt. Insamling och återgång till karta visuellt verifierade. Portalens översikt och betalningsvy visuellt granskade.
