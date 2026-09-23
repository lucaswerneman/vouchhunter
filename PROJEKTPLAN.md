# Vouchhunter – plan för komplett lanseringsversion

Status: planeringsunderlag, 23 september 2026. Vouchhunter är arbetsnamnet.

Leveransmålet är en komplett lösning för skarp användning med iPhone-app, Android-app, företagsportal, plattformsadministration, backend och riktig voucherinlösen. En fristående demo eller pilot är inte slutleveransen. Utveckling sker i etapper med separat testmiljö och verifiering före lansering. Dokumentet är en plan, inte ett besked om att produkten redan är implementerad eller produktionsklar.

## Produktidé och bekräftad riktning

En gemensam app där människor hittar företagskampanjer, går på skattjakt utomhus och samlar virtuella 3D-objekt för att få en voucher. Företag kan länka direkt till sin egen kampanjsida från annonser, sociala medier och QR-koder.

Kartan hjälper deltagaren att hitta platserna. På plats visas ett stort, lekfullt 3D-objekt i kameravyn som deltagaren kan samla in. En jättepizza på Sergels torg är referensexemplet för upplevelsen.

Plattformen ska kunna användas av olika typer av företag och för olika produkter eller lanseringar.

Första versionen ska utvecklas för både iPhone och Android. AR-upplevelsen behöver verifieras på en fysisk telefon från vardera plattformen; stöd för alla telefonmodeller är inte utlovat.

## Teknisk inriktning

Genomförandebeslut efter användarens krav på direkt Xcode-stöd: native iPhone-app med SwiftUI, MapKit och RealityKit/ARKit. Android får en egen Kotlin-app med ARCore via SceneView och Google Maps. Detta ersätter det tidigare preliminära Unity-förslaget. Båda klienterna delar backend, datamodell och regler för kampanjer, insamling och vouchers.

GPS låser upp insamling nära en kampanjplats. Objektet förankras därefter lokalt på en upptäckt yta. Exakt delad AR-förankring mellan användare ingår inte i nuvarande implementation. iPhone-appen kräver iOS 18 eller senare; kompatibla fysiska enheter måste verifieras före lansering.

Företagsportalen är en separat webbapplikation i samma repo. Drift, konfiguration och isolering beskrivs i docs/OPERATIONS.md. Faktisk implementation och kvarstående arbete beskrivs i docs/STATUS.md.

## Kampanjer vid lansering

Företagen ska själva kunna skapa och hantera kampanjer. Antal stopp, insamlingsmål, belöning, giltighet och inlösenställen konfigureras per kampanj. Pizza Hut och pizzajakten i Stockholm är illustrationsexempel; inget samarbete eller erbjudande finns bekräftat.

Arbetsförslag: varje deltagare kan samla varje objekt en gång, oberoende av andra deltagare. Placeringarna måste vara lämpliga för en jakt utomhus. Testdata och testvouchers hålls åtskilda från skarpa kampanjer och riktiga belöningar.

## Kundens flöde

1. Hitta en kampanj i appen eller öppna en direktlänk till den.
2. Läs erbjudande, insamlingsmål, område, tidsperiod och villkor för inlösen.
3. Starta jakten och se objektens platser på kartan.
4. Gå till ett stopp. Appen kontrollerar att deltagaren befinner sig i närheten.
5. Öppna kameran, se 3D-objektet och tryck för att samla det med animation och återkoppling.
6. Se sparade framsteg och fortsätt till nästa stopp.
7. Få en voucher när målet är uppfyllt och belöningsvillkoren är uppfyllda.
8. Visa vouchern för personal som kontrollerar och löser in den en gång.

## Omfattning för lanseringsversionen

### Deltagare

- Kampanjer i närheten och en egen sida per kampanj.
- Direktlänkar till kampanjer.
- Karta med insamlingsplatser och personliga framsteg.
- Platskontroll och insamling av animerade 3D-objekt i kameravyn.
- Sparade framsteg och vouchers kopplade till ett konto.
- Tydliga tillstånd för nekad kamera/platsåtkomst, osäker position och avbruten uppkoppling.

### Företag och administration

- Skapa kampanjutkast med namn, bild, erbjudande, datum och villkor.
- Välja ett objekt ur ett litet 3D-bibliotek och ange insamlingsmål.
- Ange platser, antal belöningar och deltagande inlösenställen.
- Förhandsgranska, publicera och pausa en kampanj.
- Enkel personalvy för att kontrollera och lösa in vouchers.
- Statistik över starter, slutförda jakter, utfärdade och inlösta vouchers.
- Företagskonton, medlemsinbjudningar och roller för ägare, kampanjansvarig och personal.
- Plattformens egen administration för företag, kampanjgranskning, support och missbruk.
- Händelselogg för ändringar, utfärdande och inlösen så att supportärenden kan utredas.

### Drift och leverans

- Separata utvecklings-, test- och produktionsmiljöer.
- Databas, fil- och 3D-lagring, åtkomstkontroll och hantering av hemligheter.
- Övervakning, felloggning, säkerhetskopiering och verifierad återställning.
- Versionshantering av databas och kontrollerad driftsättning med återställningsplan.
- Kontohantering, återställning av åtkomst och rutiner för användardata.
- Bygg- och publiceringsflöden för App Store och Google Play samt driftsättning av webbportaler.
- Domän, driftkonton, utvecklarkonton och eventuella betaltjänster måste kopplas till användarens verksamhet innan skarp publicering. Kostnader och publiceringsuppgifter fastställs före aktivering.

## Regler som behöver hållas av systemet

- Insamling verifieras på servern; klienten bestämmer inte själv belöning eller framsteg.
- Upprepade tryck eller nätverksomförsök får inte skapa dubbla insamlingar eller vouchers.
- En voucher kan bara lösas in en gång, även om två inlösenförsök sker samtidigt.
- Företagets belöningstak får inte överskridas när flera deltagare blir klara samtidigt.
- En utfärdad voucher har egna giltighetsvillkor; dess status ska inte oavsiktligt ändras när en kampanj pausas.
- Personal ska bara kunna hantera de kampanjer och inlösenställen som personalen har behörighet till.
- Samla bara den platsinformation som behövs för funktionen. Kontinuerlig lagring av deltagarens färdväg ingår inte i förslaget.

## Öppna beslut

1. Belöningstilldelning: tidsbegränsad reservation vid jaktstart eller först till kvarn vid slutförande? Reservation är ett tidigare förslag, inte ett godkänt beslut. Regler för utgång, återstart och full belöningspott måste bestämmas före lansering.
2. Målplattformarna är beslutade: både iPhone och Android. Exakta testtelefoner och lägsta stödda systemversioner återstår att fastställa.
3. AR-placering: räcker det att platsen låser upp ett objekt som placeras lokalt i kameravyn, eller måste alla se objektet på exakt samma fysiska punkt? Förslag: börja med lokal placering efter platskontroll.
4. Hur lång promenad och vilken belöning ska första skarpa kampanjen ha?
5. Hur hanteras påbörjade jakter om företaget pausar eller ändrar kampanjen?

## Byggordning och godkännandekriterier

Samtliga etapper ingår i leveransmålet. En enskild etapp är inte en färdig produkt.

### 1. Gemensam grund

Datamodell, konton, företagsisolering, behörigheter, kampanjregler, API och miljöer.

Kriterium: ett företag kan inte läsa eller ändra ett annat företags skyddade data. Regler för kampanjstatus, belöningspott och inlösen är definierade och testbara.

### 2. Mobilappar för iPhone och Android

Kampanjupptäckt, direktlänkar, karta, GPS, AR-insamling, konto och sparade framsteg byggs mot den gemensamma backendtjänsten.

Kriterium: hela insamlingsflödet fungerar på fysiska telefoner från båda plattformarna. Nekad behörighet, otillräcklig AR-kompatibilitet, osäker position och avbrutet nät hanteras. Återförsök ger inga dubbla insamlingar.

### 3. Företagsportal, vouchers och inlösen

Företaget kan skapa, förhandsgranska och publicera en kampanj, hantera inlösenställen och personal samt följa resultat. Kunden får en riktig voucher enligt kampanjvillkoren och personalen löser in den via QR-kod.

Kriterium: hela kedjan från publicering till inlösen fungerar. Samtidiga slutföranden överskrider inte belöningstaket. Samtidiga inlösenförsök kan inte använda en voucher mer än en gång. Eventuella reservationsregler är verifierade.

### 4. Administration och lansering

Supportverktyg, kampanjgranskning, driftövervakning, backup, återställning, publiceringsmaterial och distribution färdigställs.

Kriterium: behörighets- och belastningskontroller är genomförda, återställning har verifierats och flödena har testats utomhus på båda plattformarna. Skarpa erbjudanden, villkor, konton och driftkonfiguration är fastställda. Appbutikernas granskning är ett externt beroende och godkännande kan inte garanteras i förväg.

## Affärsmodell: betalning per kampanj

Beslutat: företagen betalar per kampanj. Abonnemang ingår inte i den beslutade affärsmodellen.

Föreslaget köpflöde för lanseringen:

1. Företaget skapar och sparar ett kampanjutkast.
2. Plattformen validerar kampanjens innehåll, platser, period, insamlingsmål och belöningspott.
3. Företaget får se pris, vad som ingår och betalningsvillkor före köp.
4. Företaget betalar för kampanjen och får betalningsbekräftelse samt kvitto eller fakturaunderlag.
5. Backend verifierar betalningen med betalningsleverantören. Kampanjen blir publicerbar när även övriga publiceringskrav är uppfyllda. Schemalagda kampanjer startar på avsedd tid.

Betalningsstatus och kampanjstatus hanteras separat. En betald kampanj kan exempelvis vara schemalagd, pausad eller avslutad. Återgång till webbplatsen efter betalning är inte tillräckligt bevis för genomförd betalning. Upprepade betalningshändelser får inte orsaka dubbla köp eller publiceringar, och avbrutna eller misslyckade betalningar ska kunna återupptas säkert.

Exakt pris, eventuell prissättning efter omfattning, betalningsleverantör samt regler för ändringar, avbokning och återbetalning återstår att fastställa. Företagets kostnad för att tillhandahålla belöningarna ska beskrivas separat från plattformens kampanjavgift; vem som finansierar belöningarna behöver uttryckligen fastställas i erbjudandet.

Betalningsflödet ingår i den kompletta lanseringsversionen. Före skarp aktivering ska det verifieras att ett obetalt köp inte ger publiceringsrätt, att ett bekräftat köp bara registreras en gång och att betalningsavbrott hanteras utan att företagets utkast förloras.

## Möjliga senare tillägg

Integration med kassasystem, uppladdning av egna 3D-modeller, poängnivåer, topplistor, vänfunktioner, handel med objekt och avancerade spelmoment. Dessa är inte beslutade krav för lanseringen. Voucherinlösen ska fungera självständigt utan kassaintegration.

## Nästa steg

Slutför reglerna för belöningstilldelning och prissättningen per kampanj. Specificera datamodell och API samt verifiera den tekniska grunden för båda mobilplattformarna. Ta fram skärmflöden och visuell riktning med referenser innan gränssnitten implementeras. Fortsätt sedan genom samtliga leveransetapper till verifierad lanseringsberedskap.
