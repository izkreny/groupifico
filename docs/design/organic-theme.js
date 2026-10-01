const SOURCES = {
  organic: {
    "base-100": ["bg #f5ead8", "base-content"], "base-200": ["surface #ebddc5", "base-content"], "base-300": ["neutral-300", "base-content"], "base-content": ["text #201e1d", "base-100"],
    "primary": ["accent-700, same as the accent role, as in daisyUI black, wireframe and silk", "primary-content"], "primary-content": ["neutral-100 #f9f4ed, same as neutral-content", "primary"],
    "secondary": ["accent-2 #7a8a5e darkened to oklch 48%, in step with primary", "secondary-content"], "secondary-content": ["neutral-100 #f9f4ed, same as neutral-content", "secondary"],
    "accent": ["accent-700", "accent-content"], "accent-content": ["neutral-100 #f9f4ed, same as neutral-content", "accent"],
    "neutral": ["neutral-800", "neutral-content"], "neutral-content": ["neutral-100", "neutral"],
    "info": ["oklch 49% 0.10 245", "info-content"], "info-content": ["proposed tint", "info"],
    "success": ["oklch 48% 0.12 145", "success-content"], "success-content": ["proposed tint", "success"],
    "warning": ["proposed, oklch 80% 0.18 95, fill only", "warning-content"], "warning-content": ["text #201e1d", "warning"],
    "error": ["proposed, oklch 51% 0.17 27", "error-content"], "error-content": ["proposed tint", "error"],
  },
  "organic-dark": {
    "base-100": ["neutral-900", "base-content"], "base-200": ["neutral-800", "base-content"], "base-300": ["neutral-700", "base-content"], "base-content": ["neutral-100", "base-100"],
    "primary": ["accent-400 muted, oklch 74% 0.10 45", "primary-content"], "primary-content": ["accent-900", "primary"],
    "secondary": ["accent-2-400", "secondary-content"], "secondary-content": ["accent-2-900", "secondary"],
    "accent": ["same as primary, as in light", "accent-content"], "accent-content": ["accent-900", "accent"],
    "neutral": ["neutral-700", "neutral-content"], "neutral-content": ["neutral-100", "neutral"],
    "info": ["oklch 74% 0.09 245", "info-content"], "info-content": ["text #201e1d", "info"],
    "success": ["oklch 74% 0.11 145", "success-content"], "success-content": ["text #201e1d", "success"],
    "warning": ["oklch 80% 0.18 95, fill only, same as light", "warning-content"], "warning-content": ["text #201e1d", "warning"],
    "error": ["oklch 72% 0.18 25", "error-content"], "error-content": ["text #201e1d", "error"],
  }
};

const lum = hex => {
  const c = [1,3,5].map(i => parseInt(hex.slice(i,i+2),16)/255).map(v => v <= 0.04045 ? v/12.92 : ((v+0.055)/1.055)**2.4);
  return 0.2126*c[0] + 0.7152*c[1] + 0.0722*c[2];
};
const ratio = (a,b) => { let x = lum(a), y = lum(b); if (x < y) [x,y] = [y,x]; return ((x+0.05)/(y+0.05)).toFixed(2); };
const canvas = document.createElement("canvas"); canvas.width = canvas.height = 1;
const ctx = canvas.getContext("2d", { willReadFrequently: true });
const paint = color => {
  const el = document.createElement("span"); el.style.backgroundColor = color; document.body.appendChild(el);
  const computed = getComputedStyle(el).backgroundColor; el.remove();
  ctx.fillStyle = "#ffffff"; ctx.fillRect(0, 0, 1, 1); ctx.fillStyle = computed; ctx.fillRect(0, 0, 1, 1);
  return "#" + [...ctx.getImageData(0, 0, 1, 1).data].slice(0, 3).map(n => n.toString(16).padStart(2, "0")).join("");
};
const activeTheme = () => document.documentElement.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "organic-dark" : "organic");

function renderTokens() {
  const theme = activeTheme();
  const tbody = document.querySelector("#tokens tbody");
  tbody.innerHTML = "";
  const hex = {};
  for (const name of Object.keys(SOURCES[theme])) hex[name] = paint(`var(--color-${name})`);
  for (const [name, [source, pair]] of Object.entries(SOURCES[theme])) {
    const r = ratio(hex[name], hex[pair]);
    const onBase = (name.endsWith("content") || name === "base-100") ? "" : ratio(hex[name], hex["base-100"]);
    const flag = v => (v === "" || name.startsWith("base-")) ? "" : (+v >= 4.5 ? "" : +v >= 3 ? " badge badge-xs badge-warning" : " badge badge-xs badge-error");
    tbody.insertAdjacentHTML("beforeend", `<tr>
      <td><code>${name}</code></td>
      <td><span class="inline-block size-8 rounded-full border border-base-300" style="background:var(--color-${name})"></span></td>
      <td><code>${hex[name]}</code></td>
      <td class="text-[12px]">${source}</td>
      <td><span class="${flag(r)}">${r}:1</span> <span class="text-[11px] opacity-70">vs ${pair}</span></td>
      <td>${onBase === "" ? "" : `<span class="${flag(onBase)}">${onBase}:1</span>`}</td>
    </tr>`);
  }
}

document.getElementById("theme-switch").addEventListener("change", e => {
  if (e.target.value) document.documentElement.dataset.theme = e.target.value; else delete document.documentElement.dataset.theme;
  renderTokens();
});
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", renderTokens);
renderTokens();
