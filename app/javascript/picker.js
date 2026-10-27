// The element picker `layouts/_head` loads wherever `config.x.picks_file` is set: the owner points at an element and says what should change, `PicksController` keeps it, and every pick still in the file stays outlined on its page.
const POLL_MS = 15000

const page = () => location.pathname + location.search
const token = () => document.querySelector("meta[name=csrf-token]")?.content

let picks = []
let picking = false
let target = null

const host = document.createElement("div")
host.setAttribute("data-picker", "")
// WHY: Turbo replaces <body> and Hotwire Spark morphs it, so the picker hangs off <html> to outlive both.
document.documentElement.append(host)
const shadow = host.attachShadow({ mode: "open" })
shadow.innerHTML = `
  <style>
    :host { all: initial; }
    .pill { position: fixed; right: 16px; bottom: 80px; z-index: 2147483647; padding: 8px 12px; border: 0; border-radius: 999px; background: #1f2937; color: #fff; font: 13px/1.2 system-ui, sans-serif; cursor: pointer; box-shadow: 0 2px 8px rgb(0 0 0 / .3); }
    .pill[aria-pressed="true"] { background: #dc2626; }
    .box, .outline { position: fixed; z-index: 2147483646; display: none; pointer-events: none; }
    .box { outline: 2px solid #dc2626; background: rgb(220 38 38 / .12); }
    .outline { outline: 2px dashed #dc2626; }
    .outline span { position: absolute; left: -2px; bottom: 100%; max-width: 280px; padding: 1px 6px; border-radius: 4px 4px 0 0; background: #dc2626; color: #fff; font: 11px/16px system-ui, sans-serif; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .form { position: fixed; z-index: 2147483647; display: none; width: 320px; padding: 8px; border-radius: 8px; background: #fff; color: #111; font: 13px/1.4 system-ui, sans-serif; box-shadow: 0 4px 16px rgb(0 0 0 / .35); }
    .form textarea { box-sizing: border-box; width: 100%; min-height: 64px; font: inherit; }
    .form p { margin: 4px 0 0; color: #555; }
  </style>
  <div class="outlines"></div>
  <div class="box"></div>
  <div class="form"><textarea aria-label="Comment" placeholder="What should change here?"></textarea><p>Ctrl+Enter saves · Esc cancels</p></div>
  <button class="pill" type="button" aria-pressed="false"></button>`
const [outlines, box, form, pill] = [".outlines", ".box", ".form", ".pill"].map(selector => shadow.querySelector(selector))
const textarea = form.querySelector("textarea")

const place = (element, el) => {
  const rect = el.getBoundingClientRect()
  Object.assign(element.style, { display: "block", left: `${rect.left}px`, top: `${rect.top}px`, width: `${rect.width}px`, height: `${rect.height}px` })
}

// WHY: a selector the agent edited by hand may no longer parse, which counts as not found rather than stopping every outline after it.
const find = selector => {
  try {
    return document.querySelector(selector)
  } catch {
    return null
  }
}

const load = async () => {
  if (document.visibilityState !== "visible") return
  const response = await fetch("/picks", { headers: { Accept: "application/json" } })
  if (response.ok) picks = await response.json()
}

const save = async pick => {
  await fetch("/picks", { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token() }, body: JSON.stringify({ pick }) })
  await load()
}

// WHY: every frame rather than on events, since a morph, a Turbo visit, a scroll, an opening dialog and a font swap all move or replace the picked elements, and the browser stops the loop by itself in a hidden tab.
const follow = () => {
  const here = picks.filter(pick => pick.page === page())
  while (outlines.children.length < here.length) outlines.append(Object.assign(document.createElement("div"), { className: "outline" }))
  while (outlines.children.length > here.length) outlines.lastChild.remove()

  const missing = here.filter((pick, index) => {
    const outline = outlines.children[index]
    const el = find(pick.selector)
    const label = `${index + 1} · ${pick.comment}`
    if (outline.textContent !== label) outline.replaceChildren(Object.assign(document.createElement("span"), { textContent: label }))
    if (el) place(outline, el)
    else outline.style.display = "none"
    return !el
  })

  const text = picking ? "Picking: click an element · Esc stops" : [ `Pick · ${here.length} here · ${picks.length} in all`, missing.length && `${missing.length} not found` ].filter(Boolean).join(" · ")
  if (pill.textContent !== text) pill.textContent = text
  const title = missing.map(pick => `Not found: ${pick.comment}`).join("\n")
  if (pill.title !== title) pill.title = title
  if (pill.getAttribute("aria-pressed") !== String(picking)) pill.setAttribute("aria-pressed", String(picking))
  requestAnimationFrame(follow)
}

const selectorFor = el => {
  const parts = []
  for (let node = el; node && node !== document.documentElement; node = node.parentElement) {
    if (node.id) {
      parts.unshift(`#${CSS.escape(node.id)}`)
      break
    }
    const twins = [...(node.parentElement?.children ?? [])].filter(sibling => sibling.localName === node.localName)
    parts.unshift(twins.length > 1 ? `${node.localName}:nth-of-type(${twins.indexOf(node) + 1})` : node.localName)
  }
  return parts.join(" > ")
}

// WHY: read from the `BEGIN`/`END` comments `annotate_rendered_view_with_filenames` writes, innermost template first, so a pick names the file to open.
const templatesOf = el => {
  const stack = []
  const walker = document.createTreeWalker(document, NodeFilter.SHOW_COMMENT)
  for (let comment = walker.nextNode(); comment; comment = walker.nextNode()) {
    if (!(comment.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING)) break
    const match = comment.data.trim().match(/^(BEGIN|END) (.+)$/)
    if (match?.[1] === "BEGIN") stack.push(match[2])
    else if (match) stack.pop()
  }
  return stack.reverse()
}

const record = (el, comment) => ({
  id: Date.now(),
  page: page(),
  comment,
  selector: selectorFor(el),
  templates: templatesOf(el),
  text: el.textContent.trim().replace(/\s+/g, " ").slice(0, 120),
  html: el.outerHTML.slice(0, 400)
})

const closeForm = () => {
  textarea.blur()
  form.style.display = "none"
  box.style.display = "none"
  target = null
}

const openForm = el => {
  target = el
  place(box, el)
  const rect = el.getBoundingClientRect()
  form.style.display = "block"
  form.style.left = `${Math.max(8, Math.min(rect.left, innerWidth - 336))}px`
  form.style.top = `${Math.max(8, Math.min(rect.bottom + 8, innerHeight - 140))}px`
  textarea.value = ""
  textarea.focus()
}

const setPicking = on => {
  picking = on
  closeForm()
}

const ours = event => event.composedPath().includes(host)
const swallow = event => {
  event.preventDefault()
  event.stopImmediatePropagation()
}

addEventListener("mousemove", event => {
  if (picking && !target && !ours(event)) place(box, event.target)
}, true)
for (const type of ["pointerdown", "mousedown", "pointerup", "mouseup"]) {
  addEventListener(type, event => {
    if (picking && !ours(event)) swallow(event)
  }, true)
}
addEventListener("click", event => {
  if (!picking || ours(event)) return
  swallow(event)
  openForm(event.target)
}, true)
addEventListener("keydown", event => {
  if (picking && event.key === "Escape" && !ours(event)) setPicking(false)
}, true)
addEventListener("scroll", () => target && place(box, target), true)
addEventListener("turbo:before-render", closeForm)
document.addEventListener("visibilitychange", load)
setInterval(load, POLL_MS)

pill.addEventListener("click", () => setPicking(!picking))
textarea.addEventListener("keydown", event => {
  event.stopPropagation()
  if (event.key === "Escape") {
    closeForm()
  } else if (event.key === "Enter" && event.ctrlKey) {
    event.preventDefault()
    const comment = textarea.value.trim()
    if (comment) save(record(target, comment))
    closeForm()
  }
})

load()
follow()
