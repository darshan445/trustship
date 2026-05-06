import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "overlay", "mobileNav"]

  connect() {
    this.storageKey = "trustship.sidebar.open"
    this.handleResize = this.onResize.bind(this)
    this.visualViewport = window.visualViewport
    this.handleViewportResize = this.onViewportResize.bind(this)

    window.addEventListener("resize", this.handleResize)
    if (this.visualViewport) this.visualViewport.addEventListener("resize", this.handleViewportResize)
    this.restoreState()
    this.onViewportResize()
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
    if (this.visualViewport) this.visualViewport.removeEventListener("resize", this.handleViewportResize)
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden", "-translate-x-full")
    this.overlayTarget.classList.remove("hidden")
    localStorage.setItem(this.storageKey, "1")
  }

  close() {
    if (window.innerWidth >= 768) return
    this.panelTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
    setTimeout(() => this.panelTarget.classList.add("hidden"), 200)
    localStorage.setItem(this.storageKey, "0")
  }

  restoreState() {
    if (window.innerWidth >= 768) {
      this.panelTarget.classList.remove("hidden", "-translate-x-full")
      this.overlayTarget.classList.add("hidden")
      return
    }

    if (localStorage.getItem(this.storageKey) === "1") {
      this.open()
    } else {
      this.close()
    }
  }

  onResize() {
    this.restoreState()
  }

  onViewportResize() {
    if (!this.hasMobileNavTarget || !this.visualViewport) return
    const keyboardOpen = window.innerHeight - this.visualViewport.height > 120
    this.mobileNavTarget.classList.toggle("hidden", keyboardOpen)
  }
}
