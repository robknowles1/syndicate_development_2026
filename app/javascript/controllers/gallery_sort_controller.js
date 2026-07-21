import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String, failedMessage: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      ghostClass: "opacity-50",
      onEnd: this.onEnd.bind(this)
    })
  }

  onEnd(event) {
    if (event.newIndex === event.oldIndex) return

    const photoIds = Array.from(this.element.querySelectorAll("[data-gallery-photo-id]"))
      .map((tile) => Number(tile.dataset.galleryPhotoId))

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ photo_ids: photoIds })
    })
      .then((response) => {
        if (!response.ok) throw new Error("reorder request failed")
      })
      .catch(() => {
        alert(this.failedMessageValue)
        window.location.reload()
      })
  }
}
