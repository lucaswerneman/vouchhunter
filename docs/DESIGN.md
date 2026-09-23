# Designbeslut

Direkt bygge enligt användarens mandat. Refero-sökningen blockerades av NO_SUBSCRIPTION; inga externa skärmar har påståtts granskade. Refero-skillens lokala Typography, Color, Craft Details och Anti-AI-slop är referensunderlag.

## Låst riktning
Ljus arbetsyta, mörk skogsgrön navigation, lime på primära handlingar, neutral systemtypografi. Kampanjer och deras status är huvudinnehållet; inga påhittade mätvärden, kunder eller aktiva erbjudanden. Mobilens karta är huvudytan. AR-objektets skala är produktens lekfulla signatur.

| Beslut | Källa | Roll |
|---|---|---|
| Systemfont, 16 px bas, korta rubriker | Typography | Läsbar arbetsprodukt och native iOS |
| Mörk text på ljus yta, få accentfärger | Color | Tydlig hierarki; lime endast handling och varumärke |
| Sidebar + kampanjlista; mobil bottennavigation | Produktens separata arbetsuppgifter | Företag administrerar, deltagare upptäcker |
| Synliga etiketter, 44 px pekytor, tangentbordsfokus | Craft Details | Tillgängliga formulär och kontroller |
| Tomt läge med skapa-handling | Anti-AI-slop + verkligt tom databas | Inga fiktiva resultat |
| Äkta kartor och native 3D | Användarens brief | Plats och AR är funktion, inte dekoration |

Undvik gradienter, emojiikoner, dekorativa diagram, säljsektioner i arbetsvyn och falska betalningsbekräftelser. Referenserna anger metod och hantverk, inte en befintlig Vouchhunter-identitet.

## Uppdaterad riktning från användaren

Användaren vill ha Apples designspråk, native iOS och egna färger. Detta ersätter den mörka sidopanelen ovan. Primär designkälla är nu Apples HIG och SwiftUI-systemkomponenter. Refero-craft används som genomförandestöd.

- [Apple HIG – Color](https://developer.apple.com/design/human-interface-guidelines/color): semantiska systembakgrunder och dynamiska färger. Egna gröna accentfärger för handlingar; inga hårdkodade ljusa textbakgrunder i mörkt läge.
- [Apple HIG – Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars): standardkontroller och tydlig navigation. Native NavigationStack, TabView, Form, List, sheet och alert.
- [Apple HIG – Materials](https://developer.apple.com/design/human-interface-guidelines/materials): systemmaterial där kontroller ligger över innehåll, särskilt AR. Ingen egen imitation av Liquid Glass i appen.
- [Apple HIG – Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars): stabil navigation för Upptäck, Vouchers och Profil.

Webbportalen använder systemfont, ljus sidonavigation och grupperade ytor med samma hierarki. Webben är inte native SwiftUI; iPhone-appen använder faktiska systemkomponenter. Android delar färger, ordval och informationsstruktur med iOS, med native Android-kontroller.

## Kund och admin

Kund betyder företaget som köper kampanjen. Kunden ser översikt, kampanjer, betalningar och inlösen, och skickar en enkel brief. Plattformens admin konfigurerar platser, 3D-objekt och publicering. Kunden ska inte exponeras för koordinatfält eller filformat.

## Spelarens upplevelse: spel före arbetsapp

Spelaren ska möta en värld att utforska, inte en dashboard. Kampanjjakten använder en karta som huvudvy, numrerade fynd, en kompakt samlingsmätare och nästa mål nära tummen. Kampanjtext och villkor ligger i en separat native sheet. Inga påhittade XP, topplistor eller falsk aktivitet.

AR använder kampanjens riktiga modell. Objektet placeras på en identifierad horisontell yta i kamerans riktning, går att trycka på och krymper bort efter serverbekräftad insamling. Haptisk respons markerar fyndet; sista fyndet leder till belöningen. Knappen finns kvar som tillgängligt alternativ till att träffa objektet.

Teknisk referens: [Apple RealityKit – ARView](https://developer.apple.com/documentation/RealityKit/ARView) för träfftestning och raycast. Det är lokal ytplacering inom en GPS-zon, inte ännu ett permanent geospatialt ankare som alla ser på exakt samma punkt. Modellstorleken är fortfarande normaliserad till 1,5 meter. Nästa kvalitetssteg är fysisk AR-verifiering, kampanjstyrd skala, objektens rörelse/ljud och motsvarande spelvy på Android.

## Family – låst appreferens

Användaren har valt Family. Refero tillgängligt igen: stil `fd409745-cef9-4cb2-ae6b-e16d9161fb89` granskad som bakgrund, men appskärmarna styr denna ändring.

| Beslut | Källa | Anpassning |
|---|---|---|
| Solida ljusa paneler, rymliga rundningar | [Watching Wallets](https://refero.design/screens/ca88e8c5-2fb2-4935-b52b-0edf5aaac6bb) | Spelarens nästa mål på vit panel över kartan; ingen grön glasdimma |
| Rundad sans, få tydliga nivåer | Båda granskade appbilderna | SF Rounded i spelvyn; Dynamic Type behålls |
| Färgat samlingskort och pillknapp | [Wallets ready](https://refero.design/screens/cc5547f7-52a5-490c-8755-d660e00917f4) | Mättad Vouchhunter-grön för handling/status, ljus mint för samling; inte Families varumärkestillgångar |
| Koncentrerad handling i nederkant | Watching Wallets | En bred primärknapp, sekundära handlingar lugnare |
| Samling visas som fyllda platser | Användarens spelkrav | Upp till tio visuella markeringar; större mål behåller numerisk progress |

Avvisat: webbplatsens serifrubriker och dekorativa karaktärer överförs inte till appens kontroller. Kartan är fortsatt huvudmedia. Inga kopierade illustrationer, inga falska belöningar. Ytor följer systemets mörka läge; animationer respekterar Reduce Motion.

## Avskalad spelkarta och kupongjakt

Användarens Amo-kartbild styr perspektivet: nära, vinklad karta med tydligt föremål. MapKit använder dämpad standardstil utan POI-etiketter. Ett valt fynd visas med kampanjens USDZ i en statisk 3D-vy; andra tillgängliga platser är små valbara punkter. Insamlade platser lämnar kartan. Samlingspill och centreringsknapp ersätter den stora övre panelen. Nästa-fynd-panelen visar återstående steg och konkret belöning. Förhandsvisningens pizza är en lokal procedurmodell, inte ett uppladdat kundobjekt.

Produktloopen är en spelifierad kuponginsamling: upptäck kampanj → gå till föremål → öppna möte → samla → åter till karta → lås upp kupong → lös in. Pokémon GO är referens för kartans upptäckt/möte, inte för grafiska tillgångar eller hela progressionsekonomin. [Niantics AR-beskrivning](https://niantic.helpshift.com/hc/en/6-pokemon-go/faq/28-catching-pokemon-in-ar-mode-1712012768/) skiljer verklig kamera-AR från kartvyn. Inga kast, strider eller nivåkrav införs i Vouchhunter. Kupongen och återstående fynd ska vara läsbara under hela jakten.

## MSCHF-bildens typografi och spelkänsla
Användarens bifogade bild styr nu spelarens HUD: monospaced systemtypografi, korta versala etiketter, tunna linjeikoner, mörka paneler och en ensam tydlig limegrön primärhandling. Detta ersätter Family-rundad typografi i jakt/AR; Family bidrar fortsatt med pillknappar, mjuka paneler och avstånd. Kartan behålls ljus och dämpad. Längre villkor skrivs fortsatt som vanlig text, inte versala textblock. Ingen gissning om referensens exakta font: native systemmonospace används.

Användaren preciserade referensen till [MSCHF Bar & Grill & E-commerce i Refero](https://refero.design/apps/115) och bekräftade att 3D-kartan ska behållas. Den vinklade kartan är fortsatt huvudytan; monospaced typografi och mörka spelpaneler ligger ovanpå. Simulatorns kombinerade vy är visuellt verifierad.

## Mörk spelkarta
Användaren har låst MSCHF som huvudreferens och vill även ha mörk karta. Jaktvyn använder därför mörkt färgschema även för MapKit, med bibehållen realistisk höjd, dämpade kartetiketter och färgat 3D-föremål. Lime reserveras för spelarens primärhandling; kupongmålet ligger kvar i panelen.

Accentprecisering: användaren vill följa MSCHF-referensen nära men ersätta gult med grönt. Primärknapp och spelaccent använder nu klart grönt (sRGB 0.18, 0.95, 0.42), inte gulgrön lime.
