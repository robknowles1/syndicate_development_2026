import { Controller } from "@hotwired/stimulus"

// Manages adding new bullet item rows to the service section new/edit form.
// Uses nested attributes naming: service_section[service_bullets_attributes][INDEX][...]
export default class extends Controller {
  static targets = ["container", "template"]

  addBullet() {
    // Rails' strong parameters only recognizes nested-attribute hash keys that are
    // purely numeric (matches /\A-?\d+\z/) — a "new_" prefix causes the entry to be
    // silently dropped by permit(), so the index must be digits only.
    const newIndex = String(Date.now())
    const existingRows = this.containerTarget.querySelectorAll(".bullet-row").length

    const clone = this.templateTarget.content.cloneNode(true)
    clone.querySelectorAll("input").forEach((input) => {
      if (input.name) {
        input.name = input.name.replace(/NEW_INDEX/g, newIndex)
      }
      if (input.value === "NEW_POS") {
        input.value = String(existingRows)
      }
    })

    this.containerTarget.appendChild(clone)
  }

  toggleDestroy(event) {
    const checkbox = event.target
    const row = checkbox.closest(".bullet-row")
    if (!row) return

    if (checkbox.checked) {
      row.classList.add("opacity-50")
      row.querySelector("input[type=text]")?.classList.add("line-through")
    } else {
      row.classList.remove("opacity-50")
      row.querySelector("input[type=text]")?.classList.remove("line-through")
    }
  }
}
