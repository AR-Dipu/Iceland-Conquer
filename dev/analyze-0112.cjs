const fs = require('fs');
const rows = JSON.parse(fs.readFileSync('docs/contested-0.1.12.json'));
const median = a => a.sort((x,y)=>x-y)[Math.floor(a.length/2)];
const total = (a,k) => a.reduce((s,r)=>s+r[k],0);
const old = rows.filter(r=>r.baseline), now = rows.filter(r=>!r.baseline);
const countries = [...new Set(rows.map(r=>r.country))].map(country => {
 const a=old.filter(r=>r.country===country),b=now.filter(r=>r.country===country);
 return {country, baseline_net_land:median(a.map(r=>r.net_land)),hunter_net_land:median(b.map(r=>r.net_land)),baseline_cuts:total(a,'cuts'),hunter_cuts:total(b,'cuts'),baseline_survival:median(a.map(r=>r.surviving_bots)),hunter_survival:median(b.map(r=>r.surviving_bots))};
});
const report={scenarios:rows.length,seconds_each:120,seeds:[190,7016,111],countries,baseline_cuts:total(old,'cuts'),hunter_cuts:total(now,'cuts'),baseline_abandoned:total(old,'abandoned'),hunter_abandoned:total(now,'abandoned'),baseline_wins:old.filter(r=>r.winner>0).length,hunter_wins:now.filter(r=>r.winner>0).length,baseline_reverse_by_action:{},hunter_reverse_by_action:{}};
for(const key of ['expand','attack','defend','recover']) for(const [mode,set] of [['baseline',old],['hunter',now]]) report[mode+'_reverse_by_action'][key]=set.reduce((s,r)=>s+r.reverse_by_action[key],0);
report.cuts_improvement=report.hunter_cuts/report.baseline_cuts-1;
report.cuts_gate=report.cuts_improvement>=.2;
report.no_country_land_regression=countries.every(r=>r.hunter_net_land>=r.baseline_net_land);
const read = file => fs.existsSync('docs/'+file) ? JSON.parse(fs.readFileSync('docs/'+file)) : null;
const captures=read('capture-performance-0.1.12.json');
if(captures){
 report.matched_capture={cases:captures.cases,baseline_p95_us:captures.baseline_p95_us,after_p95_us:captures.after_p95_us,improvement:1-captures.after_p95_us/captures.baseline_p95_us};
 report.capture_gate=report.matched_capture.improvement>=.3;
}
const beforeFrames=read('frame-pacing-0.1.12-baseline.json'),afterFrames=read('frame-pacing-0.1.12-after.json');
if(beforeFrames&&afterFrames){
 report.rendered_pacing={baseline_p95_ms:beforeFrames.p95_ms,after_p95_ms:afterFrames.p95_ms,improvement:1-afterFrames.p95_ms/beforeFrames.p95_ms};
 report.render_gate=report.rendered_pacing.improvement>=.3;
}
const beforeCPU=read('performance-0.1.12-baseline.json'),afterCPU=read('performance-0.1.12-after.json');
if(beforeCPU&&afterCPU) report.full_game_cpu={baseline_p95_ms:beforeCPU.p95_cpu_ms,after_p95_ms:afterCPU.p95_cpu_ms,note:'Same seeded Hard workload; different AI decisions and wall-clock planning slices can produce different subsequent ownership/capture workloads. Use the matched-input corpus for isolated capture cost.'};
fs.writeFileSync('docs/gates-0.1.12.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
