/// A single averaged mood reading for one day. Used by today_providers and by the chart widget
/// (implemented in the UI layer). Kept here so the provider has a stable type without importing
/// the chart widget.
class MoodPoint {
  const MoodPoint(this.day, this.value);

  final DateTime day;
  final double value; // −2..2
}
