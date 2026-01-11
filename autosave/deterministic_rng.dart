import 'dart:math';
import 'dart:convert';

int _seedFromContext({
  required String runId,
  required String chapterId,
  required String choiceId,
  required int commitIndex,
}) {
  final s = '$runId|$chapterId|$choiceId|$commitIndex';
  const int prime = 0x01000193;
  int hash = 0x811C9DC5;
  for (final b in utf8.encode(s)) {
    hash ^= b;
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash;
}

class DeterministicRNG {
  static Random fromContext({
    required String runId,
    required String chapterId,
    required String choiceId,
    required int commitIndex,
  }) {
    return Random(_seedFromContext(
      runId: runId,
      chapterId: chapterId,
      choiceId: choiceId,
      commitIndex: commitIndex,
    ));
  }
}
