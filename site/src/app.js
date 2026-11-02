/* matOS — améliorations facultatives : thème, boutons « Copier », liste des fichiers de la dernière version.
   Le site reste entièrement lisible sans JavaScript. Aucune donnée n'est envoyée nulle part, sauf la
   requête publique à l'API GitHub sur la page « Télécharger ». */
(function () {
  "use strict";
  var racine = document.documentElement;

  /* Thème : suit le système, sauf choix explicite mémorisé localement (sans cookie) */
  var bouton = document.getElementById("theme");
  function themeActuel() {
    if (racine.dataset.theme) return racine.dataset.theme;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches ? "clair" : "sombre";
  }
  function libelle() { if (bouton) bouton.textContent = themeActuel() === "clair" ? "Thème sombre" : "Thème clair"; }
  if (bouton) {
    bouton.hidden = false; libelle();
    bouton.addEventListener("click", function () {
      var suivant = themeActuel() === "clair" ? "sombre" : "clair";
      racine.dataset.theme = suivant; libelle();
      try { localStorage.setItem("matos-theme", suivant); } catch (e) {}
    });
  }

  /* Boutons « Copier » sur les blocs de commande */
  document.querySelectorAll("pre.code").forEach(function (pre) {
    var b = document.createElement("button");
    b.type = "button"; b.className = "copier"; b.textContent = "Copier";
    b.setAttribute("aria-label", "Copier la commande");
    b.addEventListener("click", function () {
      var texte = pre.innerText.replace(/^\$ /gm, "").trim();
      var fini = function () { b.textContent = "Copié"; setTimeout(function () { b.textContent = "Copier"; }, 2000); };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(texte).then(fini, function () {});
      else { var r = document.createRange(); r.selectNodeContents(pre); var s = getSelection(); s.removeAllRanges(); s.addRange(r); }
    });
    pre.appendChild(b);
  });

  /* Page « Télécharger » : informations de la dernière version publiée */
  var cible = document.getElementById("release");
  if (!cible) return;
  var etat = document.getElementById("release-etat");
  /* Go et Mo décimaux (1 Go = 10^9 octets), comme sur le reste du site */
  function mo(o) { return o >= 1e9 ? (o / 1e9).toFixed(1).replace(".", ",") + " Go" : Math.round(o / 1e6) + " Mo"; }
  fetch("https://api.github.com/repos/raantss18/MatOS/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
    .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(function (rel) {
      var parts = rel.assets.filter(function (a) { return /\.part-\d+$/.test(a.name); })
        .sort(function (a, b) { return a.name < b.name ? -1 : 1; });
      var total = parts.reduce(function (s, a) { return s + a.size; }, 0);
      var m = /SHA256 de l'ISO\s*:\s*`([0-9a-f]{64})`/.exec(rel.body || "");
      var date = new Date(rel.published_at).toLocaleDateString("fr-FR", { year: "numeric", month: "long", day: "numeric" });
      document.getElementById("rel-version").textContent = rel.name || rel.tag_name;
      document.getElementById("rel-tag").textContent = rel.tag_name;
      document.getElementById("rel-date").textContent = date;
      document.getElementById("rel-taille").textContent = mo(total);
      document.getElementById("rel-sha").textContent = m ? m[1] : "voir la page de la version";
      var corps = document.getElementById("rel-parts");
      corps.textContent = "";
      parts.forEach(function (a) {
        var tr = document.createElement("tr"), c1 = document.createElement("td"), c2 = document.createElement("td"), c3 = document.createElement("td");
        var lien = document.createElement("a"); lien.href = a.browser_download_url; lien.textContent = a.name; c1.appendChild(lien);
        c2.textContent = mo(a.size);
        var cs = document.createElement("code"); cs.textContent = (a.digest || "").replace("sha256:", "") || "—"; c3.appendChild(cs);
        tr.appendChild(c1); tr.appendChild(c2); tr.appendChild(c3); corps.appendChild(tr);
      });
      var cmd = document.getElementById("rel-cmd-version");
      if (cmd) cmd.textContent = "bash telecharger-matos.sh " + rel.tag_name;
      cible.hidden = false; if (etat) etat.hidden = true;
    })
    .catch(function () {
      if (etat) etat.textContent = "Impossible de joindre GitHub pour afficher les détails. Les liens ci-dessous restent valables.";
    });
})();
