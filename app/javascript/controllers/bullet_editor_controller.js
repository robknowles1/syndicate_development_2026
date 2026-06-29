import { Controller } from "@hotwired/stimulus"

// Manages adding new bullet item rows to the service section content editor.
export default class extends Controller {
  addBullet(event) {
    const slug = event.params.sectionSlug
    const container = document.getElementById(`bullets-${slug}`)
    const template = document.getElementById(`new-bullet-template-${slug}`)

    if (!container || !template) return

    const existingRows = container.querySelectorAll(".bullet-row").length
    const newIndex = `new_${Date.now()}`
    const newPosition = existingRows

    // Clone the template content and replace placeholders
    const clone = template.content.cloneNode(true)
    clone.querySelectorAll("input").forEach((input) => {
      input.name = input.name
        .replace(/SLUG/g, slug)
        .replace(/NEW_INDEX/g, newIndex)
        .replace(/NEW_POS/g, String(newPosition))
    })

    container.appendChild(clone)
  }
}
