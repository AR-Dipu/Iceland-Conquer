const fs = require('fs');
const read = file => JSON.parse(fs.readFileSync('docs/' + file));
const current = read('contested-0.1.13.json');
const previous = read('contested-0.1.12.json').filter(row => !row.baseline);
const baseline = current.filter(row => row.baseline);
const candidate = current.filter(row => !row.baseline);
const median = values => values.sort((a, b) => a - b)[Math.floor(values.length / 2)];
const sum = (rows, field) => rows.reduce((total, row) => total + row[field], 0);
const countries = ['bgd', 'ind', 'lka', 'jpn', 'isl'].map(country => {
  const land = rows => median(rows.filter(row => row.country === country).map(row => row.net_land));
  return {country, baseline: land(baseline), previous: land(previous), candidate: land(candidate)};
});
const metrics = rows => ({
  cuts: sum(rows, 'cuts'),
  survivors: sum(rows, 'surviving_bots'),
  abandoned: sum(rows, 'abandoned'),
  wins: rows.filter(row => row.winner > 0).length,
  expansion_reverse: rows.reduce((total, row) => total + row.reverse_by_action.expand, 0),
});
const result = {scenarios: current.length, countries, baseline: metrics(baseline), previous: metrics(previous), candidate: metrics(candidate)};
result.land_gate = countries.every(row => row.candidate >= (row.country === 'jpn' ? row.previous : row.baseline));
result.cuts_gate = result.candidate.cuts >= result.baseline.cuts * 1.2;
result.reverse_gate = result.candidate.expansion_reverse <= result.previous.expansion_reverse;
fs.writeFileSync('docs/ai-gates-0.1.13.json', JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
