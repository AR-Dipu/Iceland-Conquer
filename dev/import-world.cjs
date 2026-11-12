// Offline conversion of the already bundled, revision-pinned Natural Earth data.
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const source = JSON.parse(fs.readFileSync(path.join(__dirname, 'country_boundaries.geojson')));
const area = r => Math.abs(r.reduce((s,p,i)=>s+p[0]*r[(i+1)%r.length][1]-p[1]*r[(i+1)%r.length][0],0))/2;
function simplify(r,tolerance=.06) {
 const dist=(p,a,b)=>{let x=b[0]-a[0],y=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*x+(p[1]-a[1])*y)/(x*x+y*y||1)));return Math.hypot(p[0]-a[0]-t*x,p[1]-a[1]-t*y);};
 function rdp(p){let d=0,k=0;for(let i=1;i<p.length-1;i++){let n=dist(p[i],p[0],p.at(-1));if(n>d){d=n;k=i;}}return d>tolerance?[...rdp(p.slice(0,k+1)).slice(0,-1),...rdp(p.slice(k))]:[p[0],p.at(-1)];}
 let m=Math.floor(r.length/2);return [...rdp(r.slice(0,m+1)).slice(0,-1),...rdp([...r.slice(m),r[0]]).slice(0,-1)];
}
const entries=[], vertices=new Map();
for(const f of source.features){
 const p=f.properties, id=p.ADM0_A3.toLowerCase();
 if(p.CONTINENT==='Antarctica')continue;
 const raw=(f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates).map(p=>p[0].slice(0,-1));
 const rings=raw.filter(r=>r.length>=3).sort((a,b)=>area(b)-area(a));if(!rings.length)continue;
 let main=simplify(rings[0]);if(main.length<3)main=rings[0];
 const lat=p.LABEL_Y||0, cos=Math.max(.15,Math.cos(lat*Math.PI/180));
 const projected=main.map(v=>[v[0]*cos,-v[1]]), xs=projected.map(p=>p[0]),ys=projected.map(p=>p[1]);
 const x=Math.min(...xs),y=Math.min(...ys),scale=2400/Math.max(Math.max(...xs)-x,Math.max(...ys)-y);
 const normalize=r=>r.map(v=>[+( (v[0]*cos-x)*scale).toFixed(3),+((-v[1]-y)*scale).toFixed(3)]);
 const e={id,name:p.ADMIN||p.NAME,continent:p.CONTINENT,longitude:p.LABEL_X||0,latitude:lat,outline:normalize(main),decorative_islands:rings.slice(1,5).map(r=>normalize(simplify(r))),map_rings:rings.map(r=>simplify(r,.04)),neighbors:[],sea_neighbors:[]};
 entries.push(e);
 for(const r of raw)for(const v of r){const key=v.map(n=>n.toFixed(5)).join(',');if(!vertices.has(key))vertices.set(key,new Set());vertices.get(key).add(id);}
}
const byId=new Map(entries.map(e=>[e.id,e])), shared=new Map();
for(const set of vertices.values()){const a=[...set];for(let i=0;i<a.length;i++)for(let j=i+1;j<a.length;j++){let key=[a[i],a[j]].sort().join('|');shared.set(key,(shared.get(key)||0)+1);}}
function link(a,b,sea){for(const [u,v] of [[a,b],[b,a]]){if(!u.neighbors.includes(v.id))u.neighbors.push(v.id);if(sea&&!u.sea_neighbors.includes(v.id))u.sea_neighbors.push(v.id);}}
for(const [key,n] of shared)if(n>=2){let [a,b]=key.split('|');link(byId.get(a),byId.get(b),false);}
// Connect disconnected land components with fixed nearest-coast sea links.
function distance(a,b){let best=Infinity;for(const r of a.map_rings)for(const p of r)for(const s of b.map_rings)for(const q of s){let dx=Math.abs(p[0]-q[0]);dx=Math.min(dx,360-dx);const d=(dx*Math.cos((p[1]+q[1])*Math.PI/360))**2+(p[1]-q[1])**2;best=Math.min(best,d);}return best;}
const visited=new Set([entries[0].id]);
function flood(){let change=true;while(change){change=false;for(const id of [...visited])for(const n of byId.get(id).neighbors)if(!visited.has(n)){visited.add(n);change=true;}}}
flood();const sea=[];
while(visited.size<entries.length){let best=Infinity,pair;for(const a of entries)if(visited.has(a.id))for(const b of entries)if(!visited.has(b.id)){let d=distance(a,b);if(d<best){best=d;pair=[a,b];}}link(...pair,true);sea.push(pair.map(e=>e.id));flood();}
entries.sort((a,b)=>a.name.localeCompare(b.name));
fs.writeFileSync(path.join(root,'assets/maps/countries.json'),JSON.stringify(entries));
fs.writeFileSync(path.join(root,'assets/maps/world-routes.json'),JSON.stringify({description:'Fixed gameplay links chosen by nearest simplified coastline between disconnected land components. Not political borders.',sea_routes:sea,countries:entries.map(e=>({id:e.id,name:e.name,continent:e.continent}))},null,2));
console.log(`${entries.length} countries; ${sea.length} sea routes; graph connected`);
