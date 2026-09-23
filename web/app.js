"use strict";
const $ = (s) => document.querySelector(s),
  esc = (s) =>
    String(s ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
const paths = {
  grid: "M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z",
  pin: "M20 10c0 6-8 11-8 11S4 16 4 10a8 8 0 1 1 16 0ZM9 10a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
  scan: "M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5M3 12h18",
  arrow: "M5 12h14M13 6l6 6-6 6",
  plus: "M12 5v14M5 12h14",
  ticket:
    "M3 6h18v4a2 2 0 0 0 0 4v4H3v-4a2 2 0 0 0 0-4ZM15 6v3M15 12v1M15 16v2",
  check: "M5 12l4 4L19 6",
};
const icon = (n) =>
  `<svg class="icon" aria-hidden="true" viewBox="0 0 24 24"><path d="${paths[n] || paths.pin}"/></svg>`;
const brand = `<div class="brand"><span class="brandmark">${icon("pin")}</span>vouchhunter<span>.</span></div>`;
let me = null,
  campaigns = [],
  briefs = [],
  organizations = [],
  assetLibrary = { assets: [], models: [] },
  filter = "all",
  page = "campaigns",
  dirty = false;
const adminMode = location.pathname.startsWith("/admin");
const date = (t) => new Date(t * 1000).toLocaleDateString("sv-SE");
async function api(path, data) {
  const r = await fetch("/api" + path, {
    method: data ? "POST" : "GET",
    headers: data ? { "Content-Type": "application/json" } : {},
    body: data ? JSON.stringify(data) : undefined,
  });
  const j = await r.json();
  if (!r.ok) throw Error(j.error || "Något gick fel.");
  return j;
}
function toast(s) {
  $("#toast").textContent = s;
  setTimeout(() => ($("#toast").textContent = ""), 5000);
}
window.addEventListener("beforeunload", (e) => {
  if (dirty) {
    e.preventDefault();
    e.returnValue = "";
  }
});
function auth(register = false) {
  $("#app").innerHTML =
    `<div class="auth"><aside class="auth-story">${brand}<div><div class="eyebrow">UT I VERKLIGHETEN</div><h1>Gör din nästa kampanj till ett äventyr.</h1><p>Låt människor upptäcka dina produkter, samla föremål och hitta hela vägen till dig.</p></div><p>Företagsportalen · Vouchhunter</p></aside><main class="auth-form"><form id="authform"><div class="eyebrow">FÖR FÖRETAG</div><h1>${register ? "Din nästa kampanj börjar här." : "Välkommen tillbaka."}</h1><p>${register ? "Skapa ett konto och börja planera din första jakt." : "Logga in för att hantera dina kampanjer."}</p>${register ? '<label for="name">Ditt namn</label><input id="name" name="name" autocomplete="name" required><label for="company">Företagsnamn</label><input id="company" name="company" autocomplete="organization" required>' : ""}<label for="email">E-postadress</label><input id="email" name="email" type="email" autocomplete="email" required><label for="password">Lösenord</label><input id="password" name="password" type="password" minlength="10" autocomplete="${register ? "new-password" : "current-password"}" required>${register ? '<p class="helper">Använd minst 10 tecken.</p>' : ""}<div class="error" role="alert"></div><button class="primary" type="submit">${register ? "Skapa företagskonto" : "Logga in"} →</button><button class="ghost" id="switch" type="button">${register ? "Har du redan ett konto? Logga in" : "Ny här? Skapa företagskonto"}</button></form></main></div>`;
  $("#switch").onclick = () => auth(!register);
  $("#authform").onsubmit = async (e) => {
    e.preventDefault();
    const b = e.submitter;
    b.disabled = true;
    try {
      await api(
        register ? "/register" : "/login",
        Object.fromEntries(new FormData(e.target)),
      );
      await init();
    } catch (ex) {
      $(".error").textContent = ex.message;
    } finally {
      b.disabled = false;
    }
  };
}
function shell(content) {
  $("#app").innerHTML =
    `<div class="shell"><aside class="sidebar">${brand}<div class="workspace">${esc(adminMode ? "Vouchhunter admin" : me.organizations[0]?.name || me.name)}<small>${adminMode ? "Plattformsadministration" : "Kunddashboard"}</small></div><nav class="nav" aria-label="Huvudnavigation">${(adminMode
      ? [
          ["campaigns", "grid", "Alla kampanjer"],
          ["briefs", "pin", "Förfrågningar"],
          ["assets", "ticket", "3D-bibliotek"],
        ]
      : [
          ["campaigns", "grid", "Översikt"],
          ["payments", "ticket", "Betalningar"],
          ["redeem", "scan", "Lös in voucher"],
        ]
    )
      .map(
        ([key, symbol, label]) =>
          `<button data-page="${key}" class="${page === key ? "active" : ""}">${icon(symbol)}${label}</button>`,
      )
      .join(
        "",
      )}${me.is_admin ? `<a class="mode-link" href="${adminMode ? "/" : "/admin"}">${adminMode ? "Till kundvyn" : "Till administrationen"} ↗</a>` : ""}</nav><footer><p>Små upptäckter.<br>Stora möjligheter.</p><button class="ghost small" id="logout">Logga ut ↗</button></footer></aside><main class="main"><header class="topbar"><span>Din arbetsyta / ${{ campaigns: "Översikt", redeem: "Inlösen", payments: "Betalningar", briefs: "Förfrågningar", assets: "3D-bibliotek" }[page] || "Översikt"}</span><span class="account">${esc(me.name)}<span class="avatar">${esc(me.name.slice(0, 1).toUpperCase())}</span></span></header>${content}</main></div>`;
  document.querySelectorAll("[data-page]").forEach(
    (b) =>
      (b.onclick = () => {
        page = b.dataset.page;
        render();
      }),
  );
  $("#logout").onclick = async () => {
    await api("/logout", {});
    auth();
  };
}
function render() {
  if (page === "redeem") return redeem();
  if (page === "payments") return payments();
  if (page === "briefs") return briefPage();
  if (page === "assets") return assetsPage();
  dashboard();
}
function status(c) {
  return c.status === "active"
    ? c.starts > Date.now() / 1000
      ? "Schemalagd"
      : c.ends < Date.now() / 1000
        ? "Avslutad"
        : "Aktiv"
    : c.status === "paused"
      ? "Pausad"
      : adminMode
        ? "Utkast"
        : c.paid
          ? "Klar för start"
          : c.model_id
            ? "Redo för betalning"
            : "Förbereds";
}
function dashboard() {
  const sum = (k) => campaigns.reduce((n, c) => n + c[k], 0);
  shell(
    `<section class="pagehead"><div><div class="eyebrow">${adminMode ? "VOUCHHUNTER · KONTROLLRUM" : "DINA KAMPANJER, PÅ ETT STÄLLE"}</div><h1>${adminMode ? "Alla kampanjer" : "Din kampanjöversikt"}</h1><p>${adminMode ? "Förbered, publicera och följ varje kunds kampanj." : "Se vad som händer, följ resultaten och planera nästa lansering."}</p></div><button class="primary" id="create">+ ${adminMode ? "Konfigurera kampanj" : "Beställ kampanj"}</button></section><section class="metrics" aria-label="Resultat"><div class="metric"><span>Aktiva kampanjer</span><strong>${campaigns.filter((c) => status(c) === "Aktiv").length}</strong></div><div class="metric"><span>Startade jakter</span><strong>${sum("started")}</strong></div><div class="metric"><span>Slutförda jakter</span><strong>${sum("completed")}</strong></div><div class="metric"><span>Inlösta vouchers</span><strong>${sum("redeemed")}</strong></div></section><div class="toolbar"><div class="tabs" role="group" aria-label="Filtrera kampanjer">${[
      ["all", "Alla kampanjer"],
      ["active", "Publicerade"],
      ["draft", adminMode ? "Utkast" : "Kommande"],
      ["paused", "Pausade"],
    ]
      .map(
        ([v, t]) =>
          `<button data-filter="${v}" class="${filter === v ? "active" : ""}">${t}</button>`,
      )
      .join(
        "",
      )}</div><input class="search" id="search" type="search" aria-label="Sök kampanj" placeholder="Sök kampanj…"></div><section class="panel" id="campaign-list"></section>${
      !adminMode && briefs.some((b) => !b.campaign_id)
        ? `<section class="brief-tracker"><h2>På gång</h2>${briefs
            .filter((b) => !b.campaign_id)
            .map(
              (b) =>
                `<div class="brief-row"><span><strong>${esc(b.title)}</strong><small>${esc(b.area)} · Önskad start: ${esc(b.preferred_start)}</small></span><span class="badge">Vi förbereder upplägget</span></div>`,
            )
            .join("")}</section>`
        : ""
    }<div class="notes"><section class="note"><h3>${icon("pin")} Du har idén. Vi skapar jakten.</h3><p>Berätta om din produkt och ditt erbjudande. Vi tar hand om 3D-objekt, platser och kampanjupplägg.</p></section><section class="note"><h3>${icon("ticket")} Betala per kampanj.</h3><p>Granska det färdiga upplägget och betala när kampanjen är redo. Följ sedan resultatet hela vägen till inlösen.</p></section></div>`,
  );
  $("#create").onclick = () => (adminMode ? campaignForm() : briefForm());
  $("#search").oninput = listing;
  document.querySelectorAll("[data-filter]").forEach(
    (b) =>
      (b.onclick = () => {
        filter = b.dataset.filter;
        dashboard();
      }),
  );
  listing();
}
function listing() {
  const q = $("#search").value.toLocaleLowerCase();
  const list = campaigns.filter(
    (c) =>
      (filter === "all" || c.status === filter) &&
      c.title.toLocaleLowerCase().includes(q),
  );
  $("#campaign-list").innerHTML = list.length
    ? `<div class="table-wrap"><table><thead><tr><th>Kampanj</th><th>Status</th><th>Period</th><th>Slutförda</th><th></th></tr></thead><tbody>${list.map((c) => `<tr><td><strong>${esc(c.title)}</strong><small>${esc(c.reward)}</small></td><td><span class="badge ${c.status === "active" ? "active" : ""}">${status(c)}</span></td><td>${date(c.starts)}<small>till ${date(c.ends)}</small></td><td>${c.completed} / ${c.capacity}</td><td><button class="small" data-detail="${c.id}">Öppna →</button></td></tr>`).join("")}</tbody></table></div>`
    : `<div class="empty"><div class="empty-icon">${icon("pin")}</div><h2>${campaigns.length ? "Inga matchande kampanjer" : "Redo för din första kampanj?"}</h2><p>${campaigns.length ? "Prova ett annat sökord eller filter." : "Berätta vad du vill marknadsföra. Vi tar hand om platser, 3D-objekt och upplägget."}</p>${campaigns.length ? "" : `<button class="dark" id="empty-create">${adminMode ? "Konfigurera kampanj" : "Beställ din första kampanj"} →</button>`}</div>`;
  document
    .querySelectorAll("[data-detail]")
    .forEach((b) => (b.onclick = () => detail(b.dataset.detail)));
  if ($("#empty-create"))
    $("#empty-create").onclick = () =>
      adminMode ? campaignForm() : briefForm();
}
function openModal(html) {
  $("#modal").innerHTML = html;
  $("#modal").showModal();
  $("#modal").oncancel = (e) => {
    if (dirty && !confirm("Stäng utan att spara utkastet?")) e.preventDefault();
    else dirty = false;
  };
  const close = $("#close");
  if (close)
    close.onclick = () => {
      if (!dirty || confirm("Stäng utan att spara utkastet?")) {
        dirty = false;
        $("#modal").close();
      }
    };
}
function campaignForm(brief = null, editing = null) {
  openModal(
    `<form id="campaign-form"><div class="modalhead"><div><div class="eyebrow">NY KAMPANJ</div><h2>Skapa en upptäckt.</h2></div><button id="close" type="button" class="ghost" aria-label="Stäng">✕</button></div><p>Konfigurera kundens jakt. Kunden granskar upplägget och betalar innan du publicerar.</p><section class="form-section"><div class="section-title"><span class="step">1</span><h3>Kampanjen & belöningen</h3></div><label>Företag<select name="org_id">${organizations.map((o) => `<option value="${o.id}">${esc(o.name)}</option>`).join("")}</select></label><label>Kampanjnamn<input name="title" minlength="3" maxlength="120" placeholder="Exempel: Jakten på vår nya pizza" required></label><label>Beskrivning<textarea name="description" minlength="10" maxlength="2000" placeholder="Berätta vad deltagaren ska upptäcka…" required></textarea></label><div class="form-grid"><label>Belöning<input name="reward" minlength="3" maxlength="200" placeholder="Exempel: En valfri pizza" required></label><label>Inlösenställe<input name="venue" minlength="3" maxlength="200" placeholder="Namn och adress" required></label></div><label>Villkor för belöningen<textarea name="terms" minlength="10" maxlength="2000" placeholder="Vad ingår, när gäller erbjudandet och finns det undantag?" required></textarea></label></section><section class="form-section"><div class="section-title"><span class="step">2</span><h3>Omfattning & period</h3></div><div class="form-grid"><label>Start<input name="starts" type="datetime-local" required></label><label>Slut<input name="ends" type="datetime-local" required></label><label>Objekt att samla<input name="target" type="number" min="1" max="50" value="3" required></label><label>Antal belöningar<input name="capacity" type="number" min="1" max="100000" value="100" required></label><label>Voucherns giltighet, dagar<input name="voucher_days" type="number" min="1" max="365" value="14" required></label></div><p class="helper">En belöning reserveras i upp till 60 minuter när en deltagare startar jakten. Reservationen slutar senast vid kampanjens sluttid.</p></section><section class="form-section"><div class="section-title"><span class="step">3</span><h3>Platser att upptäcka</h3></div><p class="helper">Placera objekten på tillgängliga, säkra platser utomhus. Lägg till minst lika många platser som insamlingsmålet. Insamlingsradien är 40 meter.</p><div id="stops"></div><button id="add-stop" type="button" class="small">+ Lägg till plats</button></section><div class="error" role="alert"></div><div class="actions"><span class="helper">Sparas som utkast</span><button type="submit" class="primary">Spara kampanj →</button></div></form>`,
  );
  addStop();
  $("#add-stop").onclick = addStop;
  $("#campaign-form").oninput = () => (dirty = true);
  $("#campaign-form").onsubmit = async (e) => {
    e.preventDefault();
    e.submitter.disabled = true;
    const data = Object.fromEntries(new FormData(e.target));
    ["target", "capacity", "voucher_days"].forEach((k) => (data[k] = +data[k]));
    ["starts", "ends"].forEach(
      (k) => (data[k] = Math.floor(new Date(data[k]).getTime() / 1000)),
    );
    data.stops = [...document.querySelectorAll(".stop-row")].map((r) => ({
      name: r.querySelector("[data-name]").value,
      lat: +r.querySelector("[data-lat]").value,
      lon: +r.querySelector("[data-lon]").value,
      radius: 40,
    }));
    try {
      const created = await api(
        editing
          ? "/admin/campaigns/" + editing.id + "/edit"
          : "/admin/campaigns",
        data,
      );
      if (brief)
        await api("/admin/briefs/" + brief.id + "/link", {
          campaign_id: created.id,
        });
      dirty = false;
      $("#modal").close();
      await loadCampaigns();
      dashboard();
      toast("Kampanjen är sparad.");
    } catch (ex) {
      $("#campaign-form .error").textContent = ex.message;
    } finally {
      e.submitter.disabled = false;
    }
  };
  if (editing) {
    $("#campaign-form h2").textContent = "Redigera kampanj";
    $("#campaign-form .eyebrow").textContent = "UTKAST";
    for (const key of [
      "org_id",
      "title",
      "description",
      "reward",
      "terms",
      "venue",
      "target",
      "capacity",
      "voucher_days",
    ])
      $("#campaign-form [name=" + key + "]").value = editing[key];
    for (const key of ["starts", "ends"]) {
      const d = new Date(editing[key] * 1000);
      $("#campaign-form [name=" + key + "]").value = new Date(
        d.getTime() - d.getTimezoneOffset() * 60000,
      )
        .toISOString()
        .slice(0, 16);
    }
    $("#campaign-form [name=org_id]").disabled = true;
    $("#campaign-form [name=target]").max = editing.stops.length;
    // Locations retain their identity; this form edits the offer and its period.
    $("#stops").closest("section").hidden = true;
    $("#stops")
      .querySelectorAll("input")
      .forEach((input) => (input.disabled = true));
  }
  if (brief) {
    for (const key of ["org_id", "title", "description", "reward"])
      $("#campaign-form [name=" + key + "]").value = brief[key];
  }
}
function addStop() {
  const n = $("#stops").children.length + 1;
  $("#stops").insertAdjacentHTML(
    "beforeend",
    `<div class="stop-row"><div><label for="stop-${n}">Plats ${n}</label><input id="stop-${n}" data-name minlength="2" maxlength="100" placeholder="Namn på platsen" required></div><div><label for="lat-${n}">Latitud</label><input id="lat-${n}" data-lat type="number" step="any" min="-90" max="90" placeholder="59.3326" required></div><div><label for="lon-${n}">Longitud</label><input id="lon-${n}" data-lon type="number" step="any" min="-180" max="180" placeholder="18.0649" required></div></div>`,
  );
}
function detail(id) {
  const c = campaigns.find((c) => c.id === id);
  openModal(
    `<div class="modalhead"><span class="badge ${c.status === "active" ? "active" : ""}">${status(c)}</span><button class="ghost" id="close" aria-label="Stäng">✕</button></div><div class="eyebrow">${esc(c.brand)}</div><h1>${esc(c.title)}</h1><p>${esc(c.description)}</p><div class="detail-grid"><div><small>Belöning</small><strong>${esc(c.reward)}</strong></div><div><small>Inlösen</small><strong>${esc(c.venue)}</strong></div><div><small>Upplägg</small>${c.target} objekt · ${c.capacity} belöningar</div><div><small>Period</small>${date(c.starts)} – ${date(c.ends)}</div><div><small>Betalning</small>${c.paid ? "Betald" : c.model_id ? "Redo för betalning" : "Upplägget förbereds"}</div><div><small>Resultat</small>${c.started} startade · ${c.completed} slutförda · ${c.redeemed} inlösta</div></div><h3>Platser i kampanjen</h3><ul class="stop-list">${c.stops.map((s) => `<li>${esc(s.name)}${adminMode ? `<small>${s.lat.toFixed(4)}, ${s.lon.toFixed(4)}</small>` : ""}</li>`).join("")}</ul><h3>Villkor</h3><p>${esc(c.terms)}</p><p class="helper">Vouchern gäller i ${c.voucher_days} dagar efter slutförd jakt.</p>${adminMode ? `<section class="admin-config"><h3>3D-objekt</h3><p class="helper">Både iPhone- och Android-format måste vara kopplade innan kampanjen kan betalas.</p><form id="model-form"><label for="model-id">Objekt i biblioteket</label><select id="model-id" required ${c.editing_locked ? "disabled" : ""}><option value="">Välj 3D-objekt</option>${assetLibrary.models.map((m) => `<option value="${m.id}" ${m.id === c.model_id ? "selected" : ""}>${esc(m.name)}</option>`).join("")}</select>${!c.editing_locked ? '<button class="small" type="submit">Koppla objekt</button>' : ""}</form></section>` : ""}<div class="error" role="alert"></div><div class="actions">${c.status === "active" ? '<button id="share">Kopiera kampanjlänk</button>' : ""}${adminMode && !c.editing_locked ? '<button id="edit-campaign">Redigera upplägg</button>' : ""}${adminMode ? `<button id="admin-change" class="${c.status === "active" ? "" : "primary"}" ${!c.paid || !c.model_id ? "disabled" : ""}>${c.status === "active" ? "Pausa kampanj" : "Publicera kampanj"}</button>` : !c.paid ? `<button id="pay" class="primary" ${!c.model_id ? "disabled" : ""}>${c.model_id ? "Granska pris & betala →" : "Vi förbereder din kampanj"}</button>` : '<span class="badge active">Betald · vi sköter publiceringen</span>'}</div>`,
  );
  if ($("#share"))
    $("#share").onclick = async () => {
      try {
        await navigator.clipboard.writeText(
          location.origin + "/campaign/" + c.id,
        );
        toast("Kampanjlänken är kopierad.");
      } catch {
        toast("Länk: " + location.origin + "/campaign/" + c.id);
      }
    };
  if ($("#pay"))
    $("#pay").onclick = async (e) => {
      e.target.disabled = true;
      try {
        const r = await api("/manage/campaigns/" + id + "/checkout", {});
        location.assign(r.url);
      } catch (ex) {
        $("#modal .error").textContent = ex.message;
      } finally {
        e.target.disabled = false;
      }
    };
  if ($("#edit-campaign"))
    $("#edit-campaign").onclick = () => campaignForm(null, c);
  if ($("#admin-change"))
    $("#admin-change").onclick = async (e) => {
      e.target.disabled = true;
      try {
        const action = c.status === "active" ? "pause" : "publish";
        if (
          action === "pause" &&
          !confirm(
            "Pausa insamlingen? Befintliga reservationer fortsätter att löpa ut och utfärdade vouchers gäller fortfarande.",
          )
        )
          return;
        await api("/admin/campaigns/" + id + "/" + action, {});
        await loadCampaigns();
        dashboard();
        detail(id);
      } catch (ex) {
        $("#modal .error").textContent = ex.message;
      } finally {
        e.target.disabled = false;
      }
    };
  if ($("#model-form"))
    $("#model-form").onsubmit = async (e) => {
      e.preventDefault();
      try {
        await api("/admin/campaigns/" + id + "/model", {
          model_id: $("#model-id").value,
        });
        await loadCampaigns();
        detail(id);
      } catch (ex) {
        $("#modal .error").textContent = ex.message;
      }
    };
}
function briefForm() {
  openModal(
    `<form id="brief-form"><div class="modalhead"><div><div class="eyebrow">DIN NÄSTA KAMPANJ</div><h2>Vad vill du att fler upptäcker?</h2></div><button type="button" id="close" class="ghost" aria-label="Stäng">✕</button></div><p>Berätta om idén. Vi återkommer med ett färdigt upplägg som du kan granska och betala här.</p><label>Företag<select name="org_id">${me.organizations
      .filter((o) => o.role === "owner")
      .map((o) => `<option value="${o.id}">${esc(o.name)}</option>`)
      .join(
        "",
      )}</select></label><label>Vad ska kampanjen heta?<input name="title" minlength="3" maxlength="120" placeholder="Exempel: Upptäck vår nya pizza" required></label><label>Vad vill ni marknadsföra?<textarea name="description" minlength="10" maxlength="2000" placeholder="Berätta om produkten, lanseringen och vad ni vill uppnå…" required></textarea></label><label>Vad får deltagaren?<input name="reward" minlength="3" maxlength="200" placeholder="Exempel: En gratis pizza" required></label><div class="form-grid"><label>Var ska kampanjen synas?<input name="area" minlength="2" maxlength="200" placeholder="Exempel: Centrala Stockholm" required></label><label>När vill ni starta?<input name="preferred_start" minlength="4" maxlength="100" placeholder="Exempel: Första helgen i oktober" required></label></div><p class="helper">Ingen betalning görs nu. Vi tar hand om platserna, 3D-objektet och det tekniska upplägget.</p><div class="error" role="alert"></div><div class="actions"><button class="primary" type="submit">Skicka kampanjförfrågan →</button></div></form>`,
  );
  $("#brief-form").oninput = () => (dirty = true);
  $("#brief-form").onsubmit = async (e) => {
    e.preventDefault();
    e.submitter.disabled = true;
    try {
      await api("/manage/briefs", Object.fromEntries(new FormData(e.target)));
      dirty = false;
      $("#modal").close();
      await loadCampaigns();
      dashboard();
      toast("Din förfrågan är skickad. Du följer den i översikten.");
    } catch (ex) {
      $("#brief-form .error").textContent = ex.message;
    } finally {
      e.submitter.disabled = false;
    }
  };
}
function paymentLabel(c) {
  return (
    {
      paid: "Betald",
      pending: "Inväntar betalning",
      expired: "Betalningslänken har löpt ut",
      ready: "Redo för betalning",
      preparing: "Upplägget förbereds",
    }[c.payment_state] || (c.paid ? "Betald" : "Upplägget förbereds")
  );
}
function paymentReturnNotice() {
  const query = new URLSearchParams(location.search);
  const outcome = query.get("payment");
  if (!["received", "cancelled"].includes(outcome)) return "";
  const c = campaigns.find((item) => item.id === query.get("campaign"));
  const message = !c
    ? "Kontrollera statusen för din kampanj i listan nedan. En återkomst från betaltjänsten är inte en betalningsbekräftelse."
    : c.paid
      ? "Betalningen är bekräftad. Vi tar hand om publiceringen av din kampanj."
      : outcome === "cancelled"
        ? "Du har lämnat betalningen. Kampanjen är sparad. Här ser du den senast bekräftade betalningsstatusen."
        : "Vi inväntar bekräftelse från betaltjänsten. Det kan ta en stund. Uppdatera status innan du försöker betala igen.";
  return `<section class="panel payment-notice" role="status" aria-live="polite"><div><h2>${c?.paid ? "Tack för din betalning" : "Din betalningsstatus"}</h2>${c ? `<p>${esc(c.title)}</p>` : ""}<p>${message}</p></div></section>`;
}
function payments() {
  shell(
    `<section class="pagehead"><div><div class="eyebrow">BETALNING PER KAMPANJ</div><h1>Betalningar</h1><p>Se vilka kampanjer som är betalda och vilka som väntar på dig.</p></div><button id="refresh-payments" class="small">Uppdatera status</button></section>${paymentReturnNotice()}<p id="payment-error" class="error" role="alert"></p><section class="panel"><div class="table-wrap"><table><thead><tr><th>Kampanj</th><th>Betalningsstatus</th><th>Nästa steg</th></tr></thead><tbody>${campaigns.map((c) => `<tr><td><strong>${esc(c.title)}</strong><small>${date(c.starts)} – ${date(c.ends)}</small></td><td><span class="badge ${c.paid ? "active" : ""}">${esc(paymentLabel(c))}</span></td><td><button data-detail="${c.id}" class="small">${c.paid ? "Visa kampanj" : "Granska upplägg"} →</button></td></tr>`).join("")}</tbody></table></div>${campaigns.length ? "" : '<div class="empty"><h2>Inga betalningar ännu.</h2><p>När ditt kampanjupplägg är klart hittar du betalningen här.</p></div>'}</section>`,
  );
  $("#refresh-payments").onclick = async (e) => {
    const button = e.currentTarget;
    button.disabled = true;
    button.textContent = "Uppdaterar…";
    try {
      await loadCampaigns();
      if (page === "payments") payments();
    } catch (error) {
      if ($("#payment-error")) $("#payment-error").textContent = error.message;
    } finally {
      button.disabled = false;
      button.textContent = "Uppdatera status";
    }
  };
  document
    .querySelectorAll("[data-detail]")
    .forEach((b) => (b.onclick = () => detail(b.dataset.detail)));
}
function briefPage() {
  shell(
    `<section class="pagehead"><div><div class="eyebrow">FRÅN IDÉ TILL KAMPANJ</div><h1>Kampanjförfrågningar</h1><p>Förbered kundernas upplägg bakom kulisserna.</p></div></section><section class="panel"><div class="table-wrap"><table><thead><tr><th>Företag / kampanj</th><th>Område</th><th>Önskad start</th><th></th></tr></thead><tbody>${briefs.map((b) => `<tr><td><strong>${esc(b.title)}</strong><small>${esc(b.brand)}</small></td><td>${esc(b.area)}</td><td>${esc(b.preferred_start)}</td><td><button data-brief="${b.id}" class="small">${b.campaign_id ? "Visa kampanj" : "Förbered upplägg"} →</button></td></tr>`).join("")}</tbody></table></div>${briefs.length ? "" : '<div class="empty"><h2>Inga nya förfrågningar.</h2><p>Kundernas önskemål samlas här.</p></div>'}</section>`,
  );
  document.querySelectorAll("[data-brief]").forEach(
    (button) =>
      (button.onclick = () => {
        const b = briefs.find((b) => b.id === button.dataset.brief);
        if (b.campaign_id) detail(b.campaign_id);
        else campaignForm(b);
      }),
  );
}
function assetsPage() {
  shell(
    `<section class="pagehead"><div><div class="eyebrow">EN MODELL, TVÅ MOBILPLATTFORMAR</div><h1>3D-bibliotek</h1><p>Ladda upp objekt och koppla dem till kampanjerna du förbereder.</p></div></section><div class="asset-layout"><section class="panel padded"><h2>Ladda upp modellfil</h2><p class="helper">GLB för Android eller USDZ för iPhone. Självständig fil med inbäddade resurser, högst 12 MB.</p><form id="upload-form"><label>Filnamn i biblioteket<input name="name" minlength="2" maxlength="120" required></label><label>Modellfil<input id="asset-file" type="file" accept=".glb,.usdz" required></label><div class="error" role="alert"></div><button class="primary" type="submit">Ladda upp fil</button></form></section><section class="panel padded"><h2>Skapa ett samlingsobjekt</h2><p class="helper">Para ihop samma objekt i båda formaten. Kontrollera skala, utseende och placering på riktiga telefoner innan publicering.</p><form id="pair-form"><label>Objektets namn<input name="name" minlength="2" maxlength="120" placeholder="Exempel: Lanseringspizza" required></label>${[
      ["glb", "Android · GLB"],
      ["usdz", "iPhone · USDZ"],
    ]
      .map(
        ([format, label]) =>
          `<label>${label}<select name="${format}_asset_id" required><option value="">Välj uppladdad fil</option>${assetLibrary.assets
            .filter((a) => a.format === format)
            .map((a) => `<option value="${a.id}">${esc(a.name)}</option>`)
            .join("")}</select></label>`,
      )
      .join(
        "",
      )}<div class="error" role="alert"></div><button class="dark" type="submit">Spara 3D-objekt</button></form></section></div><h2>Färdiga samlingsobjekt</h2><section class="panel"><div class="table-wrap"><table><thead><tr><th>Objekt</th><th>Format</th><th>Tillagt</th></tr></thead><tbody>${assetLibrary.models.map((m) => `<tr><td><strong>${esc(m.name)}</strong></td><td>GLB + USDZ</td><td>${date(m.created)}</td></tr>`).join("")}</tbody></table></div>${assetLibrary.models.length ? "" : '<div class="empty"><p>Para ihop två modellfiler för att skapa ditt första objekt.</p></div>'}</section><h2>Uppladdade filer</h2><ul class="stop-list">${assetLibrary.assets.map((a) => `<li><span>${esc(a.name)} <span class="badge">${esc(a.format.toUpperCase())}</span></span><small>${(a.size / 1024 / 1024).toFixed(2)} MB</small></li>`).join("")}</ul>`,
  );
  $("#upload-form").onsubmit = async (e) => {
    e.preventDefault();
    const file = $("#asset-file").files[0];
    if (!file) return;
    if (file.size > 12 * 1024 * 1024) {
      $("#upload-form .error").textContent = "Filen får vara högst 12 MB.";
      return;
    }
    e.submitter.disabled = true;
    try {
      const content = await new Promise((resolve, reject) => {
        const r = new FileReader();
        r.onload = () => resolve(r.result.split(",")[1]);
        r.onerror = reject;
        r.readAsDataURL(file);
      });
      await api("/admin/assets", {
        name: new FormData(e.target).get("name"),
        format: file.name.split(".").pop().toLowerCase(),
        content,
      });
      await loadCampaigns();
      assetsPage();
      toast("Modellfilen är uppladdad.");
    } catch (ex) {
      $("#upload-form .error").textContent = ex.message;
    } finally {
      e.submitter.disabled = false;
    }
  };
  $("#pair-form").onsubmit = async (e) => {
    e.preventDefault();
    e.submitter.disabled = true;
    try {
      await api("/admin/models", Object.fromEntries(new FormData(e.target)));
      await loadCampaigns();
      assetsPage();
      toast("3D-objektet är sparat.");
    } catch (ex) {
      $("#pair-form .error").textContent = ex.message;
    } finally {
      e.submitter.disabled = false;
    }
  };
}
function redeem() {
  shell(
    `<section class="pagehead"><div><div class="eyebrow">FRÅN UPPTÄCKT TILL BESÖK</div><h1>Lös in voucher</h1><p>Kontrollera erbjudandet innan du bekräftar inlösen.</p></div></section><section class="panel redeem"><form id="redeem-form" class="empty"><div class="empty-icon">${icon("scan")}</div><h2>Redo för en belöning?</h2><p>Skanna med din QR-läsare eller klistra in kundens voucherkod.</p><label for="code">Voucherkod</label><input id="code" name="code" autocomplete="off" required><div class="error" role="alert"></div><button class="primary" type="submit">Kontrollera voucher</button></form></section>`,
  );
  $("#redeem-form").onsubmit = async (e) => {
    e.preventDefault();
    const code = $("#code").value.trim();
    e.submitter.disabled = true;
    try {
      const v = await api("/vouchers/check", { code });
      openModal(
        `<div class="modalhead"><h2>Bekräfta inlösen</h2><button id="close" class="ghost" aria-label="Stäng">✕</button></div><p>${esc(v.title)}</p><div class="reward"><h2>${esc(v.reward)}</h2><p>${esc(v.venue)}</p></div><p>Bekräfta när kunden får sin belöning. Vouchern kan användas en gång.</p><div class="error" role="alert"></div><button class="primary" id="confirm-redeem">Lös in voucher</button>`,
      );
      $("#confirm-redeem").onclick = async (e) => {
        e.target.disabled = true;
        try {
          await api("/vouchers/redeem", { code });
          $("#modal").close();
          $("#code").value = "";
          toast("Vouchern är inlöst.");
        } catch (ex) {
          $("#modal .error").textContent = ex.message;
        } finally {
          e.target.disabled = false;
        }
      };
    } catch (ex) {
      $("#redeem-form .error").textContent = ex.message;
    } finally {
      e.submitter.disabled = false;
    }
  };
}
function guide() {
  shell(
    `<section class="pagehead"><div><div class="eyebrow">SÅ FUNGERAR VOUCHHUNTER</div><h1>En promenad. En upptäckt. Ett besök.</h1></div></section><section class="panel empty"><div class="notes"><article><h2>01 · Skapa jakten</h2><p>Välj erbjudande, datum och platser. Bestäm hur många objekt deltagaren ska samla och hur många belöningar som finns.</p><h2>02 · Publicera & dela</h2><p>Betala per kampanj och publicera när allt är klart. Dela kampanjlänken i dina egna kanaler.</p></article><article><h2>03 · Låt staden upptäcka</h2><p>Deltagaren går mellan platserna, samlar 3D-objekt i appen och får sin voucher när målet är uppfyllt.</p><h2>04 · Välkomna kunden</h2><p>Kontrollera och lös in vouchern. Följ hela vägen från startad jakt till faktiskt besök.</p></article></div></section>`,
  );
}
async function publicCampaign(id) {
  try {
    const c = await api("/campaigns/" + id);
    $("#app").innerHTML =
      `<main class="public"><header>${brand}</header><div class="eyebrow">${esc(c.brand)} · UTOMHUS</div><h1>${esc(c.title)}</h1><p>${esc(c.description)}</p><section class="reward"><div class="eyebrow">DIN BELÖNING</div><h2>${esc(c.reward)}</h2><p>Samla ${c.target} objekt · ${c.stops.length} platser att upptäcka</p></section><h2>Här börjar äventyret</h2><ul class="stop-list">${c.stops.map((s) => `<li>${esc(s.name)}<span>${icon("pin")}</span></li>`).join("")}</ul><h3>Gäller ${date(c.starts)} – ${date(c.ends)}</h3><p>${esc(c.terms)}</p><p>Inlösen: ${esc(c.venue)}. Din voucher gäller i ${c.voucher_days} dagar.</p><p class="helper">Jakten genomförs i Vouchhunter-appen. Appbutikslänkar visas när apparna är publicerade.</p></main>`;
  } catch (ex) {
    $("#app").innerHTML =
      `<main class="public">${brand}<h1>Kampanjen är inte tillgänglig.</h1><p>${esc(ex.message)}</p></main>`;
  }
}
async function loadCampaigns() {
  const prefix = adminMode ? "/admin" : "/manage";
  const values = await Promise.all([
    api(prefix + "/campaigns"),
    api(prefix + "/briefs"),
  ]);
  campaigns = values[0].campaigns;
  briefs = values[1].briefs;
  if (adminMode) {
    const extra = await Promise.all([
      api("/admin/assets"),
      api("/admin/organizations"),
    ]);
    assetLibrary = extra[0];
    organizations = extra[1].organizations;
  }
}
async function init() {
  const m = location.pathname.match(/^\/campaign\/([a-f0-9]+)$/);
  if (m) return publicCampaign(m[1]);
  try {
    me = await api("/me");
  } catch {
    return auth();
  }
  try {
    if (adminMode && !me.is_admin)
      throw Error("Den här vyn är endast för Vouchhunters administratör.");
    await loadCampaigns();
    if (
      !adminMode &&
      ["received", "cancelled"].includes(
        new URLSearchParams(location.search).get("payment"),
      )
    )
      page = "payments";
    render();
  } catch (ex) {
    $("#app").innerHTML =
      `<main class="public"><h1>Kunde inte öppna arbetsytan.</h1><p>${esc(ex.message)}</p><button id="retry">Försök igen</button></main>`;
    $("#retry").onclick = init;
  }
}
init();
