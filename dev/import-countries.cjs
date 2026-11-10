// Deterministic conversion of the pinned Natural Earth source. No network at runtime.
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const source = JSON.parse(fs.readFileSync(path.join(__dirname, 'country_boundaries.geojson'), 'utf8'));
const detailed = JSON.parse(fs.readFileSync(path.join(__dirname, 'country_boundaries_50m.geojson'), 'utf8'));
const ids = { BGD:'Bangladesh', IND:'India', LKA:'Sri Lanka', JPN:'Japan', ISL:'Iceland' };
const area = p => Math.abs(p.reduce((a,v,i)=>a+v[0]*p[(i+1)%p.length][1]-v[1]*p[(i+1)%p.length][0],0))/2;
const world = [], countries = [];
for (const f of source.features) {
 const polygons = f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates;
 const rings = polygons.map(p=>p[0].slice(0,-1));
 for(const ring of rings) if(area(ring)>0.15) world.push(ring.map(p=>p.map(n=>Number(n.toFixed(3)))));
 const code=f.properties.ADM0_A3;
 if (!ids[code]) continue;
 let countryRings = rings;
 if(code==='JPN') {
  const feature=detailed.features.find(f=>f.properties.ADM0_A3==='JPN');
  countryRings=feature.geometry.coordinates.map(p=>p[0].slice(0,-1));
 }
 const biggest=[...countryRings].sort((a,b)=>area(b)-area(a))[0];
 const latitude=(Math.min(...biggest.map(p=>p[1]))+Math.max(...biggest.map(p=>p[1])))/2;
 const distance=(p,a,b)=>{const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1)));return Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy);};
 const rdp=points=>{let max=0,index=0;for(let i=1;i<points.length-1;i++){const d=distance(points[i],points[0],points[points.length-1]);if(d>max){max=d;index=i;}}return max>0.025?[...rdp(points.slice(0,index+1)).slice(0,-1),...rdp(points.slice(index))]:[points[0],points[points.length-1]];};
 const simplify=ring=>{const middle=Math.floor(ring.length/2);return [...rdp(ring.slice(0,middle+1)).slice(0,-1),...rdp([...ring.slice(middle),ring[0]]).slice(0,-1)];};
 if(code==='JPN') countryRings=countryRings.sort((a,b)=>area(b)-area(a)).slice(0,4).map(simplify);

 const projected=countryRings.map(p=>p.map(v=>[v[0]*Math.cos(latitude*Math.PI/180),-v[1]]));
 projected.sort((a,b)=>area(b)-area(a));
 const primary=projected[0];
 const minX=Math.min(...primary.map(p=>p[0])),minY=Math.min(...primary.map(p=>p[1]));
 const width=Math.max(...primary.map(p=>p[0]))-minX,height=Math.max(...primary.map(p=>p[1]))-minY;
 const factor=2400/Math.max(width,height);
 const normalize=ring=>ring.map(p=>[Number(((p[0]-minX)*factor).toFixed(3)),Number(((p[1]-minY)*factor).toFixed(3))]);
 countries.push({id:code.toLowerCase(),name:ids[code],outline:normalize(primary),decorative_islands:code==='JPN'?projected.slice(1).map(normalize):[],longitude:f.properties.LABEL_X,latitude:f.properties.LABEL_Y,mainland_name:code==='JPN'?'Honshu':ids[code],mainland_latitude_min:Math.min(...biggest.map(p=>p[1]))});
}
countries.sort((a,b)=>Object.keys(ids).indexOf(a.id.toUpperCase())-Object.keys(ids).indexOf(b.id.toUpperCase()));
fs.writeFileSync(path.join(root,'assets/maps/countries.json'),JSON.stringify(countries));
fs.writeFileSync(path.join(root,'assets/maps/world.json'),JSON.stringify(world));
console.log(countries.map(c=>c.name+': '+c.outline.length+' coast vertices').join('\n'));
