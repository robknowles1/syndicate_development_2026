import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "image"]

  open(event) {
    this.imageTarget.src = event.params.src
    this.imageTarget.alt = event.params.alt
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    this.imageTarget.src = ""
    document.body.classList.remove("overflow-hidden")
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }
}
