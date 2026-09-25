function weakest_route(bolts, battle) {
  return bolts.map((bolt) => bolt.ward ? bolt : { ...bolt, target: 'weakest' });
}
