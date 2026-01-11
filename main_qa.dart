import 'package:flutter/material.dart';
import 'inventory/inventory_system.dart';
import 'inventory/bag.dart';
import 'qa/inventory_diagnostic.dart';
import 'qa/inventory_qa_commands.dart';
import 'qa/inventory_qa_scenarios.dart';

/// QA 환경용 진입점
/// 
/// 이 파일은 인벤토리/가방 시스템 QA 테스트를 실행합니다.
/// 
/// 사용 예시:
/// ```bash
/// flutter run -t lib/main_qa.dart
/// ```
void main() {
  // Headless 테스트 실행 (콘솔 출력)
  runInventoryQaTests();
  
  // Flutter UI 앱 실행 (선택적)
  runApp(const QaApp());
}

/// 콘솔 기반 인벤토리 QA 테스트 실행
void runInventoryQaTests() {
  print('');
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║     Fantasy Life - Inventory/Bag System QA Test Runner      ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
  
  // 테스트용 InventorySystem 생성 (시작 가방 없이)
  final inventory = InventorySystem(
    width: 9,
    height: 6,
    initWithStarterBags: false,
  );
  
  // 전체 QA 테스트 실행
  final scenarios = InventoryQaScenarios(inventory);
  scenarios.qaRunAllTests();
  
  // 정리
  inventory.dispose();
}

/// Flutter UI 기반 QA 앱
class QaApp extends StatelessWidget {
  const QaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fantasy Life QA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const QaTestScreen(),
    );
  }
}

/// QA 테스트 화면
class QaTestScreen extends StatefulWidget {
  const QaTestScreen({super.key});

  @override
  State<QaTestScreen> createState() => _QaTestScreenState();
}

class _QaTestScreenState extends State<QaTestScreen> {
  late InventorySystem _inventory;
  late InventoryQaCommands _qa;
  String _logOutput = '';
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _inventory = InventorySystem(
      width: 9,
      height: 6,
      initWithStarterBags: false,
    );
    _qa = InventoryQaCommands(_inventory);
    _appendLog('QA Test Harness 초기화 완료\n');
  }
  
  @override
  void dispose() {
    _inventory.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _appendLog(String text) {
    setState(() {
      _logOutput += text;
    });
    // 스크롤 맨 아래로
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _clearLog() {
    setState(() {
      _logOutput = '';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Inventory QA Test Harness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '로그 지우기',
            onPressed: _clearLog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 명령어 버튼들
          _buildCommandButtons(),
          
          const Divider(height: 1),
          
          // 로그 출력 영역
          Expanded(
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectableText(
                  _logOutput,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.lightGreenAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommandButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // 전체 테스트 실행
          ElevatedButton.icon(
            onPressed: _runAllTests,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run All Tests'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 초기화 명령
          _buildButton('Reset', Icons.refresh, () {
            _qa.qaResetInventory();
            _appendLog('[CMD] Reset Inventory\n');
            _qa.qaDump();
          }),
          
          _buildButton('Reset to Starter', Icons.home, () {
            _qa.qaResetToStarter();
            _appendLog('[CMD] Reset to Starter Bags\n');
            _qa.qaDump();
          }),
          
          // 가방 장착 명령
          _buildButton('+Basic', Icons.add_box, () {
            _qa.qaEquipBag(BagType.basic);
            _appendLog('[CMD] Equip Basic Bag\n');
          }),
          
          _buildButton('+Large', Icons.add_box_outlined, () {
            _qa.qaEquipBag(BagType.large);
            _appendLog('[CMD] Equip Large Bag\n');
          }),
          
          _buildButton('+Damaged', Icons.broken_image, () {
            _qa.qaEquipBag(BagType.damaged);
            _appendLog('[CMD] Equip Damaged Bag\n');
          }),
          
          _buildButton('+Pouch', Icons.shopping_bag, () {
            _qa.qaEquipBag(BagType.pouch);
            _appendLog('[CMD] Equip Pouch\n');
          }),
          
          _buildButton('-Last Bag', Icons.remove_circle, () {
            _qa.qaUnequipBag();
            _appendLog('[CMD] Unequip Last Bag\n');
          }),
          
          // 아이템 명령
          _buildButton('+Item A', Icons.inventory_2, () {
            _qa.qaAddTestItem(itemType: 'A');
            _appendLog('[CMD] Add Item A\n');
          }),
          
          _buildButton('+Item B', Icons.inventory_2, () {
            _qa.qaAddTestItem(itemType: 'B');
            _appendLog('[CMD] Add Item B\n');
          }),
          
          _buildButton('+Item C', Icons.inventory_2, () {
            _qa.qaAddTestItem(itemType: 'C');
            _appendLog('[CMD] Add Item C\n');
          }),
          
          // 진단 명령
          _buildButton('Dump', Icons.bug_report, () {
            final output = _qa.qaDump();
            _appendLog(output);
          }),
          
          _buildButton('Quick Status', Icons.info, () {
            final status = _qa.qaQuickStatus();
            _appendLog('$status\n');
          }),
        ],
      ),
    );
  }
  
  Widget _buildButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
  
  void _runAllTests() {
    _clearLog();
    _appendLog('═══ QA_RunAllInventoryBagTests 시작 ═══\n\n');
    
    // 테스트용 인벤토리 재생성
    _inventory.dispose();
    _inventory = InventorySystem(
      width: 9,
      height: 6,
      initWithStarterBags: false,
    );
    _qa = InventoryQaCommands(_inventory);
    
    final scenarios = InventoryQaScenarios(_inventory);
    final summary = scenarios.qaRunAllTests();
    
    _appendLog('\n$summary');
  }
}
