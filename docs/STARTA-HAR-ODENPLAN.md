# I morgon: pizza på Odenplan

**Telefon:** iPhone 16e. **App:** Vouchhunter. **Kampanj:** Brillo Pizza – Upptäck vår nya pizza.

## Innan du går hemifrån

1. Anslut din iPhone 16e till datorn med kabel. Lås upp och godkänn ”Lita på den här datorn” om frågan visas.
2. Öppna `ios/Vouchhunter.xcodeproj` i det här projektet. Välj schemat **Vouchhunter Field Test** och din **iPhone 16e** som enhet.
3. Under appens target → **Signing & Capabilities**, välj ditt Apple-utvecklarteam. Projektet har ännu inget team eller giltig signeringsidentitet konfigurerat. Aktivera Developer Mode på telefonen om Xcode ber om det; följ då telefonens instruktioner och anslut igen.
4. Tryck **Run ▶**. Kontrollera att appen öppnas och att **Brillo Pizza** syns under **Upptäck**.
5. Öppna kampanjen. Fälttestet ska säga **1 föremål**. Om det står 10 är det simulatorförhandsvisningen, inte fälttestet.

**Gå inte hemifrån förrän appen faktiskt öppnas på telefonen.** TestFlight är inte uppladdat. Att TestFlight redan finns på telefonen installerar inte den här appen. Direktinstallation via Xcode är den förberedda vägen. TestFlight kräver först Apple Developer-signering, en App Store Connect-post och uppladdning/bearbetning av bygget.

## På Odenplan

1. Öppna **Upptäck → Brillo Pizza → Öppna jakten**. Läs målet och starta jakten på plats; reservationen är 60 minuter.
2. Tillåt platsåtkomst **när appen används** och aktivera **Exakt plats**.
3. Följ pizzan på kartan till Odenplans torg, vid Gustaf Vasa kyrka. Testpunkten är **59.3428, 18.0497**. Appens karta visar den exakta punkten; gå bara på tillgängliga gångytor.
4. När du är inom **50 meter**, med tillräckligt noggrann GPS, blir insamling tillgänglig. Stanna på en öppen och trygg plats.
5. Öppna kameran och tillåt kameraåtkomst. Rikta den mot marken och rör telefonen långsamt tills pizzan visas.
6. Tryck på pizzan eller insamlingsknappen. Efter insamlingen öppnar du belöningen; den finns också under **Kuponger**.

Fälttestet använder riktig GPS och kamera men sparar fynd och kupong lokalt på telefonen. Det kräver ingen Vouchhunter-server. Kartbilder kan kräva internet. Brillo är en exempelkund och kupongen är **en testkupong utan värde**, inte ett erbjudande som restaurangen löser in.

## Om något inte fungerar

- **Kameraknappen går inte att trycka:** kontrollera att jakten startats, att du är nära kartpunkten och att Exakt plats är på. Vänta utomhus tills GPS-positionen stabiliserats; noggrannheten måste vara 35 meter eller bättre och positionen aktuell.
- **Ingen pizza i kameran:** rikta mot en tydlig, ljus markyta och rör telefonen långsamt. Testa ”Försök igen” vid spårningsfel.
- **Åtkomst nekad:** öppna telefonens Inställningar → Appar → Vouchhunter och tillåt plats/kamera.
- **Jakten har gått ut eller du vill testa igen:** Konto → Börja om jakten. Detta återställer endast den lokala testjakten.
- **Xcode kan inte signera/installera:** skicka det exakta felmeddelandet. AR kan inte bedömas i simulatorn; installationsfelet måste lösas innan promenaden.

## Vad som fortfarande behöver verifieras

Det osignerade iPhone-bygget har kompilerats. Fysisk installation, verklig AR-placering, GPS på plats och hela telefonresan är ännu inte verifierade. Ingen TestFlight-distribution har gjorts. Produktionsdrift, riktiga kampanjer och giltiga vouchers är separata återstående leveranssteg.
