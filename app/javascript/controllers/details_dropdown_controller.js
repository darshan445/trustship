import { Controller } from "@hotwired/stimulus"

// Closes a <details> menu when the user clicks or taps outside it (native details
// only toggle via summary, not backdrop dismiss).
//
// Menus marked with [data-details-dropdown-panel] are positioned with `position: fixed`
// while open so they escape ancestor overflow (e.g. `overflow-x-auto` on tables).
// The panel stays `invisible` + `absolute` until coords are applied to avoid layout flicker.
export default class extends Controller {
  connect() {
    this._onPointerDown = this._onPointerDown.bind(this)
    this._onToggle = this._onToggle.bind(this)
    this._onScrollOrResize = this._onScrollOrResize.bind(this)
    document.addEventListener("pointerdown", this._onPointerDown, true)
    this.element.addEventListener("toggle", this._onToggle)
    this.panel = this.element.querySelector("[data-details-dropdown-panel]")
  }

  disconnect() {
    document.removeEventListener("pointerdown", this._onPointerDown, true)
    this.element.removeEventListener("toggle", this._onToggle)
    this._teardownScrollListeners()
    this._resetPanelLayout()
  }

  _onToggle() {
    if (!this.panel) return

    if (this.element.open) {
      this.panel.classList.add("invisible", "pointer-events-none")
      requestAnimationFrame(() => {
        if (!this.element.open) return
        this._layoutPanel()
        this.panel.classList.remove("invisible", "pointer-events-none")
        this._layoutPanel()
        window.addEventListener("scroll", this._onScrollOrResize, true)
        window.addEventListener("resize", this._onScrollOrResize)
      })
    } else {
      this.panel.classList.add("invisible", "pointer-events-none")
      this._resetPanelLayout()
      this._teardownScrollListeners()
    }
  }

  _onScrollOrResize() {
    if (!this.element.open || !this.panel) return
    this._layoutPanel()
  }

  _teardownScrollListeners() {
    window.removeEventListener("scroll", this._onScrollOrResize, true)
    window.removeEventListener("resize", this._onScrollOrResize)
  }

  _layoutPanel() {
    const summary = this.element.querySelector("summary")
    if (!summary || !this.panel) return

    const sr = summary.getBoundingClientRect()
    const gap = 4
    const width = Math.max(this.panel.offsetWidth || 0, 192)
    let left = sr.right - width
    const margin = 8
    left = Math.max(margin, Math.min(left, window.innerWidth - width - margin))
    const top = sr.bottom + gap

    this.panel.style.position = "fixed"
    this.panel.style.top = `${top}px`
    this.panel.style.left = `${left}px`
    this.panel.style.right = "auto"
    this.panel.style.bottom = "auto"
    this.panel.style.width = `${width}px`
    this.panel.style.zIndex = "100"
    this.panel.style.margin = "0"

    // If the menu would extend past the viewport bottom, open upward instead.
    const panelHeight = this.panel.offsetHeight
    const spaceBelow = window.innerHeight - top
    if (panelHeight > 0 && spaceBelow < panelHeight + margin) {
      const above = sr.top - gap - panelHeight
      if (above >= margin) {
        this.panel.style.top = `${above}px`
      }
    }
  }

  _resetPanelLayout() {
    if (!this.panel) return
    ;["position", "top", "left", "right", "bottom", "width", "z-index", "margin"].forEach(
      (prop) => {
        this.panel.style.removeProperty(prop)
      }
    )
  }

  _onPointerDown(event) {
    if (!this.element.open) return
    if (this.element.contains(event.target)) return

    this.element.removeAttribute("open")
  }
}
