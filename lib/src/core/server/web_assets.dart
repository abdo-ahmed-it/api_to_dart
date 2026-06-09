/// Static single-page web UI served by [ApiWebServer]. Vanilla HTML/CSS/JS —
/// no build step. Talks to the server over `GET /api/tree` and
/// `POST /api/generate`.
///
/// Kept as a Dart string constant so the package ships self-contained (no
/// asset files to resolve at runtime).
const String indexHtml = r'''<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>api2dart</title>
<style>
  :root{
    --bg:#0f172a; --panel:#1e293b; --ink:#e2e8f0; --muted:#94a3b8;
    --line:#334155; --accent:#38bdf8; --green:#22c55e; --red:#ef4444;
    --amber:#f59e0b; --code:#0b1220; --purple:#a78bfa;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  body{
    background:#020617;color:var(--ink);
    font-family:"Segoe UI",Tahoma,system-ui,sans-serif;
    min-height:100vh;padding:28px 20px;
  }
  .wrap{max-width:960px;margin:0 auto}
  header{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px;flex-wrap:wrap;gap:12px}
  h1{font-size:24px;font-weight:800}
  h1 .dot{color:var(--accent)}
  .src{color:var(--muted);font-size:14px}
  .src b{color:var(--ink)}
  .meta{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:18px}
  .chip{background:var(--panel);border:1px solid var(--line);border-radius:999px;
    padding:6px 14px;font-size:13px;color:var(--muted)}
  .chip b{color:var(--accent)}
  .toolbar{display:flex;gap:10px;align-items:center;margin-bottom:12px;flex-wrap:wrap}
  .btn{border:1px solid var(--line);background:var(--panel);color:var(--ink);
    padding:9px 16px;border-radius:10px;font-size:14px;font-weight:600;cursor:pointer;
    transition:.15s}
  .btn:hover{border-color:var(--accent)}
  .btn.primary{background:var(--accent);color:#04263a;border-color:var(--accent)}
  .btn.primary:hover{filter:brightness(1.08)}
  .btn:disabled{opacity:.5;cursor:not-allowed}
  .count{margin-left:auto;color:var(--muted);font-size:13px}
  .panel{background:var(--bg);border:1px solid var(--line);border-radius:14px;
    overflow:hidden;margin-bottom:18px}
  .folder{border-bottom:1px solid var(--line)}
  .folder:last-child{border-bottom:none}
  .folder-head{display:flex;align-items:center;gap:10px;padding:11px 16px;
    background:var(--panel);cursor:pointer;user-select:none;font-weight:600;font-size:14px}
  .folder-head .caret{color:var(--muted);transition:.15s;font-size:12px;width:12px}
  .folder-head.collapsed .caret{transform:rotate(-90deg)}
  .folder-head .fcount{color:var(--muted);font-weight:400;font-size:12px}
  .folder-head .fselect{margin-left:auto;color:var(--accent);font-size:12px;font-weight:600}
  .ep{display:flex;align-items:center;gap:12px;padding:10px 16px 10px 38px;
    border-top:1px solid var(--line);cursor:pointer;font-size:14px}
  .ep:hover{background:#162033}
  .ep input{width:16px;height:16px;accent-color:var(--accent);cursor:pointer}
  .method{font-family:monospace;font-size:11px;font-weight:700;padding:3px 8px;
    border-radius:6px;min-width:54px;text-align:center}
  .m-GET{background:#0e2a17;color:#86efac}
  .m-POST{background:#0c2336;color:#7dd3fc}
  .m-PUT{background:#2a230c;color:#fcd34d}
  .m-PATCH{background:#2a1c0c;color:#fdba74}
  .m-DELETE{background:#2a1212;color:#fca5a5}
  .ep .path{color:var(--muted);font-family:monospace;font-size:13px}
  .ep .nm{font-weight:600}
  .ep .lock{color:var(--amber);font-size:12px}
  .hidden{display:none}
  .results{background:var(--code);border:1px solid var(--line);border-radius:14px;padding:18px 20px}
  .results h2{font-size:16px;margin-bottom:12px}
  .res-row{display:flex;align-items:center;gap:10px;padding:6px 0;font-size:13px;font-family:monospace}
  .res-row .ok{color:var(--green)} .res-row .bad{color:var(--red)} .res-row .warn{color:var(--amber)}
  .res-path{color:var(--ink)} .res-sub{color:var(--muted)}
  .logbox{margin-top:14px;background:#060b16;border:1px solid var(--line);border-radius:10px;
    padding:12px 14px;font-family:monospace;font-size:12px;color:var(--muted);
    max-height:220px;overflow:auto;white-space:pre-wrap}
  .empty{color:var(--muted);text-align:center;padding:40px;font-size:14px}
  .spinner{display:inline-block;width:14px;height:14px;border:2px solid var(--line);
    border-top-color:var(--accent);border-radius:50%;animation:spin .7s linear infinite;vertical-align:-2px}
  @keyframes spin{to{transform:rotate(360deg)}}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>api2dart<span class="dot">.</span></h1>
    <div class="src">Source: <b id="sourceName">…</b></div>
  </header>

  <div class="meta" id="meta"></div>

  <div class="toolbar">
    <button class="btn" id="selectAll">Select all</button>
    <button class="btn" id="clearAll">Clear</button>
    <span class="count" id="selCount">0 selected</span>
  </div>

  <div class="panel" id="tree"><div class="empty">Loading endpoints…</div></div>

  <div class="toolbar">
    <button class="btn primary" id="generate" disabled>Generate</button>
    <span class="count" id="genHint"></span>
  </div>

  <div class="results hidden" id="results"></div>
</div>

<script>
const $ = (s,el=document)=>el.querySelector(s);
const $$ = (s,el=document)=>[...el.querySelectorAll(s)];
let TREE = null;

async function load(){
  const r = await fetch('/api/tree');
  TREE = await r.json();
  $('#sourceName').textContent = TREE.sourceName;
  $('#meta').innerHTML =
    `<span class="chip">Endpoints <b>${TREE.endpoints.length}</b></span>`+
    `<span class="chip">Mode <b>${TREE.mode}</b></span>`+
    `<span class="chip">Output <b>${TREE.outputDir}</b></span>`;
  renderTree();
}

function renderTree(){
  const groups = {};
  for(const ep of TREE.endpoints){
    const k = ep.folderPath || '(root)';
    (groups[k] ||= []).push(ep);
  }
  const tree = $('#tree');
  tree.innerHTML = '';
  for(const [folder, eps] of Object.entries(groups)){
    const f = document.createElement('div');
    f.className='folder';
    f.innerHTML =
      `<div class="folder-head"><span class="caret">▾</span>`+
      `<span>${esc(folder)}</span><span class="fcount">${eps.length}</span>`+
      `<span class="fselect" data-act="toggleFolder">select all</span></div>`;
    for(const ep of eps){
      const row = document.createElement('label');
      row.className='ep';
      row.innerHTML =
        `<input type="checkbox" data-idx="${ep.index}">`+
        `<span class="method m-${ep.method}">${ep.method}</span>`+
        `<span class="nm">${esc(ep.name)}</span>`+
        `<span class="path">${esc(ep.path)}</span>`+
        (ep.requiresAuth?`<span class="lock">🔒</span>`:``);
      f.appendChild(row);
    }
    tree.appendChild(f);
  }
  // folder collapse + per-folder select-all
  $$('.folder-head').forEach(h=>{
    h.addEventListener('click',e=>{
      if(e.target.dataset.act==='toggleFolder'){
        e.stopPropagation();
        const boxes = $$('input',h.parentElement);
        const allOn = boxes.every(b=>b.checked);
        boxes.forEach(b=>b.checked=!allOn);
        updateCount();
        return;
      }
      h.classList.toggle('collapsed');
      $$('.ep',h.parentElement).forEach(ep=>ep.classList.toggle('hidden'));
    });
  });
  $$('input[type=checkbox]').forEach(b=>b.addEventListener('change',updateCount));
  updateCount();
}

function selectedIdx(){return $$('input[type=checkbox]:checked').map(b=>+b.dataset.idx);}
function updateCount(){
  const n = selectedIdx().length;
  $('#selCount').textContent = `${n} selected`;
  $('#generate').disabled = n===0;
}

$('#selectAll').onclick=()=>{$$('input[type=checkbox]').forEach(b=>b.checked=true);updateCount();};
$('#clearAll').onclick=()=>{$$('input[type=checkbox]').forEach(b=>b.checked=false);updateCount();};

$('#generate').onclick=async()=>{
  const idx = selectedIdx();
  if(!idx.length) return;
  const btn=$('#generate');
  btn.disabled=true; btn.innerHTML='<span class="spinner"></span> Generating…';
  $('#genHint').textContent='';
  try{
    const r = await fetch('/api/generate',{
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({selectedIndexes:idx})
    });
    const data = await r.json();
    renderResults(data);
  }catch(err){
    renderResults({error:String(err)});
  }finally{
    btn.disabled=false; btn.textContent='Generate'; updateCount();
  }
};

function renderResults(d){
  const box=$('#results');
  box.classList.remove('hidden');
  if(d.error){
    box.innerHTML=`<h2>Error</h2><div class="res-row"><span class="bad">✗ ${esc(d.error)}</span></div>`;
    return;
  }
  let html=`<h2>Result — ${d.generated.length} generated`+
    (d.skipped.length?`, ${d.skipped.length} skipped`:``)+`</h2>`;
  for(const g of d.generated){
    const ok = g.status>=200 && g.status<300;
    html+=`<div class="res-row"><span class="${ok?'ok':'warn'}">${ok?'✓':'⚠'}</span>`+
      `<span class="res-path">${esc(g.file)}</span>`+
      `<span class="res-sub">(${g.status||'—'})</span></div>`;
  }
  for(const s of d.skipped){
    html+=`<div class="res-row"><span class="bad">✗</span>`+
      `<span class="res-path">${esc(s.name)}</span>`+
      `<span class="res-sub">${esc(s.reason)}</span></div>`;
  }
  if(d.logs && d.logs.length){
    html+=`<div class="logbox">${esc(d.logs.join('\n'))}</div>`;
  }
  box.innerHTML=html;
}

function esc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}

load().catch(e=>{$('#tree').innerHTML=`<div class="empty">Failed to load: ${esc(String(e))}</div>`;});
</script>
</body>
</html>''';
