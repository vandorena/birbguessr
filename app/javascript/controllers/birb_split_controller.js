import { Controller } from "@hotwired/stimulus"

// The slider on the seam between the birb photo and the campus map.
//
// It writes one number: --birb-split, the x of the seam, which the stylesheet
// uses both to place this handle and to clip the map. Nothing is resized --
// see the note at the top of _birb-split.scss for why that is the whole point.
//
// Two bounds, and they are not symmetric. Left it runs to 0, where the map has
// covered the photo completely. Right it stops at the position it started in,
// which is where the design opens: the photo is never given more room than it
// was drawn with, so there is no state in which pink shows through the seam.
export default class extends Controller {
  static targets = [ "slider" ]

  connect() {
    // The start is authored in CSS, as a percentage, so the stylesheet stays
    // the one place the layout is described. Resolved to pixels here rather
    // than measured off the handle: Turbo restores a cached page with whatever
    // inline --birb-split the last drag wrote, and measuring would read that
    // back as the bound the slider may not pass.
    this.start = this.element.clientWidth * this.startFraction()

    this.onResize = this.onResize.bind(this)
    window.addEventListener("resize", this.onResize)

    this.moveTo(this.start)
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
  }

  // A drag, for as long as the pointer is down. setPointerCapture keeps the
  // moves coming to this element even when the pointer outruns a 23px handle,
  // which at any real drag speed it does immediately.
  startDrag(event) {
    event.preventDefault()
    this.sliderTarget.setPointerCapture(event.pointerId)
    this.dragging = true
    this.sliderTarget.focus()
  }

  drag(event) {
    if (!this.dragging) return
    this.moveTo(event.clientX - this.element.getBoundingClientRect().left)
  }

  endDrag(event) {
    if (!this.dragging) return
    this.dragging = false
    this.sliderTarget.releasePointerCapture(event.pointerId)
  }

  // Keyboard, because a slider you can only drag is a slider half the people
  // reading this page cannot use. A step is 24px; shift is a tenth of the run.
  nudge(event) {
    const step = event.shiftKey ? this.start / 10 : 24

    switch (event.key) {
      case "ArrowLeft":
      case "ArrowDown":  this.moveTo(this.position - step); break
      case "ArrowRight":
      case "ArrowUp":    this.moveTo(this.position + step); break
      case "Home":       this.moveTo(0); break
      case "End":        this.moveTo(this.start); break
      default:           return
    }

    event.preventDefault()
  }

  // The window changing size is the one thing that legitimately moves the
  // start: it is a percentage of the viewport. Hold the seam where it is
  // proportionally rather than snapping it back.
  onResize() {
    const fraction = this.start === 0 ? 1 : this.position / this.start

    this.start = this.element.clientWidth * this.startFraction()
    this.moveTo(this.start * fraction)
  }

  // --birb-split-start as a fraction, re-read from the stylesheet because the
  // media query changes it.
  startFraction() {
    const declared = getComputedStyle(this.element).getPropertyValue("--birb-split-start")
    return parseFloat(declared) / 100 || 0
  }

  moveTo(x) {
    this.position = Math.min(Math.max(x, 0), this.start)
    this.element.style.setProperty("--birb-split", `${this.position}px`)
    this.report()
  }

  // 100 is the opening position, photo fully visible; 0 is map over everything.
  report() {
    const percent = this.start === 0 ? 100 : Math.round((this.position / this.start) * 100)

    this.sliderTarget.setAttribute("aria-valuenow", percent)
    this.sliderTarget.setAttribute("aria-valuetext", `Photo ${percent}% visible`)
  }
}
