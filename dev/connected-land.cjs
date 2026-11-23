const normalizeDelta = value => ((value + 540) % 360) - 180;
const RAD = Math.PI / 180;

function unwrap(ring) {
  const output = [ring[0]];
  for (const [lon, lat] of ring.slice(1)) {
    const previous = output.at(-1)[0];
    output.push([previous + normalizeDelta(lon - previous), lat]);
  }
  return output;
}

function geographicArea(ring) {
  let integral = 0;
  for (let i = 0; i < ring.length; i++) {
    const [lon, lat] = ring[i];
    const [nextLon, nextLat] = ring[(i + 1) % ring.length];
    const delta = (nextLat - lat) * RAD;
    const midpoint = (nextLat + lat) * RAD / 2;
    const averageSin = Math.sin(midpoint) * (delta ? Math.sin(delta / 2) / (delta / 2) : 1);
    integral += normalizeDelta(nextLon - lon) * RAD * averageSin;
  }
  return Math.abs(integral);
}

function edgesAtSeam(ring) {
  return ring.flatMap((a, i) => {
    const b = ring[(i + 1) % ring.length];
    return Math.abs(a[0]) === 180 && a[0] === b[0] && a[1] !== b[1] ? [{ i, a, b }] : [];
  });
}

function connectedRings(source) {
  const rings = source.slice();
  // The pinned dataset splits Russia and Fiji at matching antimeridian edges.
  // Stitch opposite copies of a shared land seam before ranking components.
  for (let i = 0; i < rings.length; i++) {
    for (let j = i + 1; j < rings.length; j++) {
      const a = rings[i], b = rings[j];
      let pair;
      for (const left of edgesAtSeam(a)) {
        const right = edgesAtSeam(b).find(edge => edge.a[0] === -left.a[0] &&
          edge.b[1] === left.a[1] && edge.a[1] === left.b[1]);
        if (right) { pair = [left, right]; break; }
      }
      if (!pair) continue;
      const [left, right] = pair;
      const walk = (ring, edge) => [...ring.slice(edge.i + 1), ...ring.slice(0, edge.i + 1)];
      const shift = left.a[0] - right.a[0];
      rings[i] = [...walk(a, left), ...walk(b, right).slice(1, -1).map(([lon, lat]) => [lon + shift, lat])];
      rings.splice(j, 1);
      j = i;
    }
  }
  return rings.map(unwrap).sort((a, b) => geographicArea(b) - geographicArea(a));
}

function alignRing(ring, meridian) {
  const shift = Math.round((meridian - ring[0][0]) / 360) * 360;
  return ring.map(([lon, lat]) => [lon + shift, lat]);
}

module.exports = { geographicArea, connectedRings, alignRing };
