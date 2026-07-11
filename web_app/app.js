// ─── WriteSense Web Capture App ─────────────────────────────────────────────
// Part 1: Firebase setup, Auth, Canvas, and Stroke capture

import firebaseConfig from './firebase-config.js';
import { initializeApp }                          from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import { getAuth, signInWithEmailAndPassword,
         createUserWithEmailAndPassword,
         signOut, onAuthStateChanged }            from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
import { getFirestore, doc, setDoc,
         serverTimestamp }                        from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';

// ── Firebase init ─────────────────────────────────────────────────────────────
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db   = getFirestore(app);

// ── DOM refs ──────────────────────────────────────────────────────────────────
const views = {
  login:   document.getElementById('view-login'),
  draw:    document.getElementById('view-draw'),
  results: document.getElementById('view-results'),
};
const navbar         = document.getElementById('navbar');
const userInfo       = document.getElementById('user-info');
const userEmailEl    = document.getElementById('user-email');
const authError      = document.getElementById('auth-error');
const emailInput     = document.getElementById('email');
const passwordInput  = document.getElementById('password');
const btnSignin      = document.getElementById('btn-signin');
const btnSignup      = document.getElementById('btn-signup');
const btnSignout     = document.getElementById('btn-signout');
const canvas         = document.getElementById('drawing-canvas');
const ctx            = canvas.getContext('2d');
const btnClear       = document.getElementById('btn-clear');
const btnAnalyze     = document.getElementById('btn-analyze');
const pressureWarn   = document.getElementById('pressure-warning');
const statStrokes    = document.getElementById('stat-strokes');
const statPoints     = document.getElementById('stat-points');
const statDuration   = document.getElementById('stat-duration');
const statPressure   = document.getElementById('stat-pressure');
const spinner        = document.getElementById('spinner');
const spinnerText    = document.getElementById('spinner-text');
const toast          = document.getElementById('toast');

// ── View switching ────────────────────────────────────────────────────────────
function showView(name) {
  Object.values(views).forEach(v => v.classList.remove('active'));
  views[name].classList.add('active');
}

// ── Toast ─────────────────────────────────────────────────────────────────────
let toastTimer;
function showToast(msg, type = 'info') {
  toast.textContent = msg;
  toast.className = type;
  toast.classList.remove('hidden');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.add('hidden'), 3500);
}

// ── Spinner ───────────────────────────────────────────────────────────────────
function showSpinner(text = 'Analyzing…') {
  spinnerText.textContent = text;
  spinner.classList.remove('hidden');
}
function hideSpinner() { spinner.classList.add('hidden'); }

// ── Auth state ────────────────────────────────────────────────────────────────
let currentUser = null;

onAuthStateChanged(auth, user => {
  currentUser = user;
  if (user) {
    userInfo.classList.remove('hidden');
    userEmailEl.textContent = user.email;
    showView('draw');
    setupCanvas();
  } else {
    userInfo.classList.add('hidden');
    showView('login');
  }
});

// ── Auth handlers ─────────────────────────────────────────────────────────────
function setAuthError(msg) {
  authError.textContent = msg;
  authError.classList.toggle('hidden', !msg);
}

btnSignin.addEventListener('click', async () => {
  setAuthError('');
  btnSignin.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, emailInput.value.trim(), passwordInput.value);
  } catch (e) {
    setAuthError(friendlyAuthError(e.code));
  } finally {
    btnSignin.disabled = false;
  }
});

btnSignup.addEventListener('click', async () => {
  setAuthError('');
  btnSignup.disabled = true;
  try {
    await createUserWithEmailAndPassword(auth, emailInput.value.trim(), passwordInput.value);
  } catch (e) {
    setAuthError(friendlyAuthError(e.code));
  } finally {
    btnSignup.disabled = false;
  }
});

btnSignout.addEventListener('click', () => signOut(auth));

function friendlyAuthError(code) {
  const map = {
    'auth/invalid-email':       'Invalid email address.',
    'auth/user-not-found':      'No account found with this email.',
    'auth/wrong-password':      'Incorrect password.',
    'auth/email-already-in-use':'An account already exists with this email.',
    'auth/weak-password':       'Password must be at least 6 characters.',
    'auth/too-many-requests':   'Too many attempts. Try again later.',
    'auth/invalid-credential':  'Invalid email or password.',
  };
  return map[code] || `Sign-in error (${code})`;
}

// ── Canvas setup ──────────────────────────────────────────────────────────────
function setupCanvas() {
  const wrapper = canvas.parentElement;
  const w = Math.min(wrapper.clientWidth, 900);
  const h = Math.max(340, Math.round(w * 0.55));
  canvas.width  = w;
  canvas.height = h;
  clearCanvas();
}

window.addEventListener('resize', () => { if (currentUser) setupCanvas(); });

// ── Stroke data ───────────────────────────────────────────────────────────────
let strokes      = [];   // Array of Array<{x,y,t,pressure}>
let currentStroke = null;
let sessionStart  = null;

function clearCanvas() {
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  strokes = [];
  currentStroke = null;
  sessionStart  = null;
  updateStats();
  btnAnalyze.disabled = true;
  pressureWarn.classList.add('hidden');
}

btnClear.addEventListener('click', clearCanvas);
btnAnalyze.addEventListener('click', () => runAnalysis());

// ── Pointer events (gets real pressure from Huion driver) ─────────────────────
canvas.addEventListener('pointerdown', e => {
  e.preventDefault();
  canvas.setPointerCapture(e.pointerId);
  if (!sessionStart) sessionStart = Date.now();
  currentStroke = [makePoint(e)];
  ctx.beginPath();
  ctx.moveTo(e.offsetX, e.offsetY);
});

canvas.addEventListener('pointermove', e => {
  e.preventDefault();
  if (!currentStroke) return;
  const pt = makePoint(e);
  currentStroke.push(pt);
  drawSegment(currentStroke.at(-2), pt, pt.pressure);
  updateStats();
});

canvas.addEventListener('pointerup', e => {
  e.preventDefault();
  if (!currentStroke || currentStroke.length < 2) {
    currentStroke = null;
    return;
  }
  strokes.push(currentStroke);
  currentStroke = null;
  btnAnalyze.disabled = false;
  checkPressureWarning();
  updateStats();
});

canvas.addEventListener('pointercancel', e => {
  if (currentStroke) {
    strokes.push(currentStroke);
    currentStroke = null;
    btnAnalyze.disabled = strokes.length === 0;
  }
});

function makePoint(e) {
  return {
    x: e.offsetX,
    y: e.offsetY,
    t: Date.now(),
    pressure: e.pressure > 0 ? e.pressure : 0.5,
  };
}

// ── Drawing ───────────────────────────────────────────────────────────────────
function drawSegment(p0, p1, pressure) {
  if (!p0 || !p1) return;
  const width = Math.max(1, 3 * (0.5 + pressure * 0.8));
  ctx.strokeStyle = '#1a1a2e';
  ctx.lineWidth   = width;
  ctx.lineCap     = 'round';
  ctx.lineJoin    = 'round';
  ctx.beginPath();
  const mx = (p0.x + p1.x) / 2;
  const my = (p0.y + p1.y) / 2;
  ctx.moveTo(p0.x, p0.y);
  ctx.quadraticCurveTo(p0.x, p0.y, mx, my);
  ctx.stroke();
}

// ── Stats update ──────────────────────────────────────────────────────────────
function updateStats() {
  const allStrokes = currentStroke ? [...strokes, currentStroke] : strokes;
  const totalPts   = allStrokes.reduce((s, st) => s + st.length, 0);
  const allPts     = allStrokes.flat();
  const avgPressure = allPts.length
    ? (allPts.reduce((s, p) => s + p.pressure, 0) / allPts.length).toFixed(2)
    : '—';
  const dur = sessionStart ? ((Date.now() - sessionStart) / 1000).toFixed(1) + 's' : '0s';

  statStrokes.textContent  = allStrokes.length;
  statPoints.textContent   = totalPts;
  statDuration.textContent = dur;
  statPressure.textContent = avgPressure;
}

// ── Pressure flat detection ───────────────────────────────────────────────────
function isPressureFlat(strks) {
  const all = strks.flat().map(p => p.pressure);
  if (all.length < 5) return false;
  const unique = new Set(all.map(p => p.toFixed(2)));
  const allHigh = all.every(p => p >= 0.98);
  return unique.size <= 2 || allHigh;
}

function checkPressureWarning() {
  if (isPressureFlat(strokes)) {
    pressureWarn.classList.remove('hidden');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FEATURE EXTRACTION ENGINE
// ═════════════════════════════════════════════════════════════════════════════

const safe = v => (isNaN(v) || !isFinite(v)) ? 0 : v;
const safeDivide = (n, d) => d === 0 ? 0 : safe(n / d);
const clamp01 = v => Math.max(0, Math.min(1, v));

// ── Spatial ───────────────────────────────────────────────────────────────────
function computeSpatial(strks) {
  const all = strks.flat();
  if (!all.length) return {};
  const xs = all.map(p => p.x), ys = all.map(p => p.y);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  const bw = maxX - minX, bh = maxY - minY;
  let totalLen = 0, totalDisp = 0, slantSum = 0, slantCnt = 0, curvSum = 0, curvCnt = 0;
  for (const stroke of strks) {
    if (stroke.length < 2) continue;
    let prevAngle = null, strokeLen = 0;
    for (let i = 1; i < stroke.length; i++) {
      const dx = stroke[i].x - stroke[i-1].x, dy = stroke[i].y - stroke[i-1].y;
      const seg = Math.hypot(dx, dy);
      strokeLen += seg;
      if (seg > 0) {
        const angle = Math.atan2(dy, dx);
        slantSum += angle; slantCnt++;
        if (prevAngle !== null) {
          let delta = Math.abs(angle - prevAngle);
          if (delta > Math.PI) delta = 2 * Math.PI - delta;
          curvSum += delta; curvCnt++;
        }
        prevAngle = angle;
      }
    }
    totalLen += strokeLen;
    const f = stroke[0], l = stroke[stroke.length-1];
    totalDisp += Math.hypot(l.x - f.x, l.y - f.y);
  }
  const comX = safe(xs.reduce((s,v)=>s+v,0)/xs.length);
  const comY = safe(ys.reduce((s,v)=>s+v,0)/ys.length);
  const endY = strks.filter(s=>s.length).map(s=>s[s.length-1].y);
  const meanEndY = safeDivide(endY.reduce((s,v)=>s+v,0), endY.length);
  const baselineDev = safe(Math.sqrt(safeDivide(endY.map(y=>(y-meanEndY)**2).reduce((s,v)=>s+v,0), endY.length)));
  return {
    stroke_length: safe(totalLen), bounding_width: safe(bw), bounding_height: safe(bh),
    aspect_ratio: safeDivide(bw,bh), mean_slant: safe(safeDivide(slantSum,slantCnt)),
    mean_curvature: safe(safeDivide(curvSum,curvCnt)), straightness: safeDivide(totalDisp,totalLen),
    writing_density: safeDivide(totalLen, bw*bh), baseline_deviation: baselineDev,
    center_of_mass_x: comX, center_of_mass_y: comY,
  };
}

// ── Temporal ──────────────────────────────────────────────────────────────────
function computeTemporal(strks) {
  if (!strks.length) return {};
  const sorted = [...strks].sort((a,b)=>a[0].t-b[0].t);
  const firstT = sorted[0][0].t, lastT = sorted[sorted.length-1].at(-1).t;
  const totalMs = lastT - firstT;
  let penDownMs = 0; const durations = [];
  for (const s of sorted) { const d = s.at(-1).t - s[0].t; penDownMs += d; durations.push(d); }
  const gaps = [];
  for (let i = 1; i < sorted.length; i++) gaps.push(sorted[i][0].t - sorted[i-1].at(-1).t);
  const pauses = gaps.filter(g => g >= 500);
  const meanDur = safeDivide(durations.reduce((s,v)=>s+v,0), durations.length);
  let rhythmReg = 1;
  if (durations.length >= 2 && meanDur > 0) {
    const variance = safeDivide(durations.map(d=>(d-meanDur)**2).reduce((s,v)=>s+v,0), durations.length);
    rhythmReg = clamp01(1 - safeDivide(Math.sqrt(variance), meanDur));
  }
  return {
    total_duration: safe(totalMs), pen_down_duration: safe(penDownMs),
    pen_down_ratio: safeDivide(penDownMs,totalMs), pause_count: pauses.length,
    mean_pause_duration: safe(safeDivide(pauses.reduce((s,v)=>s+v,0),pauses.length)),
    writing_tempo: safe(safeDivide(sorted.length, totalMs/1000)), rhythm_regularity: rhythmReg,
  };
}

// ── Dynamic ───────────────────────────────────────────────────────────────────
function computeDynamic(strks) {
  const allVel=[], allAcc=[], allJerk=[]; let totalLen=0, totalMs=0, dirChanges=0;
  for (const stroke of strks) {
    if (stroke.length < 2) continue;
    const vels = [];
    for (let i = 1; i < stroke.length; i++) {
      const dt = stroke[i].t - stroke[i-1].t; if (dt <= 0) continue;
      const dist = Math.hypot(stroke[i].x-stroke[i-1].x, stroke[i].y-stroke[i-1].y);
      vels.push(dist/dt); totalLen+=dist; totalMs+=dt;
    }
    allVel.push(...vels);
    const accs = [];
    for (let i = 1; i < vels.length; i++) {
      const dt = stroke[i < stroke.length-1 ? i : i-1+1].t - stroke[i-1].t || 1;
      accs.push(Math.abs(vels[i]-vels[i-1])/dt);
    }
    allAcc.push(...accs);
    for (let i = 1; i < accs.length; i++) allJerk.push(Math.abs(accs[i]-accs[i-1]));
    if (stroke.length >= 3) {
      let prev = Math.atan2(stroke[1].y-stroke[0].y, stroke[1].x-stroke[0].x);
      for (let i = 2; i < stroke.length; i++) {
        const a = Math.atan2(stroke[i].y-stroke[i-1].y, stroke[i].x-stroke[i-1].x);
        let delta = Math.abs(a-prev); if (delta > Math.PI) delta = 2*Math.PI-delta;
        if (delta > 0.3) dirChanges++; prev = a;
      }
    }
  }
  const mean = arr => safeDivide(arr.reduce((s,v)=>s+v,0), arr.length);
  const vari = arr => { const m=mean(arr); return safe(mean(arr.map(v=>(v-m)**2))); };
  const meanV = mean(allVel);
  const normJerk = allJerk.length ? safe(mean(allJerk)*(totalMs**2)/(totalLen||1)) : 0;
  let zeroCross = 0;
  for (let i=1; i<allVel.length; i++) if ((allVel[i]>meanV) !== (allVel[i-1]>meanV)) zeroCross++;
  return {
    mean_velocity: safe(meanV), max_velocity: safe(allVel.length?Math.max(...allVel):0),
    velocity_variance: safe(vari(allVel)), mean_acceleration: safe(mean(allAcc)),
    mean_jerk: safe(mean(allJerk)), normalized_jerk: safe(normJerk),
    direction_changes: dirChanges, tremor_frequency: safe(safeDivide(zeroCross,allVel.length)),
    tremor_amplitude: safe(Math.sqrt(vari(allVel))),
  };
}

// ── Irregularity index (weighted placeholder) ─────────────────────────────────
function computeIrregularityIndex(sp, tm, dy) {
  return clamp01(
    0.25 * clamp01(safeDivide(dy.normalized_jerk||0, 1e6)) +
    0.20 * (1 - clamp01(tm.rhythm_regularity||1)) +
    0.20 * clamp01(safeDivide(sp.baseline_deviation||0, 80)) +
    0.15 * clamp01(safeDivide(dy.velocity_variance||0, 0.5)) +
    0.12 * clamp01(safeDivide(dy.tremor_amplitude||0, 0.8)) +
    0.08 * clamp01(safeDivide(dy.direction_changes||0, 200))
  );
}

function classify(idx) {
  if (idx < 0.35) return 'Regular';
  if (idx < 0.60) return 'Mildly Irregular';
  return 'Irregular';
}

// ═════════════════════════════════════════════════════════════════════════════
// ANALYSIS PIPELINE
// ═════════════════════════════════════════════════════════════════════════════
async function runAnalysis() {
  if (!strokes.length) return;
  showSpinner('Extracting features…');
  btnAnalyze.disabled = true;
  await new Promise(r => setTimeout(r, 30));
  try {
    const spatial = computeSpatial(strokes), temporal = computeTemporal(strokes), dynamic = computeDynamic(strokes);
    const idx = computeIrregularityIndex(spatial, temporal, dynamic), cls = classify(idx);
    const flat = isPressureFlat(strokes);
    const features = { ...spatial, ...temporal, ...dynamic, irregularity_index: safe(idx), fluency_score: safe(1-idx) };
    hideSpinner();
    renderResults(features, idx, cls, flat);
    showView('results');
    saveToFirestore(features, idx, cls, flat);
  } catch (err) {
    hideSpinner(); showToast('Analysis error: ' + err.message, 'error');
    btnAnalyze.disabled = false; console.error(err);
  }
}

function generateUUID() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// FIRESTORE SAVE
// ═════════════════════════════════════════════════════════════════════════════
async function saveToFirestore(features, idx, cls, pressureFlat) {
  const saveBtn = document.getElementById('btn-save-status');
  const saveText = document.getElementById('save-status-text');
  try {
    const sessionId = generateUUID();
    await setDoc(doc(db, `users/${currentUser.uid}/sessions/${sessionId}`), {
      sessionId, userId: currentUser.uid, timestamp: serverTimestamp(),
      source: 'tablet', features, irregularityIndex: idx, classification: cls,
      strokeCount: strokes.length, totalPoints: strokes.reduce((s,st)=>s+st.length,0),
      pressureFlat,
    });
    saveText.textContent = '✅ Saved to cloud';
    saveBtn.disabled = false;
    showToast('Session saved!', 'success');
  } catch (err) {
    saveText.textContent = '❌ Save failed';
    saveBtn.disabled = false;
    showToast('Save error: ' + err.message, 'error');
    console.error(err);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESULTS RENDERING
// ═════════════════════════════════════════════════════════════════════════════
const GROUPS = [
  { title: '📐 Spatial', keys: ['stroke_length','bounding_width','bounding_height','aspect_ratio','mean_slant','mean_curvature','straightness','writing_density','baseline_deviation','center_of_mass_x','center_of_mass_y'] },
  { title: '⏱ Temporal', keys: ['total_duration','pen_down_duration','pen_down_ratio','pause_count','mean_pause_duration','writing_tempo','rhythm_regularity'] },
  { title: '⚡ Dynamic', keys: ['mean_velocity','max_velocity','velocity_variance','mean_acceleration','mean_jerk','normalized_jerk','direction_changes','tremor_frequency','tremor_amplitude'] },
  { title: '🎯 Scores',  keys: ['irregularity_index','fluency_score'] },
];
const NORM = { stroke_length:5000,bounding_width:800,bounding_height:600,aspect_ratio:5,mean_slant:3.14,mean_curvature:3.14,straightness:1,writing_density:0.1,baseline_deviation:100,center_of_mass_x:800,center_of_mass_y:600,total_duration:30000,pen_down_duration:20000,pen_down_ratio:1,pause_count:20,mean_pause_duration:3000,writing_tempo:5,rhythm_regularity:1,mean_velocity:2,max_velocity:10,velocity_variance:1,mean_acceleration:0.1,mean_jerk:0.01,normalized_jerk:1e6,direction_changes:200,tremor_frequency:1,tremor_amplitude:2,irregularity_index:1,fluency_score:1 };

function fmtVal(k, v) {
  if (k.includes('duration')) return v.toFixed(0)+' ms';
  if (k.includes('ratio')||k.includes('score')||k.includes('index')) return (v*100).toFixed(1)+'%';
  if (k.includes('velocity')||k.includes('jerk')||k.includes('accel')) return v.toExponential(2);
  return v.toFixed(4);
}

function renderResults(features, idx, cls, pressureFlat) {
  const scoreClass = idx < 0.35 ? 'regular' : idx < 0.60 ? 'mild' : 'irregular';
  document.getElementById('score-circle').className = `score-circle score-${scoreClass}`;
  document.getElementById('score-number').textContent = (idx*100).toFixed(0)+'%';
  const badge = document.getElementById('classification-badge');
  badge.className = `classification-badge badge-${scoreClass}`;
  badge.textContent = cls;
  document.getElementById('result-timestamp').textContent = new Date().toLocaleString();
  document.getElementById('result-pressure-note').textContent = pressureFlat ? '⚠ Pressure flat' : '✓ Pressure OK';

  const breakdown = document.getElementById('feature-breakdown');
  breakdown.innerHTML = '';
  for (const g of GROUPS) {
    const rows = g.keys.filter(k=>features[k]!==undefined).map(k => {
      const v = features[k], bar = clamp01(safeDivide(v, NORM[k]||1));
      return `<tr><td>${k.replace(/_/g,' ').replace(/^\w/,c=>c.toUpperCase())}</td>
        <td><span class="bar-wrap"><span class="bar-fill" style="width:${(bar*100).toFixed(0)}%"></span></span></td>
        <td>${fmtVal(k,v)}</td></tr>`;
    }).join('');
    if (!rows) continue;
    breakdown.insertAdjacentHTML('beforeend',
      `<details class="feature-group" open><summary>${g.title}</summary>
       <table class="feature-table"><tbody>${rows}</tbody></table></details>`);
  }
}

document.getElementById('btn-new-session').addEventListener('click', () => { clearCanvas(); showView('draw'); });
