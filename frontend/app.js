const playButton = document.getElementById('play-toggle');
const progress = document.getElementById('progress');
const currentTime = document.getElementById('current-time');

let isPlaying = false;
let tick = null;

const formatTime = (value) => {
  const totalSec = Math.floor((value / 100) * 196);
  const min = Math.floor(totalSec / 60);
  const sec = String(totalSec % 60).padStart(2, '0');
  return `${min}:${sec}`;
};

const stopTick = () => {
  if (tick) {
    clearInterval(tick);
    tick = null;
  }
};

const startTick = () => {
  stopTick();
  tick = setInterval(() => {
    const next = Math.min(Number(progress.value) + 1, 100);
    progress.value = String(next);
    currentTime.textContent = formatTime(next);
    if (next >= 100) {
      isPlaying = false;
      playButton.textContent = 'PLAY';
      stopTick();
    }
  }, 850);
};

playButton?.addEventListener('click', () => {
  isPlaying = !isPlaying;
  playButton.textContent = isPlaying ? 'PAUSE' : 'PLAY';
  if (isPlaying) {
    startTick();
  } else {
    stopTick();
  }
});

progress?.addEventListener('input', (event) => {
  const value = Number(event.target.value);
  currentTime.textContent = formatTime(value);
});
