import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = {
    configId: String,
    appId: String,
    completeUrl: String
  }

  connect() {
    this.isFbInitialized = false
    this.boundMessageHandler = this.handleWindowMessage.bind(this)
    window.addEventListener("message", this.boundMessageHandler)
    this.ensureSdk()
  }

  disconnect() {
    window.removeEventListener("message", this.boundMessageHandler)
  }

  ensureSdk() {
    if (window.FB) {
      this.initializeFb()
      return
    }
    window.fbAsyncInit = () => {
      this.initializeFb()
    }

    const id = "facebook-jssdk"
    if (document.getElementById(id)) return
    const js = document.createElement("script")
    js.id = id
    js.async = true
    js.defer = true
    js.src = "https://connect.facebook.net/en_US/sdk.js"
    document.head.appendChild(js)
  }

  initializeFb() {
    if (!window.FB || this.isFbInitialized) return
    try {
      window.FB.init({
        appId: this.appIdValue,
        autoLogAppEvents: true,
        xfbml: false,
        version: "v21.0"
      })
      // FB.login requires a valid app initialization; this verifies init actually stuck.
      window.FB.getLoginStatus(() => {
        this.isFbInitialized = true
      })
    } catch (_error) {
      this.isFbInitialized = false
    }
  }

  async start() {
    const initialized = await this.waitForFbInit()
    if (!initialized) {
      this.setMessage("Facebook SDK is not initialized. Ensure Meta App ID is configured for Embedded Signup.")
      return
    }

    this.setMessage("Opening Embedded Signup...")
    window.FB.login(
      () => {
        this.setMessage("Complete the flow in popup, then return here.")
      },
      {
        config_id: this.configIdValue,
        response_type: "code",
        override_default_response_type: true,
        extras: {
          setup: {},
          sessionInfoVersion: 3
        }
      }
    )
  }

  waitForFbInit(timeoutMs = 4000) {
    const start = Date.now()
    return new Promise((resolve) => {
      const tick = () => {
        if (window.FB && !this.isFbInitialized) this.initializeFb()
        if (this.isFbInitialized) {
          resolve(true)
          return
        }
        if (Date.now() - start >= timeoutMs) {
          resolve(false)
          return
        }
        setTimeout(tick, 100)
      }
      tick()
    })
  }

  async handleWindowMessage(event) {
    if (typeof event.data !== "string") return
    let data
    try {
      data = JSON.parse(event.data)
    } catch (_e) {
      return
    }

    if (data?.type !== "WA_EMBEDDED_SIGNUP") return

    if (data.event === "FINISH") {
      const payload = {
        waba_id: data.data?.waba_id,
        phone_number_id: data.data?.phone_number_id
      }
      if (!payload.waba_id || !payload.phone_number_id) {
        this.setMessage("Embedded Signup finished but required IDs are missing.")
        return
      }

      this.setMessage("Finalizing WhatsApp connection...")
      try {
        const response = await fetch(this.completeUrlValue, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
          },
          body: JSON.stringify(payload)
        })
        const body = await response.json().catch(() => ({}))
        if (!response.ok || !body.ok) throw new Error(body.error || "Unable to complete signup")
        this.setMessage("WhatsApp connected successfully.")
        window.location.reload()
      } catch (e) {
        this.setMessage(`Connection failed: ${e.message}`)
      }
    } else if (data.event === "CANCEL") {
      this.setMessage("Embedded Signup cancelled.")
    } else if (data.event === "ERROR") {
      this.setMessage("Embedded Signup returned an error.")
    }
  }

  setMessage(text) {
    if (!this.hasMessageTarget) return
    this.messageTarget.textContent = text
  }
}
