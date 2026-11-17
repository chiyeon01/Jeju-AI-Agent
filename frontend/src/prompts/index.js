// ─────────────────────────────────────────────
// GPT 프롬프트 모음
// 프롬프트 문장은 이 폴더의 .md 파일에 있습니다. 말투나 규칙을 바꿀 때는 .md 만 고치면 됩니다.
//   render('course_plan', { context: '...', variation: '...' })
// .md 안의 {{이름}} 은 넘긴 값으로 바뀌고, 맨 위 <!-- --> 주석은 GPT 에 보내지 않습니다.
// ─────────────────────────────────────────────
import context from './context.md?raw';
import coursePlan from './course_plan.md?raw';
import courseChat from './course_chat.md?raw';

const FILES = { context, course_plan: coursePlan, course_chat: courseChat };

export function render(name, values) {
  const text = FILES[name].replace(/^\s*<!--[\s\S]*?-->\s*/, '').trim();
  return text.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, k) => {
    if (!(k in values)) throw new Error(`프롬프트 ${name}.md 에 값이 없는 변수가 있어요: ${k}`);
    return String(values[k]);
  });
}
