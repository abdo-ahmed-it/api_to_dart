/// Static single-page web UI served by [ApiWebServer]. Vanilla HTML/CSS/JS —
/// no build step. An Apidog-like workspace: a sidebar tree (search + method
/// filter + checkboxes), a request builder with editable Params/Headers/Body/
/// Auth tabs and a Send (try-it) action, a live Response view, and a Code
/// preview tab. Talks to the server over:
///   GET  /api/tree
///   GET  /api/endpoint?index=N
///   GET  /api/preview?index=N
///   POST /api/try
///   POST /api/generate
///
/// Kept as a Dart string constant so the package ships self-contained.
const String indexHtml = r'''<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>api2dart</title>
<style>
  :root{
    --bg:#0b1120;--bg2:#0f172a;--panel:#161f33;--panel2:#1b2740;
    --ink:#e2e8f0;--muted:#94a3b8;--faint:#64748b;--line:#27324a;
    --accent:#38bdf8;--accent2:#0ea5e9;--green:#22c55e;--red:#ef4444;
    --amber:#f59e0b;--purple:#a78bfa;--code:#070d18;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html,body{height:100%}
  body{background:var(--bg);color:var(--ink);
    font-family:"Segoe UI",Tahoma,system-ui,sans-serif;font-size:14px;
    display:flex;flex-direction:column;overflow:hidden}
  button{font-family:inherit}
  .topbar{display:flex;align-items:center;gap:14px;padding:11px 18px;
    background:var(--bg2);border-bottom:1px solid var(--line);flex:0 0 auto}
  .logo{font-size:18px;font-weight:800}.logo .d{color:var(--accent)}
  .src{color:var(--muted);font-size:13px}.src b{color:var(--ink)}
  .top-meta{display:flex;gap:8px;margin-left:6px}
  .chip{background:var(--panel);border:1px solid var(--line);border-radius:999px;
    padding:4px 11px;font-size:12px;color:var(--muted)}.chip b{color:var(--accent)}
  .spacer{margin-left:auto}
  .btn{border:1px solid var(--line);background:var(--panel);color:var(--ink);
    padding:8px 15px;border-radius:9px;font-size:13px;font-weight:600;cursor:pointer;transition:.15s}
  .btn:hover{border-color:var(--accent)}
  .btn.primary{background:var(--accent);color:#04263a;border-color:var(--accent)}
  .btn.primary:hover{filter:brightness(1.08)}
  .btn.send{background:var(--green);color:#052e16;border-color:var(--green)}
  .btn:disabled{opacity:.45;cursor:not-allowed}
  .selinfo{color:var(--muted);font-size:13px}

  .main{flex:1;display:flex;min-height:0}
  /* sidebar */
  .side{width:340px;flex:0 0 auto;background:var(--bg2);border-right:1px solid var(--line);
    display:flex;flex-direction:column;min-height:0}
  .side-tools{padding:12px;border-bottom:1px solid var(--line);display:flex;flex-direction:column;gap:9px}
  .search{width:100%;background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:9px;padding:9px 12px;font-size:13px;outline:none}
  .search:focus{border-color:var(--accent)}
  .filters{display:flex;gap:5px;flex-wrap:wrap}
  .mf{font-family:monospace;font-size:11px;font-weight:700;padding:4px 9px;border-radius:7px;
    cursor:pointer;border:1px solid var(--line);background:var(--panel);color:var(--muted);user-select:none}
  .mf.on{color:var(--ink);border-color:var(--accent)}
  .mf.on.m-GET{background:#0e2a17}.mf.on.m-POST{background:#0c2336}
  .mf.on.m-PUT{background:#2a230c}.mf.on.m-PATCH{background:#2a1c0c}.mf.on.m-DELETE{background:#2a1212}
  .side-actions{display:flex;gap:7px;align-items:center}
  .selall{display:flex;align-items:center;gap:7px;cursor:pointer;user-select:none;
    color:var(--accent);font-size:12px;font-weight:600}
  .selall input{width:15px;height:15px;accent-color:var(--accent);cursor:pointer}
  .link{background:none;border:none;color:var(--accent);font-size:12px;cursor:pointer;padding:2px 4px;font-weight:600}
  .tree{flex:1;overflow:auto;padding:6px 0}
  .folder-head{display:flex;align-items:center;gap:8px;padding:8px 14px;cursor:pointer;
    user-select:none;font-weight:600;font-size:12.5px;color:var(--muted)}
  .folder-head:hover{color:var(--ink)}
  .folder-head .folder-box{width:14px;height:14px;accent-color:var(--accent);cursor:pointer;flex:0 0 auto}
  .folder-head .caret{font-size:10px;width:10px;transition:.15s}
  .folder-head.collapsed .caret{transform:rotate(-90deg)}
  .folder-head .fc{margin-left:auto;font-weight:400;font-size:11px;color:var(--faint)}
  .ep{display:flex;align-items:center;gap:9px;padding:7px 14px 7px 26px;cursor:pointer;
    border-left:2px solid transparent}
  .ep:hover{background:var(--panel)}
  .ep.active{background:var(--panel2);border-left-color:var(--accent)}
  .ep input{width:15px;height:15px;accent-color:var(--accent);cursor:pointer;flex:0 0 auto}
  .method{font-family:monospace;font-size:10px;font-weight:700;padding:2px 6px;border-radius:5px;
    min-width:48px;text-align:center;flex:0 0 auto}
  .m-GET{background:#0e2a17;color:#86efac}.m-POST{background:#0c2336;color:#7dd3fc}
  .m-PUT{background:#2a230c;color:#fcd34d}.m-PATCH{background:#2a1c0c;color:#fdba74}
  .m-DELETE{background:#2a1212;color:#fca5a5}
  .ep .nm{font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .ep .lock{color:var(--amber);font-size:11px;margin-left:auto;flex:0 0 auto}
  .empty{color:var(--faint);text-align:center;padding:30px 16px;font-size:13px}

  /* detail */
  .detail{flex:1;display:flex;flex-direction:column;min-width:0;background:var(--bg)}
  .blank{flex:1;display:flex;align-items:center;justify-content:center;color:var(--faint);font-size:14px}
  .reqline{display:flex;gap:9px;padding:14px 18px;border-bottom:1px solid var(--line);align-items:center}
  .reqline select{background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:8px;padding:8px 10px;font-family:monospace;font-weight:700;font-size:12px;outline:none}
  .reqline .url{flex:1;background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:8px;padding:8px 12px;font-family:monospace;font-size:12.5px;outline:none}
  .reqline .url:focus{border-color:var(--accent)}
  .epname{padding:10px 18px 0;font-weight:700;font-size:15px}
  .epdesc{padding:2px 18px 0;color:var(--muted);font-size:12.5px}
  .tabs{display:flex;gap:2px;padding:10px 18px 0;border-bottom:1px solid var(--line)}
  .tab{padding:8px 14px;font-size:13px;font-weight:600;color:var(--muted);cursor:pointer;
    border-bottom:2px solid transparent;user-select:none}
  .tab:hover{color:var(--ink)}
  .tab.on{color:var(--accent);border-bottom-color:var(--accent)}
  .tab .badge{background:var(--panel2);color:var(--muted);font-size:10px;padding:1px 6px;border-radius:8px;margin-left:5px}
  .tabwrap{flex:1;overflow:auto;padding:14px 18px}
  .pane{display:none}.pane.on{display:block}
  table.kv{width:100%;border-collapse:collapse}
  table.kv td{padding:4px 4px}
  table.kv input{width:100%;background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:7px;padding:7px 10px;font-size:12.5px;font-family:monospace;outline:none}
  table.kv input:focus{border-color:var(--accent)}
  table.kv td.del{width:30px;text-align:center}
  .icon-btn{background:none;border:none;color:var(--faint);cursor:pointer;font-size:15px;padding:2px 6px}
  .icon-btn:hover{color:var(--red)}
  .addrow{margin-top:8px;color:var(--accent);background:none;border:1px dashed var(--line);
    border-radius:8px;padding:7px 12px;font-size:12.5px;cursor:pointer;font-weight:600}
  .addrow:hover{border-color:var(--accent)}
  .bodybar{display:flex;gap:8px;margin-bottom:10px;align-items:center}
  .bodybar select{background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:7px;padding:6px 9px;font-size:12px;outline:none}
  textarea.raw{width:100%;min-height:200px;background:var(--code);border:1px solid var(--line);
    color:#cbd5e1;border-radius:9px;padding:12px;font-family:"SF Mono",Menlo,monospace;
    font-size:12.5px;line-height:1.6;outline:none;resize:vertical}
  .authrow{display:flex;gap:9px;align-items:center;margin-bottom:10px}
  .authrow select,.authrow input{background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:8px;padding:8px 11px;font-size:12.5px;outline:none}
  .authrow input{flex:1;font-family:monospace}
  pre.code{background:var(--code);border:1px solid var(--line);border-radius:9px;padding:14px 16px;
    font-family:"SF Mono",Menlo,monospace;font-size:12.5px;line-height:1.65;color:#cbd5e1;
    overflow:auto;white-space:pre;max-height:100%}
  .codehead{display:flex;align-items:center;gap:10px;margin-bottom:10px}
  .codehead .fn{font-family:monospace;font-size:12.5px;color:var(--accent)}

  /* response */
  .resp{flex:0 0 auto;max-height:42%;display:flex;flex-direction:column;border-top:1px solid var(--line);background:var(--bg2)}
  .resp-head{display:flex;align-items:center;gap:12px;padding:10px 18px;border-bottom:1px solid var(--line)}
  .resp-head .ttl{font-weight:700;font-size:13px}
  .status{font-family:monospace;font-weight:700;font-size:12px;padding:3px 9px;border-radius:6px}
  .status.ok{background:#0e2a17;color:#86efac}.status.bad{background:#2a1212;color:#fca5a5}
  .status.warn{background:#2a230c;color:#fcd34d}
  .resp-meta{color:var(--muted);font-size:12px}
  .resp-body{flex:1;overflow:auto;padding:0}
  .resp-body pre{padding:14px 18px;font-family:"SF Mono",Menlo,monospace;font-size:12.5px;
    line-height:1.6;color:#cbd5e1;white-space:pre-wrap;word-break:break-word}
  .resp-empty{color:var(--faint);padding:20px 18px;font-size:13px}
  .spinner{display:inline-block;width:13px;height:13px;border:2px solid var(--line);
    border-top-color:var(--accent);border-radius:50%;animation:spin .7s linear infinite;vertical-align:-2px}
  @keyframes spin{to{transform:rotate(360deg)}}
  /* generate results modal-ish panel */
  .genres{position:fixed;right:18px;bottom:18px;width:420px;max-height:60vh;overflow:auto;
    background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px 18px;
    box-shadow:0 20px 50px rgba(0,0,0,.5);z-index:50}
  .genres h3{font-size:14px;margin-bottom:10px;display:flex;align-items:center}
  .genres .x{margin-left:auto;cursor:pointer;color:var(--muted);background:none;border:none;font-size:16px}
  .gr-row{display:flex;gap:8px;padding:4px 0;font-size:12px;font-family:monospace}
  .gr-row .ok{color:var(--green)}.gr-row .bad{color:var(--red)}.gr-row .warn{color:var(--amber)}
  .gr-sub{color:var(--muted)}
  .hidden{display:none!important}
</style>
</head>
<body>
<div class="topbar">
  <span class="logo">api2dart<span class="d">.</span></span>
  <span class="src">Source: <b id="sourceName">…</b></span>
  <div class="top-meta" id="topMeta"></div>
  <span class="spacer"></span>
  <span class="selinfo" id="selInfo">0 selected</span>
  <button class="btn primary" id="generate" disabled>Generate selected</button>
</div>

<div class="main">
  <aside class="side">
    <div class="side-tools">
      <input class="search" id="search" placeholder="Search endpoints…" autocomplete="off">
      <div class="filters" id="filters"></div>
      <div class="side-actions">
        <label class="selall"><input type="checkbox" id="selectAllBox"><span id="selectAllLabel">Select all</span></label>
        <span class="fc" id="visCount" style="margin-left:auto;color:var(--faint);font-size:11px"></span>
      </div>
    </div>
    <div class="tree" id="tree"><div class="empty">Loading…</div></div>
  </aside>

  <section class="detail">
    <div class="blank" id="blank">← Select an endpoint to inspect, edit, send, or preview its code.</div>

    <div class="hidden" id="builder" style="flex:1;display:flex;flex-direction:column;min-height:0">
      <div class="epname" id="epName"></div>
      <div class="epdesc" id="epDesc"></div>
      <div class="reqline">
        <select id="mMethod"></select>
        <input class="url" id="mUrl" placeholder="https://api.example.com/path">
        <button class="btn send" id="send">Send</button>
      </div>
      <div class="tabs" id="tabs">
        <div class="tab on" data-pane="params">Params <span class="badge" id="bParams">0</span></div>
        <div class="tab" data-pane="headers">Headers <span class="badge" id="bHeaders">0</span></div>
        <div class="tab" data-pane="body">Body</div>
        <div class="tab" data-pane="auth">Auth</div>
        <div class="tab" data-pane="code">Code</div>
      </div>
      <div class="tabwrap">
        <div class="pane on" id="pane-params"></div>
        <div class="pane" id="pane-headers"></div>
        <div class="pane" id="pane-body">
          <div class="bodybar">
            <select id="bodyKind">
              <option value="none">No body</option>
              <option value="raw">raw (JSON)</option>
              <option value="formdata">form-data</option>
              <option value="urlencoded">x-www-form-urlencoded</option>
            </select>
          </div>
          <textarea class="raw hidden" id="bodyRaw" placeholder='{ "key": "value" }'></textarea>
          <div id="bodyFields" class="hidden"></div>
        </div>
        <div class="pane" id="pane-auth">
          <div class="authrow">
            <select id="authType">
              <option value="none">No auth</option>
              <option value="bearer">Bearer</option>
              <option value="basic">Basic</option>
              <option value="apiKey">API key</option>
            </select>
            <input id="authToken" placeholder="token / value" class="hidden">
          </div>
          <div class="epdesc" style="padding:0">Auth is sent as a header when you press Send.</div>
        </div>
        <div class="pane" id="pane-code">
          <div class="codehead"><span class="fn" id="codeFile"></span>
            <button class="btn" id="copyCode" style="margin-left:auto;padding:5px 11px;font-size:12px">Copy</button></div>
          <pre class="code" id="codeBox">Select the Code tab to preview…</pre>
        </div>
      </div>
    </div>

    <div class="resp hidden" id="resp">
      <div class="resp-head">
        <span class="ttl">Response</span>
        <span id="respStatus"></span>
        <span class="resp-meta" id="respMeta"></span>
        <span class="spacer" style="margin-left:auto"></span>
        <button class="link" id="respClose">hide</button>
      </div>
      <div class="resp-body" id="respBody"></div>
    </div>
  </section>
</div>

<div class="genres hidden" id="genres"></div>

<script>
const $=(s,el=document)=>el.querySelector(s);
const $$=(s,el=document)=>[...el.querySelectorAll(s)];
const METHODS=['GET','POST','PUT','PATCH','DELETE'];
let TREE=null, CUR=null, activeFilters=new Set();

function esc(s){return String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}

async function jget(u){const r=await fetch(u);return r.json();}
async function jpost(u,b){const r=await fetch(u,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)});return r.json();}

async function load(){
  TREE=await jget('/api/tree');
  $('#sourceName').textContent=TREE.sourceName;
  $('#topMeta').innerHTML=
    `<span class="chip">Endpoints <b>${TREE.endpoints.length}</b></span>`+
    `<span class="chip">Mode <b>${TREE.mode}</b></span>`+
    `<span class="chip">Out <b>${esc(TREE.outputDir)}</b></span>`;
  // method filters
  $('#filters').innerHTML=METHODS.map(m=>`<span class="mf m-${m}" data-m="${m}">${m}</span>`).join('');
  $$('.mf').forEach(f=>f.onclick=()=>{const m=f.dataset.m;
    if(activeFilters.has(m)){activeFilters.delete(m);f.classList.remove('on');}
    else{activeFilters.add(m);f.classList.add('on');}renderTree();});
  // populate method dropdown
  $('#mMethod').innerHTML=METHODS.map(m=>`<option value="${m}">${m}</option>`).join('');
  renderTree();
}

function filtered(){
  const q=$('#search').value.trim().toLowerCase();
  return TREE.endpoints.filter(ep=>{
    if(activeFilters.size && !activeFilters.has(ep.method))return false;
    if(q && !(`${ep.name} ${ep.path} ${ep.method}`.toLowerCase().includes(q)))return false;
    return true;
  });
}

function renderTree(){
  const eps=filtered();
  $('#visCount').textContent=`${eps.length} shown`;
  syncMaster();
  const groups={};
  for(const ep of eps){const k=ep.folderPath||'(root)';(groups[k]||=[]).push(ep);}
  const tree=$('#tree');
  if(!eps.length){tree.innerHTML='<div class="empty">No endpoints match.</div>';return;}
  tree.innerHTML='';
  for(const [folder,list] of Object.entries(groups)){
    const f=document.createElement('div');
    const idxs=list.map(ep=>ep.index);
    f.innerHTML=`<div class="folder-head"><input type="checkbox" class="folder-box" title="Select all in this folder">`+
      `<span class="caret">▾</span><span>${esc(folder)}</span><span class="fc">${list.length}</span></div>`;
    const fbox=f.querySelector('.folder-box');
    // toggling the folder box selects/deselects all rows inside it
    fbox.onclick=e=>{
      e.stopPropagation();
      const on=e.target.checked;
      idxs.forEach(i=>on?SELECTED.add(i):SELECTED.delete(i));
      $$('.ep input',f).forEach(b=>b.checked=on);
      updateSel();
    };
    for(const ep of list){
      const row=document.createElement('div');
      row.className='ep'+(CUR===ep.index?' active':'');
      row.dataset.idx=ep.index;
      row.innerHTML=
        `<input type="checkbox" data-idx="${ep.index}" ${SELECTED.has(ep.index)?'checked':''}>`+
        `<span class="method m-${ep.method}">${ep.method}</span>`+
        `<span class="nm" title="${esc(ep.path)}">${esc(ep.name)}</span>`+
        (ep.requiresAuth?`<span class="lock">🔒</span>`:``);
      row.querySelector('input').onclick=e=>{
        e.stopPropagation();
        toggleSel(ep.index,e.target.checked);
        syncFolderBox(fbox,idxs);
      };
      row.onclick=()=>openEndpoint(ep.index);
      f.appendChild(row);
    }
    syncFolderBox(fbox,idxs);
    f.querySelector('.folder-head').onclick=()=>{
      const head=f.querySelector('.folder-head');head.classList.toggle('collapsed');
      $$('.ep',f).forEach(e=>e.classList.toggle('hidden'));
    };
    tree.appendChild(f);
  }
}

// Reflect a folder's selection state on its header checkbox:
// checked = all in folder selected, indeterminate = some, empty = none.
function syncFolderBox(box,idxs){
  const sel=idxs.filter(i=>SELECTED.has(i)).length;
  box.checked=idxs.length>0 && sel===idxs.length;
  box.indeterminate=sel>0 && sel<idxs.length;
}

const SELECTED=new Set();
function toggleSel(idx,on){on?SELECTED.add(idx):SELECTED.delete(idx);updateSel();}
function updateSel(){
  $('#selInfo').textContent=`${SELECTED.size} selected`;
  $('#generate').disabled=SELECTED.size===0;
  syncMaster();
}
// Reflect the visible selection state on the master checkbox:
// checked = all visible selected, indeterminate = some, empty = none.
function syncMaster(){
  const box=$('#selectAllBox');if(!box)return;
  const vis=filtered();
  const sel=vis.filter(ep=>SELECTED.has(ep.index)).length;
  box.checked=vis.length>0 && sel===vis.length;
  box.indeterminate=sel>0 && sel<vis.length;
  $('#selectAllLabel').textContent=box.checked?'Deselect all':'Select all';
}
// master checkbox: toggles all currently-visible (filtered) endpoints
$('#selectAllBox').onclick=()=>{
  const vis=filtered();
  const allOn=vis.length>0 && vis.every(ep=>SELECTED.has(ep.index));
  if(allOn)vis.forEach(ep=>SELECTED.delete(ep.index));
  else vis.forEach(ep=>SELECTED.add(ep.index));
  renderTree();updateSel();
};
$('#search').oninput=renderTree;

// ---- endpoint detail / request builder ----
async function openEndpoint(idx){
  CUR=idx;
  $$('.ep').forEach(e=>e.classList.toggle('active',+e.dataset.idx===idx));
  $('#blank').classList.add('hidden');
  $('#builder').classList.remove('hidden');
  const d=await jget('/api/endpoint?index='+idx);
  $('#epName').textContent=d.name;
  $('#epDesc').textContent=d.description||'';
  $('#mMethod').value=d.method;
  $('#mUrl').value=d.url;
  renderKv('#pane-params',d.queryParams,'bParams');
  renderKv('#pane-headers',d.headers,'bHeaders');
  // body
  const kind=d.body.kind||'none';
  $('#bodyKind').value=kind;
  $('#bodyRaw').value=d.body.raw||'';
  renderBodyFields(d.body.fields||[]);
  syncBodyUI();
  // auth
  $('#authType').value=d.auth.type||'none';
  $('#authToken').value=d.auth.token||'';
  syncAuthUI();
  // reset code/preview lazily
  $('#codeBox').textContent='Select the Code tab to preview…';
  switchTab('params');
}

function renderKv(sel,list,badgeId){
  const wrap=$(sel);
  wrap.innerHTML='';
  const t=document.createElement('table');t.className='kv';
  const tb=document.createElement('tbody');t.appendChild(tb);
  (list||[]).forEach(kv=>tb.appendChild(kvRow(kv.key,kv.value)));
  wrap.appendChild(t);
  const add=document.createElement('button');add.className='addrow';add.textContent='+ Add row';
  add.onclick=()=>{tb.appendChild(kvRow('',''));updateBadges();};
  wrap.appendChild(add);
  if(badgeId)updateBadges();
}
function kvRow(k,v){
  const tr=document.createElement('tr');
  tr.innerHTML=`<td><input placeholder="key" value="${esc(k)}"></td>`+
    `<td><input placeholder="value" value="${esc(v)}"></td>`+
    `<td class="del"><button class="icon-btn">✕</button></td>`;
  tr.querySelector('.icon-btn').onclick=()=>{tr.remove();updateBadges();};
  tr.querySelectorAll('input').forEach(i=>i.oninput=updateBadges);
  return tr;
}
function collectKv(sel){
  return $$(`${sel} tr`).map(tr=>{const i=tr.querySelectorAll('input');
    return{key:i[0].value,value:i[1].value};}).filter(x=>x.key.trim());
}
function updateBadges(){
  $('#bParams').textContent=collectKv('#pane-params').length;
  $('#bHeaders').textContent=collectKv('#pane-headers').length;
}

function renderBodyFields(fields){
  const wrap=$('#bodyFields');wrap.innerHTML='';
  const t=document.createElement('table');t.className='kv';const tb=document.createElement('tbody');t.appendChild(tb);
  (fields.length?fields:[{key:'',value:''}]).forEach(f=>tb.appendChild(kvRow(f.key,f.value)));
  wrap.appendChild(t);
  const add=document.createElement('button');add.className='addrow';add.textContent='+ Add field';
  add.onclick=()=>tb.appendChild(kvRow('',''));
  wrap.appendChild(add);
}
function syncBodyUI(){
  const k=$('#bodyKind').value;
  $('#bodyRaw').classList.toggle('hidden',k!=='raw');
  $('#bodyFields').classList.toggle('hidden',!(k==='formdata'||k==='urlencoded'));
}
$('#bodyKind').onchange=syncBodyUI;
function syncAuthUI(){$('#authToken').classList.toggle('hidden',$('#authType').value==='none');}
$('#authType').onchange=syncAuthUI;

// tabs
$$('.tab').forEach(t=>t.onclick=()=>switchTab(t.dataset.pane));
function switchTab(name){
  $$('.tab').forEach(t=>t.classList.toggle('on',t.dataset.pane===name));
  $$('.pane').forEach(p=>p.classList.toggle('on',p.id==='pane-'+name));
  if(name==='code')loadPreview();
}

async function loadPreview(){
  if(CUR==null)return;
  $('#codeBox').textContent='Generating…';
  const d=await jget('/api/preview?index='+CUR);
  $('#codeFile').textContent=d.fileName;
  $('#codeBox').textContent=d.code;
}
$('#copyCode').onclick=()=>navigator.clipboard.writeText($('#codeBox').textContent);

// ---- send (try it) ----
function currentBody(){
  const k=$('#bodyKind').value;
  if(k==='none')return{kind:null};
  if(k==='raw')return{kind:'raw',raw:$('#bodyRaw').value};
  return{kind:k,fields:collectKv('#bodyFields')};
}
function applyAuthHeader(headers){
  const t=$('#authType').value, tok=$('#authToken').value.trim();
  if(t==='none'||!tok)return headers;
  if(t==='bearer')headers.push({key:'Authorization',value:'Bearer '+tok});
  else if(t==='basic')headers.push({key:'Authorization',value:'Basic '+tok});
  else if(t==='apiKey')headers.push({key:'X-Api-Key',value:tok});
  return headers;
}
$('#send').onclick=async()=>{
  if(CUR==null)return;
  const btn=$('#send');btn.disabled=true;btn.innerHTML='<span class="spinner"></span>';
  $('#resp').classList.remove('hidden');
  $('#respStatus').innerHTML='';$('#respMeta').textContent='Sending…';
  $('#respBody').innerHTML='<div class="resp-empty">Waiting for response…</div>';
  try{
    const res=await jpost('/api/try',{
      url:$('#mUrl').value,method:$('#mMethod').value,
      headers:applyAuthHeader(collectKv('#pane-headers')),
      queryParams:collectKv('#pane-params'),
      body:currentBody()
    });
    renderResponse(res);
  }catch(e){renderResponse({ok:false,error:String(e)});}
  finally{btn.disabled=false;btn.textContent='Send';}
};
function renderResponse(res){
  if(!res.ok){
    $('#respStatus').innerHTML=`<span class="status bad">failed</span>`;
    $('#respMeta').textContent='';
    $('#respBody').innerHTML=`<div class="resp-empty">${esc(res.error||'Request failed')}</div>`;
    return;
  }
  const cls=res.status>=200&&res.status<300?'ok':(res.status>=400?'bad':'warn');
  $('#respStatus').innerHTML=`<span class="status ${cls}">${res.status}</span>`;
  $('#respMeta').textContent=`${res.timeMs} ms`;
  let body=res.body;
  try{body=JSON.stringify(JSON.parse(res.body),null,2);}catch(_){}
  $('#respBody').innerHTML=`<pre>${esc(body)}</pre>`;
}
$('#respClose').onclick=()=>$('#resp').classList.add('hidden');

// ---- generate selected ----
$('#generate').onclick=async()=>{
  if(!SELECTED.size)return;
  const btn=$('#generate');btn.disabled=true;btn.innerHTML='<span class="spinner"></span> Generating…';
  try{
    const d=await jpost('/api/generate',{selectedIndexes:[...SELECTED]});
    showGenResults(d);
  }catch(e){showGenResults({error:String(e)});}
  finally{btn.disabled=false;btn.textContent='Generate selected';updateSel();}
};
function showGenResults(d){
  const box=$('#genres');box.classList.remove('hidden');
  if(d.error){box.innerHTML=`<h3>Error<button class="x">✕</button></h3><div class="gr-row"><span class="bad">✗ ${esc(d.error)}</span></div>`;}
  else{
    let h=`<h3>Generated ${d.generated.length}`+(d.skipped.length?`, skipped ${d.skipped.length}`:``)+`<button class="x">✕</button></h3>`;
    for(const g of d.generated)h+=`<div class="gr-row"><span class="ok">✓</span><span>${esc(g.file)}</span></div>`;
    for(const s of d.skipped)h+=`<div class="gr-row"><span class="bad">✗</span><span>${esc(s.name)}</span><span class="gr-sub">${esc(s.reason)}</span></div>`;
    box.innerHTML=h;
  }
  box.querySelector('.x').onclick=()=>box.classList.add('hidden');
}

// keyboard: "/" focuses search, Ctrl/Cmd+Enter sends the current request
document.addEventListener('keydown',e=>{
  if(e.key==='/' && document.activeElement.tagName!=='INPUT' && document.activeElement.tagName!=='TEXTAREA'){
    e.preventDefault();$('#search').focus();
  }
  if((e.metaKey||e.ctrlKey) && e.key==='Enter' && CUR!=null){e.preventDefault();$('#send').click();}
});

load().catch(e=>{$('#tree').innerHTML=`<div class="empty">Failed to load: ${esc(String(e))}</div>`;});
</script>
</body>
</html>''';
