// Countries, major states/provinces and cities for the employee location
// pickers. Focused on where Hyundai Mobis has R&D centres, plants and
// offices; "Other city" in the form covers anything missing.
//
// Later this list can come from the API (GET /api/reference/locations) so
// HRD can extend it without an app release.

class LocationCatalog {
  LocationCatalog._();

  /// Country → state/province → major cities.
  static const Map<String, Map<String, List<String>>> data = {
    'India': {
      'Telangana': ['Hyderabad', 'Warangal'],
      'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru'],
      'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Sriperumbudur'],
      'Andhra Pradesh': ['Anantapur', 'Visakhapatnam', 'Vijayawada'],
      'Maharashtra': ['Pune', 'Mumbai', 'Nagpur'],
      'Haryana': ['Gurugram', 'Faridabad'],
      'Delhi': ['New Delhi'],
      'Uttar Pradesh': ['Noida', 'Lucknow'],
      'Kerala': ['Kochi', 'Thiruvananthapuram'],
      'Gujarat': ['Ahmedabad', 'Vadodara'],
      'West Bengal': ['Kolkata'],
    },
    'South Korea': {
      'Seoul': ['Seoul'],
      'Gyeonggi-do': ['Yongin', 'Suwon', 'Seongnam', 'Uiwang', 'Hwaseong'],
      'Chungcheongnam-do': ['Cheonan', 'Asan', 'Seosan'],
      'Ulsan': ['Ulsan'],
      'Incheon': ['Incheon'],
      'Daejeon': ['Daejeon'],
      'Gyeongsangbuk-do': ['Gyeongju', 'Pohang'],
    },
    'United States': {
      'Michigan': ['Plymouth', 'Detroit', 'Farmington Hills'],
      'Alabama': ['Montgomery'],
      'Georgia': ['West Point', 'Atlanta'],
      'California': ['Fountain Valley', 'Irvine', 'San Jose'],
    },
    'Germany': {
      'Hesse': ['Frankfurt am Main', 'Eschborn'],
      'Bavaria': ['Munich'],
      'Baden-Württemberg': ['Stuttgart'],
    },
    'China': {
      'Jiangsu': ['Yancheng', 'Wuxi'],
      'Shanghai': ['Shanghai'],
      'Beijing': ['Beijing'],
      'Tianjin': ['Tianjin'],
    },
    'Czech Republic': {
      'Moravian-Silesian Region': ['Ostrava', 'Mošnov'],
    },
    'Slovakia': {
      'Žilina Region': ['Žilina'],
    },
    'Mexico': {
      'Nuevo León': ['Monterrey', 'Pesquería'],
    },
    'Brazil': {
      'São Paulo': ['Piracicaba', 'São Paulo'],
    },
    'Vietnam': {
      'Hanoi': ['Hanoi'],
      'Ho Chi Minh City': ['Ho Chi Minh City'],
    },
    'Turkey': {
      'Kocaeli': ['İzmit'],
    },
  };

  static List<String> get countries => data.keys.toList();

  static List<String> statesOf(String country) => data[country]?.keys.toList() ?? const [];

  static List<String> citiesOf(String country, String state) =>
      data[country]?[state] ?? const [];

  /// The country with this name, ignoring case ("india" → "India").
  static String? matchCountry(String value) => _match(countries, value);

  static String? matchState(String country, String value) => _match(statesOf(country), value);

  static String? matchCity(String country, String state, String value) =>
      _match(citiesOf(country, state), value);

  static String? _match(List<String> options, String value) {
    final key = value.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final o in options) {
      if (o.toLowerCase() == key) return o;
    }
    return null;
  }
}
