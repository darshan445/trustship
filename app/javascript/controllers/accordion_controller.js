import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "panel", "icon"]

  connect() {
    this.panelTargets.forEach((panel) => {
      panel.classList.add("max-h-0", "overflow-hidden")
      panel.classList.remove("max-h-[2000px]")
    })
    this.iconTargets.forEach((icon) => {
      icon.classList.add("rotate-0")
      icon.classList.remove("rotate-180")
    })
    this.itemTargets.forEach((button) => {
      const wrapper = button.closest("[data-open]")
      if (wrapper) wrapper.setAttribute("data-open", "false")
    })
  }

  toggle(event) {
    const button = event.currentTarget
    const idx = this.itemTargets.indexOf(button)
    if (idx === -1) return

    const panel = this.panelTargets[idx]
    const icon = this.iconTargets[idx]
    const wrapper = button.closest("[data-open]")
    const isOpen = wrapper && wrapper.getAttribute("data-open") === "true"

    if (isOpen) {
      panel.classList.remove("max-h-[2000px]")
      panel.classList.add("max-h-0", "overflow-hidden")
      icon.classList.remove("rotate-180")
      icon.classList.add("rotate-0")
      if (wrapper) wrapper.setAttribute("data-open", "false")
      return
    }

    this.panelTargets.forEach((p, i) => {
      p.classList.remove("max-h-[2000px]")
      p.classList.add("max-h-0", "overflow-hidden")
      this.iconTargets[i].classList.remove("rotate-180")
      this.iconTargets[i].classList.add("rotate-0")
      const w = this.itemTargets[i].closest("[data-open]")
      if (w) w.setAttribute("data-open", "false")
    })

    panel.classList.remove("max-h-0")
    panel.classList.add("max-h-[2000px]", "overflow-hidden")
    icon.classList.remove("rotate-0")
    icon.classList.add("rotate-180")
    if (wrapper) wrapper.setAttribute("data-open", "true")
  }
}
