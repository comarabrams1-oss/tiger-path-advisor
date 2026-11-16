enum AcademicSeason { spring, summer, fall }

class AcademicTerm implements Comparable<AcademicTerm> {
  final AcademicSeason season;
  final int year;
  const AcademicTerm(this.season, this.year);

  static const demoTerm = AcademicTerm(AcademicSeason.fall, 2026);
  static const firstPlanningTerm = AcademicTerm(AcademicSeason.spring, 2027);

  static AcademicTerm? parse(String text) {
    final match = RegExp(
      r'\b(spring|summer|fall)\s+(20\d{2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    return AcademicTerm(
      AcademicSeason.values.byName(match[1]!.toLowerCase()),
      int.parse(match[2]!),
    );
  }

  AcademicTerm get next => season == AcademicSeason.fall
      ? AcademicTerm(AcademicSeason.spring, year + 1)
      : AcademicTerm(AcademicSeason.fall, year);

  String get label =>
      '${season.name[0].toUpperCase()}${season.name.substring(1)} $year';
  String get portalKey => switch (season) {
    AcademicSeason.fall => '$year-${year + 1} - Fall',
    AcademicSeason.spring => '${year - 1}-$year - Spring',
    AcademicSeason.summer => '${year - 1}-$year - Summer',
  };

  int get _order => year * 3 + season.index;
  @override
  int compareTo(AcademicTerm other) => _order.compareTo(other._order);
  @override
  bool operator ==(Object other) =>
      other is AcademicTerm && _order == other._order;
  @override
  int get hashCode => _order.hashCode;
}
