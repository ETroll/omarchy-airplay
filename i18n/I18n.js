.pragma library

var messages = {
  en: {
    airplayMirror: "AirPlay Mirror",
    mirroringTo: "Mirroring to {name}",
    readyFor: "Ready for {name}",
    chooseReceiver: "Choose a receiver",
    discoverReceivers: "Discover receivers",
    receivers: "RECEIVERS",
    mirror: "Mirror",
    stop: "Stop",
    forget: "Forget",
    mirrorTooltip: "Start mirroring to this receiver",
    stopTooltip: "Stop mirroring",
    forgetTooltip: "Forget saved pairing; the next connection requires a PIN",
    pairNewReceiver: "PAIR A NEW RECEIVER",
    pinHelp: "Select the receiver and start once to make its PIN appear. Enter that four-digit PIN here.",
    pin: "PIN",
    pairAndConnect: "Pair & connect",
    openReceiverList: "Click the AirPlay icon in the bar to open this receiver list.",
    noReceivers: "No AirPlay receivers found",
    discoveryFailed: "AirPlay discovery failed",
    pairingCannotForget: "This receiver did not advertise a device ID, so its saved pairing cannot be removed safely.",
    connecting: "Connecting to {name}",
    stopped: "Stopped mirroring to {name}",
    mirroringTitle: "AirPlay mirroring",
    pairingForgottenTitle: "AirPlay pairing forgotten",
    pairingForgotten: "The next connection to this receiver will require its PIN.",
    pairingForgetFailed: "Could not forget receiver pairing",
    capturePreparationFailed: "Could not prepare capture source selection",
    connectionFailedTitle: "AirPlay connection failed",
    connectionFailed: "DoubleTake exited with code {code}. If the TV shows a PIN, enter it below and choose Pair & connect.",
    networkAndFirewall: "NETWORK & FIREWALL",
    activeNetwork: "Active network: {network}",
    firewallHelp: "If UFW blocks incoming media traffic, allow UDP ports for {address}. You will be asked for your administrator password.",
    firewallManaged: "UDP firewall access is managed for {address}; Forget removes this plugin-created rule.",
    allowFirewall: "Allow selected receiver",
    firewallAllowedTitle: "AirPlay firewall access allowed",
    firewallAllowed: "Allowed UDP media traffic from {address}.",
    firewallAllowFailed: "Could not add the UFW rule. Check that UFW and Polkit are available, then try again.",
    firewallRemoveFailed: "The UFW rule was not removed, so the receiver pairing was kept.",
    tooltipMirroring: "AirPlay mirroring to {name}",
    tooltipChoose: "Choose an AirPlay receiver"
  },
  nb: {
    airplayMirror: "AirPlay-speiling",
    mirroringTo: "Speiler til {name}",
    readyFor: "Klar for {name}",
    chooseReceiver: "Velg en mottaker",
    discoverReceivers: "Finn mottakere",
    receivers: "MOTTAKERE",
    mirror: "Speil",
    stop: "Stopp",
    forget: "Glem",
    mirrorTooltip: "Start speiling til denne mottakeren",
    stopTooltip: "Stopp speiling",
    forgetTooltip: "Glem lagret paring; neste tilkobling krever PIN-kode",
    pairNewReceiver: "PAR EN NY MOTTAKER",
    pinHelp: "Velg mottakeren og start én gang for å vise PIN-koden. Skriv inn den firesifrede PIN-koden her.",
    pin: "PIN",
    pairAndConnect: "Par og koble til",
    openReceiverList: "Klikk AirPlay-ikonet i topplinjen for å åpne mottakerlisten.",
    noReceivers: "Fant ingen AirPlay-mottakere",
    discoveryFailed: "AirPlay-oppdagelse feilet",
    pairingCannotForget: "Mottakeren annonserte ingen enhets-ID, så lagret paring kan ikke fjernes trygt.",
    connecting: "Kobler til {name}",
    stopped: "Stoppet speiling til {name}",
    mirroringTitle: "AirPlay-speiling",
    pairingForgottenTitle: "AirPlay-paring glemt",
    pairingForgotten: "Neste tilkobling til mottakeren krever PIN-koden.",
    pairingForgetFailed: "Kunne ikke glemme mottakerparingen",
    capturePreparationFailed: "Kunne ikke klargjøre valg av opptakskilde",
    connectionFailedTitle: "AirPlay-tilkobling feilet",
    connectionFailed: "DoubleTake avsluttet med kode {code}. Hvis TV-en viser en PIN, skriv den inn under og velg Par og koble til.",
    networkAndFirewall: "NETTVERK OG BRANNMUR",
    activeNetwork: "Aktivt nettverk: {network}",
    firewallHelp: "Hvis UFW blokkerer innkommende medietrafikk, tillat UDP-porter for {address}. Du blir bedt om administratorpassordet.",
    firewallManaged: "UDP-tilgang i brannmuren administreres for {address}; Glem fjerner regelen pluginen opprettet.",
    allowFirewall: "Tillat valgt mottaker",
    firewallAllowedTitle: "AirPlay-tilgang i brannmuren tillatt",
    firewallAllowed: "Tillot UDP-medietrafikk fra {address}.",
    firewallAllowFailed: "Kunne ikke legge til UFW-regelen. Sjekk at UFW og Polkit er tilgjengelige, og prøv igjen.",
    firewallRemoveFailed: "UFW-regelen ble ikke fjernet, så mottakerparingen ble beholdt.",
    tooltipMirroring: "AirPlay-speiling til {name}",
    tooltipChoose: "Velg en AirPlay-mottaker"
  }
}

function language(localeName) {
  var languageCode = String(localeName || "en").toLowerCase().split(/[_-]/)[0]
  return languageCode === "no" || languageCode === "nb" || languageCode === "nn" ? "nb" : "en"
}

function t(localeName, key, values) {
  var text = (messages[language(localeName)][key] || messages.en[key] || key)
  if (!values) return text
  for (var name in values) text = text.replace(new RegExp("\\{" + name + "\\}", "g"), String(values[name]))
  return text
}
