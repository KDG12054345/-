// Health-check utilities for the game core.
// P0: 스켈레톤 – P0.5에서 실제 자원 검사 로직이 연결됩니다.

class HealthReport {
  final bool ok;
  final String? message;

  const HealthReport(this.ok, [this.message]);
}

class HealthCheck {
  /// 간단한 스텁(stub) – 이후 실제 자원 검사 로직이 연결됩니다.
  Future<HealthReport> run() async {
    // TODO(P0.5): 에셋·폰트·데이터 무결성 검사 구현
    return const HealthReport(true);
  }
}


