import { Controller } from "@hotwired/stimulus"

const STORAGE_PREFIX = "trustship.dismiss."

export default class extends Controller {
  static values = {
    storageKey: { type: String, default: "pickupBanner" }
  }

  connect() {
    const key = STORAGE_PREFIX + this.storageKeyValue
    if (window.sessionStorage.getItem(key) === "1") {
      this.element.classList.add("hidden")
    }
  }

  dismiss() {
    const key = STORAGE_PREFIX + this.storageKeyValue
    window.sessionStorage.setItem(key, "1")
    this.element.classList.add("hidden")
  }
}
