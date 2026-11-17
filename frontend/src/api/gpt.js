// ─────────────────────────────────────────────
// GPT 호출은 모두 백엔드를 거칩니다. 웹은 OpenAI 키를 갖지 않습니다.
//  - 프롬프트(src/prompts/*.md)는 웹에서 만들고, 백엔드 /tourist/ai/json 으로 보내면
//    백엔드가 자기 OPENAI_API_KEY 로 GPT 에 물어 JSON 답을 돌려줍니다.
//  - 백엔드에 이 API 가 아직 없거나(목업 모드 포함) GPT 가 꺼져 있으면 gptAvailable() 이 false 이고,
//    화면은 기존 /tourist/course, /tourist/course/chat (백엔드 GPT 대화) 를 씁니다.
// ─────────────────────────────────────────────
import { aiStatus, aiJson } from './client.js';

let serverOn = null;

/** 백엔드 GPT 중계를 쓸 수 있는지 (한 번만 확인) */
export function gptAvailable() {
  if (serverOn === null) serverOn = aiStatus().then((r) => Boolean(r?.enabled));
  return serverOn;
}

/** 프롬프트를 백엔드로 보내 GPT 의 JSON 답을 받습니다. 실패하면 Error */
export async function chatJson(system, user, { purpose = 'course_plan', temperature = 0.8 } = {}) {
  if (!(await gptAvailable())) throw new Error('백엔드 GPT 를 쓸 수 없어요');
  return aiJson(purpose, system, user, temperature);
}
