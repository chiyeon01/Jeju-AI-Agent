// ─────────────────────────────────────────────
// GPT 호출은 모두 백엔드를 거칩니다. 앱은 OpenAI 키를 갖지 않습니다.
//  - 프롬프트(assets/prompts/*.md)는 앱에서 만들고, 백엔드 /tourist/ai/json 으로 보내면
//    백엔드가 자기 OPENAI_API_KEY 로 GPT 에 물어 JSON 답을 돌려줍니다.
//  - 백엔드에 이 API 가 아직 없거나(목업 모드 포함) GPT 가 꺼져 있으면 gptAvailable() 이 false 이고,
//    화면은 기존 /tourist/course, /tourist/course/chat (백엔드 GPT 대화) 를 씁니다.
// ─────────────────────────────────────────────
import 'client.dart' show aiStatus, aiJson;

/// (purpose, system, user, temperature) → GPT 의 JSON 답. 테스트에서 바꿔 끼울 수 있습니다
typedef GptAsk = Future<Map<String, dynamic>> Function(String purpose, String system, String user, double temperature);

Future<bool>? _server;

/// 백엔드 GPT 중계를 쓸 수 있는지 (한 번만 확인)
Future<bool> gptAvailable() => _server ??= aiStatus();

/// 프롬프트를 백엔드로 보내 GPT 의 JSON 답을 받습니다
Future<Map<String, dynamic>> chatJson(String system, String user, {String purpose = 'course_plan', double temperature = 0.8}) =>
    aiJson(purpose, system, user, temperature);
