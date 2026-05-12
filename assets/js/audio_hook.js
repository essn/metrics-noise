// C major pentatonic across 4 octaves (C2–A5)
const SCALE = [
  { freq: 65.41,  name: "C2" },
  { freq: 73.42,  name: "D2" },
  { freq: 82.41,  name: "E2" },
  { freq: 98.00,  name: "G2" },
  { freq: 110.00, name: "A2" },
  { freq: 130.81, name: "C3" },
  { freq: 146.83, name: "D3" },
  { freq: 164.81, name: "E3" },
  { freq: 196.00, name: "G3" },
  { freq: 220.00, name: "A3" },
  { freq: 261.63, name: "C4" },
  { freq: 293.66, name: "D4" },
  { freq: 329.63, name: "E4" },
  { freq: 392.00, name: "G4" },
  { freq: 440.00, name: "A4" },
  { freq: 523.25, name: "C5" },
  { freq: 587.33, name: "D5" },
  { freq: 659.25, name: "E5" },
  { freq: 783.99, name: "G5" },
  { freq: 880.00, name: "A5" },
]

// Each metric index gets a non-overlapping 5-note octave window
const OCTAVE_SIZE = 5
const WAVEFORMS = ["sine", "triangle", "sine", "sawtooth"]

function freqForMetric(normalized, metricIndex) {
  const octaveOffset = (metricIndex % 4) * OCTAVE_SIZE
  const noteIndex = octaveOffset + Math.round(normalized * (OCTAVE_SIZE - 1))
  return SCALE[Math.min(noteIndex, SCALE.length - 1)].freq
}

const AudioSynth = {
  ctx: null,
  master: null,
  oscillators: new Map(),

  mounted() {
    this.ctx = null
    this.master = null
    this.oscillators = new Map()
    this.handleEvent("audio:start", () => this.start())
    this.handleEvent("audio:stop", () => this.stop())
    this.handleEvent("metrics:update", ({ metrics }) => this.updateMetrics(metrics))
  },

  destroyed() {
    this.stop()
  },

  start() {
    if (this.ctx) this.ctx.close()
    this.ctx = new AudioContext()
    this.master = this.ctx.createGain()
    this.master.gain.value = 0.6
    this.master.connect(this.ctx.destination)
    this.oscillators.clear()
  },

  stop() {
    if (this.ctx) {
      this.ctx.close()
      this.ctx = null
      this.master = null
    }
    this.oscillators.clear()
  },

  updateMetrics(metrics) {
    if (!this.ctx || !this.master) return

    const now = this.ctx.currentTime
    const count = metrics.length
    const targetGain = count > 0 ? 0.5 / count : 0

    const activeNames = new Set(metrics.map(m => m.name))

    // Remove oscillators for metrics that disappeared
    for (const [name, nodes] of this.oscillators) {
      if (!activeNames.has(name)) {
        nodes.gain.gain.linearRampToValueAtTime(0, now + 0.4)
        setTimeout(() => {
          try { nodes.osc.stop() } catch (_) {}
          this.oscillators.delete(name)
        }, 500)
      }
    }

    // Add or update oscillators
    metrics.forEach(({ name, normalized, index }) => {
      const freq = freqForMetric(normalized, index)

      if (!this.oscillators.has(name)) {
        const osc = this.ctx.createOscillator()
        const gain = this.ctx.createGain()
        osc.type = WAVEFORMS[index % WAVEFORMS.length]
        osc.frequency.value = freq
        gain.gain.setValueAtTime(0, now)
        gain.gain.linearRampToValueAtTime(targetGain, now + 0.3)
        osc.connect(gain)
        gain.connect(this.master)
        osc.start()
        this.oscillators.set(name, { osc, gain })
      } else {
        const { osc, gain } = this.oscillators.get(name)
        osc.frequency.linearRampToValueAtTime(freq, now + 0.8)
        gain.gain.linearRampToValueAtTime(targetGain, now + 0.2)
      }
    })
  },
}

export default AudioSynth
