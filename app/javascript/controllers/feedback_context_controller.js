import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "field" ]

  connect() {
    const context = this.#context()

    this.fieldTargets.forEach(field => { field.value = context[field.dataset.key] ?? "" })
  }

  #context() {
    const matches = query => window.matchMedia(query).matches

    return {
      viewport_width: window.innerWidth,
      viewport_height: window.innerHeight,
      screen_width: screen.width,
      screen_height: screen.height,
      pixel_ratio: window.devicePixelRatio,
      orientation: screen.orientation?.type,
      color_scheme: matches("(prefers-color-scheme: dark)") ? "dark" : "light",
      reduced_motion: matches("(prefers-reduced-motion: reduce)") ? "reduce" : "no-preference",
      pointer: matches("(pointer: coarse)") ? "coarse" : matches("(pointer: fine)") ? "fine" : "none",
      display_mode: matches("(display-mode: standalone)") ? "standalone" : "browser",
      time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      language: navigator.language,
      // WHY: only Chromium browsers report the connection, so it stays blank on an iPhone.
      connection: navigator.connection?.effectiveType
    }
  }
}
