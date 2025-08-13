enum SimulationMode {
  singleCycle('Single-Cycle'),
  pipeline('Pipeline'),
  multiCycle('Multi-Cycle');

  const SimulationMode(this.label);
  final String label;
}