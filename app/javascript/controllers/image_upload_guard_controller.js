import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message"]
  static values = {
    maxBytes: Number,
    allowedTypes: String,
    oversizedMessage: String,
    invalidTypeMessage: String
  }

  validate() {
    const file = this.inputTarget.files[0]
    if (!file) return this.clearMessage()

    // Order matters: a video picked by mistake is both the wrong kind and too big, and
    // "that is not an image" names the mistake where a size complaint would concede it was one.
    if (this.isDisallowedType(file)) return this.reject(this.invalidTypeMessageValue)
    if (file.size > this.maxBytesValue) return this.reject(this.oversizedMessageValue)

    this.clearMessage()
  }

  isDisallowedType(file) {
    // An empty or unrecognised type is the browser declining to say, not a wrong answer.
    // Rejecting on it would turn legitimate images away; the server is the authority regardless.
    if (!file.type) return false

    return !this.allowedTypesValue.split(",").includes(file.type)
  }

  reject(message) {
    // Touch this input and this message only. The surrounding form carries unsaved text
    // edits, so anything wider — a reset, a re-render, a reload — discards the admin's work.
    this.inputTarget.value = ""
    this.messageTarget.textContent = message
    this.messageTarget.classList.remove("hidden")
  }

  clearMessage() {
    this.messageTarget.textContent = ""
    this.messageTarget.classList.add("hidden")
  }
}
