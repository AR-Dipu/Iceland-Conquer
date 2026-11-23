// Presentation-only geographic context from the pinned bundled source.
// Does not rewrite countries.json or any playable geometry.
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
const features=JSON.parse(fs.readFileSync(path.join(__dirname,'country_boundaries.geojson'))).features;
const countries=JSON.parse(fs.readFileSync(path.join(root,'assets/maps/countries.json')));
const {connectedRings}=require('./connected-land.cjs');
function simplify(r,t=.06){
 const dist=(p,a,b)=>{let x=b[0]-a[0],y=b[1]-a[1],u=Math.max(0,Math.min(1,((p[0]-a[0])*x+(p[1]-a[1])*y)/(x*x+y*y||1)));return Math.hypot(p[0]-a[0]-u*x,p[1]-a[1]-u*y);};
 function split(p){let d=0,k=0;for(let i=1;i<p.length-1;i++){let n=dist(p[i],p[0],p.at(-1));if(n>d){d=n;k=i;}}return d>t?[...split(p.slice(0,k+1)).slice(0,-1),...split(p.slice(k))]:[p[0],p.at(-1)];}
 let m=Math.floor(r.length/2);const out=[...split(r.slice(0,m+1)).slice(0,-1),...split([...r.slice(m),r[0]]).slice(0,-1)];return out.length>=3?out:r;
}
const key=p=>p.map(x=>x.toFixed(5)).join(',');
const edge=(a,b)=>[key(a),key(b)].sort().join('|');
const owners=new Map(), data=new Map();
for(const f of features){
 const id=f.properties.ADM0_A3.toLowerCase();
 const rings=(f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates).map(p=>p[0].slice(0,-1)).filter(r=>r.length>=3);
 data.set(id,{f,rings,main:connectedRings(rings)[0]});
 for(const r of rings)for(let i=0;i<r.length;i++){const k=edge(r[i],r[(i+1)%r.length]);if(!owners.has(k))owners.set(k,new Set());owners.get(k).add(id);}
}
const result={source:'Bundled pinned Natural Earth; presentation only',countries:{}};
for(const c of countries){
 const item=data.get(c.id);if(!item)continue;
 const main=simplify(item.main),cos=Math.max(.15,Math.cos(c.latitude*Math.PI/180));
 const xs=main.map(p=>p[0]*cos),ys=main.map(p=>-p[1]),x=Math.min(...xs),y=Math.min(...ys),scale=2400/Math.max(Math.max(...xs)-x,Math.max(...ys)-y);
 const project=(p,wrap=0)=>[+(((p[0]+wrap)*cos-x)*scale).toFixed(3),+((-p[1]-y)*scale).toFixed(3)];
 const maxx=Math.max(...c.outline.map(p=>p[0])),maxy=Math.max(...c.outline.map(p=>p[1]));
 const visible=r=>{const xx=r.map(p=>p[0]),yy=r.map(p=>p[1]);return Math.max(...xx)>=-1400&&Math.min(...xx)<=maxx+1400&&Math.max(...yy)>=-1400&&Math.min(...yy)<=maxy+1400;};
 const lands=[];
 for(const other of countries){if(other.id===c.id)continue;const source=data.get(other.id);if(!source)continue;
  for(const wrap of [-360,0,360])for(const raw of source.rings){const ring=simplify(raw).map(p=>project(p,wrap));if(visible(ring))lands.push({id:other.id,name:other.name,ring,label:project([source.f.properties.LABEL_X||0,source.f.properties.LABEL_Y||0],wrap)});}
 }
 const coast=[],borders=[];
 const raw=item.main;let chain=[],kind=null;
 const flush=()=>{if(chain.length>1)(kind?'borders':'coast')==='borders'?borders.push(chain):coast.push(chain);chain=[];};
 const normalized=point=>{const [lon,lat]=point;return [lon>180?lon-360:lon< -180?lon+360:lon,lat];};
 for(let i=0;i<raw.length;i++){const land=(owners.get(edge(normalized(raw[i]),normalized(raw[(i+1)%raw.length])))?.size||0)>1;if(kind!==null&&land!==kind)flush();kind=land;if(!chain.length)chain.push(project(raw[i]));chain.push(project(raw[(i+1)%raw.length]));}flush();
 result.countries[c.id]={lands,coast,borders};
}
fs.writeFileSync(path.join(root,'assets/maps/country-context.json'),JSON.stringify(result));
console.log(`Generated country context for ${Object.keys(result.countries).length} countries.`);
