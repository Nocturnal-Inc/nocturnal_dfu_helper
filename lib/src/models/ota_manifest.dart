class OTAManifest {
  final String left;
  final String right;
  final String main;
  final String timestamp;
  final String version;

  OTAManifest({
    required this.left,
    required this.right,
    required this.main,
    required this.timestamp,
    required this.version,
  });

  factory OTAManifest.fromJson(Map<String, dynamic> json) {
    return OTAManifest(
      left: json['left'],
      right: json['right'],
      main: json['main'],
      timestamp: json['timestamp'],
      version: json['version'],
    );
  }

  @override
  String toString() {
    return 'OTAManifest(left: $left, right: $right, main: $main, timestamp: $timestamp, version: $version)';
  }
}
