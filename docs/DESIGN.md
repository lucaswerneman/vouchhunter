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
