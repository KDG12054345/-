import '../dialogue_manager.dart';
import 'autosave_dialogue_manager.dart';

DialogueManager createDialogueManager() {
  return AutosaveDialogueManager();
}
