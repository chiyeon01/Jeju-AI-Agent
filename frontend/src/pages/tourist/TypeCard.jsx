export default function TypeCard({ profile, showTrip = true }) {
  return (
    <div className="type-card">
      <span className="small">나의 제주 여행 유형 · {profile.code}</span>
      <h2>{profile.name}</h2>
      <p className="small">{profile.desc}</p>
      <p className="small">{[profile.tags.join(' · '), ...(showTrip ? [profile.companion, profile.transport, profile.endTime ? `${profile.startTime}~${profile.endTime}` : null] : [])].filter(Boolean).join(' · ')}</p>
    </div>
  );
}
