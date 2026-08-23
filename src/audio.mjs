export class AudioDirector {
  constructor() {
    this.context = null;
    this.master = null;
    this.muted = false;
    this.lastStep = 0;
    this.drone = [];
  }

  async start() {
    if (this.context) return;
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    this.context = new AudioContextClass();
    this.master = this.context.createGain();
    this.master.gain.value = 0.28;
    this.master.connect(this.context.destination);
    for (const [frequency, gain] of [[92,0.012],[138,0.008],[207,0.004]]) {
      const oscillator = this.context.createOscillator();
      const amplitude = this.context.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.value = frequency;
      amplitude.gain.value = gain;
      oscillator.connect(amplitude);
      amplitude.connect(this.master);
      oscillator.start();
      this.drone.push({ oscillator, amplitude });
    }
  }

  setMuted(muted) {
    this.muted = muted;
    if (this.master && this.context) {
      this.master.gain.setTargetAtTime(muted ? 0 : 0.28, this.context.currentTime, 0.04);
    }
  }

  setMood({ comfort, energy }) {
    if (!this.context) return;
    const now = this.context.currentTime;
    this.drone.forEach(({ amplitude }, index) => {
      amplitude.gain.setTargetAtTime(
        0.004 + index*0.0015 + comfort*0.006 + energy*0.002,
        now,
        0.8
      );
    });
  }

  chime(kind = 'soft') {
    if (!this.context || this.muted) return;
    const now = this.context.currentTime;
    const notes = kind === 'warm' ? [392,523.25,659.25] : kind === 'uneasy' ? [220,233.08] : [329.63,440];
    notes.forEach((frequency,index) => {
      const oscillator = this.context.createOscillator();
      const amplitude = this.context.createGain();
      oscillator.type = kind === 'uneasy' ? 'triangle' : 'sine';
      oscillator.frequency.value = frequency;
      amplitude.gain.setValueAtTime(0, now+index*0.08);
      amplitude.gain.linearRampToValueAtTime(kind === 'uneasy' ? 0.035 : 0.055, now+0.03+index*0.08);
      amplitude.gain.exponentialRampToValueAtTime(0.0001, now+0.7+index*0.12);
      oscillator.connect(amplitude);
      amplitude.connect(this.master);
      oscillator.start(now+index*0.08);
      oscillator.stop(now+1.0+index*0.12);
    });
  }

  step(now, running = false) {
    if (!this.context || this.muted || now-this.lastStep < (running ? 0.25 : 0.37)) return;
    this.lastStep = now;
    const oscillator = this.context.createOscillator();
    const amplitude = this.context.createGain();
    oscillator.type = 'triangle';
    oscillator.frequency.value = running ? 82 : 68;
    const time = this.context.currentTime;
    amplitude.gain.setValueAtTime(0.025,time);
    amplitude.gain.exponentialRampToValueAtTime(0.0001,time+0.08);
    oscillator.connect(amplitude);
    amplitude.connect(this.master);
    oscillator.start(time);
    oscillator.stop(time+0.09);
  }
}
