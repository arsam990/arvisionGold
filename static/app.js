/* global refs */
const dropzone       = document.getElementById('dropzone');
const fileInput      = document.getElementById('fileInput');
const previewImg     = document.getElementById('previewImg');
const dropPlaceholder= document.getElementById('dropPlaceholder');
const runBtn         = document.getElementById('runBtn');
const loaderOverlay  = document.getElementById('loaderOverlay');
const signalPanel    = document.getElementById('signalPanel');
const signalDisplay  = document.getElementById('signalDisplay');
const signalReason   = document.getElementById('signalReason');
const visionPattern  = document.getElementById('visionPattern');
const aiTrend        = document.getElementById('aiTrend');
const livePrice      = document.getElementById('livePrice');
const priceDelta     = document.getElementById('priceDelta');
const tickerPrice    = document.getElementById('tickerPrice');
const tickerDelta    = document.getElementById('tickerDelta');

let selectedFile = null;

/* ── Image selection ──────────────────────────────────────────────────── */
function showPreview(file) {
  selectedFile = file;
  const url = URL.createObjectURL(file);
  previewImg.src = url;
  previewImg.classList.remove('hidden');
  dropPlaceholder.classList.add('hidden');
  runBtn.disabled = false;
}

fileInput.addEventListener('change', e => {
  if (e.target.files[0]) showPreview(e.target.files[0]);
});

dropzone.addEventListener('dragover',  e => { e.preventDefault(); dropzone.classList.add('drag-over'); });
dropzone.addEventListener('dragleave', () => dropzone.classList.remove('drag-over'));
dropzone.addEventListener('drop',      e => {
  e.preventDefault();
  dropzone.classList.remove('drag-over');
  const f = e.dataTransfer.files[0];
  if (f && f.type.startsWith('image/')) showPreview(f);
});

/* ── Run Diagnostics ──────────────────────────────────────────────────── */
runBtn.addEventListener('click', async () => {
  if (!selectedFile) return;

  /* show loader */
  loaderOverlay.classList.remove('hidden');
  runBtn.disabled = true;

  const formData = new FormData();
  formData.append('file', selectedFile);

  try {
    const res  = await fetch('/predict', { method: 'POST', body: formData });
    const data = await res.json();

    if (data.error) throw new Error(data.error);

    renderResult(data);
  } catch (err) {
    renderError(err.message);
  } finally {
    loaderOverlay.classList.add('hidden');
    runBtn.disabled = false;
  }
});

/* ── Render result ────────────────────────────────────────────────────── */
function renderResult(d) {
  /* mini metrics */
  visionPattern.textContent = d.chart_candle || '—';
  visionPattern.style.color = d.chart_candle === 'GREEN'   ? 'var(--green)'
                             : d.chart_candle === 'RED'     ? 'var(--red)'
                             : 'var(--neutral)';

  aiTrend.textContent = d.ai_trend || '—';
  aiTrend.style.color = d.ai_trend === 'UP'   ? 'var(--green)'
                      : d.ai_trend === 'DOWN'  ? 'var(--red)'
                      : 'var(--neutral)';

  /* signal panel */
  signalPanel.classList.remove('glow-buy', 'glow-sell');

  const sev   = (d.severity || 'neutral').toLowerCase();
  const label = d.signal || '—';

  signalDisplay.innerHTML = `
    <div class="signal-result ${sev}">
      <div class="signal-label">${label}</div>
      <div class="signal-sub">${sev === 'buy' ? '▲ BULLISH CONFLUENCE' : sev === 'sell' ? '▼ BEARISH CONFLUENCE' : '◆ CONFLICTING SIGNALS'}</div>
    </div>`;

  if (sev === 'buy')  signalPanel.classList.add('glow-buy');
  if (sev === 'sell') signalPanel.classList.add('glow-sell');

  signalReason.textContent = d.reason || '';

  /* live price from result */
  if (d.price && d.price > 0) {
    livePrice.textContent = `$ ${Number(d.price).toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
  }
}

function renderError(msg) {
  signalDisplay.innerHTML = `
    <div class="signal-result sell">
      <div class="signal-label" style="font-size:18px">ERROR</div>
      <div class="signal-sub">${msg}</div>
    </div>`;
  signalReason.textContent = '';
}

/* ── Live price ticker (poll every 30s) ───────────────────────────────── */
async function pollPrice() {
  try {
    const res  = await fetch('/live_price');
    const data = await res.json();
    if (!data.price) return;

    const priceStr = `$ ${Number(data.price).toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    livePrice.textContent  = priceStr;
    tickerPrice.textContent = priceStr;

    const sign = data.delta >= 0 ? '+' : '';
    const deltaStr = `${sign}${data.delta.toFixed(2)} (${sign}${data.pct.toFixed(3)}%)`;
    priceDelta.textContent  = deltaStr;
    tickerDelta.textContent = deltaStr;
    tickerDelta.className = 'tick-delta ' + (data.delta >= 0 ? 'up' : 'down');
    priceDelta.style.color = data.delta >= 0 ? 'var(--green)' : 'var(--red)';
  } catch (_) { /* silently ignore network errors */ }
}

pollPrice();
setInterval(pollPrice, 30000);
