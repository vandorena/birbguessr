import { Controller } from "@hotwired/stimulus"
import { map, tileLayer, circleMarker, geoJSON } from "leaflet"

// A map of Brown's campus, in one of two modes.
//
// Editable: a click drops your pin, or moves it if you already placed one, and
// writes the coordinates into the form's hidden fields. Read-only: it draws
// every pin the server chose to send, which is none at all until you have
// guessed -- see app/models/reveal.rb. The two modes are independent, so this
// controller never needs to know they are mutually exclusive.
//
// Leaflet 1.9.4 ships named exports and no default, hence the destructured
// import above rather than `import L from "leaflet"`.
//
// circleMarker, not marker: Leaflet's default marker finds its images with a
// DOM heuristic that reads a CSS background-image, strips the filename, and
// appends the *undigested* names marker-icon-2x.png and marker-shadow.png.
// Propshaft serves digested paths, so those 404 silently. A circle is drawn by
// Leaflet itself, needs no image at all, and takes a colour -- which is what
// tells your pin apart from everyone else's anyway.
export default class extends Controller {
  static targets = [ "canvas", "latitude", "longitude", "submit", "readout" ]
  static values = {
    bounds: Array,          // [[south, west], [north, east]]
    tileUrl: String,
    attribution: String,
    editable: Boolean,
    pins: Array,            // [{ lat, lng, mine }] -- always [] before you guess
    // A digested asset, fetched once and then cached by the browser. The
    // geometry is 165 KB; inlining it in a data attribute would mean paying for
    // it again on every birb you look at.
    buildingsUrl: String
  }

  connect() {
    // The controller element wraps both the form and the map, so that the
    // hidden fields are in target scope. The map attaches to the canvas target,
    // not to this.element.
    this.map = map(this.canvasTarget, {
      // Scrolling past a map should scroll the page, not zoom the map.
      scrollWheelZoom: false,
      // One canvas instead of an SVG path per building. Brown is 279 polygons,
      // and as separate DOM nodes that is what makes panning stutter. Leaflet
      // hit-tests canvas layers itself, so tooltips and clicks still work.
      preferCanvas: true
    })

    tileLayer(this.tileUrlValue, {
      attribution: this.attributionValue,
      // OSM has no tiles past 19, and asking for them serves grey squares.
      maxZoom: 19
    }).addTo(this.map)

    // Frames campus, and that is all it does. There is deliberately no
    // maxBounds: a fence with maxBoundsViscosity: 1.0 does not stop a pan, it
    // lets one happen and then yanks the view back the moment you let go,
    // which reads as the map fighting you. Panning is now free, and where a
    // guess may land is Guess#must_be_on_campus's business -- it always was,
    // since a hand-rolled POST never saw the fence anyway.
    this.map.fitBounds(this.boundsValue)

    this.pinsValue.forEach(pin => {
      circleMarker([ pin.lat, pin.lng ], pin.mine ? MINE : THEIRS)
        .addTo(this.map)
        .bindTooltip(pin.mine ? "Your guess" : "Someone else's guess")
    })

    if (this.editableValue) this.map.on("click", this.place)

    this.drawBuildings()
  }

  // Drawn behind the pins, which are added synchronously above and so are
  // already on the map by the time this resolves.
  //
  // A failed fetch is deliberately quiet: the buildings are context, and a
  // campus map with tiles and pins and no highlighting is still entirely
  // playable. Throwing here would take the guess form down with it.
  async drawBuildings() {
    if (!this.hasBuildingsUrlValue) return

    let geojson
    try {
      const response = await fetch(this.buildingsUrlValue)
      if (!response.ok) return
      geojson = await response.json()
    } catch {
      return
    }

    // disconnect() may have run while the fetch was in flight -- navigate away
    // fast enough and this would otherwise add a layer to a removed map.
    if (!this.map) return

    // The buildings stay interactive, for the tooltips, and that does not cost
    // the guess click: Leaflet fires a layer click with propagate: true, so it
    // reaches the map's own handler and `place` runs exactly once. Most of
    // campus *is* buildings, so a layer that swallowed clicks would make most
    // of the map unguessable -- verified by clicking the John Hay Library
    // polygon in a real browser.
    // Its own pane, below the one Leaflet puts vectors in by default. The
    // buildings arrive after the pins -- they are behind a fetch and the pins
    // are not -- and on a shared canvas "later" means "on top", which paints a
    // 25% brown wash over the guess you just placed. A pane fixes the order
    // once, rather than depending on what resolves first.
    this.map.createPane(BUILDING_PANE).style.zIndex = BUILDING_PANE_Z

    geoJSON(geojson, {
      pane: BUILDING_PANE,
      style: BUILDING_STYLE,
      onEachFeature: (feature, layer) => {
        const name = feature.properties && feature.properties.name
        if (name) layer.bindTooltip(name)
      }
    }).addTo(this.map)
  }

  // Turbo keeps the page cached and reuses the DOM, so a map left running here
  // would be initialised twice on the second visit and throw.
  disconnect() {
    if (this.map) this.map.remove()
    this.map = null
  }

  place = ({ latlng: { lat, lng } }) => {
    if (this.pin) {
      this.pin.setLatLng([ lat, lng ])
    } else {
      this.pin = circleMarker([ lat, lng ], MINE).addTo(this.map)
    }

    // toFixed(6) matches decimal(10, 6), so what is shown, what is submitted and
    // what is stored are all the same number.
    this.latitudeTarget.value = lat.toFixed(6)
    this.longitudeTarget.value = lng.toFixed(6)
    this.submitTarget.disabled = false
    this.readoutTarget.textContent = `Your pin: ${lat.toFixed(6)}, ${lng.toFixed(6)}`
  }
}

// Pins are drawn by Leaflet rather than styled by the stylesheet, so they carry
// their own colour -- the same reason are-you-in keeps its geometry styles in
// JS. Yours is the loud one; the crowd is deliberately quieter.
const MINE = { radius: 8, color: "#7c2d12", fillColor: "#c2410c", fillOpacity: 0.9, weight: 2 }
const THEIRS = { radius: 6, color: "#3f6212", fillColor: "#65a30d", fillOpacity: 0.5, weight: 1 }
// Quieter than either pin: the buildings are what you are guessing *on*, not
// what you are looking at. Enough fill to read as a footprint over the tiles,
// not enough to compete with a guess.
const BUILDING_STYLE = { color: "#7c2d12", weight: 1, fillOpacity: 0.25, interactive: true }
// Between Leaflet's tilePane (200) and its overlayPane (400), which is where
// the pins are drawn: buildings sit over the map imagery and under every guess.
const BUILDING_PANE = "buildings"
const BUILDING_PANE_Z = 350
