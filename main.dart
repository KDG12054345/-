import 'package:flutter/material.dart';
import 'app/app_wrapper.dart';

// QA 환경 플래그 (빌드 시 --dart-define=IS_QA=true로 설정)
const bool isQA = bool.fromEnvironment('IS_QA');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppWrapper();
  }
}