// Agent 가 쓴 짧은 마크다운(제목 ##, 글머리표 -, 굵게 **)만 안전하게 그립니다. HTML 은 그대로 글자로 보여 줍니다.
function inline(text, key) {
  return text.split(/(\*\*[^*]+\*\*)/g).map((part, i) => (
    part.startsWith('**') && part.endsWith('**') && part.length > 4
      ? <b key={`${key}-${i}`}>{part.slice(2, -2)}</b>
      : part
  ));
}

export default function Markdown({ text }) {
  const blocks = [];
  let items = [];
  const flush = () => {
    if (items.length) blocks.push(<ul key={`u${blocks.length}`} className="md-list">{items}</ul>);
    items = [];
  };
  String(text ?? '').split('\n').forEach((raw, i) => {
    const line = raw.trim();
    if (!line) { flush(); return; }
    const h = line.match(/^#{1,4}\s+(.*)/);
    const li = line.match(/^(?:[-*•]|\d+[.)])\s+(.*)/);
    if (h) { flush(); blocks.push(<h4 key={i} className="md-h">{inline(h[1], i)}</h4>); }
    else if (li) items.push(<li key={i}>{inline(li[1], i)}</li>);
    else { flush(); blocks.push(<p key={i} className="md-p">{inline(line, i)}</p>); }
  });
  flush();
  return <div className="md">{blocks}</div>;
}
