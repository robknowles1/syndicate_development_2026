import { Controller } from "@hotwired/stimulus"

// Toggles a live icon preview pane when the icon_key select changes.
// Expects one [data-icon-preview-icon-key] span per icon, all hidden by default.
// The currently-selected icon's span is shown.
export default class extends Controller {
  static targets = ["select", "preview"]
  static values = { current: String }

  connect() {
    this.showCurrent()
  }

  change() {
    this.currentValue = this.selectTarget.value
    this.showCurrent()
  }

  showCurrent() {
    const selected = this.selectTarget.value
    this.previewTargets.forEach((el) => {
      if (el.dataset.iconPreviewIconKey === selected) {
        el.classList.remove("hidden")
      } else {
        el.classList.add("hidden")
      }
    })
  }
}
