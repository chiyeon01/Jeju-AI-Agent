export default function TypeCard({ profile, showTrip = true }) {
  const trip = showTrip ? [profile.companion, profile.transport, profile.endTime ? `${profile.startTime}~${profile.endTime}` : null].filter(Boolean) : [];
  return (
    <div className="type-card">
      <span className="code">나의 제주 여행 유형 · {profile.code}</span>
      <h2>{profile.name}</h2>
      <p className="small">{profile.desc}</p>
      <div className="tags">
        {(profile.tags ?? []).map((t) => <span key={t}>#{t}</span>)}
        {trip.map((t) => <span key={t}>{t}</span>)}
      </div>
    </div>
  );
}
