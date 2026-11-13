import { AXES } from '../../mock/tourist.js';

export default function TypeCard({ profile, compact }) {
  return (
    <div className="type-card">
      <div>
        <p className="eyebrow" style={{ color: 'inherit', opacity: .7 }}>나의 제주 여행 유형 · {profile.code}</p>
        <h2 style={{ marginTop: 4 }}>{profile.name}</h2>
        {!compact && <p style={{ opacity: .85, marginTop: 6 }}>{profile.desc}</p>}
      </div>
      {!compact && (
        <div className="stack" style={{ gap: 10 }}>
          {AXES.map((a) => {
            const v = profile.scores[a.key];
            return (
              <div className="axis" key={a.key}>
                <span className={v <= 0 ? 'strong' : ''}>{a.left}</span>
                <span className="meter"><i style={{ left: `${(v + 100) / 2}%` }} /></span>
                <span className={`r ${v > 0 ? 'strong' : ''}`}>{a.right}</span>
              </div>
            );
          })}
        </div>
      )}
      <div className="row small" style={{ gap: 8 }}>
        {profile.tags.map((t) => <span key={t} style={{ opacity: .85 }}>{t}</span>)}
        <span style={{ opacity: .6 }}>· {profile.companion} · {profile.transport} · {profile.budget}</span>
      </div>
    </div>
  );
}
