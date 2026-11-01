let context: AudioContext | null = null;
export function chime(type = "miracle") {
  try {
    context ??= new AudioContext();
    if (context.state === "suspended") void context.resume();
    const now = context.currentTime;
    const notes =
      type === "coin"
        ? [660, 880, 1100]
        : type === "level"
          ? [440, 554, 659, 880]
          : [392, 523, 659];
    notes.forEach((frequency, i) => {
      const osc = context!.createOscillator(),
        gain = context!.createGain();
      osc.type = "sine";
      osc.frequency.value = frequency;
      gain.gain.setValueAtTime(0, now + i * 0.085);
      gain.gain.linearRampToValueAtTime(0.035, now + i * 0.085 + 0.015);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.085 + 0.4);
      osc.connect(gain);
      gain.connect(context!.destination);
      osc.start(now + i * 0.085);
      osc.stop(now + i * 0.085 + 0.4);
    });
  } catch {
    /* Audio is optional on browsers that restrict it. */
  }
}
