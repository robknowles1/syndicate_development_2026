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

    // Order matters: the type check must run before the size check (R7).
    if (this.isDisallowedType(file)) return this.reject(this.invalidTypeMessageValue)
    if (file.size > this.maxBytesValue) return this.reject(this.oversizedMessageValue)

    this.clearMessage()
  }

  isDisallowedType(file) {
    // Fails open deliberately (R12): an unset type is no answer, not a wrong one — do not reject on it.
    if (!file.type) return false

    return !this.allowedTypesValue.split(",").includes(file.type)
  }

  reject(message) {
    // Clear this input only — form.reset() here would discard the admin's unsaved text edits (R13).
    this.inputTarget.value = ""
    this.messageTarget.textContent = message
    this.messageTarget.classList.remove("hidden")
  }

  clearMessage() {
    this.messageTarget.textContent = ""
    this.messageTarget.classList.add("hidden")
  }
}
