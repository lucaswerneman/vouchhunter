# Designbeslut

## Gällande riktning – WhatsApp, neutral palett, kundens kampanj

Detta ersätter tidigare Family/MSCHF-riktningar nedan, som finns kvar enbart som historik.

- WhatsApp iOS är referensen: systemtypografi, ljusgrå bakgrund, vita grupperade rader, diskreta avdelare och tre stabila flikar: Upptäck, Kuponger, Konto.
- [WhatsApp-inställningar](https://refero.design/screens/f3caac1c-c651-4836-97e8-e43b46b76a73) styr grupper och radrytm. [Kontaktinformation](https://refero.design/screens/125f0071-b6c3-49fd-8005-a4b310f8f023) styr kampanjens avatar, namn och informationsgrupper. [Platsväljaren](https://refero.design/screens/d70f8957-114d-41b6-9b98-5c5c61ec36ac) styr kartans bottenpanel. Dessa bilder har granskats, inte bara sökresultat.
- Vouchhunters gemensamma kontroller använder grafitgrått. Kampanjen kan ha egen accent, bakgrund, logotyp och hero-bild; redigering sker på obetalda utkast och låses när betalning inletts.
- Brillo-exemplet använder rött #FF113A och gräddvitt #FFF5EB från [Brillo Pizza](https://brillopizza.se/). Kampanjen är fiktiv och kupongen saknar inlösenvärde.
- Resan börjar med kampanj och belöning. Inloggning behövs först för en riktig jakt. GPS efterfrågas i jakten och kamera vid insamling.
- Pizza, lugn svävning, pulserande ring och haptik ger spelkänsla. Minska rörelse stoppar de kontinuerliga animationerna. AR är lokal ytplacering inom GPS-radie, inte ett delat geospatialt ankare.
- Simulatorn provar tio fynd. Det separata fälttestet på Odenplan provar ett fynd med riktig GPS och AR. Det får aldrig presenteras som en skarp Brillo-kampanj.

## Förtydligad startresa – 24 september

Användarens godkända kampanjrad är fortsatt referensen. Raden behåller logotyp, företag och titel men tillför konkret insamlingsmål och belöning. Fälttestets mål är fortfarande en pizza; simulatorns mål är tio. Exempelmarkeringen visas intill erbjudandet.

Primära kampanjknappar har vit text. Knappfärgen mörkas vid behov inom samma kulör för läsbarhet; kundens logotyp och övriga accentfärg bevaras. Förstagångsintroduktionen följer de redan granskade WhatsApp-grupperna och systemtypografin: en skärm med produktförklaring, tre steg och en primär handling. Den sparas per installation och kan öppnas igen från frågetecknet eller Konto. Inga åtkomstfrågor ställs där.

## Historik – ersatta riktningar

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

## Korrigering efter MSCHF-korgreferensen
Tidigare version behöll för mycket av Family. Den senaste användarbilden låser istället panelernas faktiska struktur: tunn ljus ytterlinje, vertikal avdelare mellan objekt och fakta, jämnstor reguljär monospaced text, understruken VISA-länk, horisontella linjer mellan samlings-/belöningsrader och en separat grön pillknapp. Den stora flytande rundade fyndpanelen ersätts av en svart yta från kant till kant. Kartan och föremålets rendering bevaras.

## Gemensamt produktsystem (gällande riktning)
Denna riktning ersätter äldre ljusa/Family-dominerade beslut ovan. Användaren vill ha en egen kombination, med MSCHF:s tydliga struktur som huvudreferens. Native navigation och mjuka primärknappar är kvar; stora rundade standardkort är inte basen.

| Roll | Gemensamt beslut | Källa |
|---|---|---|
| Bakgrund | Svart, mörkgrå produktpaneler | Användarens MSCHF-korgbild |
| Typografi | Reguljär systemmonospace, korta versala etiketter; löptext får behålla normal skrift | MSCHF-bilderna och läsbarhetskrav |
| Struktur | Tunna ljusa avdelare, 12-punkters panelradie, produkt/fakta uppdelat | Korgreferensen |
| Handling | Grön pillknapp, svart text; sekundärt tunn kontur | Egen accent + begränsad Family-inspiration |
| Spelvärld | Mörk vinklad riktig karta, färgat föremål | Användarens kartreferens |
| Företagsportal | Samma färg-/typografifamilj, arbetsyta med tabeller och formulär | Separata kund/admin-uppgifter |

iOS använder delade HuntStyle, HuntPillButton, HuntSecondaryButton, HuntRule och huntPanel. Appens ordinarie rot applicerar temat även utanför simulatorn. Android använder HuntStyle för text/knappar och mörk kartstil. Webbens tidigare ljusa override-lager har ersatts av samma färgroller. Detta är en gemensam visuell grund; Androids spelinteraktioner är ännu inte likvärdiga med iOS.
