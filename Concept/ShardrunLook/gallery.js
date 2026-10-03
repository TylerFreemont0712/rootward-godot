"use strict";
const design=JSON.parse(document.getElementById("design-data").textContent);
const $=id=>document.getElementById(id);
const set=(id,value)=>$(id).textContent=value;
function list(id,items){$(id).replaceChildren(...items.map(text=>{const li=document.createElement("li");li.textContent=text;return li;}));}
const tabs=$("ring-tabs"),grid=$("contact-grid");
let selectedRing=3;
const reduced=window.matchMedia("(prefers-reduced-motion: reduce)");
function showRing(number,focus=false){
 const ring=design.rings.find(r=>r.ring===number);selectedRing=number;
 for(const tab of tabs.children){const selected=Number(tab.dataset.ring)===number;tab.setAttribute("aria-selected",String(selected));tab.tabIndex=selected?0:-1;}
 $("arena-panel").setAttribute("aria-labelledby","ring-tab-"+number);
 $("arena-image").src=ring.file;$("arena-image").alt="Ring "+number+" · "+ring.name+": "+ring.forms;$("art-link").href=ring.file;
 set("arena-ring","RING "+number);set("arena-subtitle",ring.subtitle);set("arena-title",ring.name);set("arena-hook","“"+ring.hook+"”");set("arena-story",ring.story);set("arena-forms",ring.forms);
 list("arena-motion",ring.motion);set("arena-reaction",ring.reaction);list("arena-humour",ring.humour);set("arena-map","Map identity: "+ring.map);
 const spots=number===3?[["glow",54,15,10,18,0],["glow",26,23,8,15,2]]:number===2?[["glow",17,25,8,14,1],["drip",79.5,43,0,0,0],["drip",81.5,47,0,0,2]]:number===1?[["signal",51.7,28.7,4,7,0],["signal",54.5,28.7,4,7,2],["signal",57.5,28.7,4,7,4]]:[["core",50,42.5,12,21,0]];
 $("ambient").replaceChildren(...spots.map(([cls,x,y,w,h,delay])=>{const el=document.createElement("i");el.className=cls;el.style.left=x+"%";el.style.top=y+"%";if(w){el.style.width=w+"%";el.style.height=h+"%";el.style.transform="translate(-50%,-50%)";}el.style.animationDelay=delay+"s";return el;}));
 if(focus)$("ring-tab-"+number).focus();
}
for(const ring of design.rings){
 const tab=document.createElement("button");tab.type="button";tab.id="ring-tab-"+ring.ring;tab.dataset.ring=ring.ring;tab.setAttribute("role","tab");tab.setAttribute("aria-controls","arena-panel");tab.style.setProperty("--hue",ring.color);tab.append(document.createTextNode("RING "+ring.ring));const small=document.createElement("small");small.textContent=ring.name;tab.append(small);tab.addEventListener("click",()=>showRing(ring.ring));tabs.append(tab);
 const card=document.createElement("button");card.type="button";const img=document.createElement("img");img.src=ring.file;img.alt=ring.name+" environment thumbnail";img.loading="lazy";const caption=document.createElement("span");caption.textContent="RING "+ring.ring+" / "+ring.name;const sub=document.createElement("small");sub.textContent=ring.subtitle;caption.append(sub);card.append(img,caption);card.addEventListener("click",()=>{showRing(ring.ring);$("arenas").scrollIntoView({behavior:reduced.matches?"auto":"smooth"});});grid.append(card);
}
tabs.addEventListener("keydown",event=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(event.key))return;event.preventDefault();const rings=[3,2,1,0];let index=rings.indexOf(selectedRing);index=event.key==="Home"?0:event.key==="End"?3:(index+(event.key==="ArrowRight"?1:3))%4;showRing(rings[index],true);});
function stopMotion(){document.body.classList.remove("motion-on");$("motion").setAttribute("aria-pressed","false");$("motion").textContent=reduced.matches?"Ambient motion: reduced-motion setting":"Preview ambient motion: off";$("motion").disabled=reduced.matches;}
$("motion").addEventListener("click",()=>{const active=document.body.classList.toggle("motion-on");$("motion").setAttribute("aria-pressed",String(active));$("motion").textContent="Preview ambient motion: "+(active?"on":"off");});
reduced.addEventListener("change",stopMotion);stopMotion();showRing(3);
const nodes=[],edges=[],symbols={fight:"⚔",elite:"◆",rest:"☾",forge:"+",treasure:"□",boss:"▣"};
const positions=[[4,11,20],[27,35,44],[51,59,69],[76,83,93]];
for(const [index,ring] of design.rings.entries()){
 const [y0,y1,y2]=positions[index],base=ring.ring;
 nodes.push({id:base+"a",ring:base,x:50,y:y0,kind:"fight",name:index===0?"Entry process":"Process encounter"},{id:base+"b",ring:base,x:42,y:y1,kind:["rest","treasure","forge","rest"][index],name:["Sleep() alcove","Cache","Hot patch bench","Last sleep()"][index]},{id:base+"c",ring:base,x:61,y:y1,kind:"elite",name:"Exception handler"},{id:base+"d",ring:base,x:50,y:y2,kind:"boss",name:ring.gate});
 edges.push([base+"a",base+"b"],[base+"a",base+"c"],[base+"b",base+"d"],[base+"c",base+"d"]);if(base<3)edges.push([(base+1)+"d",base+"a"]);
}
let current="3a",inspected="3a",visited=new Set(["3a"]),traversed=new Set();
const nodeButtons=new Map(),paths=[];
function available(id){return edges.some(([from,to])=>from===current&&to===id);}
for(const [from,to] of edges){
 const a=nodes.find(n=>n.id===from),b=nodes.find(n=>n.id===to),path=document.createElementNS("http://www.w3.org/2000/svg","path");path.setAttribute("d","M "+(a.x*10)+" "+(a.y*5.628)+" L "+(b.x*10)+" "+(b.y*5.628));path.setAttribute("class","route-edge");$("route-lines").append(path);paths.push({from,to,path});
}
for(const node of nodes){const button=document.createElement("button");button.type="button";button.className="room-node";button.style.left=node.x+"%";button.style.top=node.y+"%";button.textContent=symbols[node.kind];button.addEventListener("click",()=>{inspected=node.id;drawMap();});nodeButtons.set(node.id,button);$("route-nodes").append(button);}
function drawMap(){
 for(const node of nodes){const button=nodeButtons.get(node.id);button.className="room-node"+(visited.has(node.id)?" visited":"")+(available(node.id)?" available":"")+(current===node.id?" current":"")+(inspected===node.id?" inspected":"");const status=current===node.id?"Current room":visited.has(node.id)?"Visited":available(node.id)?"Available next room":"Future room";button.setAttribute("aria-label","Ring "+node.ring+" · "+node.name+" · "+status);button.title="Ring "+node.ring+" · "+node.name+" · "+status;}
 for(const {from,to,path} of paths){path.setAttribute("class","route-edge"+(traversed.has(from+">"+to)?" visited":from===current?" available":""));}
 const node=nodes.find(n=>n.id===inspected),ring=design.rings.find(r=>r.ring===node.ring);
 set("node-title",node.name);set("node-ring","Ring "+node.ring+" · "+ring.name);
 const text={fight:"Enter a process encounter on the next landing.",elite:"A more dangerous exception handler occupies this branch.",rest:"A quiet alcove for sleep(), repairs and a little recovery.",forge:"Apply a hot patch at a workshop bench.",treasure:"Inspect a cache left in the Machine.",boss:"The guardian holds this permission boundary. Its exit leads down into the next ring."};
 set("node-description",node.id==="0d"?"The root boundary and final guardian. The square kernel lies at the bottom of the Machine.":text[node.kind]);
 set("node-state",node.id===current?"CURRENT ROOM · YOU ARE HERE":visited.has(node.id)?"VISITED":available(node.id)?"AVAILABLE · NEXT DESCENT":"FUTURE ROOM · REACH ITS PARENT FIRST");
 $("descend").disabled=!available(node.id);$("descend").textContent=node.id===current?"Current room":available(node.id)?"Descend here":visited.has(node.id)?"Already visited":"Continue the route to unlock";
}
$("descend").addEventListener("click",()=>{if(!available(inspected))return;traversed.add(current+">"+inspected);current=inspected;visited.add(current);drawMap();});
$("reset-map").addEventListener("click",()=>{current="3a";inspected="3a";visited=new Set(["3a"]);traversed=new Set();drawMap();});
drawMap();
for(const [key,label] of [["camera","Fixed camera"],["staging","Battle staging"],["readability","Readable fighters"],["layers","Separate the moving parts"],["motion","Motion budget"],["transition","A descent between rings"]]){
 const article=document.createElement("article"),h=document.createElement("h4"),p=document.createElement("p");h.textContent=label;p.textContent=design.production[key];article.append(h,p);$("production-notes").append(article);
}
set("scope",design.scope);
const capture=new URLSearchParams(location.search).get("capture");
if(capture==="map")document.body.classList.add("capture-map");
window.shardrunConcept={design,nodes,edges,get current(){return current;},get visited(){return [...visited];},showRing};

