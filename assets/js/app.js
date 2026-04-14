// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/astra_auto_ex"
import topbar from "../vendor/topbar"

// ── Custom Hooks ──

const Hooks = {
  // Auto-scroll chat messages to bottom
  ScrollBottom: {
    mounted() { this.scrollToBottom() },
    updated() { this.scrollToBottom() },
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight
    }
  },

  // Drag-and-drop reordering (panels + providers)
  DragSort: {
    mounted() {
      const eventName = this.el.dataset.sortEvent || "reorder_panels"

      this.el.addEventListener("dragstart", e => {
        const item = e.target.closest("[data-panel-id]")
        if (!item) return
        e.dataTransfer.setData("text/plain", item.dataset.panelId)
        item.classList.add("opacity-50")
      })
      this.el.addEventListener("dragend", e => {
        const item = e.target.closest("[data-panel-id]")
        if (item) item.classList.remove("opacity-50")
      })
      this.el.addEventListener("dragover", e => {
        e.preventDefault()
        const target = e.target.closest("[data-panel-id]")
        if (target) target.classList.add("ring-2", "ring-blue-400/30")
      })
      this.el.addEventListener("dragleave", e => {
        const target = e.target.closest("[data-panel-id]")
        if (target) target.classList.remove("ring-2", "ring-blue-400/30")
      })
      this.el.addEventListener("drop", e => {
        e.preventDefault()
        const sourceId = e.dataTransfer.getData("text/plain")
        const target = e.target.closest("[data-panel-id]")
        if (!target) return
        target.classList.remove("ring-2", "ring-blue-400/30")
        const targetId = target.dataset.panelId
        if (sourceId === targetId) return

        // DOM reorder
        const container = this.el
        const sourceEl = container.querySelector(`[data-panel-id="${sourceId}"]`)
        const targetEl = container.querySelector(`[data-panel-id="${targetId}"]`)
        if (sourceEl && targetEl) {
          if (sourceEl.getBoundingClientRect().top < targetEl.getBoundingClientRect().top) {
            targetEl.after(sourceEl)
          } else {
            targetEl.before(sourceEl)
          }
        }
        // Push event with full order
        const order = [...container.querySelectorAll("[data-panel-id]")].map(el => el.dataset.panelId)
        this.pushEvent(eventName, {order: order, source_id: sourceId, target_id: targetId})
      })
    }
  },

  // Image crop with canvas
  ImageCrop: {
    mounted() {
      this.img = this.el.querySelector("img")
      this.canvas = this.el.querySelector("canvas")
      if (!this.img || !this.canvas) return

      this.ctx = this.canvas.getContext("2d")
      this.dragging = false
      this.crop = { x: 0, y: 0, w: 0, h: 0 }

      this.img.onload = () => {
        this.canvas.width = this.img.naturalWidth
        this.canvas.height = this.img.naturalHeight
        this.drawImage()
      }
      if (this.img.complete) this.img.onload()

      // Mouse crop selection
      this.canvas.addEventListener("mousedown", (e) => {
        const rect = this.canvas.getBoundingClientRect()
        const sx = this.canvas.width / rect.width
        const sy = this.canvas.height / rect.height
        this.crop.x = (e.clientX - rect.left) * sx
        this.crop.y = (e.clientY - rect.top) * sy
        this.dragging = true
      })

      this.canvas.addEventListener("mousemove", (e) => {
        if (!this.dragging) return
        const rect = this.canvas.getBoundingClientRect()
        const sx = this.canvas.width / rect.width
        const sy = this.canvas.height / rect.height
        this.crop.w = (e.clientX - rect.left) * sx - this.crop.x
        this.crop.h = (e.clientY - rect.top) * sy - this.crop.y
        this.drawImage()
        this.drawCropRect()
      })

      this.canvas.addEventListener("mouseup", () => {
        this.dragging = false
        if (Math.abs(this.crop.w) > 20 && Math.abs(this.crop.h) > 20) {
          this.applyCrop()
        }
      })
    },
    drawImage() {
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height)
      this.ctx.drawImage(this.img, 0, 0)
    },
    drawCropRect() {
      const {x, y, w, h} = this.crop
      this.ctx.strokeStyle = "rgba(255, 255, 255, 0.8)"
      this.ctx.lineWidth = 2
      this.ctx.setLineDash([5, 5])
      this.ctx.strokeRect(x, y, w, h)
      this.ctx.setLineDash([])
      // Dim outside crop area
      this.ctx.fillStyle = "rgba(0, 0, 0, 0.4)"
      this.ctx.fillRect(0, 0, this.canvas.width, y)
      this.ctx.fillRect(0, y + h, this.canvas.width, this.canvas.height - y - h)
      this.ctx.fillRect(0, y, x, h)
      this.ctx.fillRect(x + w, y, this.canvas.width - x - w, h)
    },
    applyCrop() {
      const {x, y, w, h} = this.crop
      const cx = Math.min(x, x + w)
      const cy = Math.min(y, y + h)
      const cw = Math.abs(w)
      const ch = Math.abs(h)

      // Create cropped canvas
      const cropped = document.createElement("canvas")
      cropped.width = cw
      cropped.height = ch
      const cctx = cropped.getContext("2d")
      cctx.drawImage(this.img, cx, cy, cw, ch, 0, 0, cw, ch)

      // Convert to blob and push event
      cropped.toBlob((blob) => {
        if (blob) {
          const reader = new FileReader()
          reader.onload = () => {
            this.pushEvent("image_cropped", {
              data_url: reader.result,
              width: cw,
              height: ch
            })
          }
          reader.readAsDataURL(blob)
        }
      }, "image/png")
    }
  },

  // Textarea auto-resize
  AutoResize: {
    mounted() {
      this.el.addEventListener("input", () => {
        this.el.style.height = "auto"
        this.el.style.height = this.el.scrollHeight + "px"
      })
    }
  },

  // Video player with controls
  VideoPlayer: {
    mounted() {
      const video = this.el.querySelector("video")
      if (!video) return
      this.handleEvent("play_video", ({url}) => {
        video.src = url
        video.play()
      })
      this.handleEvent("pause_video", () => { video.pause() })
    }
  },

  // Audio player with preview
  AudioPlayer: {
    mounted() {
      this.audio = null
      this.el.addEventListener("click", () => {
        const url = this.el.dataset.audioUrl
        if (!url) return
        if (this.audio && !this.audio.paused) {
          this.audio.pause()
          this.audio = null
          this.el.classList.remove("ring-2", "ring-green-400/50")
        } else {
          this.audio = new Audio(url)
          this.audio.play()
          this.el.classList.add("ring-2", "ring-green-400/50")
          this.audio.onended = () => {
            this.el.classList.remove("ring-2", "ring-green-400/50")
            this.audio = null
          }
        }
      })
    },
    destroyed() {
      if (this.audio) { this.audio.pause(); this.audio = null }
    }
  },

  // Progress bar animation
  ProgressBar: {
    mounted() {
      this.handleEvent("update_progress", ({percent}) => {
        const bar = this.el.querySelector("[data-progress-bar]")
        if (bar) bar.style.width = `${percent}%`
      })
    }
  },

  // Click outside to close (for modals)
  ClickOutside: {
    mounted() {
      this.handler = (e) => {
        if (!this.el.contains(e.target)) {
          this.pushEvent("close_modal", {})
        }
      }
      document.addEventListener("click", this.handler, true)
    },
    destroyed() {
      document.removeEventListener("click", this.handler, true)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

